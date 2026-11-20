# Reporte de evaluación: Quickshell vs. Alternativas y Migración a Debian Forky

**Fecha:** 2026-11-20  
**Base analizada:** commit `4a44a12` (`perf(quickshell): quitar badge de wallpaper, arranque bajo demanda e idle de 90s`) sobre Debian 13 (`trixie` + `trixie-backports`).

Este documento resume el análisis técnico y de costos para decidir con criterio cuándo conviene reemplazar componentes de Quickshell y cuándo (o cómo) migrar el repositorio hacia **Debian 14 (`forky`)**.

---

## 1. Estado actual del repositorio (`trixie` + `trixie-backports`)

- **Stack relevante:**
  - `hyprland 0.55.2+ds-1~bpo13+1` (`trixie-backports`)
  - `quickshell 0.3.0-1~bpo13+1` (`trixie-backports`)
  - `fuzzel 1.12.0+ds-1` (`main`)
- **Optimizaciones recientes (`ee549e7` → `0e69639` → `4a44a12`):**
  - Se eliminó `WallpaperBadge.qml` (ya no existe UI persistente de fondo en Quickshell).
  - `LauncherWindow` y `OverviewWindow` se instancian bajo demanda mediante `LazyLoader` en `hypr/quickshell/shell.qml`.
  - Se retiró `qs -n -d` de `hypr/conf/autostart.conf`: Quickshell arranca únicamente al invocar `launcher-toggle.sh` u `overview-toggle.sh`.
  - Se redujo `idleShutdown` de 10 minutos a **90 segundos** sin ventanas abiertas (`Qt.quit()`), devolviendo el ~210 MB+ de base Qt6/QML/EGL en reposo. *(Pendiente menor de documentación: `README.md` todavía menciona 10 minutos en la tabla de resumen).*

---

## 2. Evaluación en Trixie (sin migrar a Forky): reemplazar solo `overview-toggle.sh`

Reemplazar únicamente `hypr/scripts/overview-toggle.sh` por un selector basado en `fuzzel --dmenu` + `hyprctl -j clients/workspaces` envuelto con `toggle-menu.sh` tiene el siguiente impacto real:

| Escenario | Hoy (Quickshell `OverviewWindow`) | Con `fuzzel --dmenu` + `hyprctl -j` | Ganancia real |
| :--- | :--- | :--- | :--- |
| **Sesión en reposo** (sin usar `Super+A`) | **0 MB** (tras 90 s de idle) | **0 MB** | **Nula** (ya resuelto en `4a44a12`) |
| **Usando solo el menú maestro (`Super`)** | ~200+ MB mientras vive (`OverviewWindow` no se instancia por `LazyLoader`) | ~200+ MB mientras vive | **Despreciable** (solo unos KB de QML/JS menos en `shell.qml`) |
| **Abrir `Super+A` en frío** (Quickshell apagado) | Levanta Quickshell (~200–250+ MB RAM), abre un `PanelWindow` fullscreen por monitor con `ScreencopyView` (`live: true`) por cada ventana y queda residente **90 s** | **~10–25 MB RAM** transitorios solo mientras el menú está visible, **0 MB** de contexto EGL/VRAM/screencopy y **0 MB al instante** al cerrar | **Alta en pico y latencia**: ahorra ~200+ MB durante 90 s, elimina el streaming GPU de miniaturas y baja la apertura en frío de **~500 ms a <80 ms** |
| **Abrir `Super+A` con Quickshell ya vivo** (<90 s desde el último menú) | Instancia `Variants` + `ScreencopyView` en vivo sobre todos los monitores y reinicia el timer de 90 s | ~10–25 MB transitorios, sin instanciar `OverviewWindow` ni reiniciar el timer de 90 s | **Moderada**: evita el pico de GPU/VRAM y deja que Quickshell muera antes |
| **Disco y dependencias** | `quickshell` y el stack Qt6/QML siguen siendo necesarios para `LauncherWindow.qml` | Igual | **Nula** |

### Trade-offs y puntos de entrada si se decide hacer este cambio

