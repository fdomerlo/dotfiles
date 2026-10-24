# 2. VS Code: deduplicar legacy .list si ya existe el .sources DEB822
# ------------------------------------------------------------------------------
if [ -f "$SOURCES_D/vscode.sources" ] && [ -f "$SOURCES_D/vscode.list" ]; then
    echo "  Deduplicando VS Code: eliminando vscode.list (se conserva vscode.sources DEB822)..."
    rm -f "$SOURCES_D/vscode.list"
    ok "VS Code deduplicado."
fi

# ------------------------------------------------------------------------------
# 3. Repositorios oficiales: completar Signed-By vacío en Backports y FastTrack
# ------------------------------------------------------------------------------
BACKPORTS="$SOURCES_D/debian-backports.sources"
DEB_KEYRING="/usr/share/keyrings/debian-archive-keyring.gpg"
if [ -f "$BACKPORTS" ] && [ -f "$DEB_KEYRING" ] && grep -q '^Signed-By:[[:space:]]*$' "$BACKPORTS"; then
    echo "  Completando Signed-By en debian-backports.sources..."
    sed -i "s|^Signed-By:[[:space:]]*$|Signed-By: $DEB_KEYRING|" "$BACKPORTS"
    ok "Signed-By restaurado en backports."
fi

FASTTRACK="$SOURCES_D/debian-fasttrack.sources"
FASTTRACK_KEYRING="/usr/share/keyrings/fasttrack-archive-keyring.gpg"
if [ -f "$FASTTRACK" ] && [ -f "$FASTTRACK_KEYRING" ] && grep -q '^Signed-By:[[:space:]]*$' "$FASTTRACK"; then
    echo "  Completando Signed-By en debian-fasttrack.sources..."
    sed -i "s|^Signed-By:[[:space:]]*$|Signed-By: $FASTTRACK_KEYRING|" "$FASTTRACK"
    ok "Signed-By restaurado en fasttrack."
fi

# ------------------------------------------------------------------------------
# 4. Modernización a formato DEB822 (.sources) vía apt modernize-sources
# ------------------------------------------------------------------------------