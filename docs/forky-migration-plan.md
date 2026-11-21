# Plan de migración a Debian Forky (Hyprland 0.57 Lua + Rofi 2.0)

- **Rama:** `forky` (creada desde `main` en `ecefb97`)
- **Fecha:** 2026-11-20
- **Referencia previa:** `docs/forky-migration-report.md`
- **Decisiones de arquitectura ya tomadas:**
  - **Base del SO:** Debian Testing apuntando explícitamente a **`forky`** (sin `debian-backports.sources`).
  - **Fallback y servicios:** se mantiene **`gnome-core` estándar** (sin extensiones) + **GDM** + **`gnome-keyring`** + `hyprland-portals.conf` (no se migra a KDE Plasma).
  - **Compositor:** migración obligatoria de Hyprland `0.55.2` (`hyprland.conf`) → **`0.57+` (`hyprland.lua`)**.
  - **Lanzador y Overview:** se elimina **`quickshell`** (2.152 líneas QML) y se reemplaza por **`rofi` 2.0+ (Wayland nativo) + scripts**; se mantiene **`fuzzel`** para dmenus rápidos (`clipboard`, `powermenu`, `network`, `themes`, `keybinds`, `file-search`, `ai`).
  - **Temas soportados:** par unificado **`cyber-teal`** (oscuro) + **`cyber-teal-light`** (diurno); retirados `gruvbox-light` y `mr-robot`.
  - **Invariantes del repo (`AGENTS.md`):** idempotencia, sin daemons permanentes nuevos, sin IA local, paquetes APT declarados en `packages/*.txt`, symlinks desde `~/.dotfiles` (no editar `~/.config` a mano).

---

## Fase 0 — Chequeo post-upgrade (en GNOME fallback o TTY)

Antes de modificar el repositorio, verificar el estado real del sistema recién actualizado:

- [x] Confirmar suite y repos activos: `cat /etc/debian_version` (`forky/sid`) y `apt-cache policy` (`o=Debian,a=testing,n=forky`, sin `trixie` ni `stable-backports`).
- [x] Revisar residuos de Trixie backports o paquetes rotos: `dpkg --audit` limpio; 0 paquetes `~bpo13` residuales tras `make hyprland`.
- [x] Verificar versiones exactas de paquetes clave:
  - `hyprland 0.57.0+ds-1` (Lua)
  - `rofi 2.0.0-0.2`, `fuzzel 1.15.0+ds-1`, `waybar 0.15.0-1+b1`, `sway-notification-center 0.12.6-1`, `swayosd 0.3.0-5`, `hypridle 0.1.8-1+b1`, `hyprlock 0.9.7-1+b1`, `hyprpolkitagent 0.2.0-1`, `xdg-desktop-portal-hyprland 1.5.0-1`, `foot 1.28.0`
- [x] Inspeccionar la API/documentación Lua exacta de `hyprland 0.57.0` empaquetada en Forky (`/usr/share/hypr/hyprland.lua`, `/usr/share/hypr/stubs/hl.meta.lua`, `man hyprctl`).
- [x] Incorporar `apt-listbugs` (`0.1.49`) en `packages/apt-base.txt`.

---

## Fase 1 — "Que todo funcione" (Base operativa sin Quickshell)

**Criterio de cierre:** iniciar sesión en Hyprland 0.57 desde GDM con `hyprctl configerrors` vacío, `Super` (lanzador) y `Super+A` (overview) operativos en Rofi 2.0 (<80 ms, 0 MB en reposo), `make host` / `make hyprland` / `make refresh` / `make verify` en verde y GNOME fallback intacto.

*(Commiteada en `5d3c57d` sobre rama `forky`.)*

### 1.1 Gates APT, manifiestos y mantenimiento para Forky
- [x] **`packages/apt-backports.txt`** y **`packages/apt-hyprland.txt`**: adaptados para Forky `main`, retirado `quickshell`, sumado `rofi`, reemplazado `network-manager-gnome` → `nm-connection-editor`.
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
  - Los **3 temas**: `hypr/themes/cyber-teal/appearance.lua`, `hypr/themes/cyber-teal-light/appearance.lua` y `hypr/themes/mr-robot/appearance.lua`
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
- [x] Verificar en vivo en sesión Hyprland 0.57: `hyprctl configerrors` vacío, `Super` / `Super+A`, `Super+X`, `Super+Shift+T` (3 temas), `Super+Shift+S` (scratchpad), `Super+L`, Waybar, SwayNC, SwayOSD, `hypridle`, `hyprlock`, `hyprpolkitagent`, `gnome-keyring`, portales y `make verify` 100% `[ OK ]`.
- [x] Purgar `quickshell` del sistema (`sudo apt purge quickshell && make clean`).

---

## Fase 2 — "Que se vea bien" (Estética, 3 temas y pulido UX)

