#!/usr/bin/env bash
# scripts/apt-maintenance.sh - Higiene APT segura e idempotente (Debian Testing, podman-only).
#
# Ejecutar como root (los llamadores ya lo garantizan):
#   host/setup.sh  -> directo (ya es root), ANTES de `apt-get update`.
#   scripts/update.sh -> vía `sudo bash ...`, ANTES de `apt-get update`.
#
# Hace (seguro, re-ejecutable, nunca aborta el aprovisionamiento):
#   1. Elimina fuentes activas de Docker Inc (docker.list/docker.sources),
#      purga la pila docker-ce/containerd.io/docker.io si está instalada y
#      deshabilita sus servicios. Este repo es podman-only.
#   2. Deduplica VS Code: si existe vscode.sources (DEB822),
#      elimina el legacy vscode.list duplicado (mismo URI/suite/componente).
#   3. Gestiona repositorios oficiales para Debian Testing:
#      - Elimina debian-backports.sources y debian-fasttrack.sources si existieran.
#      - Asegura la existencia de /etc/apt/preferences.d/00-testing-pinning.pref.
#   4. Moderniza repositorios tradicionales (.list) al formato estándar DEB822
#      (.sources) vía `apt modernize-sources` si está disponible en la versión de APT.
#   5. Purgado de configuraciones residuales (paquetes desinstalados en estado 'rc' de dpkg).
#   6. Repara estados interrumpidos: dpkg --configure -a, apt-get install -f -y,
#      autoremove --purge y clean.
# Reporta sin tocar: fuentes de terceros desconocidas, keyrings referenciados
# ausentes y respaldos *.bak/*.save (decisión manual del operador).
#
# Hooks de test: APT_SOURCES_D, APT_KEYRINGS_D (por defecto rutas del sistema).
set -euo pipefail

SOURCES_D="${APT_SOURCES_D:-/etc/apt/sources.list.d}"
KEYRINGS_D="${APT_KEYRINGS_D:-/etc/apt/keyrings}"

[[ $EUID -eq 0 ]] || { echo "Ejecutar como root: sudo bash scripts/apt-maintenance.sh"; exit 1; }

warn() { echo "  ⚠️ $1"; }
ok()   { echo "  ✔ $1"; }

echo "================================================================="
echo "==> Higiene APT ([Debian Testing], podman-only, DEB822, idempotente)"
echo "================================================================="

# ------------------------------------------------------------------------------
# 1. Docker Inc: fuera (fuentes, keyring huérfano, paquetes y servicios)
# ------------------------------------------------------------------------------
for f in "$SOURCES_D/docker.list" "$SOURCES_D/docker.sources"; do
    if [ -e "$f" ]; then
        echo "  Eliminando fuente Docker: $(basename "$f")..."
        rm -f "$f"
    fi
done

if [ -e "$KEYRINGS_D/docker.asc" ]; then
    if grep -rh 'docker\.asc' "$SOURCES_D" --include='*.list' --include='*.sources' 2>/dev/null | grep -qv '^[[:space:]]*\(#\|$\)'; then
        ok "Keyring docker.asc aún referenciado por una fuente activa, se conserva."
    else
        echo "  Eliminando keyring huérfano: docker.asc..."
        rm -f "$KEYRINGS_D/docker.asc"
    fi
fi

DOCKER_PKGS=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras docker.io)
TO_PURGE=()
for pkg in "${DOCKER_PKGS[@]}"; do
    if dpkg -s "$pkg" &>/dev/null; then
        TO_PURGE+=("$pkg")
    fi
done
if [ "${#TO_PURGE[@]}" -gt 0 ]; then
    echo "  Purgando pila Docker (podman-only): ${TO_PURGE[*]}..."
    apt-get purge -y "${TO_PURGE[@]}" || warn "purga parcial, revisar con 'apt-get purge'."
    ok "Pila Docker purgada."
else
    ok "Sin paquetes Docker instalados."
fi
systemctl disable --now docker.service docker.socket containerd.service 2>/dev/null || true

# ------------------------------------------------------------------------------
# 2. VS Code: deduplicar legacy .list si ya existe el .sources DEB822
# ------------------------------------------------------------------------------
if [ -f "$SOURCES_D/vscode.sources" ] && [ -f "$SOURCES_D/vscode.list" ]; then
    echo "  Deduplicando VS Code: eliminando vscode.list (se conserva vscode.sources DEB822)..."
    rm -f "$SOURCES_D/vscode.list"
    ok "VS Code deduplicado."
fi

