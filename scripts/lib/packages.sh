#!/usr/bin/env bash
# scripts/lib/packages.sh - Utilidades para leer manifiestos planos en packages/.

# Lee un archivo de manifiesto (una entrada por línea, soporta comentarios '#')
# y puebla el array destino pasado por nombre.
read_manifest() {
    local manifest_file="$1"
    local target_var="$2"
    # shellcheck disable=SC2178
    local -n _manifest_out="$target_var"
    local line

    _manifest_out=()
    if [ ! -r "$manifest_file" ]; then
        echo "ERROR: No se pudo leer el manifiesto de paquetes: $manifest_file" >&2
        return 1
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        [ -n "$line" ] && _manifest_out+=("$line")
    done < "$manifest_file"
}
