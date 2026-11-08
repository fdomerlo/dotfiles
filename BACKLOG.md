# Backlog — Hyprland productivo

Actualizado: 2026-11-08

Estado: los bloques **flujo diario nativo**, **notificaciones + OSD** y **shell productiva** ya están implementados en el repo. Falta instalar los paquetes nuevos y validar el comportamiento en una sesión real.

---

## P0 — Bloqueante: instalar y activar

- [ ] Instalar los paquetes que requieren contraseña:
  ```bash
  sudo apt update
  sudo apt install sway-notification-center swayosd zoxide atuin starship tmux
  ```
- [ ] Reemplazar `mako` por `swaync` en la sesión actual:
  ```bash
  pkill -x mako
  swaync >/dev/null 2>&1 &
  swayosd-server >/dev/null 2>&1 &
  ```
- [ ] Reiniciar Waybar para que cargue el módulo `custom/notification`:
  ```bash
  pkill -x waybar
  ~/.config/hypr/scripts/start-waybar.sh >/dev/null 2>&1 &
  ```
- [ ] Abrir una terminal nueva (o `exec zsh`) y confirmar que aparecen `zoxide`, `atuin` y el prompt de `starship`.
- [ ] Ejecutar `make verify` y confirmar que desaparecen los FAIL de `swaync`, `swayosd`, `zoxide`, `atuin`, `starship` y `tmux`.
- [ ] Cerrar y volver a iniciar sesión una vez para validar el arranque automático desde `hypr/conf/autostart.conf`.

## P1 — Validación funcional de lo implementado

### Notificaciones (`swaync`)

- [ ] Verificar que `swaync` toma el bus de notificaciones sin conflicto con `mako`.
- [ ] Probar `Super+N` (centro de notificaciones) y `Super+Shift+N` (No molestar).
- [ ] Confirmar historial, botón "Limpiar todo", MPRIS, volumen y brillo en el centro de control.
- [ ] Verificar los estados del módulo de Waybar: normal, con notificaciones, DND e inhibido.
- [ ] Revisar que `~/.config/swaync/config.json` y `style.css` se lean sin warnings en el log de swaync.
- [ ] Ajustar el widget `backlight` si el equipo no usa `intel_backlight` (ver `ls /sys/class/backlight`).

### OSD (`swayosd`)

- [ ] Probar volumen subir/bajar/mute y mic mute con las teclas `XF86Audio*`.
- [ ] Probar brillo subir/bajar con `XF86MonBrightness*`.
- [ ] Verificar que si `swayosd-server` no corre, `hypr/scripts/osd.sh` siga funcionando vía `wpctl`/`brightnessctl`.
- [ ] Confirmar que `swayosd-server` no interfiere con GNOME al volver a esa sesión.

### Flujo diario

- [ ] Probar `Alt+Tab`, `Alt+Shift+Tab` y `Alt+\`` con varias ventanas y en multi-monitor.
- [ ] Probar `Super+\`` con scratchpad abierto, cerrado y con la terminal cerrada.
- [ ] Probar `Super+Shift+\`` para mover una ventana al scratchpad.
- [ ] Probar grupos: `Super+G`, `Super+Tab`, `Super+Shift+Tab`, `Super+Ctrl+G`, `Super+Shift+G`.
- [ ] Verificar que `Super+Shift+1..0` mueve la ventana sin cambiar de workspace.
- [ ] Abrir `Super+/` y confirmar que el cheatsheet lista los atajos nuevos con nombres legibles.
- [ ] Validar `Super+M` (maximizar/restaurar) en ventanas tileadas y flotantes.

### Shell

- [ ] Probar `z` y `zi` con directorios recientes.
- [ ] Probar `Ctrl+R` de Atuin y decidir si convive bien con el `Ctrl+R` de `fzf`.
- [ ] Revisar el prompt de Starship en repos Git con cambios, ramas y comandos lentos.
- [ ] Probar `Super+Shift+Return` y confirmar que reutiliza la sesión `main` de tmux.
- [ ] Revisar `~/.tmux.conf`: prefix `Ctrl+a`, splits en el directorio actual y recarga con `prefix + r`.

## P2 — Siguiente lote de productividad

### Búsqueda y acciones rápidas

