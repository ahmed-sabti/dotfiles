#!/bin/bash
# Unattended daily brew upgrade (launchd: com.user.brew-auto-upgrade).

set -u

STAMP_DIR="$HOME/.local/state/brew-auto-upgrade"
STAMP="$STAMP_DIR/last-success"
LOG="$HOME/Library/Logs/brew-auto-upgrade.log"
MIN_INTERVAL=72000  # 20h: dedups RunAtLoad + noon calendar firing on the same day

mkdir -p "$STAMP_DIR"
[ -f "$LOG" ] && tail -n 500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
exec >>"$LOG" 2>&1

if [ -f "$STAMP" ]; then
    age=$(( $(date +%s) - $(stat -f %m "$STAMP") ))
    if [ "$age" -lt "$MIN_INTERVAL" ]; then
        echo "[$(date '+%F %T')] last success $((age / 3600))h ago, skipping"
        exit 0
    fi
fi

echo "=== [$(date '+%F %T')] run start ==="
eval "$(/opt/homebrew/bin/brew shellenv)"
export HOMEBREW_NO_ENV_HINTS=1

notify() {
    osascript -e "display notification \"$1 — see ~/Library/Logs/brew-auto-upgrade.log\" with title \"brew auto-upgrade FAILED\"" || true
}

# Network grace: right after wake, Wi-Fi may not be up yet
if ! brew update; then
    echo "brew update failed, retrying in 60s"
    sleep 60
    if ! brew update; then
        notify "brew update failed twice (no network?)"
        echo "=== [$(date '+%F %T')] aborted: brew update failed ==="
        exit 1
    fi
fi

failed=""
brew upgrade --formula || failed="$failed formulae"

# Casks whose upgrade removes root-owned system paths (e.g. obs writes to
# /Library/CoreMediaIO/Plug-Ins/DAL). Homebrew shells out to sudo for those, and
# launchd has no TTY and no askpass helper, so they can NEVER succeed here.
# Upgrade everything else and report these instead of failing the whole run.
NEEDS_ROOT=" obs "

upgradable=""; deferred=""
for c in $(brew outdated --cask --quiet 2>/dev/null); do
    case "$NEEDS_ROOT" in
        *" $c "*) deferred="$deferred $c" ;;
        *)        upgradable="$upgradable $c" ;;
    esac
done

if [ -n "$upgradable" ]; then
    brew upgrade --cask $upgradable || failed="$failed casks"
else
    echo "no casks to upgrade"
fi

if [ -n "$deferred" ]; then
    echo "deferred (need root, upgrade manually):$deferred"
    osascript -e "display notification \"Run: brew upgrade --cask$deferred\" with title \"brew: manual upgrade needed\"" || true
fi

brew cleanup --prune=7 || failed="$failed cleanup"

if [ -n "$failed" ]; then
    notify "step(s) failed:$failed"
    echo "=== [$(date '+%F %T')] finished WITH FAILURES:$failed ==="
    exit 1
fi

date > "$STAMP"
echo "=== [$(date '+%F %T')] run finished OK ==="