- **Trade-off funcional:** se pierden las miniaturas en vivo (`ScreencopyView`) y la grilla espacial multi-monitor; se gana apertura instantánea, búsqueda fuzzy directa por workspace + clase + título de ventana y menor presión en GPU/compositor (especialmente relevante en estaciones modestas o con GPU híbrida).
- **Puntos de entrada actuales de `overview-toggle.sh`:**
  - `hypr/conf/keybinds.conf` (`Super+A`)
  - `hypr/themes/cyber-teal/waybar/config.jsonc` y `hypr/themes/mr-robot/waybar/config.jsonc` (`on-click-right`)
  - `hypr/themes/cyber-teal/appearance.conf` y `hypr/themes/mr-robot/appearance.conf` (gesto de 3 dedos abajo)
  - `hypr/scripts/main-menu.sh`
  - Botón inferior de `hypr/quickshell/LauncherWindow.qml` (hoy llama a `root.openOverview()`)

---

## 3. Alternativas a Quickshell en Debian Forky (solo APT oficial, sin compilar)

Respetando la filosofía del repositorio (paquetes oficiales Debian sin compilación manual ni daemons permanentes nuevos):

### Qué NO resuelve Forky por APT

1. **Hyprland `0.56/0.57+` sigue sin Overview/Activities nativo:** no incluye un modo exposé integrado en el compositor.
2. **`hyprland-plugin-hyprexpo` no está en `hyprland-plugins` de Forky:** el paquete fuente `hyprland-plugins` en Forky construye `hyprbars`, `hyprfocus`, `borders-plus-plus` y `csgo-vulkan-fix`. Además, los plugins C++ siguen expuestos a desfases de ABI entre versiones menores de Hyprland (como ya documenta `hypr/conf/plugins.conf`). Sin compilar vía `hyprpm`, no hay HyprExpo nativo salvo que vuelva a empaquetarse antes del freeze.
3. **Lanzadores y toolkits populares ausentes en Debian oficial:** `walker`, `vicinae`, `anyrun`, `hyprswitch`, `hyprshell`, `ags`, `ignis`, `eww` y `nwg-drawer` no cuentan con paquete oficial en Forky.

### Qué SÍ llega en Debian Forky (`main`)

| Opción en Forky (`main`) | Solo APT (cero build) | Sin daemon permanente | Reemplaza `LauncherWindow` (tabs + iconos + búsqueda mixta) | Reemplaza `OverviewWindow` (previews en vivo) | Consumo activo / reposo |
| :--- | :---: | :---: | :--- | :--- | :--- |
| **`rofi` 2.0+ (Wayland nativo)** | Sí | **Sí** | **Sí** (`combi` + `mode-switcher` con `Tab`/`Shift+Tab`, scripts por categoría, iconos, temas `.rasi`) | Solo lista textual con iconos (`hyprctl`) | ~15–30 MB / **0 MB** |
| **`hyprlauncher` (`hyprtoolkit`, C++)** | Sí | No (daemon por defecto) | Parcial (`desktop`, `math`, `unicode`, `font` y `--dmenu`, sin pestañas ricas) | Solo lista vía `--dmenu` | Bajo (C++) / residente |
| **`fuzzel` 1.15+** | Sí | **Sí** | No (sin pestañas ni búsqueda mixta; sí menú jerárquico) | Solo lista textual (`hyprctl`) | ~10–25 MB / **0 MB** |
| **`quickshell` 0.3.2+** | Sí | Sí (con idle 90 s) | **Sí** (control total QML) | **Sí** (`ScreencopyView` en vivo) | ~200+ MB / **0 MB tras 90 s** |

