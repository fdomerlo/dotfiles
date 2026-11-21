---
name: Workstation Debian
description: Perfil operativo de esta estación de trabajo Debian Forky (ingeniería de sistemas, desarrollo asistido por IA y DevOps; Podman rootless, uv/fnm/sdkman, Hyprland 0.57 Lua/Wayland + Rofi 2.0). Usar al trabajar en cualquier proyecto sobre la estación, definir contenedores, elegir runtimes, diagnosticar el sistema o recomendar comandos.
---

# Workstation Debian Forky

Estación de trabajo orientada a **ingeniería de sistemas, desarrollo asistido
por IA y DevOps** sobre **Debian Testing (`forky`)**, aprovisionada de forma
declarativa e idempotente desde `~/.dotfiles`.

El mismo aprovisionamiento se despliega en **varias estaciones** con hardware
distinto. Las recomendaciones y comandos deben respetar la arquitectura de esta
estación, no una máquina genérica ni un hardware fijo.

## Stack operativo disponible

- **Contenedores (Podman rootless):** `podman` con `crun` + `pasta` y socket
  compatible con Docker (`$XDG_RUNTIME_DIR/podman/podman.sock`). En Zsh,
  `docker`, `d`, `dc` y `pc` apuntan a `podman` / `podman compose`, y `lzd`
  abre `lazydocker` contra ese socket.
- **Runtimes en user-space:**
  - Python: **`uv`** (`uv run`, `uv venv`, `uv tool`).
  - Node.js: **`fnm`** (`fnm use`, versiones por proyecto).
  - JVM: **`sdkman`** (`sdk use`).
- **Shell y CLI de ingeniería:** `zsh`, `tmux`, `nvim`, `rg` (ripgrep), `fd`
  (`fdfind`), `bat` (`batcat`), `fzf`, `zoxide`, `atuin`, `jq`, `btop`, `yazi`,
  `mc`, `gh`, `direnv` y `devctl`.
- **Escritorio:** Hyprland 0.57+ (`hyprland.lua`, Wayland) con `foot`, `rofi`
  2.0 (Wayland nativo, 0 MB en reposo), `fuzzel`, `waybar` y portapapeles
  `wl-copy` / `wl-paste`. GNOME estándar queda como fallback en GDM.
- **Virtualización bajo demanda:** Quickemu + QEMU/KVM (`quickget` / `quickemu`
  en `~/VMs`), sin `libvirtd` ni autostart. Cada VM es un proceso de usuario.
- **Agentes de IA:** OpenCode CLI (`c` / `cc`, con `--standalone` por defecto)
  y Antigravity (CLI `agy` / IDE). Los modelos corren en cloud.

## Criterios de trabajo en esta estación

### 1. Contenedores y DevOps
- Asumir **Podman rootless** como motor de contenedores. No proponer instalar
  Docker Engine ni habilitar `dockerd`.
- Al redactar `Containerfile`, `Dockerfile` o `compose.yml`:
  - Usar puertos no privilegiados (`>= 1024`) o advertir si hace falta bindear
    puertos bajos.
  - Evitar `--privileged` o montajes pensados para `dockerd` rootful salvo
    necesidad real.
  - Cuidar mapeo de UIDs y permisos en bind mounts rootless.

### 2. Runtimes y dependencias de proyectos
- Preferir entornos aislados por proyecto (`uv`, `fnm`, `sdkman`) antes que
  instalar librerías globales con `pip`, `npm -g` o paquetes `python3-*` del
  sistema.
- En Debian, no romper el Python del sistema ni sugerir `--break-system-packages`.

### 3. Hardware y recursos reales
- **Medir antes de dimensionar.** No asumir cantidad de CPUs, RAM, GPU ni disco:
  cuando una decisión dependa de capacidad (paralelismo de builds, límites de
  memoria en contenedores, levantar una VM con Quickemu), inspeccionar la
  estación actual con `nproc`, `free -h`, `df -h`, `lspci` o `zramctl`.

### 4. Gestión declarativa de la estación
- `~/.zshrc`, `~/.gitconfig`, `~/.tmux.conf`, `~/.local/bin/devctl` y la
  mayoría de `~/.config/*` son **symlinks a `~/.dotfiles`**.
- **No proponer editar archivos enlazados en `~` o `~/.config` a mano** ni
  instalar herramientas permanentes fuera del repo como solución definitiva:
  indicar que el cambio debe hacerse en `~/.dotfiles` y re-aplicarse con
  `make <target>` / `make refresh`.
- Si la tarea consiste en modificar el propio aprovisionamiento dentro de
  `~/.dotfiles`, leer primero `~/.dotfiles/AGENTS.md`.

### 5. Diagnóstico y mantenimiento del entorno
- Salud integral de la estación: `devctl doctor` o `make -C ~/.dotfiles verify`.
- Actualización del sistema y herramientas user-space: `devctl update` o
  `make -C ~/.dotfiles update` (en Debian Forky, si hay paquetes retenidos por
  transiciones, aplicar `sudo apt full-upgrade` manualmente tras revisar `apt-listbugs`).
- Si una sesión de Hyprland necesita recargar symlinks/configs tras cambios en
  dotfiles: `make -C ~/.dotfiles refresh`.

## Límites no negociables

- **Sin IA local:** no proponer instalar Ollama, LlamaFile, GGUF ni servidores
  de inferencia locales.
- **Sin daemons permanentes extra:** evitar proponer servicios `systemd`
  always-on innecesarios (ni `libvirtd`, ni `dockerd`, ni dejar el servicio de
  fondo de OpenCode activo salvo que el usuario use `oc-on`).
- **Cuidado de secretos:** nunca exponer ni commitear tokens, credenciales de
  proveedores (`~/.config/opencode/*.json`, credenciales bajo `~/.gemini/`),
  claves SSH ni archivos `.env*`.
