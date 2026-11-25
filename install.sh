#!/bin/bash
# Builds touchid-gate and installs touchid-gate and vpnctl.
# Run from this folder in your own Terminal (not through an agent).
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building touchid-gate"
swiftc -O touchid-gate.swift -o touchid-gate
codesign -f -s - -o runtime touchid-gate

echo "==> Installing (sudo)"
sudo install -d -o root -g wheel -m 755 /usr/local/libexec /usr/local/sbin
sudo install -o root -g wheel -m 755 touchid-gate /usr/local/libexec/touchid-gate
sudo install -o root -g wheel -m 755 vpnctl       /usr/local/sbin/vpnctl

echo "==> Checking every path component is owned by root"
bad=0
for p in / /usr /usr/local /usr/local/sbin /usr/local/libexec \
         /usr/local/sbin/vpnctl /usr/local/libexec/touchid-gate; do
  owner=$(stat -f %Su "$p")
  if [[ $owner != root ]]; then
    echo "WARNING: $p is owned by $owner, not root. Anything running as $owner could replace the files." >&2
    bad=1
  fi
done
[[ $bad -eq 0 ]] && echo "OK"

cat <<'EOF'

Next steps:
  sudo vpnctl set-password                           # Touch ID, then the password twice (active user@site)
  security delete-generic-password -s <site>          # remove the login-keychain copy (<site> from: trac info)
  sudo vpnctl up                                      # Touch ID, then connect
  sudo vpnctl status
  sudo vpnctl down
EOF
