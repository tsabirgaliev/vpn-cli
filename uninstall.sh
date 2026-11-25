#!/bin/bash
# Removes vpnctl, touchid-gate and any sudoers rule left by an earlier install.
# The stored password is kept; pass --purge to delete it from the System keychain too.
set -euo pipefail

sudo rm -f /etc/sudoers.d/vpnctl /usr/local/sbin/vpnctl /usr/local/libexec/touchid-gate
echo "removed vpnctl, touchid-gate"

if [[ "${1:-}" == "--purge" ]]; then
  # vpnctl tags every item it saves with kind "vpnctl"; delete until none are left.
  n=0
  while sudo security delete-generic-password -D vpnctl /Library/Keychains/System.keychain >/dev/null 2>&1; do
    n=$((n + 1))
  done
  echo "removed $n password(s) from System keychain"
fi
