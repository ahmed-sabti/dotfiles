#!/usr/bin/env bash
# Re-apply Catppuccin Mocha once Plasma is up.
# The custom ubuntu-desk session (desk-xsession.sh) doesn't reliably run Plasma's
# standard autostart, so desk-xsession.sh launches this waiter instead.
for i in $(seq 1 60); do
  pgrep -x plasmashell >/dev/null 2>&1 && break
  sleep 1
done
sleep 4
plasma-apply-colorscheme CatppuccinMocha >/dev/null 2>&1 || true
