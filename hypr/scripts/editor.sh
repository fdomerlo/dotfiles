#!/usr/bin/env bash
# ==============================================================================
# Lanza el editor de código predeterminado.
#
# Prioridad: $DOTFILES_EDITOR (permite comandos con argumentos), Zed, VS Code y
# Neovim en Foot como último respaldo. Sin argumentos abre el editor vacío; con
# rutas las abre como workspace.
#
# Uso:
#   editor.sh                 # abre el editor predeterminado
#   editor.sh ~/proyecto      # abre una carpeta o archivo
# ==============================================================================
set -euo pipefail

if [ -n "${DOTFILES_EDITOR:-}" ] && command -v "${DOTFILES_EDITOR%% *}" >/dev/null 2>&1; then
    # El split es intencional para permitir comandos compuestos.
    # shellcheck disable=SC2086
    exec ${DOTFILES_EDITOR} "$@"
fi

if command -v zed >/dev/null 2>&1; then
    exec zed "$@"
fi

if command -v code >/dev/null 2>&1; then
    exec code "$@"
fi

if command -v nvim >/dev/null 2>&1 && command -v foot >/dev/null 2>&1; then
    exec foot -e nvim "$@"
fi

exit 1
