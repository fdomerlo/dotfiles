![status](https://img.shields.io/badge/status-active-success)
![platform](https://img.shields.io/badge/platform-Debian%20Stable%20(Trixie)-red)
![shell](https://img.shields.io/badge/shell-zsh-green)
![podman](https://img.shields.io/badge/podman-rootless-purple)
![apps](https://img.shields.io/badge/apps-Flatpak%20%7C%20AppImage-blue)

# Dotfiles - Debian Stable Workstation

Aprovisionamiento automatizado, modular e idempotente de una estación de trabajo de alto rendimiento basada en **Debian Stable (Trixie)**, combinando la inmutabilidad y estabilidad del sistema base con capas modernas desacopladas: **Backports**, **Debian FastTrack**, **Flatpak + Flathub**, soporte nativo para **AppImage** y contenedores **Podman Rootless** (`crun` + `pasta`/`passt`).

---

## 🎯 Arquitectura y Rationale

* **Sistema Base Inmutable (`preseed.cfg`):** Instalación desatendida de Debian Stable con particionado GPT + EFI + EXT4 monolítico (`noatime,commit=60`), memoria comprimida ultra-rápida vía `systemd-zram-generator` (`zstd`, prioridad 100) respaldada por swapfile de 4 GB, microcódigo y firmware oficial completo para hardware **AMD e Intel** (CPU, GPU Vulkan/VA-API, Wi-Fi `iwlwifi`/`realtek`/`atheros`, audio SOF) y entorno mínimo `gnome-core`.
* **Repositorios Extendidos Oficiales (Backports & FastTrack):**
  * **Debian Backports (`trixie-backports`):** Habilitado en formato DEB822 para instalar kernels recientes (`linux-image-amd64`) y controladores actualizados cuando el hardware lo requiera, manteniendo la prioridad segura por defecto de APT (pin-priority 100).
  * **Debian FastTrack (`fasttrack.debian.net`):** Servicio oficial de Debian configurado con su keyring oficial (`fasttrack-archive-keyring`) para disponer de paquetes upstream de rápido movimiento (VirtualBox, Matrix, etc.) sin esperar el ciclo de congelamiento de Stable.
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
* **Tríada CLI Moderna:** Incluye `ripgrep` (`rg`), `fd-find` (`fd`), `fzf`, `bat`, `btop`, `direnv` y `wl-clipboard` integrados directamente en Zsh.
* **Tooling de Desarrollo Nativo:** Editores (VS Code con repositorio oficial APT DEB822 de Microsoft, Zed editor, Antigravity IDE) y navegadores (Google Chrome oficial) instalados como binarios nativos para evitar restricciones de permisos en entornos de depuración y contenedores.
* **Respaldos del Sistema Opcionales (`make timeshift`):** Deja preconfigurado `/etc/timeshift/timeshift.json` (modo RSYNC en EXT4 o BTRFS, excluyendo `/home`, `/swapfile` y cachés de contenedores) sin forzar snapshots automáticos iniciales.

---

## 💿 Fase 0: Instalación Desatendida de Debian (`preseed.cfg`)

El archivo [`preseed.cfg`](preseed.cfg) automatiza la instalación limpia de Debian Stable (Trixie). Por seguridad, las credenciales sensibles están parametrizadas con placeholders:

1. **Reemplazar placeholders locales antes de inyectar en el instalador/USB:**
   * `<WIFI_SSID>` y `<WIFI_PASSWORD>`: Nombre y clave WPA de tu red Wi-Fi.
   * `<PASSWORD_HASH_SHA512>`: Hash de tu contraseña de usuario generado con:
     ```bash
     openssl passwd -6
     ```

---

## 🚀 Fase 1: Post-Instalación Rápida (One-Command)

En una instalación limpia de Debian ejecutar:

```bash
rm -rf ~/.dotfiles && \
git clone https://github.com/fdomerlo/dotfiles.git ~/.dotfiles && \
cd ~/.dotfiles && \
make help
```

Para aprovisionar el equipo por completo:

```bash
make install
```

*(Opcional)* Para instalar y dejar configurado **Timeshift** (sin crear snapshots automáticos en ese instante):

```bash
make timeshift
```

---

## 📂 Estructura del Repositorio

```text
debian/
├── Makefile                       # Orquestador con targets modulares
├── preseed.cfg                    # Instalador desatendido Debian Stable (AMD/Intel)
├── README.md                      # Documentación y referencia
├── LICENSE                        # Licencia del proyecto
├── .gitignore                     # Filtros de exclusión de git
│
├── host/                          # Scripts a nivel de sistema
│   ├── setup.sh                   #   APT, Backports, FastTrack, AppImage, Flatpak y Podman (sudo)
│   ├── timeshift.sh               #   Instalación y configuración opcional de Timeshift (sudo)
│   └── podman.sh                  #   Configuración de Podman Rootless (crun, pasta) y socket (usuario)
│
├── scripts/                       # Instaladores y configuración de usuario
│   ├── antigravity.png            #   Icono oficial para el lanzador .desktop
│   ├── apt-maintenance.sh         #   Higiene APT podman-only (fuentes Docker, duplicados, reparación)
│   ├── clean-system.sh            #   Limpieza profunda post-upgrade (purga rc, huérfanos, cachés y logs)
│   ├── desktop.sh                 #   Tipografías, botones ventana, carpetas Proyectos/Aplicaciones y GNOME
│   ├── devai.sh                   #   Instalador de OpenCode CLI y Antigravity 2.0
│   ├── devtools.sh                #   Instalador de gh (APT), uv, fnm y sdkman
│   ├── ohmyzsh.sh                 #   Instalación de Zsh, Oh My Zsh y plugins
│   ├── setup_agy.sh               #   Despliegue de Antigravity Core/IDE en /opt y CLI
│   ├── setup_gh.sh                #   Configuración desatendida de clave SSH con GitHub
│   ├── tooling.sh                 #   Instalación de VS Code (APT DEB822), Chrome (.deb) y Zed
│   ├── update.sh                  #   Actualización idempotente (only-upgrade + self-updates + flatpak)
│   └── verify.sh                  #   Diagnóstico y validación post-instalación
│
└── shell/                         # Dotfiles y utilitarios de línea de comandos
    ├── devctl                     #   CLI de diagnóstico, actualización y limpieza
    ├── gitconfig                  #   Configuración global ergonómica de Git
    └── zshrc                      #   Configuración Zsh con uv, fnm, sdkman, fzf, direnv, XDG y Podman
```

---

## 🛠️ Makefile Targets

| Target | Descripción |
| :--- | :--- |
| `make install` | Aprovisionamiento completo (host + podman + shell + devtools + tooling + devai + desktop) |
| `make update` | Actualización idempotente (higiene APT + only-upgrade + user-space + flatpak, sin tocar SSH/`gh auth`) |
| `make host` | Configura APT, Backports, FastTrack, paquetes base, CLI moderna, AppImage, Flatpak y Podman |
| `make timeshift` | *(Opcional)* Instala y configura `/etc/timeshift/timeshift.json` sin crear snapshots iniciales |
| `make podman` | Configura Podman en modo Rootless con backend pasta (systemd --user) |
| `make shell` | Instala Zsh, Oh My Zsh, plugins y enlaza `.zshrc`, `.gitconfig` y `devctl` |
| `make devtools` | Instala `gh`, `uv`, `fnm`, `sdkman` y sincroniza credenciales SSH con GitHub |
| `make tooling` | Instala navegadores y editores nativos (VS Code, Chrome, Zed) |
| `make devai` | Instala OpenCode CLI, Antigravity CLI y despliega Antigravity Core/IDE |
| `make desktop` | Aplica tipografías, botones de ventana (min/max/close), directorios de trabajo y extensiones GNOME |
| `make verify` | Ejecuta el test integral de salud del sistema |
| `make clean` | Limpia paquetes residuales de APT y directorios temporales |
| `make clean-deep` | Limpieza profunda post-upgrade: purga configs residuales (`rc`), dependencias huérfanas, journals y cachés |

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
12. Ecosistema de aplicaciones: Flatpak + Flathub activo, AppImage runtime FUSE y repositorios extendidos (Backports y FastTrack).
