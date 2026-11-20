# Plan de migración a Debian Forky (Hyprland 0.57 Lua + Rofi 2.0)

- **Rama:** `forky` (creada desde `main` en `ecefb97`)
- **Fecha:** 2026-11-20
- **Referencia previa:** `docs/forky-migration-report.md`
- **Decisiones de arquitectura ya tomadas:**
  - **Base del SO:** Debian Testing apuntando explícitamente a **`forky`** (sin `debian-backports.sources`).
  - **Fallback y servicios:** se mantiene **`gnome-core` estándar** (sin extensiones) + **GDM** + **`gnome-keyring`** + `hyprland-portals.conf` (no se migra a KDE Plasma).
  - **Compositor:** migración obligatoria de Hyprland `0.55.2` (`hyprland.conf`) → **`0.57+` (`hyprland.lua`)**.
  - **Lanzador y Overview:** se elimina **`quickshell`** (2.152 líneas QML) y se reemplaza por **`rofi` 2.0+ (Wayland nativo) + scripts**.
  - **Temas soportados:** los 3 temas activos del repo (`mr-robot`, `cyber-teal`, `gruvbox-light`).
  - **Invariantes del repo (`AGENTS.md`):** idempotencia, sin daemons permanentes nuevos, sin IA local, paquetes APT declarados en `packages/*.txt`, symlinks desde `~/.dotfiles` (no editar `~/.config` a mano).

---

## Prompt de rehidratación (usar si se pierde la sesión tras reiniciar)

```text
Retomamos la migración de ~/.dotfiles a Debian Forky en la rama `forky`.

Leé primero:
1. AGENTS.md
2. docs/forky-migration-plan.md
3. docs/forky-migration-report.md

Estado actual:
- Ya actualicé el SO a Debian Forky (eliminé debian-backports.sources y corrí full-upgrade) y reinicié (estoy en GNOME fallback / terminal).
- El repo está en la rama `forky`, todavía sin cambios aplicados a los archivos del escritorio.

Decisiones ya cerradas (no volver a debatir):
- Mantener `gnome-core` stock + GDM + `gnome-keyring` como fallback y servicios.
- Migrar Hyprland a `0.57+` (`hyprland.lua`, incluidos los 3 temas: mr-robot, cyber-teal, gruvbox-light).
- Eliminar Quickshell y reemplazar `launcher-toggle.sh` y `overview-toggle.sh` por `rofi` 2.0 (Wayland nativo) + scripts.

Empecemos por la Fase 0 (chequeo de versiones reales instaladas en Forky y documentación Lua de Hyprland 0.57) y luego avancemos paso a paso con la Fase 1 ("que todo funcione").
```

---

## Fase 0 — Chequeo post-upgrade (en GNOME fallback o TTY)

Antes de modificar el repositorio, verificar el estado real del sistema recién actualizado:

- [ ] Confirmar suite y repos activos: `cat /etc/debian_version` y `apt-cache policy` (sin `trixie` ni `stable-backports`).
- [ ] Revisar residuos de Trixie backports o paquetes rotos: `dpkg -l | grep '~bpo13'` y `dpkg --audit`.
- [ ] Verificar versiones exactas de paquetes clave:
  - `Hyprland --version` (esperado `0.57.x` con Lua)
  - `apt-cache policy rofi fuzzel waybar sway-notification-center swayosd hypridle hyprlock hyprpolkitagent`
  - `rofi -version` (confirmar `2.0+` con Wayland nativo; instalar `rofi` si aún no está)
- [ ] Inspeccionar la API/documentación Lua exacta de `hyprland 0.57.x` empaquetada en Forky (`/usr/share/doc/hyprland*`, `man hyprland`, ejemplos incluidos) antes de traducir los `.conf`.
- [ ] Opcional recomendado para Testing: instalar `apt-listbugs`.

---

## Fase 1 — "Que todo funcione" (Base operativa sin Quickshell)

**Criterio de cierre:** iniciar sesión en Hyprland 0.57 desde GDM con `hyprctl configerrors` vacío, `Super` (lanzador) y `Super+A` (overview) operativos en Rofi 2.0 (<80 ms, 0 MB en reposo), `make host` / `make hyprland` / `make refresh` / `make verify` en verde y GNOME fallback intacto.

### 1.1 Gates APT, manifiestos y mantenimiento para Forky
- [ ] **`packages/apt-backports.txt`** y **`packages/apt-backports-tools.txt`**: adaptar para Forky `main` (en Forky todo vive en `main`), retirar `quickshell` y sumar `rofi`.
- [ ] **`packages/apt-base.txt`**: evaluar incorporar `apt-listbugs` para higiene en Testing.
- [ ] **`scripts/hyprland-packages.sh`**: reemplazar `qs` por `rofi` en `HYPR_REQUIRED_BINS`.
- [ ] **`host/setup.sh`**:
  - Aceptar `forky` / `testing` (sin fallar ni omitir pasos críticos).
  - No crear `/etc/apt/sources.list.d/debian-backports.sources` en `forky` y eliminarlo si quedó de Trixie.
