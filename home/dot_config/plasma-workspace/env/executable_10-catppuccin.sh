#!/bin/sh
# Plasma workspace env: route Qt apps through Kvantum for Catppuccin styling - only where Kvantum is installed.
# Without Kvantum this variable breaks Qt theming for the whole session (seen on the T480: colours fell back to Breeze Light).
command -v kvantummanager >/dev/null 2>&1 && export QT_QPA_PLATFORMTHEME=kvantum