- [ ] Evaluar un lanzador con búsqueda global (apps + archivos + calculadora + web + emoji).
  - Walker y Vicinae no están empaquetados en Debian; habría que compilarlos o usar *scripts* sobre `wofi`.
  - Alternativa de bajo riesgo: `Super+Ctrl+F` para buscar archivos con `fdfind` + `fzf` + `batcat`.
- [ ] Agregar `Super+=` para `gnome-calculator` (ya instalado).
- [ ] Evaluar `rofi-calc` / `rofi-emoji` solo si se migra a Debian Testing.

### Ventanas estilo GNOME

- [ ] Definir si se adopta el "modo GNOME" de ventanas:
  - `Super+flechas` para snap/maximize, dejando el foco en `Super+hjkl`.
  - `Super+1..9` para apps y workspaces en `Super+Ctrl+1..0`.
- [ ] Implementar snap a mitades/cuartos con scripts o reglas si se adopta ese modo.
- [ ] Evaluar "minimizar": Hyprland no tiene minimize nativo; opciones son workspace especial, scratchpad o `special:minimized`.

### Overview tipo Activities

- [ ] Elegir implementación:
  - `hyprexpo` vía `hyprpm` (requiere `hyprland-dev`, `pkg-config`, `cmake`, `meson`).
  - `hyprshell` (overview + launcher; compilar con Rust).
  - Quickshell + módulo de overview (paquete disponible en backports).
- [ ] **No** usar `hyprland-plugin-hyprexpo` de APT: es 0.53.0 y depende de `hyprland-abi-c8f4c09`; Hyprland 0.55.2 provee `hyprland-abi-ff3b2cb`.
- [ ] Definir si `Super` sigue abriendo `wofi` o pasa a abrir el overview.

### Sistema y quick settings

- [ ] Agregar `wlogout` para el menú de apagado en grilla (o mantener el menú wofi actual).
- [ ] Evaluar módulos de Waybar para batería, brillo, perfil de energía e inhibidor de idle.
- [ ] Luz nocturna: `hyprsunset` (backports) o `gammastep`, con toggle y módulo de Waybar.
- [ ] Grabación de pantalla: `wf-recorder` + indicador en Waybar.
- [ ] Capturas con anotación: `swappy` (disponible en trixie).
- [ ] OCR de capturas: `tesseract` + `grim`/`slurp` + `wl-copy`.
- [ ] Selector de color: `hyprpicker` (backports).

### Estética

- [ ] Evaluar generación de tema desde el wallpaper (`matugen`/`wallust`), sabiendo que no están empaquetados y hay que compilarlos.
- [ ] Unificar notificaciones, Waybar, wofi y tmux bajo la misma paleta Cyber-Teal (parcialmente hecho).

## P3 — Exploración / decisiones futuras

- [ ] Si se migra a Debian Testing/Forky, evaluar `rofi 2.0` (Wayland nativo) en paralelo a `wofi`.
  - Adaptar `toggle-wofi.sh` a `pgrep -x rofi` y probar `combi`, `window`, `filebrowser`.
  - `rofi-calc` y `rofi-emoji` siguen sin empaquetar en Debian.
- [ ] Evaluar `Quickshell` para widgets propios (OSD, overview, quick settings) si el stack actual queda corto.
- [ ] Evaluar `hyprland-plugin-xtra-dispatchers` solo cuando exista una versión compatible con la ABI instalada.

## Deuda técnica y repo

- [ ] Revisar y commitear los cambios actuales (hay archivos modificados y nuevos sin commit).
- [ ] Decidir si `scripts/update.sh` debe actualizar también los paquetes del perfil Hyprland (`swaync`, `swayosd`, etc.).
- [ ] Revisar si `verify.sh` debe tratar `swaync`/`swayosd` como obligatorios o como opcionales con aviso.
- [ ] Documentar en README el flujo de rollback de notificaciones: volver a `mako` si `swaync` falla.
- [ ] Agregar una captura o GIF del escritorio al README (opcional).

## Criterios para dar por cerrado el lote actual

- [ ] `make verify` sin FAIL en el perfil Hyprland ni en herramientas de shell.
- [ ] `hyprctl configerrors` vacío tras un login limpio.
- [ ] Notificaciones, DND y OSD funcionando sin `mako` corriendo en paralelo.
- [ ] `Alt+Tab`, scratchpad, grupos y cheatsheet probados en uso real durante una jornada.
- [ ] `zoxide`, `atuin`, `starship` y `tmux` funcionando en una terminal nueva.
