#!/bin/bash
set -euo pipefail

echo "=== Docker Network Troubleshooting Script ==="

# Check if running as root
if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

echo "1. Checking Docker daemon status..."
systemctl status docker --no-pager -l

echo -e "\n2. Checking Docker daemon configuration..."
if [[ -f /etc/docker/daemon.json ]]; then
    echo "Current daemon.json:"
    cat /etc/docker/daemon.json
else
    echo "No daemon.json found"
fi

echo -e "\n3. Testing basic connectivity..."
if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
    echo "✓ Internet connectivity OK"
else
    echo "✗ Internet connectivity failed"
fi

echo -e "\n4. Testing DNS resolution..."
if nslookup registry-1.docker.io >/dev/null 2>&1; then
    echo "✓ DNS resolution OK"
else
    echo "✗ DNS resolution failed"
fi

echo -e "\n5. Testing Docker Hub connectivity..."
if curl -s --connect-timeout 10 https://registry-1.docker.io/v2/ >/dev/null 2>&1; then
    echo "✓ Docker Hub connectivity OK"
else
    echo "✗ Docker Hub connectivity failed"
fi

echo -e "\n6. Checking Docker daemon logs..."
journalctl -u docker --no-pager -n 20

echo -e "\n=== Recommended Actions ==="
echo "If connectivity issues persist:"
echo "1. Copy docker-daemon.json to /etc/docker/daemon.json"
echo "2. Restart Docker: sudo systemctl restart docker"
echo "3. Try pulling a simple image: docker pull hello-world"
echo "4. If still failing, check corporate proxy settings"