- [ ] **`scripts/hyprland.sh`** y **`scripts/devtools.sh`**:
  - Quitar/flexibilizar la exigencia estricta de `o=Debian,a=stable,`, `debian-backports.sources` y `-t stable-backports` para instalar directo desde `main` en Forky.
- [ ] **`scripts/apt-maintenance.sh`**: ajustar preflight de `a=stable` para reconocer `forky`/`testing` sin falsas advertencias y limpiar `debian-backports.sources` si aplica.
- [ ] **`scripts/update.sh`**: mantener `--only-upgrade` seguro y mostrar aviso si hay paquetes retenidos que requieran `sudo apt full-upgrade` manual (nunca ejecutar `full-upgrade -y` desatendido).
- [ ] **`scripts/verify.sh`** y **`shell/devctl`**:
  - Adaptar checks de repos (`forky` en vez de `Backports`).
  - Validar `~/.config/hypr/hyprland.lua`, `local.lua`, `webapps.lua` y `rofi` (retirar checks de `hyprland.conf` y `quickshell/shell.qml`).

### 1.2 Migración de Hyprland `0.55` → `0.57` (`hyprland.conf` → `hyprland.lua`)
- [ ] Traducir los **13 archivos de configuración del compositor** a Lua:
  - `hypr/hyprland.conf` → `hypr/hyprland.lua`
  - `hypr/conf/`: `env`, `monitors`, `workspaces`, `keybinds`, `windowrules`, `plugins`, `autostart` → `.lua`
  - `hypr/conf/profiles/`: `desktop`, `laptop` → `.lua` (overrides locales no versionados: `local.lua` y `webapps.lua`)
  - Los **3 temas**: `hypr/themes/mr-robot/appearance.lua`, `hypr/themes/cyber-teal/appearance.lua` y `hypr/themes/gruvbox-light/appearance.lua`
  - *(Se mantienen en `.conf`)*: `hypr/hypridle.conf`, `hypr/hyprlock.conf`, `hypr/themes/*/hyprlock.conf` y `hypr/lockscreens/*.conf`.
- [ ] Actualizar scripts que enlazan, generan o leen configs de Hyprland:
  - `scripts/hyprland.sh` y `scripts/hyprland-refresh.sh`: enlazar `.lua` y `hypr/rofi/*`, eliminar enlaces y reinicio de `quickshell`, podar symlinks rotos `.conf` heredados de Trixie.
  - `hypr/scripts/station-profile.sh`: generar `~/.config/hypr/conf/local.lua` desde `profiles/*.lua`.
  - `hypr/scripts/webapp-install.sh`: generar reglas Lua en `~/.config/hypr/conf/webapps.lua`.
  - `hypr/scripts/monitor-scale.sh`: emitir sintaxis Lua para `local.lua`.
  - `hypr/scripts/theme-switch.sh`: validar `appearance.lua` y `rofi/theme.rasi` en lugar de `appearance.conf` y `quickshell/Theme.qml`; eliminar bloque de reinicio de `qs`.
- [ ] Auditar y ajustar llamadas runtime de `hyprctl` para `0.57`:
  - `hypr/scripts/workspaces-init.sh`
  - `hypr/scripts/toggle-menu.sh`
  - `hypr/scripts/workspace-cycle.sh`
  - `hypr/scripts/scratchpad.sh`
  - `hypr/scripts/powermenu.sh`
  - `hypr/hypridle.conf`

### 1.3 Reemplazo funcional de Quickshell → `rofi 2.0` + scripts
- [ ] Retirar `hypr/quickshell/` (`shell.qml`, `LauncherWindow.qml`, `OverviewWindow.qml`, `Theme.qml`, `qmldir`) y `hypr/themes/*/quickshell/`.
- [ ] Reescribir **`hypr/scripts/launcher-toggle.sh`** sobre `rofi` (Wayland nativo):
  - Toggle limpio (`pkill -x rofi` si ya está abierto; si no, abrir en monitor 1).
  - `mode-switcher` (`Tab` / `Shift+Tab`) replicando las pestañas del lanzador unificado:
    1. **Apps** (`drun` con iconos + PWAs)
    2. **Dev & IA** (script de modo: OpenCode, editor, VMs, `devctl`, `btop`, `lazydocker`, `yazi`, servicio IA)
    3. **Sistema** (script de modo: Red/VPN, Audio, Bluetooth, Captura, Estilo/Temas, Energía)
- [ ] Reescribir **`hypr/scripts/overview-toggle.sh`** sobre `rofi` + `hyprctl -j clients/workspaces`:
  - Listado con iconos por `[WS] clase · título` y búsqueda fuzzy.
  - Al seleccionar, enfocar vía `hyprctl dispatch focuswindow address:<addr>`.
- [ ] Verificar en vivo: Waybar, SwayNC, SwayOSD, `hypridle`, `hyprlock`, `hyprpolkitagent`, `gnome-keyring`, `hyprland-portals.conf` y sesión GNOME fallback.
- [ ] Purgar `quickshell` del sistema una vez verificado que todo funciona (`sudo apt purge quickshell && sudo apt autoremove --purge`).

---

