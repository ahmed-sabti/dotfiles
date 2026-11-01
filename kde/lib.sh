# Shared by apply.sh and snapshot.sh: which os/ and hosts/ layer this machine uses.
kde_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# os/<id>: the first of /etc/os-release ID, then ID_LIKE, that has a directory (cachyos -> arch)
detect_os() {
    local id
    # shellcheck disable=SC1091
    . /etc/os-release
    for id in ${ID:-} ${ID_LIKE:-}; do
        [ -d "$kde_dir/os/$id" ] && { echo "$id"; return; }
    done
    echo "no os/ layer for ${ID:-unknown} (${ID_LIKE:-}); add kde/os/${ID:-<id>}/" >&2
    return 1
}

# hosts/<name>: the one passed with --host, else the one whose directory name or HOSTNAMES
# matches this machine's hostname
resolve_host() {
    local want=${1:-} me conf
    if [ -n "$want" ]; then
        [ -f "$kde_dir/hosts/$want/host.conf" ] && { echo "$want"; return; }
        echo "no kde/hosts/$want/host.conf" >&2; return 1
    fi
    me=$(uname -n); me=${me%%.*}
    for conf in "$kde_dir"/hosts/*/host.conf; do
        if (HOSTNAMES=""; . "$conf"; for n in "$(basename "$(dirname "$conf")")" $HOSTNAMES; do
                [ "$n" = "$me" ] && exit 0; done; exit 1); then
            basename "$(dirname "$conf")"; return
        fi
    done
    echo "this machine ($me) has no kde/hosts/<name>/host.conf: pass --host NAME or add one" >&2
    return 1
}

# this install's Plasma activity id (each install has its own)
current_activity() {
    grep -oP '^currentActivity=\K.*' "$HOME/.config/kactivitymanagerdrc" 2>/dev/null \
        || sed -n '/^\[activities\]/,/^\[/s/^\([0-9a-f-]\{36\}\)=.*/\1/p' "$HOME/.config/kactivitymanagerdrc" 2>/dev/null | head -1
}
