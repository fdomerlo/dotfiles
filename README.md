![status](https://img.shields.io/badge/status-active-success)
![platform](https://img.shields.io/badge/platform-Debian%20Testing-red)
![shell](https://img.shields.io/badge/shell-zsh-green)
![podman](https://img.shields.io/badge/podman-rootless-purple)
![apps](https://img.shields.io/badge/apps-Flatpak%20%7C%20AppImage-blue)

# Dotfiles - Debian Testing Workstation

Aprovisionamiento automatizado, modular e idempotente de una estación de trabajo de alto rendimiento para tareas de **ingeniería de software, DevOps e Inteligencia Artificial**, diseñada exclusivamente sobre **Debian Testing**.

> **Nota de diseño:** Estos scripts y políticas de configuración están basados e inspirados en el esquema **Rodete** (*Rolling Debian Testing*) que utiliza Google internamente para sus estaciones de trabajo Linux, combinando la agilidad rolling de Debian Testing con guardarraíles de estabilidad (**APT Pinning Híbrido** + **Filtro Sieve** con `apt-listbugs`, `apt-listchanges` y `needrestart`), **Flatpak + Flathub**, soporte para **AppImage** y contenedores **Podman Rootless** (`crun` + `pasta`/`passt`).

---

## 🎯 Arquitectura y Rationale

* **Perfil Debian Testing con Guardarraíles de Estabilidad:**
  * **Repositorios Híbridos DEB822 (`/etc/apt/sources.list.d/debian.sources`):** Configura `testing`, `testing-updates` y `testing-security` como base principal (Pin-Priority `900`), con fallback de seguridad a `stable-security` (`500`) y `unstable` (`100`) en `/etc/apt/preferences.d/00-testing-pinning.pref`.
  * **Guardarraíles "Sieve":** Incluye de serie `apt-listbugs`, `apt-listchanges` y `needrestart` para interceptar regresiones críticas antes de aplicar actualizaciones y detectar servicios desactualizados.
* **Sistema Base Inmutable (`preseed.cfg`):** Instalación desatendida directamente en `testing` con particionado GPT + EFI + EXT4 monolítico (`noatime,commit=60`), memoria comprimida ultra-rápida vía `systemd-zram-generator` (`zstd`, prioridad 100) respaldada por swapfile de 4 GB, microcódigo y firmware oficial completo para hardware **AMD e Intel** (CPU, GPU Vulkan/VA-API, Wi-Fi `iwlwifi`/`realtek`/`atheros`, audio SOF) y entorno mínimo `gnome-core`.
* **Aplicaciones de Escritorio Aisladas (Flatpak & AppImage):**
  * **Flatpak + Flathub:** Configurado de forma nativa (`gnome-software-plugin-flatpak`, `xdg-desktop-portal-gnome` y remote `flathub`) para aislar completamente las aplicaciones de consumo general del sistema base.
  * **AppImage Out-of-the-Box:** Soporte garantizado en Testing mediante `fuse3`, `libfuse2t64` (si está disponible) y `APPIMAGE_EXTRACT_AND_RUN=1` en `/etc/environment`, con directorio dedicado `~/Aplicaciones` integrado directamente en el `$PATH` del usuario.
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
* **Tooling de Desarrollo Nativo & DevAI:**
  * **Editores y Navegadores:** VS Code (con repositorio oficial APT DEB822 de Microsoft), Zed editor, Google Chrome oficial.
  * **Herramientas de IA:** OpenCode CLI, Antigravity IDE (Core 2.0 en `/opt`) y Antigravity CLI (`agy` / `antigravity-cli`).
* **Respaldos del Sistema Opcionales (`make timeshift`):** Deja preconfigurado `/etc/timeshift/timeshift.json` (modo RSYNC en EXT4 o BTRFS, excluyendo `/home`, `/swapfile`, logs, temporales y cachés de contenedores) e integrado con `devctl snapshot` y `devctl rollback`.

---

## 💿 Fase 0: Instalación Desatendida de Debian Testing (`preseed.cfg`)

El archivo [`preseed.cfg`](preseed.cfg) automatiza la instalación limpia directamente sobre **Debian Testing**. Por seguridad, las credenciales sensibles están parametrizadas con placeholders:

1. **Reemplazar placeholders locales antes de inyectar en el instalador/USB:**
   * `<WIFI_SSID>` y `<WIFI_PASSWORD>`: Nombre y clave WPA de tu red Wi-Fi.
   * `<PASSWORD_HASH_SHA512>`: Hash de tu contraseña de usuario generado con:
     ```bash
     openssl passwd -6
     ```

---

## 🔍 Estaciones Preexistentes: Auditoría vs Adopción (`make audit` / `make adopt`)

¿Qué ocurre si ya tienes una estación con Debian instalado y deseas alinearla al perfil de ingeniería? El repositorio incluye herramientas automáticas de auditoría, diagnóstico y nivelación:

### 1. Diagnóstico y Comparativa contra `preseed.cfg`
Ejecuta la auditoría de solo lectura para inspeccionar el estado actual frente a la arquitectura propuesta:

```bash
make audit
# o alternativamente:
devctl audit
```

El script evalúa:
* **Criterios Críticos de Sistema (Showstoppers):**
  * Sistema Operativo: ¿Es Debian puro o compatible?
  * Modo de arranque: ¿Es UEFI nativo con GPT (`/sys/firmware/efi`)? *(Si está en BIOS Legacy o MBR se recomienda reinstalar para evitar rotura de booteo)*.
  * Espacio disponible en `/`: ¿Cuenta con al menos 15-20 GB libres para herramientas y contenedores?
  * Suite de Debian: ¿Es Testing / Sid o Debian 12 reciente? *(Debian 11 o inferior requiere reinstalación)*.
* **Capa Base de Preseed:**
  * Microcódigo de CPU detectado (`amd64-microcode` o `intel-microcode`).
  * Drivers gráficos Vulkan/VA-API y firmware no-libre de red/audio.
  * Memoria de intercambio: `zRAM` (`systemd-zram-generator`) + `/swapfile` (4 GB, pri=10).
  * Sysctl optimizado (`vm.swappiness = 180`, etc.) y opciones de montaje en fstab (`noatime,commit=60`).
* **Capa de Aprovisionamiento (`make install`):**
  * Repositorios DEB822 Testing y APT Pinning.
  * Podman Rootless, dotfiles, devtools (`gh`, `uv`, `fnm`, `sdkman`), navegadores, editores y DevAI.

### 2. Adopción y Nivelación In-Place
Si la estación es dictaminada como **Apta para Adopción In-Place**, ejecuta la nivelación automática:

```bash
make adopt
# o alternativamente:
devctl adopt
```

`make adopt` asimilará la base de `preseed.cfg` (zRAM, microcode, sysctl, fstab, timers) y posteriormente ejecutará el aprovisionamiento completo de `make install`.

---

## 🚀 Fase 1: Post-Instalación Rápida (One-Command)

En una instalación limpia de Debian Testing (o tras clonar los dotfiles) ejecutar:

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
├── Makefile                       # Orquestador modular (audit, adopt, install, update, etc.)
├── preseed.cfg                    # Instalador desatendido Debian Testing (AMD/Intel)
│
├── host/                          # Configuración del sistema base (requiere sudo)
│   ├── podman.sh                  #   Configuración de Podman Rootless (crun, pasta) y socket (usuario)
│   ├── setup.sh                   #   Configuración de APT DEB822 + APT Pinning, Sieve, base y podman
│   └── timeshift.sh               #   Configuración opcional de snapshots Timeshift
│
├── scripts/                       # Instaladores y configuración de usuario
│   ├── adopt-system.sh            #   Nivelación in-place de estaciones existentes hacia preseed.cfg
│   ├── antigravity.png            #   Icono oficial para el lanzador .desktop
│   ├── apt-maintenance.sh         #   Higiene APT (podman-only, DEB822, APT Pinning y keyrings)
│   ├── audit-system.sh            #   Auditoría profunda vs preseed.cfg y make install
│   ├── clean-system.sh            #   Limpieza profunda post-upgrade (purga rc, huérfanos, cachés y logs)
│   ├── desktop.sh                 #   Tipografías, botones ventana, carpetas Proyectos/Aplicaciones y GNOME
│   ├── devai.sh                   #   Instalador de OpenCode CLI y Antigravity Core/CLI
│   ├── devtools.sh                #   Instalador de gh (APT), uv, fnm y sdkman
│   ├── ohmyzsh.sh                 #   Instalación de Zsh, Oh My Zsh y plugins
│   ├── setup_agy.sh               #   Despliegue de Antigravity Core/IDE en /opt y CLI
│   ├── setup_gh.sh                #   Configuración desatendida de clave SSH con GitHub
│   ├── tooling.sh                 #   Instalación de VS Code (APT DEB822), Chrome (.deb) y Zed
│   ├── update.sh                  #   Actualización sincronizada (upgrade --with-new-pkgs + user-space + flatpak)
│   └── verify.sh                  #   Diagnóstico y validación post-instalación
│
└── shell/                         # Dotfiles y utilitarios de línea de comandos
    ├── devctl                     #   CLI de diagnóstico, auditoría, actualización, snapshots y limpieza
    ├── gitconfig                  #   Configuración global ergonómica de Git
    └── zshrc                      #   Configuración Zsh con uv, fnm, sdkman, fzf, direnv, XDG y Podman
```

---

## 🛠️ Makefile Targets

| Target | Descripción |
| :--- | :--- |
| `make audit` | Audita estación preexistente vs `preseed.cfg` y `make install` (dictamina adopción vs reinstalación) |
| `make adopt` | Nivelación base de estación preexistente (zRAM, microcode, sysctl, fstab) + `make install` |
| `make install` | Aprovisionamiento completo (host + podman + shell + devtools + tooling + devai + desktop) |
| `make update` | Actualización idempotente (higiene APT + upgrade sincronizado + user-space + flatpak, sin tocar SSH/`gh auth`) |
| `make host` | Configura APT (DEB822 híbrido + APT Pinning), filtro Sieve, CLI moderna, AppImage, Flatpak y Podman |
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
# Diagnóstico integral del sistema Debian Testing, guardarraíles Sieve/Pinning, CLI moderna, Podman rootless, zram, Flatpak y AppImage
devctl doctor

# Auditoría comparativa frente a preseed.cfg y make install
devctl audit

# Adopción y nivelación in-place de estación preexistente (zram, microcode, sysctl, fstab + make install)
devctl adopt [--force]

# Actualización sincronizada de la estación (acepta --snapshot opcional para crear respaldo previo en Timeshift)
devctl update [--snapshot]

# Crea un snapshot manual del sistema con Timeshift
devctl snapshot [comentario]

# Lista los snapshots disponibles e inicia restauración interactiva con Timeshift
devctl rollback

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
12. Ecosistema de aplicaciones: Flatpak + Flathub activo, AppImage runtime (`fuse3` + `APPIMAGE_EXTRACT_AND_RUN=1` / `libfuse2t64`) y repositorios/Pinning de Debian Testing.
