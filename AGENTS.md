# AGENTS.md — ~/.dotfiles (Workstation Debian Stable)

Instrucciones para agentes de IA al trabajar **dentro del repositorio `~/.dotfiles`**.
El contexto operativo general de la estación para cualquier proyecto vive separado en
`ai/skills/workstation/SKILL.md`.

## Qué es este repositorio

Aprovisionamiento idempotente de **estaciones de trabajo** de ingeniería de
sistemas, desarrollo asistido con IA y DevOps sobre **Debian Stable (`trixie`)**.
El mismo repositorio se aplica en **varias estaciones**, así que nada debe
asumir un hardware concreto.

- **Escritorio principal:** Hyprland (Wayland) con Quickshell (barra superior,
  notificaciones, OSD, calendario, lanzador y overview), Fuzzel y Foot. **GNOME estándar** queda como fallback en GDM, sin extensiones.
- **Contenedores:** Podman rootless con `crun` + `pasta`, socket compatible con
  Docker para herramientas que lo esperan.
- **Shell:** Zsh + Oh My Zsh, Starship, Atuin, Zoxide, fzf, tmux, `devctl`.
- **Runtimes en user-space:** `uv` (Python), `fnm` (Node), `sdkman` (JVM).
- **Agentes de IA:** OpenCode CLI y Antigravity IDE/CLI.
- **Virtualización opcional:** Quickemu + QEMU/KVM, sin daemon ni autostart.
- **Hardware:** heterogéneo entre estaciones. No fijes CPU, RAM ni GPU en
  scripts ni documentación: si una decisión depende de recursos, medilos en la
  máquina actual (`nproc`, `free -h`, `lspci`, `df -h`). Las diferencias por
  estación van en `hypr/conf/local.conf` (gitignored).
- **Memoria y swap:** `host/setup.sh` dimensiona `/swapfile` según la RAM
  detectada; el repo no fija tamaños absolutos.

## Principio rector

El repositorio es la **fuente de verdad**. `~/.config`, `~/.zshrc`, `~/.gitconfig`
y compañía son **symlinks** al repo. Una vez aprovisionada, cada estación **no se
toca a mano**: se modifica el repo y se re-aplica.

Regla de convivencia: **no refactorizar de más**. Las estaciones funcionan y se
usan a diario; los cambios deben limitarse a lo pedido y no romper la
idempotencia.

## Mapa del repositorio

```text
~/.dotfiles/
├── AGENTS.md                 # Reglas de mantenimiento de este repositorio
├── Makefile                  # Orquestador: install, base-install, full-install,
│                             # update, refresh, host, podman, shell, devtools,
│                             # tooling, devai, virt, hyprland, verify, clean(-deep)
├── packages/                 # Manifiestos declarativos (una entrada por línea)
│   ├── apt-base.txt          # APT base (host/setup.sh)
│   ├── apt-hyprland.txt      # APT del escritorio
│   ├── apt-optional.txt      # APT opcional/bajo demanda (incluye Quickemu)
│   ├── apt-backports.txt     # APT desde backports
│   ├── apt-backports-tools.txt # Herramientas CLI desde backports
│   ├── flatpak.txt           # Apps Flatpak
│   └── external.txt          # Inventario de binarios fuera de APT
├── host/                     # setup.sh (root): APT, backports, zRAM, swap, sleep,
│                             # Podman rootless, linger, timeshift.sh
├── scripts/                  # Instaladores modulares y mantenimiento
│   ├── devai.sh              # OpenCode, Antigravity y enlace de skills globales
│   ├── virt.sh               # Quickemu + QEMU/KVM (sin daemon)
│   ├── verify.sh             # Diagnóstico de salud (make verify)
│   ├── update.sh             # APT --only-upgrade + self-updates user-space
│   ├── hyprland.sh           # Instala y enlaza el escritorio
│   ├── hyprland-refresh.sh   # Re-enlaza configs y recarga la sesión
│   └── lib/packages.sh       # Lector de manifiestos (read_manifest)
├── shell/                    # zshrc, gitconfig, tmux, starship, atuin, devctl,
│                             # nvim, yazi, mc, btop, lazydocker, zathura
├── hypr/                     # hyprland.conf, conf/, scripts/, quickshell/,
│                             # foot/, fuzzel/, themes/
└── ai/skills/workstation/    # Skill global de la estación (enlazada en OpenCode
                              # y Antigravity mediante scripts/devai.sh)
```

## Invariantes que no se negocian

1. **Idempotencia:** todo target debe poder ejecutarse N veces sin romper nada.
   Los enlaces se crean con `ln -sf` / `ln -sfn`; los archivos se escriben solo
   si cambian.
