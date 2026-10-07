#!/usr/bin/env bash
set -euo pipefail

echo "================================================================="
echo "==> Instalando herramientas de Inteligencia Artificial..."
echo "================================================================="

# OpenCode CLI
if ! command -v opencode &> /dev/null; then
    echo "Instalando OpenCode CLI..."
    curl -fsSL https://opencode.ai/v2/install | bash
else
    echo "✔ OpenCode CLI ya está instalado"
fi

# Antigravity Core & CLI
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/setup_agy.sh"

echo "✔ Herramientas de IA instaladas."
