#!/usr/bin/env bash
# Provision the `arch` container (bleeding-edge Arch + Hyprland, Sunshine streaming)
# with packages + the dotfiles shell/rice stack. Also usable, unmodified, to bootstrap
# a real bare-metal Arch laptop later -- see the container-vs-laptop detection below.
# Run as the desktop user (user, has passwordless sudo). Idempotent -- re-run
# anytime after adding a line to pkgs-pacman.txt / pkgs-aur.txt.
set -euo pipefail

H="$HOME"
REPO="$H/projects/dotfiles"

IS_CONTAINER=0
systemd-detect-virt --container -q && IS_CONTAINER=1 || true
IS_LAPTOP=0
ls /sys/class/power_supply/BAT* >/dev/null 2>&1 && IS_LAPTOP=1 || true

echo "[1/10] detect environment: container=$IS_CONTAINER laptop=$IS_LAPTOP"

echo "[2/10] bootstrap yay if missing"
if ! command -v yay >/dev/null; then
  sudo pacman -S --needed --noconfirm base-devel git
  tmpdir=$(mktemp -d)
  git clone --depth=1 https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (cd "$tmpdir/yay" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
fi

echo "[3/10] enable multilib + full system update"
# archlinux:latest ships pacman.conf with NO [multilib] section at all (not even
# commented out) -- unlike a real ISO install. Append it outright if missing,
# same pattern gaming-arch's Dockerfile already uses.
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
fi
sudo pacman -Syu --noconfirm

echo "[4/10] official-repo packages (hypr/pkgs-pacman.txt)"
# NVIDIA userspace libs come from the host via `runtime: nvidia` (NVIDIA
# Container Toolkit injection, version-matched to the host kernel driver) --
# NOT from pacman. Without --assume-installed, pacman's dependency resolver
# picks a REAL package to satisfy the opengl-driver/vulkan-driver virtual
# groups (aquamarine/steam depend on them) and tries to install nvidia-utils/
# egl-wayland/egl-wayland2/egl-gbm for real, which then conflicts with the
# already-injected files on disk -- and worse, risks a future `pacman -Syu`
# pulling a newer nvidia-utils than the host's actual kernel module. Mesa
# itself IS a real hard dependency (aquamarine depends on it directly, not
# just the virtual group) and does need to install for real; its one
# genuinely conflicting file (libGLX_indirect.so.0, an indirect-GLX
# compatibility shim, not driver-version-sensitive) is safe to overwrite.
mapfile -t pac_pkgs < <(grep -vE '^\s*#|^\s*$' "$REPO/hypr/pkgs-pacman.txt")
sudo pacman -S --needed --noconfirm \
  --overwrite /usr/lib/libGLX_indirect.so.0 \
  --assume-installed opengl-driver \
  --assume-installed vulkan-driver \
  --assume-installed lib32-vulkan-driver \
  "${pac_pkgs[@]}"

echo "[5/10] AUR packages (hypr/pkgs-aur.txt)"
mapfile -t aur_pkgs < <(grep -vE '^\s*#|^\s*$' "$REPO/hypr/pkgs-aur.txt")
yay -S --needed --noconfirm "${aur_pkgs[@]}"

echo "[6/10] Sunshine (upstream LizardByte release, same family gaming-arch uses)"
if ! command -v sunshine >/dev/null; then
  SUNSHINE_VERSION="${SUNSHINE_VERSION:-v2026.516.143833}"
  curl -fsSL "https://github.com/LizardByte/Sunshine/releases/download/${SUNSHINE_VERSION}/sunshine-${SUNSHINE_VERSION#v}-1-x86_64.pkg.tar.zst" \
    -o /tmp/sunshine.pkg.tar.zst
  sudo pacman -U --noconfirm /tmp/sunshine.pkg.tar.zst
  rm -f /tmp/sunshine.pkg.tar.zst
fi
sudo setcap cap_sys_admin,cap_sys_nice+ep "$(readlink -f "$(command -v sunshine)")"

echo "[7/10] fonts + Bibata cursor theme"
if [ ! -d /usr/share/icons/Bibata-Modern-Ice ]; then
  url=$(curl -fsSL https://api.github.com/repos/ful1e5/Bibata_Cursor/releases/latest \
        | python3 -c "import sys,json; r=json.load(sys.stdin); print(*[a['browser_download_url'] for a in r['assets'] if a['name']=='Bibata-Modern-Ice.tar.xz'])")
  curl -fsSL "$url" -o /tmp/bibata.tar.xz
  sudo mkdir -p /usr/share/icons
  sudo tar -xJf /tmp/bibata.tar.xz -C /usr/share/icons
  rm -f /tmp/bibata.tar.xz
fi

if [ "$IS_CONTAINER" -eq 0 ] && [ "$IS_LAPTOP" -eq 1 ]; then
  echo "[8/10] real laptop detected -- installing power management"
  sudo pacman -S --needed --noconfirm tlp tlp-rdw auto-cpufreq powertop
  sudo systemctl enable --now tlp.service
else
  echo "[8/10] skipping power management (container, or not a laptop)"
fi

echo "[9/10] dotfiles: shell + Hyprland/waybar/wofi/swaync rice"
DOTFILES_HYPR=1 bash "$REPO/install.sh"
sudo usermod -s /usr/bin/zsh "$(whoami)"

echo "[10/10] done"
echo
echo "Re-check after a genuine container/laptop recreate:"
echo "  - Sunshine pairing PIN (https://<host>:49990 in-container, or :47990 on a laptop)"
echo "  - NVIDIA_VISIBLE_DEVICES / by-path GPU device assumptions (container only)"
echo "  - Steam library path (/games bind-mount, container only)"
