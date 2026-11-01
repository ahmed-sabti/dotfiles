#!/usr/bin/env bash
# Provision the ubuntu-desk container (Ubuntu/KDE via Sunshine) with the dotfiles
# shell stack + Catppuccin Mocha theme. Idempotent — safe to re-run.
# Run as root INSIDE the container, after the dotfiles repo is at ~/projects/dotfiles.
set -euo pipefail
H=/home/user
REPO="$H/projects/dotfiles"
export DEBIAN_FRONTEND=noninteractive

echo "[1/8] apt packages (zsh stack, theme deps, modern tools)"
apt-get update -qq
apt-get install -y --no-install-recommends \
  zsh zsh-autosuggestions zsh-syntax-highlighting \
  papirus-icon-theme qt5-style-kvantum qt6-style-kvantum gtk2-engines-murrine \
  fastfetch eza bat ripgrep btop unzip curl ca-certificates

echo "[2/8] starship -> /usr/local/bin"
command -v starship >/dev/null || curl -sS https://starship.rs/install.sh | sh -s -- -b /usr/local/bin -y

echo "[3/8] krabby 0.3.0 -> /usr/local/bin (via cargo)"
command -v krabby >/dev/null || {
  apt-get install -y --no-install-recommends cargo
  cargo install --root /usr/local --locked --version 0.3.0 krabby
}

echo "[4/8] opencode -> /usr/local/bin"
command -v opencode >/dev/null || curl -fsSL https://opencode.ai/install | bash

echo "[5/8] dotfiles into desktop home (install.sh)"
HOME="$H" DOTFILES_DESKTOP=1 bash "$REPO/install.sh"

echo "[6/8] GTK theme (catppuccin-mocha-mauve) + Kvantum theme"
mkdir -p "$H/.themes" "$H/.config/Kvantum"
if [ ! -d "$H/.themes/catppuccin-mocha-mauve-standard+default" ]; then
  curl -fsSL -o /tmp/gtk.zip 'https://github.com/catppuccin/gtk/releases/download/v1.0.3/catppuccin-mocha-mauve-standard%2Bdefault.zip'
  rm -rf /tmp/gtk_ex; mkdir -p /tmp/gtk_ex; unzip -o -q /tmp/gtk.zip -d /tmp/gtk_ex
  for d in /tmp/gtk_ex/*/; do mv "$d" "$H/.themes/"; done
  rm -rf /tmp/gtk.zip /tmp/gtk_ex
fi
if [ ! -d "$H/.config/Kvantum/catppuccin-mocha-mauve" ]; then
  curl -fsSL -o /tmp/kv.tgz https://github.com/catppuccin/kvantum/archive/refs/heads/main.tar.gz
  tar xzf /tmp/kv.tgz -C /tmp
  cp -a /tmp/kvantum-main/themes/catppuccin-mocha-mauve "$H/.config/Kvantum/"
  rm -rf /tmp/kv.tgz /tmp/kvantum-main
fi
printf '[General]\ntype=kvantum\ntheme=catppuccin-mocha-mauve\n' > "$H/.config/Kvantum/kvantum.kvconfig"

echo "[7/8] patch desk-xsession.sh (zsh session shell, \$HOME cwd, kvantum Qt, theme waiter)"
install -m 0755 "$REPO/kde/os/ubuntu/apply-catppuccin.sh" /usr/local/bin/apply-catppuccin.sh
XS=/usr/local/bin/desk-xsession.sh
[ -f "$XS.bak" ] || cp "$XS" "$XS.bak"
grep -q '^export QT_QPA_PLATFORMTHEME=kvantum' "$XS" || sed -i '/^set -u$/a export QT_QPA_PLATFORMTHEME=kvantum' "$XS"
grep -q '^export SHELL=/usr/bin/zsh'          "$XS" || sed -i '/^export XDG_RUNTIME_DIR=/a export SHELL=/usr/bin/zsh' "$XS"
grep -q '^cd "$HOME"$'                        "$XS" || sed -i '/^exec plasma_session$/i cd "$HOME"' "$XS"
grep -q 'apply-catppuccin.sh'                 "$XS" || sed -i '/^exec plasma_session$/i /usr/local/bin/apply-catppuccin.sh \&' "$XS"
bash -n "$XS"

echo "[8/8] ownership + login shell + KDE color/icons"
chown -R user:user \
  "$H/.themes" "$H/.config/Kvantum" "$H/.config/environment.d" \
  "$H/.config/plasma-workspace" "$H/.config/autostart" "$H/.local/share/color-schemes"
usermod -s /usr/bin/zsh user
kwriteconfig6 --file "$H/.config/kdeglobals" --group General --key ColorScheme CatppuccinMocha
kwriteconfig6 --file "$H/.config/kdeglobals" --group Icons   --key Theme Papirus-Dark
kwriteconfig6 --file "$H/.config/kdeglobals" --group KDE     --key widgetStyle kvantum

echo
echo "DONE. Note: inject the glm-5.2 key separately into"
echo "  $H/.local/share/opencode/auth.json  (secret, not in this repo)."
echo "Reboot/restart the container so Plasma picks up the theme + zsh session."
