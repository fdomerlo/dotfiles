![status](https://img.shields.io/badge/status-active-success)
![platform](https://img.shields.io/badge/platform-Debian%20Stable-red)
![shell](https://img.shields.io/badge/shell-zsh-green)
![podman](https://img.shields.io/badge/podman-rootless-purple)
![apps](https://img.shields.io/badge/apps-Flatpak%20%7C%20AppImage-blue)

# Dotfiles - Debian Stable Workstation

Aprovisionamiento automatizado, modular e idempotente de una estación de trabajo de alto rendimiento para tareas de **ingeniería de software, DevOps e Inteligencia Artificial**, diseñada exclusivamente para **Debian Stable**. Cada ejecución converge el sistema al estado deseado y puede repetirse sin efectos secundarios.

Combina la estabilidad del sistema base con capas modernas desacopladas: **Backports** (en Stable), **Flatpak + Flathub**, soporte nativo para **AppImage** y contenedores **Podman Rootless** (`crun` + `pasta`/`passt`). Incluye además un **perfil opcional Hyprland** (`make hyprland`) que convive con GNOME sin reemplazarlo.

---

## 🎯 Arquitectura y Rationale

* **Base Debian Stable con Repositorios Extendidos:**
  * **Debian Stable:** Se aprovisiona con soporte extendido para kernels recientes vía **Debian Backports** (`stable-backports`), manteniendo la estabilidad de la base del sistema. El aprovisionamiento está diseñado y validado para **Debian Stable**; Testing/Forky no está soportado y el perfil Hyprland rechaza explícitamente sistemas que no sean Stable.
  * **Convergencia idempotente:** Cada ejecución de `make install` o `make host` deja Backports en su estado canónico (formato DEB822, `Signed-By` correcto y suite `stable-backports`), corrigiendo desviaciones sin duplicar configuración.
  * **Sin FastTrack:** Se eliminó el repositorio FastTrack del aprovisionamiento: ningún paquete lo requería y su presencia rompía la resolución de APT en suites no estables. Si un host conserva `/etc/apt/sources.list.d/debian-fasttrack.sources`, `make host` lo elimina automáticamente.
* **Sistema Base Inmutable (`preseed.cfg`):** Instalación desatendida con particionado GPT + EFI + EXT4 monolítico (`noatime,commit=60`), memoria comprimida ultra-rápida vía `systemd-zram-generator` (`zstd`, prioridad 100) respaldada por swapfile de 4 GB, microcódigo y firmware oficial completo para hardware **AMD e Intel** (CPU, GPU Vulkan/VA-API, Wi-Fi `iwlwifi`/`realtek`/`atheros`, audio SOF) y entorno mínimo `gnome-core`.
* **Aplicaciones de Escritorio Aisladas (Flatpak & AppImage):**
  * **Flatpak + Flathub:** Configurado de forma nativa (`gnome-software-plugin-flatpak`, `xdg-desktop-portal-gnome` y remote `flathub`) para aislar completamente las aplicaciones de consumo general del sistema base.
  * **AppImage Out-of-the-Box:** Soporte FUSE 2 y FUSE 3 garantizado mediante `libfuse2t64` y `fuse3`, con directorio dedicado `~/Aplicaciones` integrado directamente en el `$PATH` del usuario.
* **Tipografías Nativas y Descanso Visual (Repositorios Debian):**
  * **Interfaz de GNOME:** `Adwaita Sans 11` (tipografía oficial predeterminada de GNOME, limpia y balanceada).
  * **Documentos:** `Noto Sans 12` (`fonts-noto-core`, excelente legibilidad para lectura de documentación).
  * **Monoespaciada / Código:** `JetBrains Mono 11` (`fonts-jetbrains-mono`, diseñada específicamente para programadores y descanso visual) con fallback a `Fira Code` (`fonts-firacode`).
  * Sin binarios de fuentes en el repo: 100% provistas y gestionadas por paquetes APT oficiales.
* **Ergonomía de GNOME y Estándar XDG:**
  * **Botones de ventana completos:** Configura minimizar, maximizar y cerrar en la barra de títulos (`org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'`).
  * **Directorios de trabajo dedicados:** Crea y registra `~/Proyectos` (`XDG_PROJECTS_DIR`) y `~/Aplicaciones` (`XDG_APPLICATIONS_DIR`) en `~/.config/user-dirs.dirs`, con aliases rápidos en Zsh (`pdir` y `adir`).
* **Podman Rootless de Alto Rendimiento:** Motor de contenedores OCI sin demonio (daemonless) ejecutándose en espacio del usuario:
  * No requiere demonio en segundo plano (`dockerd`) ni privilegios de superusuario (`sudo`).
  * Emplea *user namespaces* (`subuid`/`subgid`), runtime OCI rápido **`crun`** y el motor de red de alto rendimiento **`pasta` (`passt`)** preconfigurado en `~/.config/containers/containers.conf`.
  * Soporte completo de socket de compatibilidad Docker vía `systemd --user` (`podman.socket`) y aliases de conveniencia (`docker`, `d`, `podman compose`, `dc`).
* **Runtimes Aislados en User-Space (PEP 668 Compliant):**
  * **Python:** Administrado exclusivamente con [uv](https://astral.sh/uv) (rápido, compatible con PEP 668 y sin riesgo de corromper paquetes de Debian).
  * **Node.js:** Administrado con [fnm](https://github.com/Schniz/fnm) (Fast Node Manager escrito en Rust).
  * **Java/JVM:** Administrado con [sdkman](https://sdkman.io).
* **CLI Moderna y Shell Productiva:** `ripgrep` (`rg`), `fd-find` (`fd`), `fzf`, `bat`, `btop`, `direnv` y `wl-clipboard`, más `zoxide` (`z`/`zi`), `atuin` (historial con `Ctrl+R`), `starship` (prompt) y `tmux` (sesiones persistentes, `Super+Shift+Return`).
* **Tooling de Desarrollo Nativo & DevAI:**
  * **Editores y Navegadores:** VS Code (con repositorio oficial APT DEB822 de Microsoft), Zed editor, Google Chrome oficial.
  * **Herramientas de IA:** OpenCode CLI, Antigravity IDE (Core 2.0 en `/opt`) y Antigravity CLI (`agy` / `antigravity-cli`).
* **Respaldos del Sistema Opcionales (`make timeshift`):** Deja preconfigurado `/etc/timeshift/timeshift.json` (modo RSYNC en EXT4 o BTRFS, excluyendo `/home`, `/swapfile` y cachés de contenedores) sin forzar snapshots automáticos iniciales.

---

## 💿 Fase 0: Instalación Desatendida de Debian (`preseed.cfg`)

El archivo [`preseed.cfg`](preseed.cfg) automatiza la instalación limpia de Debian Stable. Por seguridad, las credenciales sensibles están parametrizadas con placeholders:

1. **Reemplazar placeholders locales antes de inyectar en el instalador/USB:**
   * `<WIFI_SSID>` y `<WIFI_PASSWORD>`: Nombre y clave WPA de tu red Wi-Fi.
   * `<PASSWORD_HASH_SHA512>`: Hash de tu contraseña de usuario generado con:
     ```bash
     openssl passwd -6
     ```
   * En `preseed.cfg`, la suite de instalación está fijada en `stable`.

---

## 🚀 Fase 1: Post-Instalación Rápida (One-Command)

En una instalación limpia de Debian ejecutar:

```bash
sudo apt update && sudo apt install -y git make && \
rm -rf ~/.dotfiles && \
git clone https://github.com/fdomerlo/dotfiles.git ~/.dotfiles && \
cd ~/.dotfiles
make help
```

---

## 📂 Estructura del Repositorio

```text
~/.dotfiles/
├── Makefile                       # Orquestador modular (install, update, host, devai, etc.)
├── BACKLOG.md                     # Pendientes y próximos lotes de productividad
├── preseed.cfg                    # Instalador desatendido Debian Stable (AMD/Intel)
│
├── host/                          # Configuración del sistema base (requiere sudo)
│   ├── podman.sh                  #   Configuración de Podman Rootless (crun, pasta) y socket (usuario)
│   ├── setup.sh                   #   Configuración de APT (Backports), base y podman
│   └── timeshift.sh               #   Configuración opcional de snapshots Timeshift
│
├── hypr/                          # Perfil opcional Hyprland (no reemplaza GNOME)
│   ├── hyprland.conf              #   Entrada principal; incluye conf/*.conf
│   ├── conf/                      #   env, monitors, appearance, keybinds, windowrules, autostart
│   ├── hypridle.conf              #   Bloqueo y apagado de pantalla por inactividad
│   ├── hyprlock.conf              #   Pantalla de bloqueo
│   ├── hyprpaper.conf             #   Wallpaper (fallback a swaybg)
│   ├── mako/config                #   Notificaciones (respaldo)
│   ├── swaync/                    #   Centro de notificaciones (config.json + style.css)
│   ├── scripts/                   #   wallpaper, screenshots, portapapeles, scratchpad, atajos y OSD
│   ├── waybar/                    #   Barra (config.jsonc + style.css)
│   └── wofi/                      #   Lanzador (config + style.css)
│
├── scripts/                       # Instaladores y configuración de usuario
│   ├── antigravity.png            #   Icono oficial para el lanzador .desktop
│   ├── apt-maintenance.sh         #   Higiene APT (podman-only, DEB822, deduplicación y keyrings)
│   ├── clean-system.sh            #   Limpieza profunda post-upgrade (purga rc, huérfanos, cachés y logs)
│   ├── desktop.sh                 #   Tipografías, botones ventana, carpetas Proyectos/Aplicaciones y GNOME
│   ├── devai.sh                   #   Instalador de OpenCode CLI, Antigravity CLI y Core/IDE
│   ├── devtools.sh                #   Instalador de gh (binario oficial), uv, fnm y sdkman
│   ├── hyprland.sh                #   Instalador del perfil opcional Hyprland (solo Debian Stable)
│   ├── ohmyzsh.sh                 #   Instalación de Zsh, Oh My Zsh y plugins
│   ├── setup_agy.sh               #   Despliegue atómico de Antigravity Core/IDE en /opt (opcional)
│   ├── setup_gh.sh                #   Configuración y autenticación SSH con GitHub CLI
│   ├── setup_git.sh               #   Configuración idempotente de identidad global de Git
│   ├── tooling.sh                 #   Instalación de VS Code (APT DEB822), Chrome (.deb) y Zed
│   ├── update.sh                  #   Actualización idempotente (only-upgrade + self-updates + flatpak)
│   └── verify.sh                  #   Diagnóstico y validación post-instalación
│
└── shell/                         # Dotfiles y utilitarios de línea de comandos
    ├── atuin.toml                 #   Historial de comandos (Atuin)
    ├── devctl                     #   CLI de diagnóstico, actualización y limpieza
    ├── gitconfig                  #   Configuración global ergonómica de Git
    ├── starship.toml              #   Prompt (Starship)
    ├── tmux.conf                  #   Sesiones y splits de tmux
    └── zshrc                      #   Configuración Zsh con uv, fnm, sdkman, fzf, direnv, XDG y Podman
```

---

## 🛠️ Makefile Targets

| Target | Descripción |
| :--- | :--- |
| `make install` | Aprovisionamiento completo (host + podman + shell + devtools + tooling + devai + desktop) |
| `make update` | Actualización idempotente (higiene APT + only-upgrade + user-space + flatpak, sin tocar SSH/`gh auth`) |
| `make host` | Configura APT (Backports), CLI moderna, AppImage, Flatpak y Podman |
| `make timeshift` | *(Opcional)* Instala y configura `/etc/timeshift/timeshift.json` sin crear snapshots iniciales |
| `make podman` | Configura Podman en modo Rootless con backend pasta (systemd --user) |
| `make shell` | Instala Zsh, Oh My Zsh, plugins y enlaza `.zshrc`, `.gitconfig` y `devctl` |
| `make devtools` | Instala `gh`, `uv`, `fnm`, `sdkman`, prepara SSH con GitHub e identidad Git |
| `make gitconfig` | Configura `user.name` y `user.email` en Git (idempotente e interactivo) |
| `make github-auth` | Flujo interactivo oficial de autenticación en GitHub CLI (`gh auth login`) |
| `make tooling` | Instala navegadores y editores nativos (VS Code, Chrome, Zed) |
| `make devai` | Instala OpenCode CLI, Antigravity CLI y despliega Antigravity Core/IDE (opcional) |
| `make desktop` | Aplica tipografías, botones de ventana (min/max/close), directorios de trabajo y extensiones GNOME |
| `make hyprland` | *(Opcional)* Instala y configura el perfil Hyprland sin reemplazar GNOME (solo Debian Stable) |
| `make verify` | Ejecuta el test integral de salud del sistema |
| `make clean` | Limpia paquetes residuales de APT y directorios temporales |
| `make clean-deep` | Limpieza profunda post-upgrade: purga configs residuales (`rc`), dependencias huérfanas, journals y cachés |

---

## 🪟 Perfil opcional Hyprland

`make hyprland` instala un escritorio Wayland completo **sin reemplazar GNOME** y **solo sobre Debian Stable**. GNOME sigue siendo el entorno predeterminado y puede elegirse en GDM en cualquier momento.

```bash
make host       # asegura Backports de Stable (requerido)
make hyprland   # instala el stack e enlaza la configuración
```

El script aborta si el sistema no es Debian Stable o si falta `/etc/apt/sources.list.d/debian-backports.sources`.

### Componentes

| Función | Paquete / Herramienta |
| :--- | :--- |
| Compositor | `hyprland` (desde `stable-backports`) |
| Barra | `waybar` |
| Lanzador | `wofi` (`rofi` queda como alternativa manual) |
| Notificaciones | `sway-notification-center` (`swaync`) con historial y No molestar; `mako` queda como respaldo |
| OSD | `swayosd` para volumen y brillo (respaldo directo con `wpctl`/`brightnessctl`) |
| Idle / bloqueo | `hypridle` + `hyprlock` |
| Wallpaper | `hyprpaper` si existe `~/.config/hypr/wallpapers/default.png`; si no, `swaybg` con color sólido |
| Agente polkit | `hyprpolkitagent` |
| Portales | `xdg-desktop-portal-hyprland` + `xdg-desktop-portal-gtk` (fallback) |
| Capturas | `grim` + `slurp` |
| Portapapeles | `wl-clipboard` + `cliphist` |
| Audio / brillo / media | `wpctl` (PipeWire/WirePlumber), `brightnessctl`, `playerctl` |
| Terminal / archivos | `kitty` / `nautilus` |
| Tema | JetBrains Mono, Fira Code, Noto, iconos del sistema (GNOME/KDE), Bibata, `qt6ct` |

En Stable, `hyprland`, `hyprpaper`, `hypridle`, `hyprlock`, `hyprpolkitagent` y `xdg-desktop-portal-hyprland` se instalan con `-t stable-backports`; el resto proviene de Stable main.

### Atajos principales

| Atajo | Acción |
| :--- | :--- |
| `Super+Return` | Terminal (`kitty`) |
| `Super+Shift+Return` | Terminal con `tmux` (sesión `main` persistente) |
| `Super` | Abrir/cerrar el lanzador (`wofi`) |
| `Super+D` / `Super+Space` | Lanzador de aplicaciones (`wofi`, alterna) |
| `Super+E` | Gestor de archivos (`nautilus`) |
| `Super+Q` | Cerrar ventana |
| `Super+F` | Pantalla completa |
| `Super+M` | Maximizar / restaurar |
| `Super+Shift+Space` | Alternar flotante |
| `Super+L` | Bloquear sesión (`hyprlock`) |
| `Alt+Tab` / `Alt+Shift+Tab` | Siguiente / anterior ventana |
| ``Alt+` `` | Volver a la ventana anterior |
| ``Super+` `` | Abrir/cerrar scratchpad (terminal flotante) |
| ``Super+Shift+` `` | Mover la ventana actual al scratchpad |
| `Super+G` | Crear/deshacer grupo de ventanas |
| `Super+Tab` / `Super+Shift+Tab` | Ciclar ventanas del grupo |
| `Super+Ctrl+G` / `Super+Shift+G` | Mover ventana al grupo / sacarla del grupo |
| `Super+N` / `Super+Shift+N` | Centro de notificaciones / No molestar |
| `Super+Shift+T` | Intercambiador de temas (Mr. Robot / Cyber-Teal) |
| `Super+F1` | Cheatsheet de atajos activos |
| `Super+V` / `Super+Shift+V` | Historial de portapapeles (`cliphist` + `wofi`, alterna) |
| `Print` | Captura de región a archivo + portapapeles |
| `Shift+Print` | Captura de pantalla completa a archivo + portapapeles |
| `Super+1..0` / `Super+Shift+1..0` | Ir al workspace / mover ventana sin seguirla (también con el teclado numérico) |
| `Super+flechas` / `Super+Shift+flechas` | Foco / mover ventana |
| `Super+Ctrl+flechas` | Redimensionar ventana |
| `XF86Audio*` / `XF86MonBrightness*` | Volumen, mute, multimedia y brillo (con OSD) |

### Sesión, portal y theming

* **Display manager:** GDM detecta automáticamente `/usr/share/wayland-sessions/hyprland.desktop`. No se instala `sddm`, `greetd` ni `uwsm`.
* **Agente polkit:** `hyprpolkitagent` se inicia desde `autostart.conf` solo dentro de Hyprland; no se habilita globalmente para no interferir con el agente de GNOME.
* **Waybar:** se lanza con `hypr/scripts/start-waybar.sh`, que espera los sockets IPC de Hyprland antes de iniciar la barra para evitar la carrera de arranque de `exec-once`. El `waybar.service` que Debian habilita por defecto se enmascara porque `graphical-session.target` lo arranca en GNOME, donde falla al no existir `wlr-layer-shell`.
* **Iconos de Waybar:** `style.css` usa `Symbols Nerd Font` para los glifos de los módulos. Debian no empaqueta Nerd Fonts, así que `scripts/hyprland.sh` descarga el release oficial `NerdFontsSymbolsOnly` en `~/.local/share/fonts` si la fuente no está presente. Sin ella los iconos se ven como cuadros.
* **Screen sharing:** `xdg-desktop-portal-hyprland` provee `hyprland.portal` con `UseIn=Hyprland`, por lo que se selecciona solo dentro de la sesión. `xdg-desktop-portal-gtk` cubre el file picker y aplicaciones GTK.
* **`XDG_CURRENT_DESKTOP`:** se define como `Hyprland:GNOME` en `env.conf` de forma intencional, para que los portales de GNOME cubran file picker y secretos. Por eso `appearance.conf` activa `misc:disable_xdg_env_checks`, que silencia el aviso de Hyprland sobre entornos «gestionados externamente».
* **Portal (`portals.conf`):** como `XDG_CURRENT_DESKTOP` incluye `GNOME`, `xdg-desktop-portal` intentaba usar `gnome.portal` para las interfaces que `hyprland.portal`/`gtk.portal` no implementan. Ese backend no existe en Hyprland y el portal quedaba bloqueado esperando timeouts de D-Bus; como consecuencia `org.freedesktop.portal.Settings` no respondía y Waybar se quedaba esperando el esquema de color sin dibujarse. `hypr/xdg-desktop-portal/portals.conf` fija `default=hyprland;gtk`, mantiene `Secret=gnome-keyring` y desactiva con `none` las interfaces exclusivas de GNOME.
* **Teclado:** layout `latam` (`pc105`), consistente con `preseed.cfg`.
* **Monitores:** `hypr/conf/monitors.conf` usa `monitor = ,preferred,auto,1`. Para fijar salidas, reemplazar por reglas explícitas (ver `hyprctl monitors`).
* **Wallpaper:** crear `~/.config/hypr/wallpapers/default.png` y ejecutar `~/.config/hypr/scripts/wallpaper.sh`; sin imagen se usa `swaybg -c '#1e1e2e'`.
* **Configuración:** los archivos de `hypr/` se enlazan uno por uno en `~/.config/hypr`, `~/.config/waybar`, `~/.config/wofi`, `~/.config/mako` y `~/.config/swaync`. Si ya existía un archivo real, se conserva como `.bak.<timestamp>`; reejecutar `make hyprland` es idempotente. Los archivos que dependen del tema son symlinks a `hypr/themes/active/…` (ver **Temas**).
* **Notificaciones y OSD:** `swaync` reemplaza a `mako` como demonio de notificaciones (historial, No molestar y panel de control); si no está instalado, `autostart.conf` arranca `mako` como respaldo. `swayosd-server` muestra el OSD de volumen y brillo; `~/.config/hypr/scripts/osd.sh` cae a `wpctl`/`brightnessctl` si `swayosd` no está presente.
* **Red y reloj:** el estado de red se muestra solo en el módulo `network` de Waybar; no se inicia `nm-applet` para evitar el icono duplicado en la bandeja. Las conexiones nuevas se gestionan con `nm-connection-editor` o `nmcli`. El reloj muestra solo la hora local (con `locale` y `timezone` explícitos) y la fecha completa en el tooltip.
* **Panel de notificaciones:** `swaync` corre con `keyboard-shortcuts: false` para no quedarse con el teclado/foco, y con `layer-shell-cover-screen: true` para cerrar al hacer clic fuera. Una `layerrule` mantiene Waybar por encima del panel, y el icono de la campana usa `notifications-toggle.sh` con caché de estado. Trade-off: ESC y la navegación por teclado dentro del panel no están disponibles; se cierra con clic en la campana, clic afuera o `Super+N`.
* **Indicadores CPU/MEM:** un clic abre `btop` en kitty.
* **Shell:** `shell/zshrc` inicializa `zoxide`, `atuin` y `starship` solo si están instalados, y conserva el prompt nativo con `vcs_info` como respaldo. `make shell` enlaza además `~/.config/starship.toml`, `~/.config/atuin/config.toml` y `~/.tmux.conf`.

### Temas

Los archivos con variantes visuales viven en `hypr/themes/<tema>/` y los paths clásicos (`hypr/conf/appearance.conf`, `hypr/waybar/*`, `hypr/swaync/style.css`, `hypr/wofi/style.css`, `hypr/kitty/kitty.conf` y `hypr/hyprlock.conf`) son symlinks a `hypr/themes/active/…`. Cambiar de tema solo mueve el symlink `active`, así que no se modifican archivos versionados ni queda el working tree sucio.

| Tema | Estilo |
| :--- | :--- |
| `mr-robot` | Negro azulado, bordes acero de 1 px, transparencia pareja, foco solo por borde, acento rojo `fsociety`, reloj con segundos. |
| `cyber-teal` | Glass cian/turquesa, bordes degradados, esquinas redondeadas, blur y sombras. |

```bash
~/.config/hypr/scripts/theme-switch.sh            # tema activo
~/.config/hypr/scripts/theme-switch.sh list       # temas disponibles
~/.config/hypr/scripts/theme-switch.sh menu       # selector con wofi
~/.config/hypr/scripts/theme-switch.sh toggle     # alterna al siguiente
~/.config/hypr/scripts/theme-switch.sh mr-robot   # aplica un tema
```

`Super+Shift+T` abre el selector. El script recarga Hyprland, reinicia Waybar y relee el CSS de swaync; `wofi`, `kitty` e `hyprlock` toman el tema en su próxima apertura. `hypr/themes/active` es estado runtime y está en `.gitignore`; `make hyprland` lo recrea con `mr-robot` si no existe.

Para agregar un tema, crear `hypr/themes/<nombre>/` con la misma estructura (`appearance.conf`, `hyprlock.conf`, `kitty/kitty.conf`, `swaync/style.css`, `waybar/config.jsonc`, `waybar/style.css`, `wofi/style.css`) y usar `theme-switch.sh <nombre>`.

### Rollback

1. En GDM, elegir **GNOME** (o **GNOME on Xorg**) y volver a iniciar sesión.
2. Opcionalmente, quitar solo los enlaces creados por el perfil (los archivos propios y backups se conservan):
   ```bash
   find ~/.config/hypr ~/.config/waybar ~/.config/wofi ~/.config/mako \
     -maxdepth 2 -type l -lname '*/.dotfiles/hypr/*' -delete 2>/dev/null || true
   sudo apt-get remove --purge hyprland hyprpaper hypridle hyprlock hyprpolkitagent \
       xdg-desktop-portal-hyprland waybar wofi mako-notifier grim slurp cliphist swaybg
   ```
3. Restaurar los backups `.bak.<timestamp>` si se habían personalizado archivos previos.

GNOME y el resto del aprovisionamiento no se modifican al instalar o quitar el perfil.

---

## 🧰 CLI `devctl`

`devctl` se instala automáticamente en `~/.local/bin/devctl` como enlace simbólico al repositorio.

```bash
# Diagnóstico integral del sistema, CLI moderna, Podman rootless, zram, Flatpak y AppImage
devctl doctor

# Actualización idempotente de la estación (equivale a `make update`)
devctl update

# Limpieza profunda post-upgrade (equivale a `make clean-deep`)
devctl clean
```

---

## 🧪 Verificación y Diagnóstico

Para validar la integridad de la estación de trabajo en cualquier momento:

```bash
make verify
```

El script comprueba de forma automática:
1. Módulo DRM del kernel para aceleración gráfica (`amdgpu` / `i915` / `xe`).
2. Activación de `zRAM` como swap primario de alta velocidad.
3. Existencia y montaje del `swapfile` secundario en EXT4.
4. Estado de **Timeshift** (informativo/opcional).
5. Estado operativo y modo rootless de **Podman Rootless**.
6. Disponibilidad de tipografías del sistema en Fontconfig (`JetBrains Mono`, `Fira Code`, `Noto Sans`).
7. Integridad de los enlaces simbólicos de dotfiles (`~/.zshrc`, `~/.gitconfig`, `devctl`).
8. Presencia en el `PATH` de los binarios esenciales (`git`, `gh`, `uv`, `fnm`, `code`, `zed`, `antigravity`, `podman`).
9. Higiene de repositorios APT (podman-only, sin duplicados) y autenticación de GitHub (SSH y API).
10. Personalizaciones de GNOME (botones de ventana minimizar, maximizar y cerrar).
11. Directorio dedicado de desarrollo (`~/Proyectos` / `XDG_PROJECTS_DIR`).
12. Ecosistema de aplicaciones: Flatpak + Flathub activo, AppImage runtime FUSE y repositorios oficiales de Debian Stable (Backports).
13. Perfil Hyprland (opcional): binarios, agente polkit, sesión en GDM, portal de escritorio, symlinks de configuración y `hyprctl configerrors` cuando la sesión está activa. Si no está instalado, solo informa sin fallar.
