#!/bin/bash
set -euo pipefail

echo "=== Docker Proxy Configuration Script ==="

# Check if running as root
if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

# Function to backup existing config
backup_config() {
    if [[ -f /etc/docker/daemon.json ]]; then
        cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
        echo "Backed up existing daemon.json"
    fi
}

# Function to create proxy config
create_proxy_config() {
    local proxy_host="$1"
    local proxy_port="$2"
    local proxy_user="${3:-}"
    local proxy_pass="${4:-}"
    
    backup_config
    
    cat > /etc/docker/daemon.json << EOF
{
  "dns": ["8.8.8.8", "8.8.4.4"],
  "ipv6": false,
  "registry-mirrors": [],
  "proxies": {
    "http-proxy": "http://${proxy_host}:${proxy_port}",
    "https-proxy": "http://${proxy_host}:${proxy_port}",
    "no-proxy": "localhost,127.0.0.1,::1"
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

    echo "Created proxy configuration"
}

# Function to create non-proxy config
create_non_proxy_config() {
    backup_config
    
    cat > /etc/docker/daemon.json << EOF
{
  "dns": ["8.8.8.8", "8.8.4.4"],
  "ipv6": false,
  "registry-mirrors": [],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

    echo "Created non-proxy configuration"
}

echo "Choose configuration type:"
echo "1. Configure with proxy (for corporate environments)"
echo "2. Configure without proxy (direct internet access)"
echo "3. Exit"

read -p "Enter choice (1-3): " choice

case $choice in
    1)
        read -p "Enter proxy host: " proxy_host
        read -p "Enter proxy port: " proxy_port
        read -p "Enter proxy username (optional): " proxy_user
        read -p "Enter proxy password (optional): " proxy_pass
        
        if [[ -n "$proxy_user" && -n "$proxy_pass" ]]; then
            create_proxy_config "${proxy_host}:${proxy_user}:${proxy_pass}@" "${proxy_port}"
        else
            create_proxy_config "$proxy_host" "$proxy_port"
        fi
        ;;
    2)
        create_non_proxy_config
        ;;
    3)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo -e "\nRestarting Docker daemon..."
systemctl restart docker

echo -e "\nTesting Docker connectivity..."
if docker pull hello-world >/dev/null 2>&1; then
    echo "✓ Docker connectivity test successful"
else
    echo "✗ Docker connectivity test failed"
    echo "Check the configuration and try again"
fi