## Fase 2 — "Que se vea bien" (Estética, 3 temas y pulido UX)

**Criterio de cierre:** los 3 temas (`mr-robot`, `cyber-teal`, `gruvbox-light`) cambian al instante con `Super+Shift+T` con estética consistente en Hyprland, Waybar, Foot, Rofi, SwayNC, SwayOSD, GTK/libadwaita y wallpapers, sin retroceso UX respecto a Quickshell.

- [ ] **Theming nativo de Rofi 2.0 (`.rasi`):**
  - `hypr/rofi/config.rasi` (estructura común, fuentes `Inter` / `JetBrains Mono`, iconos, `mode-switcher`, keybinds `Tab`/`Shift+Tab`, ubicación en monitor 1).
  - `hypr/themes/mr-robot/rofi/theme.rasi`
  - `hypr/themes/cyber-teal/rofi/theme.rasi`
  - `hypr/themes/gruvbox-light/rofi/theme.rasi`
  - Symlink `hypr/rofi/theme.rasi` → `themes/active/rofi/theme.rasi`.
- [ ] **Decisión de unificación `rofi` vs `fuzzel`:**
  - Evaluar si mantener `fuzzel` para dmenus rápidos (`clipboard.sh`, `powermenu.sh`, `network-menu.sh`, `file-search.sh`, `main-menu.sh`) o unificar todo en `rofi -dmenu` para compartir 100% de la estética y retirar duplicación.
- [ ] **Pulido visual en Hyprland 0.57 + GNOME de Forky:**
  - `layerrule` para `rofi` (blur, bordes, animación ágil) y revisión de reglas flotantes en `windowrules.lua`.
  - Verificar `hypr/scripts/session-gsettings.sh` (modo claro/oscuro, acentos libadwaita, fuentes, cursor Bibata) con la versión de GNOME en Forky, y `qt6ct`.
  - Revisar los 3 temas de Waybar (`gruvbox-light` translúcido, clic derecho en workspaces hacia el nuevo `overview-toggle.sh`, y disponibilidad de `gnome-calendar` en Forky).
  - Limpiar referencia a `quickshell` en `hypr/scripts/lock-telemetry.sh`.
- [ ] **Documentación alineada al nuevo stack:**
  - Actualizar `README.md`, `AGENTS.md` y `ai/skills/workstation/SKILL.md` (Forky, Hyprland Lua, Rofi 2.0, sin menciones a Quickshell ni "10 min").

---

## Fase 3 — "Replicarlo en otras estaciones" (`preseed.cfg`, Ventoy y rollout)

**Criterio de cierre:** instalación desatendida desde cero validada en VM y runbook claro para migrar el resto de las estaciones sin romper equipos todavía en Trixie.

### 3.1 Instalación desatendida desde cero
- [ ] **`preseed.cfg`:**
  - Cambiar `d-i mirror/suite string stable` → `forky`.
  - Revisar `d-i apt-setup/services-select` para Forky pre-freeze (evitar fallos si `forky-security`/`forky-updates` no aplican igual que en Stable).
  - Validar que todos los paquetes de `pkgsel/include` existan con el mismo nombre en Forky (`gnome-core`, firmware, drivers Mesa/Intel, `systemd-zram-generator`, etc.) y evaluar incluir `apt-listbugs`.
- [ ] **`ventoy/ventoy.json`:**
  - Actualizar `/debian-13.7.0-amd64-netinst.iso` a la ISO `netinst` de Debian Testing (`forky`).
- [ ] **Prueba end-to-end en VM (Quickemu):**
  - Instalar desde ISO de Forky + `preseed.cfg`.
  - Correr `git clone -b forky ... ~/.dotfiles && make install && make verify`.
  - Comprobar tanto la sesión Hyprland 0.57 como el fallback GNOME en GDM.

### 3.2 Runbook para migrar otras estaciones ya desplegadas en Trixie
1. Verificar hardware (en particular, si la estación tiene GPU NVIDIA Pascal antes de migrar) y tomar snapshot con Timeshift.
2. Cambiar `/etc/apt/sources.list.d/debian.sources` a `forky` y eliminar `/etc/apt/sources.list.d/debian-backports.sources`.
3. Ejecutar `sudo apt update && sudo apt upgrade --without-new-pkgs && sudo apt full-upgrade` y reiniciar en **GNOME fallback**.
4. En `~/.dotfiles`: `git fetch && git checkout forky && git pull`.
5. Ejecutar `make host && make hyprland && make refresh && make clean-deep && make verify`.
6. Migrar overrides manuales previos (ej. escalas de monitores en `local.conf.bak.*`) a `~/.config/hypr/conf/local.lua` o reaplicar `make hypr-desktop` / `make hypr-laptop`.
7. Cerrar GNOME e iniciar sesión en Hyprland.

### 3.3 Gobierno de ramas
- Mantener `main` estable para estaciones que continúen en Trixie.
- Trabajar toda la evolución de Forky en la rama `forky`.
- Cuando todas las estaciones hayan migrado (o al entrar Forky en freeze), etiquetar `trixie-final` en `main` y hacer merge `forky` → `main`.