**Criterio de cierre:** los temas activos (`cyber-teal`, `cyber-teal-light`, `mr-robot`) cambian al instante con `Super+Shift+T` con estética consistente en Hyprland, Waybar, Foot, Rofi, SwayNC, SwayOSD, GTK/libadwaita y wallpapers, sin retroceso UX respecto a Quickshell.

- [x] **Pulido visual y funcional de Rofi 2.0 + Fuzzel:**
  - Estética unificada entre Rofi y Fuzzel: ancho compacto `620px`, `Inter 10.5`, `inputbar` plano sobre el vidrio, pestañas tipo pill limpio sin bordes pesados y `selection-radius=7` en Fuzzel (`cyber-teal` y `cyber-teal-light`).
  - Glifos simbólicos monocromos por función en todas las pestañas: nuevo `hypr/scripts/rofi-apps.sh` (caché por `mtime` + MRU + `gio launch`) y `rofi-windows.sh` alineado (`show-icons: false`).
  - Buscador global en pestaña **`Todo`** (`hypr/scripts/rofi-all.sh`, abierta por defecto con `Super`) agregando en paralelo Apps, Ventanas y todas las categorías.
- [x] **Decisión de unificación `rofi` vs `fuzzel`:**
  - Cerrada: mantener `fuzzel` para dmenus rápidos (`clipboard.sh`, `powermenu.sh`, `network-menu.sh`, `file-search.sh`, `theme-switch.sh`, `keybinds.sh`, `ai.sh`) y dejar Rofi 2.0 para `Super` y `Super+A`.
- [x] **Pulido visual en Hyprland 0.57 + GNOME de Forky:**
  - Reglas `layer_rule` para `rofi` aplicadas en los 3 `appearance.lua` (`blur`, `dim_around`, animación `popin`).
  - Waybar migrado a `ext/workspaces` (clics nativos en Hyprland 0.57) y reducido a **5 workspaces por monitor** (`1–5` / `6–10`).
  - Refinamiento de `cyber-teal` (borde activo cyan uniforme, animaciones rápidas `fluent_decel`, gaps uniformes `4 px`, Waybar flotante de `40 px` unificada sin cajas con lanzador `>_` y hover redondeado incluido `#tray`, jerarquía glass translúcida en chrome/terminal + `inactive_opacity = 0.91` y blur `size = 5`).
  - Consolidados los temas en el par **`cyber-teal` / `cyber-teal-light`** (retirados `gruvbox-light` y `mr-robot`; default fallback actualizado a `cyber-teal`).
  - Limpieza integral de dependencias/código retirado: eliminados `qt5ct`, `qt6ct`, `qtwayland5`, `gnome-themes-extra`, `hypr/qt6ct/` y el menú legacy `hypr/scripts/main-menu.sh`.
  - Verificados `session-gsettings.sh` y `gnome-calendar 51.0` en Forky.
  - Limpiada referencia a `quickshell` en `hypr/scripts/lock-telemetry.sh`.
- [x] **Documentación alineada al nuevo stack:**
  - Actualizados `README.md`, `AGENTS.md` y `ai/skills/workstation/SKILL.md` (Forky, Hyprland 0.57 Lua, Rofi 2.0, `Super+X`, sin menciones a Quickshell).

---

## Fase 3 — "Replicarlo en otras estaciones" (`preseed.cfg`, Ventoy y rollout)

**Criterio de cierre:** instalación desatendida desde cero validada en VM y runbook claro para migrar el resto de las estaciones sin romper equipos todavía en Trixie.

### 3.1 Instalación desatendida desde cero
- [x] **`preseed.cfg`:**
  - Fijado `d-i mirror/suite string forky` y `d-i mirror/codename string forky`.
  - Verificado en vivo en el host: `forky-security` y `forky-updates` responden sin errores, por lo que `d-i apt-setup/services-select multiselect security, updates` se mantiene activo.
  - Validados los 21 paquetes de `pkgsel/include` contra APT de Forky (`0` faltantes). `apt-listbugs` se deja exclusivamente en `packages/apt-base.txt` (`make host`) para no introducir prompts interactivos durante la instalación desatendida `d-i`.
- [x] **`ventoy/ventoy.json`:**
  - Actualizado `/debian-13.7.0-amd64-netinst.iso` → `/debian-testing-amd64-netinst.iso` (ISO oficial weekly/daily de Debian Testing).
- [x] **Prueba end-to-end en VM (Quickemu):**
  - Instalar desde ISO de Forky + `preseed.cfg`.
  - Correr `git clone -b forky ... ~/.dotfiles && make install && make verify`.
  - Comprobar tanto la sesión Hyprland 0.57 como el fallback GNOME en GDM.

### 3.2 Runbook para migrar otras estaciones ya desplegadas en Trixie

> **Runbook detallado y copiable:** [`docs/trixie-to-forky-runbook.md`](trixie-to-forky-runbook.md)

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
