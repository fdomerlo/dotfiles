![status](https://img.shields.io/badge/status-active-success)
![platform](https://img.shields.io/badge/platform-Debian%20Stable%20%7C%20Testing-red)
![shell](https://img.shields.io/badge/shell-zsh-green)
![podman](https://img.shields.io/badge/podman-rootless-purple)

# Dotfiles - Debian Workstation

Aprovisionamiento automatizado, modular e idempotente de una estación de trabajo de desarrollo en **Debian (Trixie Stable / Forky Testing)**, desde la instalación desatendida del sistema operativo (`preseed.cfg` compatible con PC/Notebooks AMD e Intel) hasta contenedores **Podman Rootless** (acelerados con `crun` y `pasta`/`passt`), utilidades CLI modernas, personalización ergonómica de escritorio GNOME (botones minimizar/maximizar/cerrar y carpeta `~/Proyectos`), tipografías ergonómicas del sistema (`Adwaita Sans`, `JetBrains Mono`, `Noto Sans`), soporte Flatpak para aplicaciones de escritorio y gestores de lenguajes aislados en espacio de usuario (`uv`, `fnm`, `sdkman`).

---

## 🎯 Arquitectura y Rationale

* **Instalación Base Desatendida (`preseed.cfg`):** Configuración `debian-installer` para Debian con detección automática de disco NVMe/SATA, particionado GPT + EFI + EXT4 monolítico (`noatime,commit=60`), `systemd-zram-generator` (`zstd`, prioridad 100) + `/swapfile` secundario de 4 GB (prioridad 10), ajuste de `sysctl` para memoria comprimida, microcódigo y firmware completo para **AMD e Intel** (CPU, GPU Vulkan/VA-API, Wi-Fi `iwlwifi`/`realtek`/`atheros`, audio SOF) y entorno mínimo `gnome-core`. Los espejos base configuran `security` y `updates`, evitando bloqueos en espejos de red en etapas tempranas.
* **Tipografías Nativas y Descanso Visual (Repositorios Debian):**
  * **Interfaz de GNOME:** `Adwaita Sans 11` (tipografía oficial predeterminada de GNOME, limpia y balanceada).
  * **Documentos:** `Noto Sans 12` (`fonts-noto-core`, excelente legibilidad para lectura de documentación).
  * **Monoespaciada / Código:** `JetBrains Mono 11` (`fonts-jetbrains-mono`, diseñada específicamente para programadores y descanso visual) con fallback a `Fira Code` (`fonts-firacode`).
  * Sin binarios de fuentes versionados en el repositorio: 100% provistas y gestionadas por los paquetes APT oficiales de Debian.
* **Ergonomía de GNOME y Estándar XDG:**
  * **Botones de ventana completos:** Configura minimizar, maximizar y cerrar en la barra de títulos (`org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'`).
  * **Carpeta dedicada de proyectos:** Crea y registra `~/Proyectos` según el estándar Freedesktop XDG (`XDG_PROJECTS_DIR="$HOME/Proyectos"` en `~/.config/user-dirs.dirs`), exportado en Zsh (`$PROJECTS`) junto al alias rápido `pdir`.
* **Podman Rootless de Alto Rendimiento:** Motor de contenedores OCI sin demonio (daemonless) ejecutándose en espacio del usuario:
  * No requiere demonio en segundo plano (`dockerd`) ni privilegios de superusuario (`sudo`).
  * Emplea *user namespaces* (`subuid`/`subgid`), runtime OCI rápido **`crun`** y el motor de red de alto rendimiento **`pasta` (`passt`)** preconfigurado en `~/.config/containers/containers.conf`.
  * Soporte completo de socket de compatibilidad Docker vía `systemd --user` (`podman.socket`) y aliases de conveniencia (`docker`, `d`, `podman compose`, `dc`).
* **Runtimes Aislados en User-Space (PEP 668 Compliant):**
  * **Python:** Administrado exclusivamente con [uv](https://astral.sh/uv) (rápido, compatible con PEP 668 y sin riesgo de corromper paquetes de Debian).
  * **Node.js:** Administrado con [fnm](https://github.com/Schniz/fnm) (Fast Node Manager escrito en Rust).
  * **Java/JVM:** Administrado con [sdkman](https://sdkman.io).
* **Tríada CLI Moderna:** Incluye `ripgrep` (`rg`), `fd-find` (`fd`), `fzf`, `bat`, `btop`, `direnv` y `wl-clipboard` integrados directamente en Zsh.
* **Tooling de Desarrollo Nativo + Flatpak para Escritorio:** Editores (VS Code con repositorio oficial APT DEB822 de Microsoft, Zed editor, Antigravity IDE) y navegadores (Google Chrome oficial) instalados como binarios nativos para evitar los problemas de integración y permisos en herramientas de desarrollo, mientras que Flatpak + Flathub se aprovisionan en `make host` exclusivamente para aplicaciones de escritorio general.
* **Respaldos del Sistema Opcionales (`make timeshift`):** Instala y deja preconfigurado `/etc/timeshift/timeshift.json` (modo RSYNC en EXT4 o BTRFS, excluyendo `/home`, `/swapfile` y cachés de contenedores) sin forzar snapshots iniciales durante el aprovisionamiento. Los snapshots quedan bajo control del usuario.

---

## 💿 Fase 0: Instalación Desatendida de Debian (`preseed.cfg`)

El archivo [`preseed.cfg`](preseed.cfg) automatiza la instalación limpia de Debian. Por seguridad, las credenciales sensibles están parametrizadas con placeholders:

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
├── preseed.cfg                    # Instalador desatendido Debian (AMD/Intel)
├── README.md                      # Documentación y referencia
├── LICENSE                        # Licencia del proyecto
├── .gitignore                     # Filtros de exclusión de git
│
├── host/                          # Scripts a nivel de sistema
│   ├── setup.sh                   #   APT, paquetes base, CLI moderna, Flatpak y Podman (sudo)
│   ├── timeshift.sh               #   Instalación y configuración opcional de Timeshift (sudo)
│   └── podman.sh                  #   Configuración de Podman Rootless (crun, pasta) y socket (usuario)
│
├── scripts/                       # Instaladores y configuración de usuario
│   ├── antigravity.png            #   Icono oficial para el lanzador .desktop
│   ├── apt-maintenance.sh         #   Higiene APT podman-only (fuentes Docker, duplicados, reparación)
│   ├── desktop.sh                 #   Tipografías, botones de ventana (min/max/close), XDG Proyectos y extensiones GNOME
│   ├── devai.sh                   #   Instalador de OpenCode CLI y Antigravity 2.0
│   ├── devtools.sh                #   Instalador de gh (APT), uv, fnm y sdkman
│   ├── ohmyzsh.sh                 #   Instalación de Zsh, Oh My Zsh y plugins
│   ├── setup_agy.sh               #   Despliegue de Antigravity Core/IDE en /opt y CLI
│   ├── setup_gh.sh                #   Configuración desatendida de clave SSH con GitHub
│   ├── tooling.sh                 #   Instalación de VS Code (APT DEB822), Chrome (.deb) y Zed
│   ├── update.sh                  #   Actualización idempotente (only-upgrade + self-updates)
│   └── verify.sh                  #   Diagnóstico y validación post-instalación
│
└── shell/                         # Dotfiles y utilitarios de línea de comandos
    ├── devctl                     #   CLI de diagnóstico y actualización
    ├── gitconfig                  #   Configuración global ergonómica de Git
    └── zshrc                      #   Configuración Zsh con uv, fnm, sdkman, fzf, direnv, XDG y Podman
```

---

## 🛠️ Makefile Targets

| Target | Descripción |
| :--- | :--- |
| `make install` | Aprovisionamiento completo (host + podman + shell + devtools + tooling + devai + desktop) |
| `make update` | Actualización idempotente (higiene APT + only-upgrade + user-space, sin tocar SSH/`gh auth`, `/opt`, `chsh`) |
| `make host` | Actualiza APT, instala paquetes base, CLI moderna, Flatpak y Podman (requiere `sudo`) |
| `make timeshift` | *(Opcional)* Instala y configura `/etc/timeshift/timeshift.json` sin crear snapshots iniciales (requiere `sudo`) |
| `make podman` | Configura Podman en modo Rootless con backend pasta (systemd --user) |
| `make shell` | Instala Zsh, Oh My Zsh, plugins y enlaza `.zshrc`, `.gitconfig` y `devctl` |
| `make devtools` | Instala `gh`, `uv`, `fnm`, `sdkman` y sincroniza credenciales SSH con GitHub |
| `make tooling` | Instala navegadores y editores nativos (VS Code, Chrome, Zed) |
| `make devai` | Instala OpenCode CLI, Antigravity CLI y despliega Antigravity Core/IDE |
| `make desktop` | Aplica tipografías, botones de ventana (min/max/close), carpeta de proyectos y extensiones GNOME |
| `make verify` | Ejecuta el test integral de salud del sistema |
| `make clean` | Limpia paquetes residuales de APT y directorios temporales |

---

## 🧰 CLI `devctl`

`devctl` se instala automáticamente en `~/.local/bin/devctl` como enlace simbólico al repositorio.

```bash
# Diagnóstico integral del sistema, CLI moderna, Podman rootless, zram y swap
devctl doctor

# Actualización idempotente de la estación (equivale a `make update`)
devctl update
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
