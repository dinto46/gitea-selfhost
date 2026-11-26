#!/usr/bin/env bash
# Script: gitea_publish_repository.sh
# Description: Initialize a local project and push its first commit to Gitea over SSH.
# Prerequisite: Create an empty repository in Gitea and register this client's public key.

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME <project_dir> <gitea_username> <ubuntu_ip> <repository> [branch]

Initializes Git when needed, commits existing project files if there is no
commit yet, adds the Gitea SSH remote, and pushes the selected branch.
The destination repository must already exist and be empty in Gitea.

Example:
  $SCRIPT_NAME ./test-gitea alice 192.168.1.100 test
EOF
}

if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then usage; exit 0; fi
if [[ $# -lt 4 || $# -gt 5 ]]; then usage >&2; exit 2; fi

project_dir="$1"
gitea_user="$2"
ubuntu_ip="$3"
repository="$4"
branch="${5:-main}"

command -v git >/dev/null || { echo "[ERROR] git is required." >&2; exit 1; }
[[ -d "$project_dir" ]] || { echo "[ERROR] Project directory not found: $project_dir" >&2; exit 1; }
[[ "$repository" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "[ERROR] Repository name contains unsupported characters." >&2; exit 2; }
[[ "$gitea_user" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "[ERROR] Gitea username contains unsupported characters." >&2; exit 2; }

cd "$project_dir"
if [[ ! -d .git ]]; then
  git init
fi

if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  if [[ -z "$(git status --porcelain)" ]]; then
    echo "[ERROR] No files to commit. Add a README or project files, then rerun." >&2
    exit 1
  fi
  author_name="${GIT_AUTHOR_NAME:-$(git config user.name 2>/dev/null || true)}"
  author_email="${GIT_AUTHOR_EMAIL:-$(git config user.email 2>/dev/null || true)}"
  if [[ -z "$author_name" || -z "$author_email" ]]; then
    echo "[ERROR] Set Git identity first: git config --global user.name and user.email." >&2
    exit 1
  fi
  git add .
  git -c user.name="$author_name" -c user.email="$author_email" \
      commit -m "Initial commit"
fi

git branch -M "$branch"
remote_url="git@${ubuntu_ip}:${gitea_user}/${repository}.git"
if git remote get-url origin >/dev/null 2>&1; then
  current_remote="$(git remote get-url origin)"
  if [[ "$current_remote" != "$remote_url" ]]; then
    echo "[ERROR] origin already points to '$current_remote'. Update it explicitly before rerunning." >&2
    exit 1
  fi
else
  git remote add origin "$remote_url"
fi

printf '[INFO] Pushing %s to %s...\n' "$branch" "$remote_url"
git push -u origin "$branch"
printf '[OK] Push complete. Check the repository in the Gitea web interface.\n'
