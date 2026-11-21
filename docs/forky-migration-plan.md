# Plan de migración a Debian Forky (Hyprland 0.57 Lua + Rofi 2.0)

- **Rama:** `forky` (creada desde `main` en `ecefb97`)
- **Fecha:** 2026-11-20
- **Referencia previa:** `docs/forky-migration-report.md`
- **Decisiones de arquitectura ya tomadas:**
  - **Base del SO:** Debian Testing apuntando explícitamente a **`forky`** (sin `debian-backports.sources`).
  - **Fallback y servicios:** se mantiene **`gnome-core` estándar** (sin extensiones) + **GDM** + **`gnome-keyring`** + `hyprland-portals.conf` (no se migra a KDE Plasma).
  - **Compositor:** migración obligatoria de Hyprland `0.55.2` (`hyprland.conf`) → **`0.57+` (`hyprland.lua`)**.
  - **Lanzador y Overview:** se elimina **`quickshell`** (2.152 líneas QML) y se reemplaza por **`rofi` 2.0+ (Wayland nativo) + scripts**; se mantiene **`fuzzel`** para dmenus rápidos (`clipboard`, `powermenu`, `network`, `themes`, `keybinds`, `file-search`, `ai`).
  - **Temas soportados:** los 3 temas activos del repo (`mr-robot`, `cyber-teal`, `gruvbox-light`).
  - **Invariantes del repo (`AGENTS.md`):** idempotencia, sin daemons permanentes nuevos, sin IA local, paquetes APT declarados en `packages/*.txt`, symlinks desde `~/.dotfiles` (no editar `~/.config` a mano).

---

## Fase 0 — Chequeo post-upgrade (en GNOME fallback o TTY)

Antes de modificar el repositorio, verificar el estado real del sistema recién actualizado:

- [x] Confirmar suite y repos activos: `cat /etc/debian_version` (`forky/sid`) y `apt-cache policy` (`o=Debian,a=testing,n=forky`, sin `trixie` ni `stable-backports`).
- [x] Revisar residuos de Trixie backports o paquetes rotos: `dpkg --audit` limpio; 00 paquetespaquetes `~bpo13` residuales trasresiduales tras `makemake hyprlandhyprland`.
- [x] Verificar versiones exactas de paquetes clave:
  - `hyprland 0.57.0+ds-1` (Lua)
  - `rofi 2.0.0-0.2`, `fuzzel 1.15.0+ds-1`, `waybar 0.15.0-1+b1`, `sway-notification-center 0.12.6-1`, `swayosd 0.3.0-5`, `hypridle 0.1.8-1+b1`, `hyprlock 0.9.7-1+b1`, `hyprpolkitagent 0.2.0-1`, `xdg-desktop-portal-hyprland 1.5.0-1`, `foot 1.28.0`
- [x] Inspeccionar la API/documentación Lua exacta de `hyprland 0.57.0` empaquetada en Forky (`/usr/share/hypr/hyprland.lua`, `/usr/share/hypr/stubs/hl.meta.lua`, `man hyprctl`).
- [x] Incorporar `apt-listbugs` (`0.1.49`) en `packages/apt-base.txt`.

---

## Fase 1 — "Que todo funcione" (Base operativa sin Quickshell)

**Criterio de cierre:** iniciar sesión en Hyprland 0.57 desde GDM con `hyprctl configerrors` vacío, `Super` (lanzador) y `Super+A` (overview) operativos en Rofi 2.0 (<80 ms, 0 MB en reposo), `make host` / `make hyprland` / `make refresh` / `make verify` en verde y GNOME fallback intacto.

