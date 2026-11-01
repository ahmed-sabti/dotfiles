#!/usr/bin/env bash
# Set up a KDE machine from this repo: Catppuccin Mocha + Papirus-Dark + Bibata-Modern-Ice +
# CaskaydiaCove Nerd Font, the same panel, shortcuts, KWin/Dolphin/Konsole settings, apps and the
# chezmoi dotfiles. Built from layers, so a new distro or machine is one more directory:
#   common/        every machine: Flatpaks, npm globals, light/dark themes (theme.sh), wallpaper, launchers
#   os/<id>/       per distro, picked from /etc/os-release ID then ID_LIKE (cachyos -> arch):
#                  install.sh + its package lists, rewrite.sed for the copied configs
#   hosts/<name>/  per machine: host.conf (role, whose snapshot to use), config/ from snapshot.sh,
#                  rewrite.sed
# Run as your normal user inside a Plasma session:  bash ~/projects/dotfiles/kde/apply.sh
#   --kde-only     only the KDE configs, theme, wallpaper and launchers (after a new snapshot.sh)
#   --host NAME    use hosts/NAME instead of the one matching this hostname
# Safe to re-run. Existing KDE configs are backed up to ~/.config/kde-profile-backup-<date>/ first.
set -euo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
repo="$(cd "$kde_dir/.." && pwd)"
[ "$(id -u)" -ne 0 ] || { echo "run as your user, not root"; exit 1; }
kde_only=false; host_arg=""
while [ $# -gt 0 ]; do
    case $1 in
        --kde-only) kde_only=true ;;
        --host) host_arg=${2:?--host needs a name}; shift ;;
        *) echo "unknown option $1"; exit 1 ;;
    esac
    shift
done

os=$(detect_os); host=$(resolve_host "$host_arg")
set -a
# shellcheck disable=SC1090
. "$kde_dir/hosts/$host/host.conf"
set +a
CONFIG_FROM=${CONFIG_FROM:-$host}
echo "==> host $host (role ${ROLE:-?}), os layer $os, KDE configs from hosts/$CONFIG_FROM"
list() { grep -vE '^\s*(#|$)' "$1" || true; }

if ! $kde_only; then
    if [ -x "$kde_dir/os/$os/install.sh" ]; then "$kde_dir/os/$os/install.sh"
    else echo "==> no os/$os/install.sh, skipping distro packages"; fi

    echo "==> flatpaks"
    flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    # shellcheck disable=SC2046
    flatpak install --user -y --noninteractive flathub $(list "$kde_dir/common/flatpaks.txt")

    echo "==> npm globals into ~/.local (no sudo)"
    npm config set prefix "$HOME/.local"
    # shellcheck disable=SC2046
    npm install -g $(list "$kde_dir/common/npm-global.txt")

    echo "==> dotfiles (chezmoi: zsh, kitty, starship, nvim, GTK, Catppuccin colours, ...)"
    bash "$repo/install.sh" ${ROLE:+--promptString "role=$ROLE"}
fi

echo "==> KDE configs"
# this install's own Plasma activity; the snapshot carries @ACTIVITY@ in its place
act=$(current_activity)
[ -n "$act" ] || { echo "no Plasma activity yet: log into Plasma once, then re-run"; exit 1; }
maps=(-e "s#/home/user#$HOME#g" -e "s#@ACTIVITY@#$act#g")
while IFS='|' read -r from to need; do
    [ -e "/usr/share/applications/$from.desktop" ] && continue
    # not preceded by a dot, so "firefox" doesn't match inside "org.mozilla.firefox"
    [ -e "$need" ] && maps+=(-e "s#\(^\|[^.[:alnum:]_-]\)${from//./\\.}\b#\1$to#g")
done < <(list "$kde_dir/common/aliases.txt")
for f in "$kde_dir/os/$os/rewrite.sed" "$kde_dir/hosts/$host/rewrite.sed"; do
    [ -f "$f" ] && maps+=(-f "$f")
done
# the snapshot's files, with this host's own config/ taking precedence
declare -A files=()
for dir in "$kde_dir/hosts/$CONFIG_FROM/config" "$kde_dir/hosts/$host/config"; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*; do [ -f "$f" ] && files[$(basename "$f")]=$f; done
done
[ ${#files[@]} -gt 0 ] || { echo "no configs in hosts/$CONFIG_FROM/config or hosts/$host/config"; exit 1; }
# Plasma writes its panel/desktop state back on exit, so it must not be running while we replace it
plasma_was_running=false
if systemctl --user -q is-active plasma-plasmashell.service 2>/dev/null; then
    plasma_was_running=true; systemctl --user stop plasma-plasmashell.service
fi
backup="$HOME/.config/kde-profile-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
for name in "${!files[@]}"; do
    [ -f "$HOME/.config/$name" ] && cp "$HOME/.config/$name" "$backup/"
    sed "${maps[@]}" "${files[$name]}" > "$HOME/.config/$name"
done
echo "    ${#files[@]} files; backup of the previous ones: $backup"

echo "==> wallpaper (macOS 27 Golden Gate Dark, same path as on the T480)"
wp_dir="$HOME/Bilder/Wallpapers"; wp="$wp_dir/golden-gate-dark-6k.png"
mkdir -p "$wp_dir"
[ -s "$wp" ] || curl -fL --retry 3 -o "$wp" https://basicappleguy.com/s/Golden_Dark_6k.png

echo "==> OpenLogi (MX Keys / MX mice): settings from the T480, agent at login"
if command -v openlogi-agent >/dev/null; then
    [ -f "$HOME/.config/openlogi/config.toml" ] || install -Dm600 "$kde_dir/common/openlogi/config.toml" "$HOME/.config/openlogi/config.toml"
    systemctl --user enable --now openlogi-agent.service || true
fi

echo "==> YGO Omega launcher (copy the game to ~/Games/YGO-Omega yourself)"
mkdir -p "$HOME/.local/share/applications"
sed "s#/home/user#$HOME#g" "$kde_dir/common/ygo-omega.desktop" > "$HOME/.local/share/applications/ygo-omega.desktop"

echo "==> apply theme live"
$plasma_was_running && systemctl --user start plasma-plasmashell.service
bash "$kde_dir/common/theme.sh"
plasma-apply-wallpaperimage --fill-mode preserveAspectCrop "$wp" || true
[ -x "$kde_dir/hosts/$host/tweaks.sh" ] && "$kde_dir/hosts/$host/tweaks.sh"
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true

echo
echo "Done. Log out and back in once so Plasma reloads the panel, shortcuts and KWin settings."
echo "Optional extras:"
echo "  Liquid Glass theme: git clone --depth 1 https://github.com/lestercorderomurillo/macos-tahoe-liquid-kde ~/projects/macos-tahoe-liquid-kde"
echo "                      cd ~/projects/macos-tahoe-liquid-kde && sudo ./install --dark --no-plymouth --no-sddm --no-nautilus --no-nautilus-bookmarks --no-firefox"
echo "  Firefox (betterfox, policies): handled by chezmoi's run_after_firefox script"
