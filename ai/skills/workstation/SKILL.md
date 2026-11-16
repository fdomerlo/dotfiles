---
name: Workstation Debian
description: Contexto operativo de esta workstation Debian Stable (Hyprland, Podman rootless, OpenCode/Antigravity). Usar al trabajar sobre ~/.dotfiles, instalar paquetes, modificar scripts, diagnosticar la estación o proponer cambios de aprovisionamiento.
---

# Workstation Debian Stable

## Qué es esta estación

Workstation personal de **ingeniería de sistemas, desarrollo asistido con IA y
DevOps** sobre **Debian Stable (trixie)**, aprovisionada de forma idempotente
desde el repositorio `~/.dotfiles`.

- **Escritorio principal:** Hyprland (Wayland) con Waybar, Quickshell, Fuzzel y
  Foot. **GNOME estándar** queda como fallback en GDM, sin extensiones.
- **Contenedores:** Podman rootless con `crun` + `pasta`, socket compatible con
  Docker para herramientas que lo esperan.
- **Shell:** Zsh + Oh My Zsh, Starship, Atuin, Zoxide, fzf, tmux.
- **Runtimes en user-space:** `uv` (Python), `fnm` (Node), `sdkman` (JVM).
- **Agentes de IA:** OpenCode CLI (principal) y Antigravity IDE/CLI.
- **Virtualización opcional:** Quickemu + QEMU/KVM, sin daemon ni autostart.
- **Hardware de referencia:** AMD Ryzen 5 5600G, 7.1 GB RAM, iGPU Vega,
  zRAM + swapfile. Las decisiones deben asumir RAM ajustada.

## Principio rector

El repositorio es la **fuente de verdad**. `~/.config`, `~/.zshrc`, `~/.gitconfig`
y compañía son **symlinks** al repo. Una vez aprovisionada, la estación **no se
toca a mano**: se modifica el repo y se re-aplica.

Regla de convivencia: **no refactorizar de más**. La estación funciona y se usa a
diario; los cambios deben limitarse a lo pedido y no romper la idempotencia.

## Mapa del repositorio

```text
~/.dotfiles/
├── Makefile              # Orquestador: install, base-install, full-install,
│                         # update, refresh, host, podman, shell, devtools,
│                         # tooling, devai, virt, hyprland, verify, clean(-deep)
├── packages/             # Manifiestos declarativos (una entrada por línea)
│   ├── apt-base.txt      # APT base (host/setup.sh)
│   ├── apt-hyprland.txt  # APT del escritorio
│   ├── apt-optional.txt  # APT opcional/bajo demanda (incluye Quickemu)
│   ├── apt-backports.txt # APT desde backports
│   ├── flatpak.txt       # Apps Flatpak
│   └── external.txt      # Inventario de binarios fuera de APT
├── host/                 # setup.sh (root): APT, backports, zRAM, swap, sleep,
│                         # Podman rootless, linger, timeshift.sh
├── scripts/              # Instaladores modulares y mantenimiento
│   ├── devai.sh          # OpenCode, Antigravity y skill del repo
│   ├── virt.sh           # Quickemu + QEMU/KVM (sin daemon)
│   ├── verify.sh         # Diagnóstico de salud (make verify / devctl doctor)
│   ├── update.sh         # APT --only-upgrade + self-updates user-space
│   ├── hyprland.sh       # Instala y enlaza el escritorio
│   ├── hyprland-refresh.sh # Re-enlaza configs y recarga la sesión
│   └── lib/packages.sh   # Lector de manifiestos (read_manifest)
├── shell/                # zshrc, gitconfig, tmux, starship, atuin, devctl,
│                         # nvim, yazi, mc, btop, lazydocker, zathura
├── hypr/                 # hyprland.conf, conf/, scripts/, quickshell/,
│                         # waybar/, foot/, fuzzel/, swaync/, themes/
└── ai/skills/workstation # Esta skill (enlazada en ~/.config/opencode/skills)
```

