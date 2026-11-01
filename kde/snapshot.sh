#!/usr/bin/env bash
# Refresh hosts/<this host>/config from the live KDE settings. Run it on the machine whose look the
# others copy (the T480; see CONFIG_FROM in hosts/*/host.conf) after changing the panel, shortcuts,
# theme etc., check `git diff`, commit, push; then `apply.sh --kde-only` on the other machines.
#   --host NAME   write hosts/NAME/config instead of the one matching this hostname
# Machine-specific values are turned into placeholders that apply.sh fills in on the target:
#   @ACTIVITY@  the Plasma activity id (each install has its own; Plasma ignores a foreign one
#               and puts up a fresh desktop with the default wallpaper)
# System-wide Flatpak launcher paths become applications:<id>.desktop, which also finds --user installs.
# Left out on purpose: power/display/fingerprint, kwallet, KMail/Akonadi, activity database.
set -euo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
if [ "${1:-}" = "--host" ]; then host=$(resolve_host "${2:?--host needs a name}"); else host=$(resolve_host); fi
out="$kde_dir/hosts/$host/config"
FILES=(
  dolphinrc kcminputrc kdeglobals kglobalshortcutsrc konsolerc kwinrc
  plasma-org.kde.plasma.desktop-appletsrc plasmanotifyrc plasmarc plasmashellrc
  kscreenlockerrc spectaclerc okularrc okularpartrc gwenviewrc plasma-localerc baloofilerc
)
act=$(current_activity)
[ -n "$act" ] || { echo "no Plasma activity in ~/.config/kactivitymanagerdrc"; exit 1; }

mkdir -p "$out"
for f in "${FILES[@]}"; do
  src="$HOME/.config/$f"
  [ -f "$src" ] || { echo "skip $f (not on this machine)"; continue; }
  sed -E -e "s#$act#@ACTIVITY@#g" \
         -e 's#file:///var/lib/flatpak/app/[^/,]+/current/active/export/share/applications/([^,]+\.desktop)#applications:\1#g' \
         "$src" > "$out/$f"
done
# OpenLogi (Logitech MX devices): the app rewrites this file itself, so it is copied, never symlinked
[ -f "$HOME/.config/openlogi/config.toml" ] && install -Dm600 "$HOME/.config/openlogi/config.toml" "$kde_dir/common/openlogi/config.toml"
echo "snapshot of ${#FILES[@]} files from $host written to $out — review with: git -C $kde_dir diff"