### 1.1 Gates APT, manifiestos y mantenimiento para Forky
- [x] **`packages/apt-backports.txt`** y **`packages/apt-hyprland.txt`**: adaptados para Forky `main`, retirado `quickshell`,, sumado `rofi`, reemplazado `network-manager-gnome` → `nm-connection-editor`.
- [x] **`packages/apt-base.txt`**: incorporado `apt-listbugs` para higiene en Testing.
- [x] **`scripts/hyprland-packages.sh`**: reemplazado `qs` por `rofi` y `nm-applet`/`blueman-applet` por `nm-connection-editor`/`blueman-manager` en `HYPR_REQUIRED_BINS`.
- [x] **`host/setup.sh`**:
  - Acepta `forky` / `testing` sin crear `/etc/apt/sources.list.d/debian-backports.sources` y lo elimina si quedó de Trixie.
- [x] **`scripts/hyprland.sh`** y **`scripts/devtools.sh`**:
  - Flexibilizada la detección de suite para instalar directo desde `main` en Forky (sin `-t stable-backports` ni `debian-backports.sources`), con `LC_ALL=C` en `apt-cache policy`.
- [x] **`scripts/apt-maintenance.sh`**: preflight actualizado para reconocer `forky`/`testing` y limpiar `debian-backports.sources`.
- [x] **`scripts/update.sh`**: mantiene `--only-upgrade` seguro y avisa si quedan paquetes retenidos en Forky que requieran `sudo apt full-upgrade` manual.
- [x] **`scripts/verify.sh`** y **`shell/devctl`**:
  - Checks adaptados a Forky (`hyprland.lua`, `plugins.lua`, `local.lua`, `webapps.lua`, `rofi/config.rasi`, `rofi/theme.rasi`).

### 1.2 Migración de Hyprland `0.55` → `0.57` (`hyprland.conf` → `hyprland.lua`)
- [x] Traducidos los **13 archivos de configuración del compositor** a Lua:
  - `hypr/hyprland.lua`
  - `hypr/conf/`: `env.lua`, `monitors.lua`, `workspaces.lua`, `keybinds.lua` (+ `Super+X` para `powermenu.sh`), `windowrules.lua`, `plugins.lua`, `autostart.lua`
  - `hypr/conf/profiles/`: `desktop.lua`, `laptop.lua` (overrides locales: `local.lua` y `webapps.lua`)
  - Los **3 temas**: `hypr/themes/mr-robot/appearance.lua`, `hypr/themes/cyber-teal/appearance.lua` y `hypr/themes/gruvbox-light/appearance.lua`
  - *(Mantenidos en `.conf`)*: `hypr/hypridle.conf`, `hypr/hyprlock.conf`, `hypr/themes/*/hyprlock.conf` y `hypr/lockscreens/*.conf`.
- [x] Actualizados los 3 `hypr/themes/*/foot/foot.ini` para `foot 1.28.0` (`initial-color-theme`, `[colors-dark]`/`[colors-light]` y `cursor=` en colores).
- [x] Actualizados los scripts que enlazan, generan o leen configs de Hyprland:
  - `scripts/hyprland.sh` y `scripts/hyprland-refresh.sh`: enlazan `.lua` y `hypr/rofi/*`, eliminan enlaces y reinicio de `quickshell`, podan symlinks rotos `.conf` heredados de Trixie.
  - `hypr/scripts/station-profile.sh`: genera `~/.config/hypr/conf/local.lua` desde `profiles/*.lua`.
  - `hypr/scripts/webapp-install.sh`: genera reglas `hl.window_rule` en `~/.config/hypr/conf/webapps.lua`.
  - `hypr/scripts/monitor-scale.sh`: emite bloques `hl.monitor(...)` (`--lua` / `--hyprconf`).
  - `hypr/scripts/theme-switch.sh`: valida `appearance.lua` y `rofi/theme.rasi`; eliminado reinicio de `qs`.
  - `hypr/scripts/keybinds.sh`: soporte case-insensitive para `Super_L`.
- [x] Auditadas y actualizadas las llamadas runtime de `hyprctl` para `0.57` (`hyprctl eval` + `hl.dsp.*`):
  - `hypr/scripts/workspaces-init.sh`
  - `hypr/scripts/toggle-menu.sh`
  - `hypr/scripts/workspace-cycle.sh`
  - `hypr/scripts/scratchpad.sh`
  - `hypr/scripts/powermenu.sh`
  - `hypr/hypridle.conf`

