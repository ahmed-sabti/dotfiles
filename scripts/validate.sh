#!/usr/bin/env bash
# Self-contained validation for CI (no make deps). Mirrors `make check`.
# Validates: JSON configs, shell syntax.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

echo "== json =="
for f in firefox/policies.json; do
  python3 -m json.tool "$f" >/dev/null 2>&1 && echo "  ok $f" || { echo "  FAIL $f"; fail=1; }
done

echo "== shell =="
bash -n install.sh && echo "  ok install.sh" || { echo "  FAIL install.sh"; fail=1; }
bash -n scripts/yugioh-lob-art.sh && echo "  ok yugioh-lob-art.sh" || { echo "  FAIL yugioh-lob-art.sh"; fail=1; }
for f in kde/*.sh kde/common/*.sh kde/os/*/*.sh; do
  bash -n "$f" && echo "  ok $f" || { echo "  FAIL $f"; fail=1; }
done
for f in kde/hosts/*/host.conf; do
  bash -n "$f" && grep -q '^ROLE=' "$f" && echo "  ok $f" || { echo "  FAIL $f (syntax or no ROLE=)"; fail=1; }
done
grep -vE "^\{\{" home/run_onchange_after_shell-packages.sh.tmpl | bash -n && echo "  ok shell-packages" || { echo "  FAIL shell-packages"; fail=1; }

if [ "$fail" -ne 0 ]; then echo "VALIDATION FAILED"; exit 1; fi
echo "all checks passed"
