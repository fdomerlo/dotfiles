#!/usr/bin/env bash
# scripts/detect-suite.sh - Detección dinámica de Suite Debian (Stable vs Testing)
#
# Determina si el sistema actual corre sobre 'stable' o 'testing' de forma
# agnóstica a los nombres en clave (codenames como bookworm, trixie, forky, etc.).
#
# Uso:
#   bash scripts/detect-suite.sh          # Imprime: stable | testing
#   bash scripts/detect-suite.sh --label  # Imprime: Stable | Testing
#   bash scripts/detect-suite.sh --info   # Imprime: Debian Stable | Debian Testing
#   source scripts/detect-suite.sh        # Exporta DEBIAN_SUITE y DEBIAN_SUITE_LABEL
set -euo pipefail

detect_suite() {
    # 1. Consultar la prioridad de archivo de Debian si APT está inicializado
    if command -v apt-cache &>/dev/null; then
        local apt_archive
        apt_archive=$(apt-cache policy 2>/dev/null | grep -oP '(?<=o=Debian,a=)(stable|testing)' | head -n 1 || true)
        if [ "$apt_archive" = "testing" ] || [ "$apt_archive" = "stable" ]; then
            echo "$apt_archive"
            return
        fi
    fi

    # 2. Consultar fuentes configuradas en /etc/apt
    if grep -rhE '^[[:space:]]*Suites:[[:space:]]*(.*)' /etc/apt/sources.list.d/*.sources 2>/dev/null | grep -qw 'testing'; then
        echo "testing"
        return
    elif grep -rhE '^[[:space:]]*deb[[:space:]]+.*[[:space:]]+testing([[:space:]]|$)' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null | grep -qv '^[[:space:]]*#'; then
        echo "testing"
        return
    fi

    # 3. Consultar /etc/debian_version (en testing suele contener 'sid' o 'testing')
    if [ -f /etc/debian_version ]; then
        local deb_ver
        deb_ver=$(cat /etc/debian_version 2>/dev/null || true)
        if [[ "$deb_ver" == *"sid"* ]] || [[ "$deb_ver" == *"testing"* ]]; then
            echo "testing"
            return
        fi
    fi

    # 4. Consultar /etc/os-release
    if [ -f /etc/os-release ]; then
        if grep -qi 'testing' /etc/os-release 2>/dev/null; then
            echo "testing"
            return
        fi
    fi

    # 5. Por defecto Debian Stable
    echo "stable"
}

CURRENT_SUITE=$(detect_suite)
CURRENT_LABEL="Stable"
[ "$CURRENT_SUITE" = "testing" ] && CURRENT_LABEL="Testing"

export DEBIAN_SUITE="$CURRENT_SUITE"
export DEBIAN_SUITE_LABEL="$CURRENT_LABEL"

# Si el script se ejecuta directamente (no mediante source), emitir según argumentos
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        --label)
            echo "$CURRENT_LABEL"
            ;;
        --info)
            echo "Debian $CURRENT_LABEL"
            ;;
        *)
            echo "$CURRENT_SUITE"
            ;;
    esac
fi
