# Backlog — Hyprland productivo

Actualizado: 2026-11-11

Estado: los bloques **flujo diario nativo**, **notificaciones + OSD**, **shell productiva**, **migración a Foot + Fuzzel** y la **suite Sysadmin / Productividad (Debian 13 Trixie)** están implementados y validados. Quedan los ítems de exploración futura y próximos lotes de productividad.

---

## P2 — Siguiente lote de productividad

### Búsqueda y acciones rápidas

- [ ] Evaluar un lanzador con búsqueda global (apps + archivos + calculadora + web + emoji).
  - Alternativa de bajo riesgo: `Super+Ctrl+F` para buscar archivos con `fdfind` + `fzf` + `batcat` o `fuzzel --dmenu`.
- [ ] Agregar `Super+=` para `gnome-calculator` (ya instalado).

### Overview tipo Activities

- [ ] Elegir implementación:
  - `hyprexpo` vía `hyprpm` (requiere `hyprland-dev`, `pkg-config`, `cmake`, `meson`).
  - `hyprshell` (overview + launcher; compilar con Rust).
  - Quickshell + módulo de overview (paquete disponible en backports).
- [ ] **No** usar `hyprland-plugin-hyprexpo` de APT: es 0.53.0 y depende de `hyprland-abi-c8f4c09`; Hyprland 0.55.2 provee `hyprland-abi-ff3b2cb`.
- [ ] Definir si `Super` sigue abriendo `fuzzel` o pasa a abrir el overview.

### Sistema y quick settings

- [ ] Agregar `wlogout` para el menú de apagado en grilla (o mantener el menú `fuzzel` actual).
- [ ] Evaluar módulos de Waybar para batería, brillo, perfil de energía e inhibidor de idle.
- [ ] Luz nocturna: `hyprsunset` (backports) o `gammastep`, con toggle y módulo de Waybar.
- [ ] Grabación de pantalla: `wf-recorder` + indicador en Waybar.
- [ ] OCR de capturas: `tesseract` + `grim`/`slurp` + `wl-copy`.
- [ ] Selector de color: `hyprpicker` (backports).
- [ ] Evaluar wallpaper por tema y aplicarlo desde `theme-switch.sh`.

## P3 — Exploración / decisiones futuras

- [ ] Evaluar migración de Display Manager a `greetd + tuigreet` (login TUI minimalista) para instalaciones dedicadas sin GDM/GNOME.
- [ ] Evaluar `thunar + gvfs-backends` como alternativa ultraliviana a `nautilus` si se prescinde de `gnome-core`.
- [ ] Si se migra a Debian Testing/Forky, evaluar `rofi 2.0` (Wayland nativo) en paralelo a `fuzzel`.
- [ ] Evaluar `Quickshell` para widgets propios (OSD, overview, quick settings) si el stack actual queda corto.
- [ ] Evaluar `hyprland-plugin-xtra-dispatchers` solo cuando exista una versión compatible con la ABI instalada.
