# Backlog — Hyprland productivo

Actualizado: 2026-11-09

Estado: los bloques **flujo diario nativo**, **notificaciones + OSD** y **shell productiva** están implementados y el **P0 quedó validado** el 2026-11-08 (paquetes instalados, swaync activo sin mako, OSD operativo, shell y tmux funcionando). Queda la validación de uso real del P1 y los lotes del P2.

---

## P0 — Bloqueante: instalar y activar

- [x] Instalar los paquetes que requieren contraseña:
  ```bash
  sudo apt update
  sudo apt install sway-notification-center swayosd zoxide atuin starship tmux
  ```
- [x] Reemplazar `mako` por `swaync` en la sesión actual:
  ```bash
  pkill -x mako
  swaync >/dev/null 2>&1 &
  swayosd-server >/dev/null 2>&1 &
  ```
- [x] Reiniciar Waybar para que cargue el módulo `custom/notification`:
  ```bash
  pkill -x waybar
  ~/.config/hypr/scripts/start-waybar.sh >/dev/null 2>&1 &
  ```
- [x] Abrir una terminal nueva (o `exec zsh`) y confirmar que aparecen `zoxide`, `atuin` y el prompt de `starship`.
- [x] Ejecutar `make verify` y confirmar que desaparecen los FAIL de `swaync`, `swayosd`, `zoxide`, `atuin`, `starship` y `tmux`.
- [x] Cerrar y volver a iniciar sesión una vez para validar el arranque automático desde `hypr/conf/autostart.conf`.

Evidencia del login del 2026-11-08 10:30:48: `swaync` y `swayosd-server` fueron lanzados por `exec-once`, `mako` no corre y `make verify` quedó sin FAIL en el perfil Hyprland y en herramientas de shell.

## P1 — Validación funcional de lo implementado

### Notificaciones (`swaync`)

- [x] Verificar que `swaync` toma el bus de notificaciones sin conflicto con `mako`.
- [x] Probar `Super+N` (centro de notificaciones) y `Super+Shift+N` (No molestar). Los comandos `swaync-client -op/-cp` y `-dn/-df` responden y los binds están cargados.
- [x] Confirmar historial, botón "Limpiar todo", MPRIS, volumen y brillo en el centro de control.
- [x] Verificar visualmente los estados del módulo de Waybar: normal, con notificaciones, DND e inhibido.
- [x] Revisar que `~/.config/swaync/config.json` y `style.css` se lean sin warnings en el log de swaync. El journal no muestra errores de configuración ni de CSS.
- [x] Verificar `backlight`: este equipo no expone `/sys/class/backlight`, así que el widget y el OSD de brillo no tienen efecto. Evaluar quitar el widget en P2.

### Waybar

- [x] Dar al icono de notificaciones el mismo borde, fondo y padding que el resto de los módulos derechos.
- [x] Unificar el indicador de red: queda solo el módulo `network` de Waybar y se quitó `nm-applet` del autostart.
- [x] Reloj: solo hora local en la barra (con `locale` y `timezone` explícitos), sin `format-alt`; el tooltip muestra la fecha completa en lugar del calendario.
- [x] swaync: `keyboard-shortcuts: false` para no secuestrar el teclado/foco, `layer-shell-cover-screen: true` para detectar el clic afuera y `layerrule order -1` para dejar Waybar por encima del panel.
- [x] Clic en CPU y MEM abre `btop` en una terminal kitty.
- [x] Quitar `blueman-applet` del autostart: el módulo nativo `bluetooth` de Waybar ya cubre estado/batería y el clic abre `blueman-manager`, sin ícono duplicado en la bandeja.
- [x] Confirmar manualmente que el clic en la campana alterna el panel y que el clic afuera también lo cierra.

### OSD (`swayosd`)

