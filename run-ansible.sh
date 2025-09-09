#!/usr/bin/env bash
set -euo pipefail

# Simple helper to load .env and run the playbook.
# Usage:
#   cp .env .env.local && edit .env.local
#   ./run-ansible.sh

# Load .env if present
if [ -f .env ]; then
  # shellcheck disable=SC1090
  . .env
fi

PLAYBOOK="${ANSIBLE_PLAYBOOK:-playbook.yml}"

# Prefer ansible-pull when available (designed to run on the VPS itself).
if command -v ansible-pull >/dev/null 2>&1; then
  echo "Running ansible-pull with playbook: $PLAYBOOK"
  ansible-pull -U https://github.com/SAM-AEL/ansible-vps.git "$PLAYBOOK" -i localhost
else
  echo "ansible-pull not found, falling back to ansible-playbook"
  ansible-playbook -i localhost "$PLAYBOOK" --ask-become-pass
fi