## Invariantes que no se negocian

1. **Idempotencia:** todo target debe poder ejecutarse N veces sin romper nada.
   Los enlaces se crean con `ln -sf`; los archivos se escriben solo si cambian.
2. **Sin daemons permanentes nuevos.** Podman rootless ya usa systemd de usuario;
   no agregar servicios always-on (ni libvirt, ni servidores de modelos).
3. **Sin IA local.** Se descartó por RAM y mantenimiento. Los modelos son cloud
   vía OpenCode (`/connect`); el provider se elige en runtime.
4. **Paquetes APT siempre en `packages/*.txt`**, nunca hardcodeados en un script
   (salvo casos dinámicos ya existentes, como Chrome o Neovim).
5. **Instaladores remotos** (OpenCode, Antigravity, Zed, etc.) se ejecutan con
   `run_with_zshrc_guard` para que no ensucien `shell/zshrc`.
6. **No tocar** claves SSH, `gh auth`, `/opt/Antigravity`, `chsh`, linger ni
   registros de Podman desde `update.sh`.
7. **Secretos fuera del repo:** `~/.config/opencode/service.json`,
   `~/.config/opencode/auth.json`, `~/.pi/agent/auth.json`, `.env*`.
8. **Configs locales por máquina** van en `hypr/conf/local.conf` (gitignored).

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

### Actualizar o diagnosticar
- `make update` / `devctl update`: APT `--only-upgrade` + herramientas
  user-space + Flatpak.
- `make verify` / `devctl doctor`: sintaxis, manifiestos, drivers, symlinks,
  Podman, keyring y errores de Hyprland.
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

## IA integrada (OpenCode)

- OpenCode se instala con `make devai`; los proveedores se conectan con
  `/connect` (OpenCode Zen/Console, Google AI Studio, etc.).
- Acciones rápidas: `hypr/scripts/ai.sh` — menú con `Super+Shift+A`, explicar
  portapapeles con `Super+Ctrl+I`. También está en el menú `Dev & IA` y en el
  lanzador de Quickshell.
- Las invocaciones usan `opencode run --archived` para no ensuciar el historial
  de sesiones. Se puede forzar modelo con `AI_MODEL=provider/modelo`.
- Alias de shell: `c` (opencode), `cc` (continuar sesión), `ai` (acciones).
- Esta skill se versiona en `ai/skills/workstation/SKILL.md` y se enlaza en
  `~/.config/opencode/skills/workstation` desde `scripts/devai.sh`. Ese script
  enlaza todas las skills de `ai/skills/*/SKILL.md`, así que las nuevas se
  suman sin cambiar el instalador.

## Virtualización (opcional)

- `make virt` instala Quickemu + QEMU/KVM, OVMF, swtpm y utilidades.
- **No hay libvirtd ni autostart.** Cada VM es un proceso QEMU del usuario.
- VMs en `~/VMs` (override con `VMS_DIR`).
- Uso: `quickget windows 10`, `quickget ubuntu 24.04`, `quickget zorin 17`,
  `quickget fedora <release>`; luego `quickemu --vm ~/VMs/<conf>`.
- Pensado para pruebas esporádicas y paridad con estaciones Windows/Ubuntu/
  Zorin/Fedora. No para Windows 11 con 7 GB de RAM ni para cargas pesadas.

## Qué NO hacer

- No agregar modelos locales, LlamaFile, GGUF ni servidores de inferencia.
- No instalar GNOME Boxes ni libvirt salvo pedido explícito y justificado.
- No reemplazar Podman por Docker ni agregar el daemon de Docker.
- No editar archivos en `~/.config` directamente: editar el repo y `make refresh`.
- No agregar Flatpaks o AppImages sin registrarlos en su manifiesto.
- No ejecutar `make install` para un cambio menor: usar el target específico.
- No commitear credenciales, tokens ni archivos de estado runtime.
- No reformatear ni "mejorar" código ajeno al alcance del pedido.
