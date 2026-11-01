#!/usr/bin/env bash
# Fedora packages for the KDE setup: pkgs-dnf.txt (plus flatpak, which apply.sh needs next).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
list() { grep -vE '^\s*(#|$)' "$1" || true; }

echo "==> packages (dnf)"
# shellcheck disable=SC2046
sudo dnf install -y flatpak $(list "$here/pkgs-dnf.txt")
