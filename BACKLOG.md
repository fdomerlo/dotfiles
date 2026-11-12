# Backlog — Hyprland productivo

Actualizado: 2026-11-12

Estado: los bloques **flujo diario nativo**, **notificaciones + OSD**, **shell productiva**, **migración a Foot + Fuzzel** y la **suite Sysadmin / Productividad (Debian 13 Trixie)** están implementados y validados. El **Lote 1** (calculadora, búsqueda de archivos y selector de color), el **Lote 2** (luz nocturna y grabación de pantalla), el **Lote 3 / Ola 2** (OCR, módulos Waybar de energía/portátil e inhibidor de idle, y wallpaper por tema) y el **Lote 3 / Ola 3** (Overview tipo Activities con Quickshell y `local.conf` por máquina) están implementados. Quedan los ítems de exploración futura.

---

## P2 — Siguiente lote de productividad

### Búsqueda y acciones rápidas

- [ ] Evaluar un lanzador con búsqueda global (apps + archivos + calculadora + web + emoji).
  - [x] Alternativa de bajo riesgo implementada: `Super+Ctrl+F` busca archivos con `fd` + `fuzzel --dmenu` y abre el elegido con `xdg-open` (`hypr/scripts/file-search.sh`).
- [x] Agregar `Super+=` para `gnome-calculator`.

### Overview tipo Activities

- [x] Implementación elegida: **Quickshell** (`0.3.0`, `stable-backports`) con `ScreencopyView` e IPC nativo de Hyprland (`hypr/quickshell/` + `hypr/scripts/overview-toggle.sh`), tematizado en `mr-robot` y `cyber-teal`.
  - Descartado `hyprland-plugin-hyprexpo` de APT por incompatibilidad de ABI (`0.53.0` / `hyprland-abi-c8f4c09` vs Hyprland `0.55.2` / `hyprland-abi-ff3b2cb`).
- [x] `Super` mantiene `fuzzel` (lanzador rápido); el Overview se abre con `Super+A` (y gesto de 3 dedos hacia abajo en touchpad).

### Sistema y quick settings

- [x] Menú de apagado mantenido en `fuzzel` (`hypr/scripts/powermenu.sh`); `wlogout` descartado por ahora para mantener un único selector.
- [x] Módulos de Waybar para batería (`battery`), brillo (`backlight`), perfil de energía (`power-profiles-daemon`) e inhibidor de idle (`idle_inhibitor`) configurados y estilizados en `mr-robot` y `cyber-teal`.
- [x] Luz nocturna: `hyprsunset` (backports) con toggle (`Super+Ctrl+N`) y módulo de Waybar; se controla por IPC con `hyprctl hyprsunset temperature 4000|6500`.
- [x] Grabación de pantalla: `wf-recorder` con toggle (`Super+Shift+R`), detección del monitor enfocado, notificación al guardar e indicador `REC` en Waybar.
- [x] OCR de capturas: `tesseract-ocr` (`spa+eng`) + `grim`/`slurp` + `wl-copy` en `Super+Ctrl+O` (`hypr/scripts/ocr-region.sh`).
- [x] Selector de color: `hyprpicker` (backports) en `Super+Shift+P`; copia el color del píxel al portapapeles.
- [x] Wallpaper por tema: `wallpaper.sh` prioriza subcarpetas `<tema>/` (`~/.config/hypr/wallpapers/<tema>`, `~/Imágenes/Wallpapers/<tema>`, `hypr/themes/<tema>/wallpapers`) con fallback global, y `theme-switch.sh` rota el fondo al cambiar de tema.

## P3 — Exploración / decisiones futuras

- [ ] Evaluar `Quickshell` para widgets adicionales (OSD o quick settings) si `swayosd`/`swaync` quedan cortos en el futuro.
- [ ] Evaluar `hyprland-plugin-xtra-dispatchers` solo cuando exista una versión compatible con la ABI instalada.
