#!/usr/bin/env bash
set -euo pipefail

# Usage: sudo ./install_prereqs.sh [path/to/prereqs.txt]
# - Installs Docker Engine and Compose plugin on Ubuntu
# - Idempotent: safe to re-run
# - Does NOT modify your .env or project files

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run as root: sudo $0 [prereqs-file]" >&2
    exit 1
  fi
}

detect_ubuntu() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    if [[ "${ID}" != "ubuntu" ]]; then
      echo "This script supports Ubuntu only (detected: ${PRETTY_NAME:-unknown})." >&2
      exit 1
    fi
    UBUNTU_CODENAME="${VERSION_CODENAME}"
  else
    echo "/etc/os-release not found. Cannot detect OS." >&2
    exit 1
  fi
}

read_packages() {
  local file_path="$1"
  if [[ ! -f "${file_path}" ]]; then
    echo "Packages file not found: ${file_path}" >&2
    exit 1
  fi
  mapfile -t PACKAGES < <(grep -vE '^[[:space:]]*#' "${file_path}" | sed '/^\s*$/d')
  if [[ ${#PACKAGES[@]} -eq 0 ]]; then
    echo "No packages found in ${file_path}" >&2
    exit 1
  fi
}

setup_docker_repo() {
  install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  local list_file="/etc/apt/sources.list.d/docker.list"
  local entry="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable"
  if [[ ! -f "${list_file}" ]] || ! grep -q "download.docker.com" "${list_file}"; then
    echo "${entry}" > "${list_file}"
  fi
}

install_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  # Ensure core dependencies for repo setup are present first
  apt-get install -y ca-certificates curl gnupg lsb-release
  apt-get update -y
  apt-get install -y "${PACKAGES[@]}"
}

enable_docker() {
  systemctl enable --now docker
  # Add invoking user to docker group if possible
  local target_user="${SUDO_USER:-}"
  if id -u docker >/dev/null 2>&1; then
    :
  fi
  if getent group docker >/dev/null 2>&1; then
    :
  else
    groupadd docker || true
  fi
  if [[ -n "${target_user}" && "${target_user}" != "root" ]]; then
    usermod -aG docker "${target_user}" || true
    echo "User '${target_user}' added to 'docker' group. You may need to log out/in to use docker without sudo."
  fi
}

verify() {
  echo "Docker version: $(docker --version || echo 'not found')"
  echo "Compose version: $(docker compose version || echo 'not found')"
}

main() {
  require_root
  detect_ubuntu

  local pkgs_file="${1:-prereqs.txt}"
  read_packages "${pkgs_file}"

  setup_docker_repo
  install_packages
  enable_docker
  verify

  if [[ -f docker-compose.yml ]]; then
    echo "Found docker-compose.yml in $(pwd). Start the stack with: docker compose up -d"
  else
    echo "No docker-compose.yml found in $(pwd). Place your stack files here, then run: docker compose up -d"
  fi
}

main "$@"