2. **Sin daemons permanentes nuevos.** Podman rootless ya usa systemd de usuario;
   no agregar servicios always-on (ni `libvirtd`, ni servidores de modelos).
3. **Sin IA local.** Los modelos son cloud vía OpenCode (`/connect`) o
   Antigravity; el repo no despliega servidores de inferencia porque no son
   portables entre estaciones y suman mantenimiento.
4. **Paquetes APT siempre en `packages/*.txt`**, nunca hardcodeados en un script
   (salvo casos dinámicos ya existentes, como Chrome o Neovim).
5. **Instaladores remotos** (OpenCode, Antigravity, Zed, etc.) se ejecutan con
   `run_with_zshrc_guard` para que no ensucien `shell/zshrc`.
6. **No tocar** claves SSH, `gh auth`, `/opt/Antigravity*`, `chsh`, linger ni
   registros de Podman desde `update.sh`.
7. **Secretos fuera del repo:** `~/.config/opencode/service.json`,
   `~/.config/opencode/auth.json`, `~/.pi/agent/auth.json`, credenciales de
   `~/.gemini/`, `.env*`.
8. **Configs locales por máquina** van fuera de Git (`hypr/conf/local.conf`,
   `~/.config/quickshell/local.json`, `~/.config/git/local.gitconfig`).

## Flujos típicos

### Agregar un paquete APT
1. Agregarlo al manifiesto correcto en `packages/`.
2. Si es del host, `host/setup.sh` lo toma; si es opcional, `apt-optional.txt`
   lo actualiza con `--only-upgrade`.
3. Verificar con `make verify`.

### Agregar un script o comando
- Scripts de usuario: `scripts/<nombre>.sh`, `chmod +x`, target en `Makefile`
  (agregar a `.PHONY` y a `help`).
- Scripts de Hyprland: `hypr/scripts/<nombre>.sh`. Se enlazan solos con
  `make hyprland` o `make refresh`.
- Lógica compartida: `scripts/lib/` o `shell/devctl`.

### Cambiar un atajo o el menú
- Atajos: `hypr/conf/keybinds.conf` (usar `$mod` = Super).
- Menú maestro: `hypr/scripts/main-menu.sh` (Fuzzel dmenu).
- Lanzador unificado: `hypr/quickshell/LauncherWindow.qml` (categoría `dev`).
- Después: `make refresh` (re-enlaza y recarga Hyprland/Quickshell).

### Agregar una skill global de IA
- Crear `ai/skills/<id>/SKILL.md` con frontmatter YAML (`name` y `description`).
- Redactarla agnóstica al agente (sirve tanto para OpenCode como Antigravity).
- Ejecutar `make devai` para enlazarla en `~/.config/opencode/skills/` y en las
  rutas globales de Antigravity (`~/.gemini/config/skills/` y perfiles activos).

### Actualizar o diagnosticar
- `make update` / `devctl update`: APT `--only-upgrade` + herramientas
  user-space + Flatpak.
- `make verify` / `devctl doctor`: sintaxis, manifiestos, drivers, symlinks,
  Podman, skills de IA, keyring y errores de Hyprland.
- `make clean` / `make clean-deep`: limpieza de APT, huérfanos, logs y cachés.

## Convenciones de código

- Bash estricto: `#!/usr/bin/env bash`, `set -euo pipefail`.
- Scripts de usuario **no** se ejecutan como root; usan `sudo -n true` y avisan
  si falta elevación (ver `scripts/tooling.sh` y `scripts/virt.sh`).
- Mensajes en español, con `ok()` / `warn()` / `step()` cuando el script ya los
  define.
- Rutas relativas al repo con `SCRIPT_DIR` y `REPO_DIR`; nunca asumir `$PWD`.
- En `hypr/scripts/`, usar `notify-send` y `fuzzel` como en `main-menu.sh`.
- Los prompts de Fuzzel que deban cerrarse con `Super+Alt+Space` incluyen la
  palabra `Menú`.

## Qué NO hacer

- No agregar modelos locales, LlamaFile, GGUF ni servidores de inferencia.
- No instalar GNOME Boxes ni `libvirt` salvo pedido explícito y justificado.
- No reemplazar Podman por Docker ni agregar el daemon de Docker.
- No editar archivos en `~/.config` directamente: editar el repo y `make refresh`.
- No agregar Flatpaks o AppImages sin registrarlos en su manifiesto.
- No ejecutar `make install` para un cambio menor: usar el target específico.
- No commitear credenciales, tokens ni archivos de estado runtime.
- No reformatear ni "mejorar" código ajeno al alcance del pedido.
- No fijar requisitos de hardware (RAM, CPU, GPU, disco) en scripts ni docs:
  el repo se aplica en varias estaciones.