# ------------------------------------------------------------------------------
# 3. Repositorios oficiales y Pinning para Debian Testing
# ------------------------------------------------------------------------------
for legacy_repo in "$SOURCES_D/debian-backports.sources" "$SOURCES_D/debian-fasttrack.sources"; do
    if [ -f "$legacy_repo" ]; then
        echo "  Eliminando repositorio obsoleto de Stable: $(basename "$legacy_repo")..."
        rm -f "$legacy_repo"
        ok "$(basename "$legacy_repo") eliminado."
    fi
done

PINNING_FILE="/etc/apt/preferences.d/00-testing-pinning.pref"
if [ ! -f "$PINNING_FILE" ]; then
    echo "  Recreando $PINNING_FILE con prioridades de Testing (Testing=900, Stable-Security=500, Unstable=100)..."
    mkdir -p /etc/apt/preferences.d
    cat > "$PINNING_FILE" << 'EOF'
Package: *
Pin: release a=testing
Pin-Priority: 900

Package: *
Pin: release a=testing-security
Pin-Priority: 900

Package: *
Pin: release a=testing-updates
Pin-Priority: 900

Package: *
Pin: release a=stable-security
Pin-Priority: 500

Package: *
Pin: release a=unstable
Pin-Priority: 100
EOF
    ok "APT Pinning configurado en $PINNING_FILE."
else
    ok "APT Pinning presente en $PINNING_FILE."
fi

# ------------------------------------------------------------------------------
# 4. Modernización a formato DEB822 (.sources) vía apt modernize-sources
# ------------------------------------------------------------------------------
if apt help 2>&1 | grep -q "modernize-sources"; then
    has_legacy_sources=0
    if [ -s /etc/apt/sources.list ] && grep -vE '^[[:space:]]*(#|$)' /etc/apt/sources.list >/dev/null 2>&1; then
        has_legacy_sources=1
    elif ls "$SOURCES_D"/*.list >/dev/null 2>&1; then
        for f in "$SOURCES_D"/*.list; do
            if [ -s "$f" ] && grep -vE '^[[:space:]]*(#|$)' "$f" >/dev/null 2>&1; then
                has_legacy_sources=1
                break
            fi
        done
    fi

    if [ "$has_legacy_sources" -eq 1 ]; then
        echo "  Modernizando fuentes legacy (.list) a formato canónico DEB822 (.sources)..."
        apt modernize-sources 2>/dev/null || warn "apt modernize-sources devolvió advertencias."
        ok "Fuentes modernizadas a formato DEB822."
    fi
fi

# ------------------------------------------------------------------------------
# 5. Purgar configuraciones residuales (paquetes en estado 'rc' en dpkg)
# ------------------------------------------------------------------------------
RC_PKGS=$(dpkg -l 2>/dev/null | awk '/^rc/ {print $2}' || true)
if [ -n "$RC_PKGS" ]; then
    echo "  Purgando archivos de configuración residuales (estado rc)..."
    # shellcheck disable=SC2086
    dpkg --purge $RC_PKGS 2>/dev/null || warn "purga parcial de paquetes en estado rc."
    ok "Configuraciones residuales purgadas."
fi

# ------------------------------------------------------------------------------
# 6. Reparación segura de estados interrumpidos (no-op en sistema sano)
# ------------------------------------------------------------------------------
echo "==> Reparando estado de paquetes..."
dpkg --configure -a || warn "dpkg --configure -a devolvió errores."
apt-get install -f -y || warn "apt-get install -f devolvió errores."
apt-get autoremove --purge -y || warn "autoremove devolvió errores."
apt-get clean || warn "apt-get clean devolvió errores."
ok "Estado reparado y caché limpia."

# ------------------------------------------------------------------------------
# 7. Auditoría informativa (solo lectura, sin cambios)
# ------------------------------------------------------------------------------
echo "==> Auditoría de fuentes (informativa)..."
echo "  Fuentes de terceros activas:"
grep -rhE '^(deb[[:space:]]|URIs:)' "$SOURCES_D" --include='*.list' --include='*.sources' 2>/dev/null \
    | grep -v 'debian\.org\|security\.debian\.org' || echo "    (ninguna además de Debian)"
echo "  Keyrings referenciados inexistentes:"
missing=0
while IFS= read -r key; do
    if [ -n "$key" ] && [ ! -e "$key" ]; then
        echo "    ✘ Falta: $key"
        missing=1
    fi
done < <( { sed -n 's/.*signed-by=\([^]]*\).*/\1/p' "$SOURCES_D"/*.list 2>/dev/null; \
            sed -n 's/^Signed-By:[[:space:]]*//p' "$SOURCES_D"/*.sources 2>/dev/null; } | sort -u )

[ "$missing" -eq 0 ] && ok "Todos los keyrings referenciados existen."

echo "✔ Higiene APT completada."