- [x] Probar volumen subir/bajar/mute y mic mute con las teclas `XF86Audio*`. Los cuatro comandos de `osd.sh` salen con código 0.
- [x] Probar brillo subir/bajar con `XF86MonBrightness*`: sin dispositivo de backlight en este equipo, no hay cambio visible.
- [x] Verificar que si `swayosd-server` no corre, `hypr/scripts/osd.sh` siga funcionando vía `wpctl`/`brightnessctl`. Probado con stubs.
- [x] Corregir el volumen atascado en 100%: `audio-init.sh` detecta si WirePlumber dejó solo `Dummy Output` y lo reinicia antes de lanzar Waybar para que aparezcan Speaker/HDMI.
- [x] Confirmar que `swayosd-server` no interfiere con GNOME al volver a esa sesión.

### Flujo diario

- [x] Probar `Alt+Tab`, `Alt+Shift+Tab` y `Alt+\`` con varias ventanas y en multi-monitor.
- [x] Probar `Super+\`` con scratchpad abierto, cerrado y con la terminal cerrada. La ventana queda en `special:magic`, flotante y centrada.
- [ ] Probar `Super+Shift+\`` para mover una ventana al scratchpad.
- [x] Probar grupos: `Super+G`, `Super+Tab`, `Super+Shift+Tab`, `Super+Ctrl+G`, `Super+Shift+G`.
- [x] Verificar que `Super+Shift+1..0` mueve la ventana sin cambiar de workspace.
- [x] Abrir `Super+F1` y confirmar que el cheatsheet lista los atajos nuevos con nombres legibles. Genera 84 entradas y el bind está cargado. Se cambió desde `Super+/` porque en latam `/` es `Shift+7` y colisiona con `movetoworkspacesilent 7`.
- [x] Validar `Super+M` (maximizar/restaurar) en ventanas tileadas y flotantes.

### Multi-monitor

- [x] Fijar layout de dos monitores por conector (`HDMI-A-1` izquierda, `HDMI-A-2` derecha) y rangos de workspaces `1–5` / `6–0`.
- [x] Ajustar Waybar para mostrar cada rango solo en su salida (`all-outputs: false` + `persistent-workspaces` por monitor).
- [x] Validar en uso real que `Super+1..5` y `Super+6..0` enfocan siempre el monitor correcto, incluso con el foco en el otro.

### Shell

- [x] Probar `z` y `zi` con directorios recientes: las funciones existen y `zoxide query` responde.
- [x] Probar la inicialización de Atuin y su historial: `atuin history list` responde. Falta confirmar el chord `Ctrl+R` en una terminal interactiva frente a `fzf`.
- [x] Revisar el prompt de Starship en repos Git con cambios, ramas y comandos lentos: renderiza rama, estado y duración.
- [x] Probar `Super+Shift+Return` y confirmar que reutiliza la sesión `main` de tmux.
- [x] Revisar `~/.tmux.conf`: prefix `Ctrl+a`, mouse, `history-limit 100000`, `base-index 1`, splits en el directorio actual y recarga con `prefix + r` verificados con `tmux show`/`list-keys`.
- [x] Configurar Yazi como gestor de archivos de terminal tipo GUI: layout `[1, 4, 3]`, atajos F2/F5/F6/F7/F8, pestañas, búsqueda `fd`/`rg`, tema Nord de alto contraste y enlace `fd -> fdfind`.
- [x] Cambiar el opener de carpetas de Yazi a Zed (primer opener de `edit`), dejando VS Code y nano como alternativas en `F4`.
- [x] Corregir el opener de Zed en Yazi: se lanza con `sh -c '"$HOME/.local/bin/zed" %s'` porque el proceso de Yazi no hereda `~/.local/bin` en el `PATH`. Verificado abriendo un `.md` con el `PATH` restringido.
- [x] Ocultar el submenú de acciones de los `.desktop` en wofi con `no_actions=true` (Chrome, Zed, Nautilus, etc. aparecen como una sola entrada).
- [x] Instalar `7zip` y `ffmpeg` para previews de comprimidos y video en Yazi (requiere `sudo apt install 7zip ffmpeg`).