- **`rofi` 2.0+ (Wayland nativo)** fusionó oficialmente el soporte de Wayland (`wlr-layer-shell`) en el paquete estándar `rofi`. Es la alternativa más superadora para reemplazar `LauncherWindow.qml` y eliminar Qt6/Quickshell por completo sin perder pestañas, iconos ni búsqueda unificada, con consumo mínimo y cero proceso residente. (El listado de ventanas en Hyprland se resuelve de forma confiable con un script sobre `hyprctl clients -j` en modo `script`, en lugar del modo `window` genérico).
- **`hyprlauncher`** (escrito en C++ sobre `libhyprtoolkit` por `hyprwm`) aporta providers integrados (`desktop`, calculadora `math`, `unicode`, `font`) y `--dmenu`, pero funciona como daemon residente por diseño y no ofrece la UI con pestañas del lanzador actual.
- **`quickshell`** deja de depender de backports en Forky (pasa a `main`) y sigue siendo la única opción oficial vía APT si se desea UI completamente personalizada o `ScreencopyView` en vivo.

---

## 4. Qué habría que cambiar para migrar a Forky hoy y costo real

### Bloque 1 — Gates de Debian Stable / Backports (Costo: **Bajo**, ~1–2 horas)

En Forky todos los paquetes relevantes del escritorio existen en `main` (`hyprland`, `quickshell`, `fuzzel`, `rofi`, `hyprlauncher`, `swayosd`, `quickemu`, `ripgrep-all`, `qtwayland5`, `qt5ct`, `slirp4netns`). Hoy el repositorio aborta explícitamente fuera de `stable` + `stable-backports`:

- **`host/setup.sh`:** permitir `testing`/`forky` sin crear `/etc/apt/sources.list.d/debian-backports.sources` (no existe `forky-backports`), y eliminar dicho archivo si quedó de Trixie para no mezclar `stable-backports` con `testing`.
- **`scripts/hyprland.sh`:** bifurcar o flexibilizar la validación de `o=Debian,a=stable,`, el chequeo de `debian-backports.sources` / `-backports/` y el uso de `-t stable-backports`, instalando desde `main` cuando la estación corre `testing`/`forky`.
- **`scripts/devtools.sh`:** instalar los paquetes de `packages/apt-backports-tools.txt` (`ripgrep-all`) sin `-t stable-backports` en Forky.
- **`scripts/apt-maintenance.sh` y `scripts/verify.sh`:** adaptar las advertencias sobre `a=stable` y la comprobación de `debian-backports.sources` para no emitir falsos avisos/fallos en `testing`/`forky`.
- **`scripts/update.sh`:** no fija `-t stable-backports` y sigue funcionando con `--only-upgrade`, pero en `testing` las transiciones de librerías retienen paquetes con mayor frecuencia y requieren ejecutar `apt full-upgrade` manual periódicamente.

### Bloque 2 — Migración obligatoria Hyprland `0.55.2` → `0.57.0` (`hyprland.conf` → `hyprland.lua`) (Costo: **Alto**, ~1–2 días + ruptura multi-estación)

El **7 de noviembre de 2026** migró a Forky `hyprland 0.57.0+ds-1`. **Hyprland 0.57 eliminó el soporte para archivos `hyprland.conf` (`hyprlang`)** y exige configuración en Lua (`hyprland.lua`). Este es el costo principal de migrar hoy:

- **Reescritura de ~750 líneas en 12 archivos `.conf` a Lua:**
  - `hypr/hyprland.conf`
  - `hypr/conf/`: `keybinds.conf`, `windowrules.conf`, `plugins.conf`, `autostart.conf`, `monitors.conf`, `workspaces.conf`, `env.conf`
  - `hypr/conf/profiles/`: `desktop.conf` y `laptop.conf`
  - `hypr/themes/`: `cyber-teal/appearance.conf` y `mr-robot/appearance.conf`
  - *Excepción:* `hypr/hyprlock.conf`, `hypr/themes/*/hyprlock.conf`, `hypr/lockscreens/*.conf` y `hypr/hypridle.conf` pertenecen a `hyprlock` e `hypridle` y no requieren migrarse a Lua.
- **Scripts que enlazan, generan o modifican `.conf`:**
  - `scripts/hyprland.sh`, `scripts/hyprland-refresh.sh` y `scripts/verify.sh` (symlinks y validación de `hyprland.lua`, `local.lua`, `webapps.lua`).
  - `hypr/scripts/webapp-install.sh` (genera reglas `windowrule` en `webapps.conf`).
  - `hypr/scripts/station-profile.sh` (escribe `local.conf` desde `profiles/*.conf`).
  - `hypr/scripts/theme-switch.sh` (enlaza `appearance.conf`) y `hypr/scripts/monitor-scale.sh` (genera bloques de monitores).
