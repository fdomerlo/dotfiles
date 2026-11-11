# Backlog — Hyprland productivo

Actualizado: 2026-11-11

Estado: los bloques **flujo diario nativo**, **notificaciones + OSD**, **shell productiva**, **migración a Foot + Fuzzel** y la **suite Sysadmin / Productividad (Debian 13 Trixie)** están implementados y validados. El **Lote 1** (calculadora, búsqueda de archivos y selector de color) y el **Lote 2** (luz nocturna y grabación de pantalla) también están implementados. Quedan los ítems de exploración futura y próximos lotes de productividad.

---

## P2 — Siguiente lote de productividad

### Búsqueda y acciones rápidas

- [ ] Evaluar un lanzador con búsqueda global (apps + archivos + calculadora + web + emoji).
  - [x] Alternativa de bajo riesgo implementada: `Super+Ctrl+F` busca archivos con `fd` + `fuzzel --dmenu` y abre el elegido con `xdg-open` (`hypr/scripts/file-search.sh`).
- [x] Agregar `Super+=` para `gnome-calculator`.

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
- [x] Luz nocturna: `hyprsunset` (backports) con toggle (`Super+Ctrl+N`) y módulo de Waybar; se controla por IPC con `hyprctl hyprsunset temperature 4000|6500`.
- [x] Grabación de pantalla: `wf-recorder` con toggle (`Super+Shift+R`), notificación al guardar y indicador `REC` en Waybar.
- [ ] OCR de capturas: `tesseract` + `grim`/`slurp` + `wl-copy`.
- [x] Selector de color: `hyprpicker` (backports) en `Super+Shift+P`; copia el color del píxel al portapapeles.
- [ ] Evaluar wallpaper por tema y aplicarlo desde `theme-switch.sh`.

## P3 — Exploración / decisiones futuras

- [ ] Evaluar migración de Display Manager a `greetd + tuigreet` (login TUI minimalista) para instalaciones dedicadas sin GDM/GNOME.
- [ ] Evaluar `thunar + gvfs-backends` como alternativa ultraliviana a `nautilus` si se prescinde de `gnome-core`.
- [ ] Si se migra a Debian Testing/Forky, evaluar `rofi 2.0` (Wayland nativo) en paralelo a `fuzzel`.
- [ ] Evaluar `Quickshell` para widgets propios (OSD, overview, quick settings) si el stack actual queda corto.
- [ ] Evaluar `hyprland-plugin-xtra-dispatchers` solo cuando exista una versión compatible con la ABI instalada.
