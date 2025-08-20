# Docker Network Troubleshooting Guide

## Issue 1: Docker can't reach registry-1.docker.io (IPv6)

### Symptoms
- Error: `dial tcp [IPv6]:443: connect: network is unreachable`
- Docker Compose fails to pull images
- Network connectivity issues in corporate environments

## Issue 2: TLS Certificate Verification Failed

### Symptoms
- Error: `tls: failed to verify certificate: x509: certificate signed by unknown authority`
- Docker can reach the registry but fails on certificate verification
- Common in corporate environments with proxy servers or custom certificates

### Quick Fix Steps

#### Step 1: Apply Basic Docker Configuration
```bash
# Copy the provided daemon configuration
sudo cp docker-daemon.json /etc/docker/daemon.json

# Restart Docker daemon
sudo systemctl restart docker

# Test connectivity
docker pull hello-world
```

#### Step 2: Run Network Diagnostics
```bash
# Run the troubleshooting script
sudo ./fix_docker_network.sh
```

#### Step 3: Configure Proxy (if needed)
If you're in a corporate environment with proxy:
```bash
# Run the proxy configuration script
sudo ./configure_docker_proxy.sh
```

#### Step 4: Fix Certificate Issues (if needed)
If you get certificate verification errors:
```bash
# Run the certificate troubleshooting script
sudo ./fix_docker_certificates.sh
```

### Manual Configuration Options

#### Option A: Disable IPv6 and Set DNS
Create `/etc/docker/daemon.json`:
```json
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
```

#### Option B: Configure Corporate Proxy
If your organization uses a proxy server:
```json
{
  "dns": ["8.8.8.8", "8.8.4.4"],
  "ipv6": false,
  "proxies": {
    "http-proxy": "http://proxy.company.com:8080",
    "https-proxy": "http://proxy.company.com:8080",
    "no-proxy": "localhost,127.0.0.1,::1"
  }
}
```

### Environment-Specific Solutions

#### For MOH.Health.Gov.IL Environment
Based on your environment, you might need:

1. **Internal Registry Mirror**: Check if there's an internal Docker registry
2. **Corporate Proxy**: Use the proxy configuration script
3. **Network Policies**: Contact your network administrator

#### Testing Steps
After configuration:
```bash
# Test basic connectivity
ping 8.8.8.8

# Test DNS resolution
nslookup registry-1.docker.io

# Test Docker Hub access
curl -s --connect-timeout 10 https://registry-1.docker.io/v2/

# Test Docker pull
docker pull hello-world

# Test Docker Compose
docker compose pull
docker compose up -d
```

### Common Issues and Solutions

#### Issue: Still getting IPv6 errors
- Ensure `"ipv6": false` is in daemon.json
- Check system IPv6 settings: `sysctl net.ipv6.conf.all.disable_ipv6`

#### Issue: DNS resolution fails
- Try different DNS servers (1.1.1.1, 8.8.8.8)
- Check `/etc/resolv.conf`

#### Issue: Proxy authentication required
- Use the proxy configuration script with credentials
- Or set environment variables: `HTTP_PROXY`, `HTTPS_PROXY`

### Getting Help
If issues persist:
1. Run `sudo ./fix_docker_network.sh` and share the output
2. Check Docker daemon logs: `journalctl -u docker -f`
3. Contact your network administrator for proxy settings