- **Llamadas runtime a `hyprctl` a auditar y ajustar para 0.57:**
  - `hypr/scripts/workspaces-init.sh` (`hyprctl keyword workspace` / `dispatch`).
  - `hypr/scripts/toggle-menu.sh` (`hyprctl getoption input:follow_mouse` y `hyprctl keyword input:follow_mouse`).
  - `hypr/hypridle.conf`, `hypr/scripts/workspace-cycle.sh`, `hypr/scripts/scratchpad.sh` y `hypr/scripts/powermenu.sh` (`hyprctl dispatch ...`).
- **Impacto multi-estación:** `hyprland.lua` (0.57) es incompatible con estaciones que permanezcan en Trixie (`0.55.2`), lo que obliga a mantener una rama `forky` separada o doble configuración mientras convivan ambas versiones.

### Bloque 3 — Migración del lanzador a `rofi` 2.0 (Costo: **Medio**, ~4–6 horas, opcional/diferible)

No es obligatorio hacer este cambio el mismo día del salto a Forky porque `quickshell` y `fuzzel` siguen disponibles en Forky `main`. Se puede migrar `LauncherWindow.qml` → `rofi` 2.0 (`.rasi` por tema + scripts de pestañas) en una segunda etapa una vez estabilizado `hyprland.lua`.

### Bloque 4 — Riesgos operativos de `testing` pre-freeze

- **Sin calendario de freeze:** Debian 14 (`forky`) aún no tiene fechas oficiales de freeze publicadas (ventana estimada de lanzamiento: mediados de 2027).
- **Mantenimiento y reversión:** `testing` no cuenta con repositorio `stable-security` dedicado, atraviesa transiciones activas de paquetes y no permite downgrade limpio sin snapshot previo (p. ej. Timeshift).
- **Estaciones con GPU NVIDIA Pascal:** actualmente Forky mantiene `nvidia-driver 550.163.01-6`, compatible con la serie Pascal (GTX 10xx). Si antes del freeze Debian avanzara a la rama **590+** (que retiró soporte para Pascal; la última rama con soporte es la **580**), las estaciones con ese hardware tendrían que pasar a un paquete legacy `580xx` (si entra al archivo de Debian) o apoyarse en GPU integrada / Nouveau.

---

## 5. Recomendación y orden sugerido cuando se decida migrar

1. **Si el objetivo inmediato es reducir consumo/picos:** no conviene migrar hoy a Forky solo por eso. En Trixie, Quickshell ya consume 0 MB en reposo tras 90 s (`4a44a12`), y si se desea bajar picos de `Super+A`, el cambio puntual de `overview-toggle.sh` a `fuzzel --dmenu` + `hyprctl -j` es barato y totalmente compatible con Trixie y reutilizable luego en Forky.
2. **Momento más favorable para migrar el repo a Forky:** esperar al **Soft Freeze / Hard Freeze** de Forky, cuando la ABI de paquetes, `rofi` 2.0 y la API Lua de Hyprland 0.57+ estén estabilizadas.
3. **Si se decide adelantar la prueba antes del freeze:**
   1. Abrir una rama dedicada (`forky`) en el repositorio para no romper estaciones en Trixie.
   2. Probar primero en una VM (Quickemu) o en una sola estación secundaria con snapshot previo de `timeshift`.
   3. Adaptar primero los gates APT (`host/setup.sh`, `scripts/hyprland.sh`, `scripts/devtools.sh`, `scripts/apt-maintenance.sh`, `scripts/verify.sh`) y migrar la configuración + scripts a `hyprland.lua`.
   4. En una segunda etapa, ya estable la sesión 0.57, evaluar y ejecutar el reemplazo de `LauncherWindow.qml` por `rofi` 2.0.
