#!/usr/bin/env bash
# Script: gitea_server_install.sh
# Description: Prepare an Ubuntu Server host and install Gitea as a systemd service.
# Scope: Automates installation steps from the project guide; VM and web setup remain manual.

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
GITEA_VERSION="${GITEA_VERSION:-1.23.4}"
readonly GITEA_USER="git"
readonly GITEA_HOME="/home/git"
readonly GITEA_WORK_DIR="/var/lib/gitea"
readonly GITEA_CONFIG_DIR="/etc/gitea"
readonly GITEA_CONFIG="${GITEA_CONFIG_DIR}/app.ini"
readonly GITEA_BINARY="/usr/local/bin/gitea"
readonly SERVICE_FILE="/etc/systemd/system/gitea.service"

info() { printf '\e[34m[INFO]\e[0m %s\n' "$*"; }
success() { printf '\e[32m[OK]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[WARN]\e[0m %s\n' "$*" >&2; }
error() { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: sudo $SCRIPT_NAME [--version VERSION] [--help]

Install OpenSSH, Git, wget, and Gitea ${GITEA_VERSION} on Ubuntu/Debian,
create the dedicated git account and data directories, and enable the service.

Options:
  --version VERSION  Gitea version to install (default: 1.23.4)
  -h, --help         Show this help

After installation, open http://<UBUNTU_IP>:3000 and complete the setup wizard.
Choose SQLite3, set the domain/base URL, and create the administrator account.
This script does not configure VirtualBox networking or create the web account.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 && -n "$2" ]] || { error "--version requires a value"; exit 2; }
      GITEA_VERSION="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) error "Unknown option: $1"; usage >&2; exit 2 ;;
  esac
done

[[ $EUID -eq 0 ]] || { error "Run with sudo: sudo $SCRIPT_NAME"; exit 1; }
[[ -r /etc/os-release ]] || { error "Cannot identify operating system."; exit 1; }
# shellcheck source=/dev/null
source /etc/os-release
[[ "${ID:-}" == ubuntu || "${ID_LIKE:-}" == *debian* ]] || {
  error "This installer supports Ubuntu and Debian-based systems."; exit 1;
}
[[ "$(uname -m)" == x86_64 ]] || { error "This project binary targets x86_64 (AMD64)."; exit 1; }
command -v apt-get >/dev/null || { error "apt-get is required."; exit 1; }

tmp_binary="$(mktemp)"
cleanup() { rm -f "$tmp_binary"; }
trap cleanup EXIT

info "Updating package lists and installing required packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server git wget ca-certificates
systemctl enable --now ssh

if id "$GITEA_USER" >/dev/null 2>&1; then
  info "Account '$GITEA_USER' already exists; keeping it."
else
  info "Creating dedicated '$GITEA_USER' system account..."
  adduser --system --group --disabled-password --shell /bin/bash --home "$GITEA_HOME" "$GITEA_USER"
fi

info "Downloading Gitea ${GITEA_VERSION} for Linux AMD64..."
wget --https-only --tries=3 --timeout=30 -O "$tmp_binary" \
  "https://dl.gitea.com/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-linux-amd64"
install -o root -g root -m 0755 "$tmp_binary" "$GITEA_BINARY"

install -d -o "$GITEA_USER" -g "$GITEA_USER" -m 0750 \
  "$GITEA_WORK_DIR/custom" "$GITEA_WORK_DIR/data" "$GITEA_WORK_DIR/log" "$GITEA_CONFIG_DIR"

info "Writing systemd service to $SERVICE_FILE..."
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Gitea (Git with a cup of tea)
After=network.target

[Service]
RestartSec=2s
Type=simple
User=${GITEA_USER}
Group=${GITEA_USER}
WorkingDirectory=${GITEA_WORK_DIR}
ExecStart=${GITEA_BINARY} web --config ${GITEA_CONFIG}
Restart=always
Environment=USER=${GITEA_USER} HOME=${GITEA_HOME} GITEA_WORK_DIR=${GITEA_WORK_DIR}

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 "$SERVICE_FILE"

systemctl daemon-reload
systemctl enable --now gitea

if command -v ufw >/dev/null 2>&1 && ufw status | grep -qi '^Status: active'; then
  info "UFW is active; allowing SSH and Gitea's web port 3000/tcp..."
  ufw allow ssh
  ufw allow 3000/tcp
else
  warn "UFW is not active; no firewall rules were changed. Ensure SSH and TCP 3000 are reachable."
fi

success "Gitea ${GITEA_VERSION} installed and enabled."
printf '\nNext steps:\n'
printf '  1. Find this server address: hostname -I\n'
printf '  2. Open http://<UBUNTU_IP>:3000 in a client browser.\n'
printf '  3. Select SQLite3 and finish the Gitea setup wizard.\n'
printf '  4. Secure the generated config: chmod 750 %s && chmod 640 %s\n' "$GITEA_CONFIG_DIR" "$GITEA_CONFIG"
printf '  5. Check service: systemctl status gitea\n'
