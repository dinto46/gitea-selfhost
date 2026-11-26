#!/usr/bin/env bash
# Script: gitea_client_ssh_setup.sh
# Description: Create an Ed25519 client key and install its public key on Ubuntu Server.
# Run on each Linux/macOS client, not on the Gitea server.

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly KEY_PATH="${HOME}/.ssh/id_ed25519"

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME <ubuntu_user> <ubuntu_ip> [key_comment]

Creates ~/.ssh/id_ed25519 if needed and copies its public key to the Ubuntu
account with ssh-copy-id. You will need the account password for the first copy.

Example:
  $SCRIPT_NAME alice 192.168.1.100 client-machine-1

Windows clients: use PowerShell commands documented in installation.md.
EOF
}

if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then usage; exit 0; fi
if [[ $# -lt 2 || $# -gt 3 ]]; then usage >&2; exit 2; fi

ubuntu_user="$1"
ubuntu_ip="$2"
key_comment="${3:-$(hostname)-gitea}"

command -v ssh-keygen >/dev/null || { echo "[ERROR] ssh-keygen is required." >&2; exit 1; }
command -v ssh-copy-id >/dev/null || { echo "[ERROR] ssh-copy-id is required (install OpenSSH client tools)." >&2; exit 1; }
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

if [[ -e "$KEY_PATH" || -e "${KEY_PATH}.pub" ]]; then
  if [[ -f "$KEY_PATH" && -f "${KEY_PATH}.pub" ]]; then
    printf '[INFO] Existing key pair found at %s; keeping it.\n' "$KEY_PATH"
  else
    echo "[ERROR] Only part of the key pair exists at $KEY_PATH. Inspect it before continuing." >&2
    exit 1
  fi
else
  printf '[INFO] Creating Ed25519 key: %s\n' "$KEY_PATH"
  ssh-keygen -t ed25519 -C "$key_comment" -f "$KEY_PATH"
fi

printf '[INFO] Copying public key to %s@%s...\n' "$ubuntu_user" "$ubuntu_ip"
ssh-copy-id -i "${KEY_PATH}.pub" "${ubuntu_user}@${ubuntu_ip}"
printf '\n[OK] Operating-system SSH key setup complete. Test with:\n'
printf '  ssh %s@%s\n' "$ubuntu_user" "$ubuntu_ip"
printf '\nAdd the public key to your Gitea account separately (Settings > SSH / GPG Keys):\n'
printf '  cat %s\n' "${KEY_PATH}.pub"
printf '[INFO] Never share the private key: %s\n' "$KEY_PATH"
