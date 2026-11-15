#!/usr/bin/env bash
# ==============================================================================
# Lanza el navegador predeterminado del sistema (Firefox por defecto en estos
# dotfiles), con respaldo automático a Firefox Flatpak/nativo o Chrome.
# ==============================================================================
set -euo pipefail

if command -v xdg-settings >/dev/null 2>&1 && command -v gtk-launch >/dev/null 2>&1; then
    default_desktop="$(xdg-settings get default-web-browser 2>/dev/null || true)"
    if [ -n "$default_desktop" ] && gtk-launch "$default_desktop" "$@" >/dev/null 2>&1; then
        exit 0
    fi
fi

if command -v flatpak >/dev/null 2>&1 && flatpak info org.mozilla.firefox >/dev/null 2>&1; then
    exec flatpak run org.mozilla.firefox "$@"
elif command -v firefox >/dev/null 2>&1; then
    exec firefox "$@"
elif command -v firefox-esr >/dev/null 2>&1; then
    exec firefox-esr "$@"
elif command -v google-chrome >/dev/null 2>&1; then
    exec google-chrome "$@"
fi

exit 1
