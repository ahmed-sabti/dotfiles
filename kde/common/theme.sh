#!/usr/bin/env bash
# Light and dark global themes that keep this rice. Plasma's Breeze / Breeze Dark put the cursor,
# icons and colours back to Breeze on every light/dark switch (the quick toggle has no "choose what
# to apply"), so this installs copies with our values, points the switch at them, applies the one
# for the current mode and gives the login screen the same cursor.
# Run inside the Plasma session (apply.sh does); safe to re-run. host.conf can override the values.
#   bash ~/projects/dotfiles/kde/common/theme.sh
set -euo pipefail
CURSOR=${CURSOR:-Bibata-Modern-Ice}
CURSOR_SIZE=${CURSOR_SIZE:-24}
DARK_COLORS=${DARK_COLORS:-CatppuccinMocha}
DARK_ICONS=${DARK_ICONS:-Papirus-Dark}
LIGHT_COLORS=${LIGHT_COLORS:-BreezeLight}
LIGHT_ICONS=${LIGHT_ICONS:-Papirus-Light}

src=/usr/share/plasma/look-and-feel
dst=$HOME/.local/share/plasma/look-and-feel

# make_lnf <id> <name> <Plasma package it copies> <colour scheme> <icon theme>
make_lnf() {
    local id=$1 name=$2 base=$src/$3 colors=$4 icons=$5 d=$dst/$1 e
    [ -d "$base" ] || { echo "missing $base"; return 1; }
    rm -rf "$d"; mkdir -p "$d/contents"
    # everything but the defaults stays a link, so Plasma updates still come through
    for e in "$base"/contents/*; do
        [ "$(basename "$e")" = defaults ] || ln -s "$e" "$d/contents/"
    done
    # no [Wallpaper]: switching modes must not replace the wallpaper
    awk -v c="$colors" -v i="$icons" -v cur="$CURSOR" -v sz="$CURSOR_SIZE" '
        /^\[/ { sec = $0; skip = (sec == "[Wallpaper]") }
        skip { next }
        sec == "[kdeglobals][General]" && /^ColorScheme=/ { $0 = "ColorScheme=" c }
        sec == "[kdeglobals][Icons]"   && /^Theme=/       { $0 = "Theme=" i }
        sec == "[kcminputrc][Mouse]"   && /^cursorTheme=/ { print "cursorTheme=" cur; $0 = "cursorSize=" sz }
        { print }' "$base/contents/defaults" > "$d/contents/defaults"
    for want in "ColorScheme=$colors" "Theme=$icons" "cursorTheme=$CURSOR"; do
        grep -qx "$want" "$d/contents/defaults" || { echo "$3 defaults changed layout: $want not set"; return 1; }
    done
    python3 -I - "$base/metadata.json" "$d/metadata.json" "$id" "$name" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
k = m["KPlugin"]
for key in [key for key in k if key.startswith(("Name[", "Description["))]:
    del k[key]
k["Id"], k["Name"] = sys.argv[3], sys.argv[4]
json.dump(m, open(sys.argv[2], "w"), indent=4)
PY
}

echo "==> light/dark global themes ($CURSOR, $DARK_COLORS / $LIGHT_COLORS)"
make_lnf dotfiles-dark.desktop "Dotfiles Dark" org.kde.breezedark.desktop "$DARK_COLORS" "$DARK_ICONS"
make_lnf dotfiles-light.desktop "Dotfiles Light" org.kde.breeze.desktop "$LIGHT_COLORS" "$LIGHT_ICONS"
kwriteconfig6 --file kdeglobals --group KDE --key DefaultDarkLookAndFeel dotfiles-dark.desktop
kwriteconfig6 --file kdeglobals --group KDE --key DefaultLightLookAndFeel dotfiles-light.desktop

# stay in the mode the machine is in now; anything not obviously light counts as dark
case $(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage) in
    dotfiles-light.desktop | org.kde.breeze.desktop | org.fedoraproject.fedora.desktop) mode=light ;;
    *) mode=dark ;;
esac
plasma-apply-lookandfeel -a "dotfiles-$mode.desktop"
echo "    applied dotfiles-$mode.desktop"

echo "==> login screen cursor"
if [ ! -d "/usr/share/icons/$CURSOR" ]; then
    echo "    skipped: $CURSOR is not in /usr/share/icons, the login screen can't read it"
elif systemctl -q is-enabled plasmalogin.service 2>/dev/null; then
    sudo -u plasmalogin kwriteconfig6 --file /var/lib/plasmalogin/.config/kcminputrc --group Mouse --key cursorTheme "$CURSOR"
    sudo -u plasmalogin kwriteconfig6 --file /var/lib/plasmalogin/.config/kcminputrc --group Mouse --key cursorSize "$CURSOR_SIZE"
    echo "    Plasma Login Manager: $CURSOR"
elif systemctl -q is-enabled sddm.service 2>/dev/null; then
    sudo install -d /etc/sddm.conf.d
    printf '[Theme]\nCursorTheme=%s\nCursorSize=%s\n' "$CURSOR" "$CURSOR_SIZE" | sudo tee /etc/sddm.conf.d/10-cursor.conf >/dev/null
    echo "    SDDM: $CURSOR"
else
    echo "    skipped: neither plasmalogin nor sddm is enabled"
fi
