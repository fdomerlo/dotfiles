#!/usr/bin/env bash
# ==============================================================================
# Repara el arranque de audio cuando WirePlumber enumera los dispositivos antes
# de que el core de PipeWire esté listo (sof-hda-dsp). En ese caso queda solo
# "Dummy Output", cuyo volumen no responde y hace que Waybar parezca congelado.
#
# Si el sink por defecto es el fallback auto_null, reinicia WirePlumber una vez
# para que cree Speaker/HDMI. Idempotente: si el sink real ya existe, no hace nada.
# ==============================================================================
set -u

# Espera hasta 5 s a que exista un sink por defecto.
node=""
for _ in $(seq 1 50); do
    node="$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null \
        | awk -F'"' '/node.name/{print $2; exit}')"
    [ -n "$node" ] && break
    sleep 0.1
done

# auto_null significa que WirePlumber no pudo crear las salidas ALSA reales.
if [ -z "$node" ] || [ "$node" = "auto_null" ]; then
    systemctl --user restart wireplumber 2>/dev/null || true
fi
