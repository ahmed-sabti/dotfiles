#!/usr/bin/env bash
# Bootstrap: install chezmoi if missing, then apply this repo to $HOME.
# chezmoi asks once for the machine role (mac/laptop/gaming/server) and whether
# to install the Hyprland rice; answers live in ~/.config/chezmoi/chezmoi.toml.
# Re-running is safe: `chezmoi apply` only changes what differs.
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v chezmoi >/dev/null; then
  if command -v brew >/dev/null; then brew install chezmoi
  elif command -v pacman >/dev/null; then sudo pacman -S --needed chezmoi
  elif command -v dnf >/dev/null; then sudo dnf install -y chezmoi
  elif command -v apt-get >/dev/null; then sudo apt-get install -y chezmoi
  else sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"; export PATH="$HOME/.local/bin:$PATH"
  fi
fi

chezmoi init --source "$repo_dir" --apply "$@"   # extra args, e.g. --promptString role=gaming
