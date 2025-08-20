#!/bin/bash
set -euo pipefail

echo "=== Docker Certificate Troubleshooting Script ==="

# Check if running as root
if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

echo "1. Checking current Docker daemon configuration..."
if [[ -f /etc/docker/daemon.json ]]; then
    echo "Current daemon.json:"
    cat /etc/docker/daemon.json
else
    echo "No daemon.json found"
fi

echo -e "\n2. Checking for corporate certificates..."
if [[ -d /usr/local/share/ca-certificates ]]; then
    echo "Found certificates in /usr/local/share/ca-certificates:"
    ls -la /usr/local/share/ca-certificates/
fi

if [[ -d /etc/ssl/certs ]]; then
    echo "Found certificates in /etc/ssl/certs:"
    ls -la /etc/ssl/certs/ | grep -E "(corp|company|proxy)" || echo "No obvious corporate certificates found"
fi

echo -e "\n3. Testing certificate chain..."
if command -v openssl >/dev/null 2>&1; then
    echo "Testing connection to Docker Hub:"
    echo | openssl s_client -connect registry-1.docker.io:443 -servername registry-1.docker.io 2>/dev/null | openssl x509 -noout -subject -issuer || echo "Certificate test failed"
else
    echo "openssl not available for certificate testing"
fi

echo -e "\n4. Checking system certificate store..."
if [[ -f /etc/ca-certificates.conf ]]; then
    echo "System CA certificates configuration found"
fi

echo -e "\n=== Certificate Fix Options ==="
echo "Choose an option:"
echo "1. Add Docker Hub to insecure registries (temporary fix)"
echo "2. Configure corporate proxy with certificates"
echo "3. Update system CA certificates"
echo "4. Exit"

read -p "Enter choice (1-4): " choice

case $choice in
    1)
        echo "Adding Docker Hub to insecure registries..."
        if [[ -f /etc/docker/daemon.json ]]; then
            # Backup existing config
            cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
            
            # Update the insecure-registries array
            jq '.insecure-registries = ["registry-1.docker.io"]' /etc/docker/daemon.json > /etc/docker/daemon.json.tmp
            mv /etc/docker/daemon.json.tmp /etc/docker/daemon.json
        else
            cat > /etc/docker/daemon.json << EOF
{
  "dns": ["8.8.8.8", "8.8.4.4"],
  "ipv6": false,
  "insecure-registries": ["registry-1.docker.io"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
        fi
        echo "Configuration updated. Restarting Docker..."
        systemctl restart docker
        ;;
    2)
        echo "Corporate proxy configuration..."
        read -p "Enter proxy host: " proxy_host
        read -p "Enter proxy port: " proxy_port
        read -p "Enter proxy username (optional): " proxy_user
        read -p "Enter proxy password (optional): " proxy_pass
        
        # Create proxy config with certificate handling
        cat > /etc/docker/daemon.json << EOF
{
  "dns": ["8.8.8.8", "8.8.4.4"],
  "ipv6": false,
  "proxies": {
    "http-proxy": "http://${proxy_host}:${proxy_port}",
    "https-proxy": "http://${proxy_host}:${proxy_port}",
    "no-proxy": "localhost,127.0.0.1,::1"
  },
  "insecure-registries": ["registry-1.docker.io"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
        echo "Proxy configuration created. Restarting Docker..."
        systemctl restart docker
        ;;
    3)
        echo "Updating system CA certificates..."
        update-ca-certificates --fresh
        echo "CA certificates updated. Restarting Docker..."
        systemctl restart docker
        ;;
    4)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo -e "\nTesting Docker connectivity..."
if docker pull hello-world >/dev/null 2>&1; then
    echo "✓ Docker connectivity test successful"
else
    echo "✗ Docker connectivity test failed"
    echo "Try option 1 (insecure registries) if you're in a corporate environment"
fi
