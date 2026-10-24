#!/usr/bin/env bash
# scripts/clean-system.sh - Limpieza profunda e higienización post-upgrade en Debian.
#
# Diseñado para purgar residuos dejados por transiciones entre versiones de Debian
# (ej. Stable -> Testing o Testing -> Sid):
#   1. Purga configuraciones residuales (paquetes desinstalados en estado 'rc' de dpkg).
#   2. Purga dependencias huérfanas con autoremove --purge.
#   3. Limpieza de paquetes huérfanos con deborphan si está disponible.
#   4. Vaciado de caché local de paquetes APT (/var/cache/apt/archives).
#   5. Compactación de registros y logs de systemd journal (vacuum).
#   6. Limpieza de temporales en espacio de usuario.
set -euo pipefail

log() { echo -e "\n==> $1"; }
ok()  { echo "  ✔ $1"; }
warn(){ echo "  ⚠️ $1"; }

# 1. Tareas con privilegios de root (APT / dpkg / systemd)
clean_root() {
    log "1. Purgando archivos de configuración residuales (estado 'rc' en dpkg)..."
    local rc_pkgs
    rc_pkgs=$(dpkg -l 2>/dev/null | awk '/^rc/ {print $2}' || true)
    if [ -n "$rc_pkgs" ]; then
        echo "  Paquetes residuales encontrados:"
        echo "$rc_pkgs" | sed 's/^/    - /'
        # shellcheck disable=SC2086
        dpkg --purge $rc_pkgs 2>/dev/null || warn "Algunos paquetes no pudieron ser purgados."
        ok "Configuraciones residuales eliminadas."
    else
        ok "Sin configuraciones residuales pendientes."
    fi

    log "2. Purgando dependencias y paquetes huérfanos (autoremove --purge)..."
    apt-get autoremove --purge -y 2>/dev/null || warn "autoremove devolvió advertencias."
    ok "Dependencias huérfanas purgadas."

    log "3. Verificando librerías y paquetes huérfanos (deborphan)..."
    if command -v deborphan &>/dev/null; then
        local orphan_pkgs
        orphan_pkgs=$(deborphan --guess-all 2>/dev/null || true)
        if [ -n "$orphan_pkgs" ]; then
            echo "  Librerías huérfanas detectadas:"
            echo "$orphan_pkgs" | sed 's/^/    - /'
            echo "$orphan_pkgs" | xargs -r apt-get purge -y || warn "Error al purgar paquetes de deborphan."
            ok "Librerías huérfanas eliminadas."
        else
            ok "No se detectaron librerías huérfanas."
        fi
    else
        ok "deborphan no instalado (opcional, omitido)."
    fi

    log "4. Limpiando caché local de descargas APT..."
    apt-get clean
    ok "Caché de paquetes vaciada."

    log "5. Compactando registros del sistema (journalctl vacuum)..."
    if command -v journalctl &>/dev/null; then
        journalctl --vacuum-time=3d 2>/dev/null || true
        ok "Logs del sistema compactados a los últimos 3 días."
    fi
}

# 2. Tareas en espacio de usuario
clean_user() {
    log "6. Limpiando temporales en espacio de usuario..."
    rm -rf "$HOME/.oh-my-zsh.tmp" 2>/dev/null || true
    rm -rf "$HOME/.cache/thumbnails" 2>/dev/null || true
    ok "Temporales de usuario limpios."
}

echo "================================================================="
echo "==> Limpieza Profunda del Sistema Debian (Post-Upgrade)"
echo "================================================================="

if [ "$EUID" -eq 0 ]; then
    clean_root
    clean_user
else
    can_sudo=0
    if sudo -n true 2>/dev/null; then
        can_sudo=1
    elif sudo -v 2>/dev/null; then
        can_sudo=1
    fi

    if [ "$can_sudo" -eq 1 ]; then
        sudo bash "$0"
    else
        warn "Sin elevación sudo disponible en este entorno: ejecutando tareas de limpieza en user-space."
        warn "Para ejecutar la purga completa a nivel sistema, corre: sudo bash scripts/clean-system.sh"
        clean_user
    fi
fi

echo -e "\n================================================================="
echo "✔ Limpieza finalizada."
echo "================================================================="