## P2 — Siguiente lote de productividad

### Búsqueda y acciones rápidas

- [ ] Evaluar un lanzador con búsqueda global (apps + archivos + calculadora + web + emoji).
  - Walker y Vicinae no están empaquetados en Debian; habría que compilarlos o usar *scripts* sobre `wofi`.
  - Alternativa de bajo riesgo: `Super+Ctrl+F` para buscar archivos con `fdfind` + `fzf` + `batcat`.
- [ ] Agregar `Super+=` para `gnome-calculator` (ya instalado).

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

- [x] Intercambiador de temas con dos variantes completas: `mr-robot` y `cyber-teal` (`theme-switch.sh`, `Super+Shift+T`). Cubre Hyprland, Waybar, swaync, wofi, kitty y hyprlock.
- [ ] Evaluar generación de tema desde el wallpaper (`matugen`/`wallust`), sabiendo que no están empaquetados y hay que compilarlos.
- [x] Neutralizar `btop` con un tema monocromático propio (`shell/btop/themes/neutral.theme`) y fondo transparente, independiente de `mr-robot` y `cyber-teal`. La config semilla se copia una sola vez porque btop la reescribe al salir.
- [x] Unificar el cursor en `Adwaita` 24 px entre Hyprland, GTK, Qt y GNOME para evitar que el puntero alterne con Bibata según la ventana.
- [ ] Evaluar wallpaper por tema y aplicarlo desde `theme-switch.sh`.

## P3 — Exploración / decisiones futuras

- [ ] Si se migra a Debian Testing/Forky, evaluar `rofi 2.0` (Wayland nativo) en paralelo a `wofi`.
  - Adaptar `toggle-wofi.sh` a `pgrep -x rofi` y probar `combi`, `window`, `filebrowser`.
  - `rofi-calc` y `rofi-emoji` siguen sin empaquetar en Debian.
- [ ] Evaluar `Quickshell` para widgets propios (OSD, overview, quick settings) si el stack actual queda corto.
- [ ] Evaluar `hyprland-plugin-xtra-dispatchers` solo cuando exista una versión compatible con la ABI instalada.

## Deuda técnica y repo

- [x] Revisar y commitear los cambios actuales (hay archivos modificados y nuevos sin commit).
- [x] `scripts/update.sh` actualiza también los paquetes del perfil Hyprland (`hyprland`, `waybar`, `swaync`, `swayosd`, etc.), filtrando solo los instalados.
- [x] Agregar `make refresh` (`scripts/hyprland-refresh.sh`) para re-sincronizar configs/scripts tras `git pull` y recargar Hyprland, Waybar, swaync e hypridle sin reinstalar.
- [ ] Revisar si `verify.sh` debe tratar `swaync`/`swayosd` como obligatorios o como opcionales con aviso.
- [x] Quitar `papirus-icon-theme` del sistema (opcional, requiere sudo): Hyprland ya no lo instala ni lo fuerza y usa el tema de iconos del sistema.
- [ ] Documentar en README el flujo de rollback de notificaciones: volver a `mako` si `swaync` falla.
- [x] Agregar una captura del escritorio al README (`assets/hyprland-desktop.png`).
- [x] Separar la configuración de portales por sesión (`hyprland-portals.conf`) y cerrar `graphical-session.target` al salir de Hyprland: evita que GNOME herede un `xdg-desktop-portal` con el entorno de Hyprland y que sus apps queden esperando timeouts de D-Bus.

## Criterios para dar por cerrado el lote actual

- [x] `make verify` sin FAIL en el perfil Hyprland ni en herramientas de shell.
- [x] `hyprctl configerrors` vacío tras un login limpio.
- [x] Notificaciones, DND y OSD funcionando sin `mako` corriendo en paralelo.
- [ ] `Alt+Tab`, scratchpad, grupos y cheatsheet probados en uso real durante una jornada.
- [x] `zoxide`, `atuin`, `starship` y `tmux` funcionando en una terminal nueva.
