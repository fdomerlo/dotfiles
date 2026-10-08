![status](https://img.shields.io/badge/status-active-success)
![platform](https://img.shields.io/badge/platform-Debian%20Trixie-red)
![shell](https://img.shields.io/badge/shell-zsh-green)
![docker](https://img.shields.io/badge/docker-rootless-blue)

# Dotfiles - Debian Workstation

Aprovisionamiento automatizado, modular e idempotente de una estación de trabajo de desarrollo en **Debian Stable (Trixie)**, contenedores **Docker Rootless**, gestores de paquetes modernos en espacio de usuario (`uv`, `fnm`, `sdkman`).

---

## 🎯 Arquitectura y Rationale

* **Docker Engine Rootless:** Despliegue de Docker CE con el demonio ejecutándose en el espacio del usuario bajo `systemd --user`. Toda la CLI de `docker` y `docker compose` opera sin permisos de superusuario (`sudo`) ni sockets expuestos a nivel de root.
* **Runtimes Aislados en User-Space:**
  * **Python:** Administrado exclusivamente con [uv](https://astral.sh/uv) (rápido, compatible con PEP 668 de Debian y sin riesgo de corromper paquetes del sistema).
  * **Node.js:** Administrado con [fnm](https://github.com/Schniz/fnm) (Fast Node Manager escrito en Rust).
  * **Java/JVM:** Administrado con [sdkman](https://sdkman.io).
* **Tooling Nativo sin Sandboxes:** Editores (VS Code con repositorio oficial APT de Microsoft, Zed editor) y navegadores (Google Chrome oficial) instalados como binarios nativos para evitar los problemas de integración y permisos típicos de Flatpak.

---

## 🚀 Instalación Rápida (One-Command)

En una instalación limpia de Debian ejecutar:

```bash
rm -rf ~/.dotfiles && \
git clone https://github.com/fdomerlo/debian-dotfiles.git ~/.dotfiles && \
cd ~/.dotfiles && \
make help
```

Para aprovisionar el equipo por completo:

```bash
make install
```

---

## 📁 Estructura del Repositorio

```text
debian/
├── Makefile                       # Orquestador con targets modulares
├── README.md                      # Documentación y referencia
├── LICENSE                        # Licencia del proyecto
├── .gitignore                     # Filtros de exclusión de git
├── .envrc.template                # Plantilla para direnv en proyectos
│
├── host/                          # Scripts a nivel de sistema
│   ├── setup.sh                   #   Actualización APT, paquetes base y repos de Docker CE (sudo)
│   └── docker_rootless.sh         #   Instalación de Docker Rootless bajo systemd --user
│
├── scripts/                       # Instaladores y configuración de usuario
│   ├── antigravity.png            #   Icono oficial para el lanzador .desktop
│   ├── desktop.sh                 #   Tipografías del sistema y extensiones de GNOME Shell
│   ├── devai.sh                   #   Instalador de OpenCode CLI y Antigravity 2.0
│   ├── devtools.sh                #   Instalador de gh (APT), uv, fnm y sdkman
│   ├── fonts.sh                   #   Despliegue de tipografías locales Google Sans
│   ├── ohmyzsh.sh                 #   Instalación de Zsh, Oh My Zsh y plugins
│   ├── setup_agy.sh               #   Despliegue de Antigravity Core/IDE en /opt y CLI
│   ├── setup_gh.sh                #   Configuración desatendida de clave SSH con GitHub
│   ├── tooling.sh                 #   Instalación de VS Code (APT), Chrome (.deb) y Zed
│   └── verify.sh                  #   Diagnóstico y validación post-instalación
│
├── shell/                         # Dotfiles y utilitarios de línea de comandos
│   ├── devctl                     #   CLI para scaffolding de proyectos y diagnósticos
│   ├── gitconfig                  #   Configuración global de Git
│   └── zshrc                      #   Configuración Zsh con uv, fnm, sdkman y Docker Rootless
│
├── templates/                     # Plantillas de inicio rápido
│   └── django/
│       └── manage.sh              #   Script de inicialización de Django con uv venv
│
└── fonts/                         # Colección tipográfica de alta legibilidad
    └── .local/share/fonts/        #   Google Sans, Google Sans Code, Space Grotesk
```

---

## 🛠️ Makefile Targets

| Target | Descripción |
| :--- | :--- |
| `make install` | Aprovisionamiento completo (host + docker + shell + devtools + tooling + devai + desktop + fonts) |
| `make host` | Actualiza APT, instala paquetes base, dependencias y repositorios (requiere `sudo`) |
| `make docker` | Configura e inicia Docker Engine Rootless en el usuario actual (`systemd --user`) |
| `make shell` | Instala Zsh, Oh My Zsh, plugins y enlaza `.zshrc`, `.gitconfig` y `devctl` |
| `make devtools` | Instala `gh`, `uv`, `fnm`, `sdkman` y sincroniza credenciales SSH con GitHub |
| `make tooling` | Instala navegadores y editores nativos (VS Code, Chrome, Zed) |
| `make devai` | Instala OpenCode CLI, Antigravity CLI y despliega Antigravity Core/IDE |
| `make fonts` | Enlaza tipografías Google Sans en `~/.local/share/fonts` y actualiza la caché |
| `make desktop` | Aplica configuración de tipografías del sistema y activa extensiones GNOME |
| `make verify` | Ejecuta el test integral de salud del sistema |
| `make clean` | Limpia paquetes residuales de APT y directorios temporales |

---

## 🧰 CLI `devctl`

`devctl` se instala automáticamente en `~/.local/bin/devctl` como enlace simbólico al repositorio.

```bash
# Diagnóstico integral del sistema, Docker rootless, zram y swap
devctl doctor

# Inicializa un proyecto Django moderno con uv, venv y .envrc
devctl project init django
```

---

## 🧪 Verificación y Diagnóstico

Para validar la integridad de la estación de trabajo en cualquier momento:

```bash
make verify
```

El script comprueba de forma automática:
1. Módulo del kernel para aceleración gráfica (`amdgpu`).
2. Activación de `zRAM` como swap primario de alta velocidad.
3. Existencia y montaje del `swapfile` secundario en EXT4.
4. Respuesta activa del demonio **Docker Rootless** en el socket de usuario.
5. Disponibilidad de tipografías *Google Sans* y *Fira Code* en Fontconfig.
6. Integridad de los enlaces simbólicos de dotfiles (`~/.zshrc`, `~/.gitconfig`, `devctl`).
7. Presencia en el `PATH` de los binarios esenciales (`git`, `gh`, `uv`, `fnm`, `code`, `antigravity`).
