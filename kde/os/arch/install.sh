#!/usr/bin/env bash
# Arch/CachyOS packages for the KDE setup: pkgs-pacman.txt, then pkgs-aur.txt via paru.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
list() { grep -vE '^\s*(#|$)' "$1" || true; }

echo "==> packages (pacman)"
# shellcheck disable=SC2046
sudo pacman -Syu --needed --noconfirm $(list "$here/pkgs-pacman.txt")

echo "==> packages (AUR via paru)"
command -v paru >/dev/null || sudo pacman -S --needed --noconfirm paru
# shellcheck disable=SC2046
paru -S --needed --noconfirm $(list "$here/pkgs-aur.txt")
