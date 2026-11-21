# Runbook: Migración de estación Debian Trixie → Debian Forky

Guía paso a paso para migrar estaciones de trabajo ya desplegadas sobre **Debian 13 (Trixie)** con este repositorio (`main`) a **Debian Testing (`forky`)** con Hyprland `0.57+` (Lua), Rofi `2.0` y el par de temas `cyber-teal` / `cyber-teal-light`.

> **Regla de oro:** nunca ejecutes `apt full-upgrade` desde dentro de Hyprland `0.55` (el salto a `0.57` cambia la sintaxis de `.conf` a `.lua` y puede cerrar la sesión a mitad del proceso). Todo el upgrade del SO se hace desde **GNOME fallback** o una TTY.

---

## 0. Pre-chequeos y respaldo (en Trixie)

1. **Verificar GPU (atención NVIDIA Pascal / GTX 10xx):**
   ```bash
   lspci -nn | grep -iE 'vga|3d|display'
   ```
   Si la estación usa GPU NVIDIA Pascal con driver propietario `535/550`, validar compatibilidad del driver en Forky antes de migrar (AMD `amdgpu` e Intel `i915`/`xe` migran sin fricción).

2. **Comprobar espacio libre (recomendado ≥ 8 GiB en `/`) y salud de paquetes:**
   ```bash
   df -h /
   sudo dpkg --audit
   ```

3. **Tomar snapshot previo con Timeshift (si está instalado):**
   ```bash
   sudo timeshift --create --comments "Pre-migracion Trixie -> Forky" --tags O
   ```

4. **Respaldar overrides locales de Hyprland 0.55** (por si el equipo tenía escalas/monitores personalizados):
   ```bash
   mkdir -p ~/backup-hypr-trixie
   cp -a ~/.config/hypr/conf/local.conf ~/.config/hypr/conf/webapps.conf ~/backup-hypr-trixie/ 2>/dev/null || true
   ```

---

## 1. Cambiar a GNOME fallback

1. Cerrá la sesión actual de Hyprland (`Super+X` → *Cerrar sesión*).
2. En **GDM**, seleccioná **GNOME** (no Hyprland) e iniciá sesión.
3. Abrí una terminal en GNOME para ejecutar los pasos siguientes.

---

## 2. Actualizar fuentes APT de Trixie → Forky

1. **Eliminar `debian-backports.sources`** heredado de Trixie (en Forky todo el stack vive en `forky/main`):
   ```bash
   sudo rm -f /etc/apt/sources.list.d/debian-backports.sources
   ```

2. **Reemplazar `trixie` → `forky` en `/etc/apt/sources.list.d/debian.sources`** (conservando `forky`, `forky-security` y `forky-updates`, todos activos en los mirrors de Forky):
   ```bash
   sudo sed -i 's/\btrixie\b/forky/g' /etc/apt/sources.list.d/debian.sources
   cat /etc/apt/sources.list.d/debian.sources
   ```
   *(Si el equipo todavía usaba `/etc/apt/sources.list` clásico, migrarlo primero con `sudo apt modernize-sources` o reemplazar `trixie` por `forky` en `/etc/apt/sources.list`.)*

3. **Verificar que no queden menciones a `trixie` ni `backports` en `/etc/apt/`:**
   ```bash
   grep -rniE 'trixie|backports' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null || echo "Fuentes limpias"
   ```

---

## 3. Upgrade del sistema en dos fases

```bash
sudo apt update
sudo apt upgrade --without-new-pkgs
sudo apt full-upgrade
```

- Ante prompts de configuración (`debconf`/`ucf`), conservar configs gestionadas por dotfiles y aceptar las actualizaciones estándar del mantenedor en servicios del sistema.
- Al finalizar, **reiniciá el equipo** y volvé a entrar en **GNOME fallback**:
  ```bash
  sudo reboot
  ```