### 1.3 Reemplazo funcional de Quickshell → `rofi 2.0` + scripts
- [x] Retirados `hypr/quickshell/` y `hypr/themes/*/quickshell/`.
- [x] Creados `hypr/rofi/config.rasi` (liberando `kb-element-next/prev` de Rofi 2.0 para `Tab`/`Shift+Tab`), los 3 temas `hypr/themes/*/rofi/theme.rasi` + symlink `hypr/rofi/theme.rasi`, `hypr/scripts/rofi-actions.sh` (+ wrappers `rofi-{dev,capturar,estilo,sistema}.sh`) y `hypr/scripts/rofi-windows.sh`.
- [x] Reescritos **`hypr/scripts/launcher-toggle.sh`** (toggle + pestañas `Apps`, `Dev & IA`, `Capturar`, `Estilo`, `Sistema`, `Ventanas` con `Tab`/`Shift+Tab`) y **`hypr/scripts/overview-toggle.sh`** (selector fuzzy de ventanas con iconos sobre `hyprctl clients -j` + `hl.dsp.focus`).
- [x] Instalar `rofi` y `apt-listbugs` en el equipo (`make host && make hyprland && make verify`).
- [xx] Verificar en vivo en sesión Hyprland 0.57: `hyprctl configerrors` vacío, `Super` / `Super+A`, `Super+X`, `Super+Shift+T` (3 temas), `Super+Shift+S` (scratchpad), `Super+L`, `Super+Shift+S` (scratchpad), `Super+L`, Waybar, SwayNC, SwayOSD, `hypridle`, `hyprlock`, `hyprpolkitagent`, `gnome-keyring`, portalesportales y `make`make verify` 100% `[ OK ]`verify` 100% `[ OK ]`.
- [ ] Purgar `quickshell` deldel sistemasistema (`sudo apt purge quickshell && make clean`).

---

## Fase 2 — "Que se vea bien" (Estética, 3 temas y pulido UX)

**Criterio de cierre:** los 3 temas (`mr-robot`, `cyber-teal`, `gruvbox-light`) cambian al instante con `Super+Shift+T` con estética consistente en Hyprland, Waybar, Foot, Rofi, SwayNC, SwayOSD, GTK/libadwaita y wallpapers, sin retroceso UX respecto a Quickshell.

- [ ] **Pulido visual de Rofi 2.0 (`.rasi`):**
  - Refinar proporciones, tipografías, spacing, badges/subtítulos y posición en monitor principal en `mr-robot`, `cyber-teal` y `gruvbox-light` tras verlo en vivo.
- [x] **Decisión de unificación `rofi` vs `fuzzel`:**
  - Cerrada: mantener `fuzzel` para dmenus rápidos (`clipboard.sh`, `powermenu.sh`, `network-menu.sh`, `file-search.sh`, `theme-switch.sh`, `keybinds.sh`, `ai.sh`) y dejar Rofi 2.0 para `Super` y `Super+A`.
- [ ] **Pulido visual en Hyprland 0.57 + GNOME de Forky:**
  - [x] Reglas[x] Reglas `layer_rule` para `rofi` aplicadasaplicadas en los 3 `appearanceappearance.lua` (`blur`, `dim_around`, animación `popin`).
  - [x] Verificados[x] Verificados `session-gsettings.sh` (`prefer-dark``prefer-dark`, `slate``slate`, ``Bibata-Modern-Classic`-Modern-Classic`, `Adwaita`),`Adwaita`), `qt6ct` y `gnome-calendar 51.0` en Forky.
  - [ ] Revisar detalles de los 3 temas de Waybar yy `windowruleswindowrules.lualua` sisi apareceaparece algún detalle visualalgún detalle visual en vivovivo.
  - [x] Limpiada referencia a `quickshell` en `hypr/scripts/lock-telemetry.sh`.
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
