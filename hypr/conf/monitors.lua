-- Layout de monitores.
-- Se usan nombres de conector (no modelo/serie) para no depender del monitor.
-- Si en otra PC los conectores se llaman distinto, ajustar en conf/local.lua.
--
-- Izquierda: HDMI-A-1
-- Derecha:   HDMI-A-2
--
-- Para intercambiar el orden físico, invertir los nombres de las dos reglas
-- (o intercambiar los cables). Ver salidas disponibles con: hyprctl monitors
--
-- Escala: se deja 1 en todas las salidas.
-- La escala es un zoom lógico por salida, no un ajuste automático de densidad.
-- Como los equipos de escritorio usan paneles 1080p de 92-96 PPI, a escala 1 se
-- ven iguales entre sí y no hace falta nada. `hypr/scripts/monitor-scale.sh`
-- sigue disponible para casos puntuales.

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "preferred",
    position = "0x0",
    scale    = 1,
})

hl.monitor({
    output   = "HDMI-A-2",
    mode     = "preferred",
    position = "auto-right",
    scale    = 1,
})

-- Monitor 24" 1080p (Hexium Ltd. L23, ~92 PPI): usar VGA.
-- Por HDMI el panel aplica overscan (recorta los bordes) y no expone la opción
-- en el OSD, porque su EDID se anuncia como entrada de video CEA-861. Por VGA
-- aparece como DP-1 (la placa lo cuelga de un puente DP→VGA) y se muestra 1:1.
-- No lleva regla propia: el fallback lo deja en escala 1, igual que el resto.

-- Fallback para cualquier salida que no tenga una regla explícita.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