Tras el reinicio, verificá el estado base:
```bash
cat /etc/debian_version                          # esperado: forky/sid
sudo dpkg --audit                                # esperado: salida vacía
dpkg -l | grep -E '~bpo13' || echo "0 ~bpo13"    # esperado: 0 paquetes de Trixie backports
```

---

## 4. Cambiar `~/.dotfiles` a la rama `forky` y desplegar el nuevo stack

```bash
cd ~/.dotfiles
git fetch origin
git checkout forky
git pull --ff-only
```

Ejecutar el aprovisionamiento del host, Hyprland 0.57 (Lua) + Rofi 2.0 y refresco de symlinks:
```bash
make host
make hyprland
make refresh
```

> **Notas automáticas de `make hyprland` / `make refresh`:**
> - Enlaza `hyprland.lua`, `conf/*.lua` y `rofi/{config,theme}.rasi`.
> - Si el tema previo era `mr-robot` o `gruvbox-light` (retirados), repara automáticamente `hypr/themes/active` → **`cyber-teal`**.
> - Poda symlinks rotos heredados (`*.conf` de Hyprland 0.55, `quickshell/`, `main-menu.sh`, etc.).

---

## 5. Purgar paquetes obsoletos de Trixie y limpiar

```bash
sudo apt purge -y quickshell qt5ct qt6ct qtwayland5 gnome-themes-extra 2>/dev/null || true
rm -rf ~/.config/qt6ct ~/.config/quickshell
make clean-deep
```

---

## 6. Migrar overrides locales por máquina (`.conf` → `.lua`)

1. **Perfil base desktop/laptop** (si no se sembró automáticamente):
   ```bash
   make hypr-desktop   # o: make hypr-laptop
   ```

2. **Si tenías monitores/escalas personalizadas en `~/backup-hypr-trixie/local.conf`:**
   - Revisá tus overrides previos (`cat ~/backup-hypr-trixie/local.conf`) y pasalos a `~/.config/hypr/conf/local.lua` con sintaxis `hl.monitor(...)`, o regeneralos interactivamente con:
     ```bash
     ~/.config/hypr/scripts/monitor-scale.sh --lua
     ```
   - Si tenías PWAs instaladas en `webapps.conf`, podés reinstalarlas desde el lanzador (`Super` → *Web Apps / PWAs*) para que genere `~/.config/hypr/conf/webapps.lua` en sintaxis Lua.

---

## 7. Validar en sesión Hyprland 0.57

1. Cerrá la sesión de GNOME y elegí **Hyprland** en GDM.
2. En una terminal (`Super+Enter`), corré el chequeo integral:
   ```bash
   make verify
   hyprctl configerrors
   ```
   Ambos deben quedar en verde / sin errores.
3. **Smoke test rápido de interacción:**
   - `Super` → abre el buscador global **`Todo`** en Rofi 2.0 (`Tab` recorre `Todo · Apps · Dev · Capturar · Estilo · Sistema · Ventanas`).
   - `Super+A` → selector de ventanas abiertas.
   - `Super+X` → menú de energía y sesión (Fuzzel).
   - `Super+Shift+T` → alternar entre **`cyber-teal`** y **`cyber-teal-light`** (verificar Waybar, Rofi, Foot, SwayNC y GTK/libadwaita).
   - Clic en workspaces `1–5` en Waybar (`ext/workspaces`).
   - `Super+Shift+S` → scratchpad de terminal (`foot 1.28`).
   - `Super+L` → pantalla de bloqueo (`hyprlock`).

4. Cuando todo esté verificado, podés borrar el respaldo temporal:
   ```bash
   rm -rf ~/backup-hypr-trixie
   ```

---

## Rollback rápido si algo falla

- **Fallback inmediato de escritorio:** en GDM elegí **GNOME** (permanece stock y sin extensiones).
- **Restauración completa del sistema a Trixie:** restaurá el snapshot previo de Timeshift (`sudo timeshift --restore`) y volvé el repo a `main` (`git -C ~/.dotfiles checkout main`).
