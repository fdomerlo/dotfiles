![status](https://img.shields.io/badge/status-active-success)
![platform](https://img.shields.io/badge/platform-Debian%20Stable-red)
![shell](https://img.shields.io/badge/shell-zsh-green)
![podman](https://img.shields.io/badge/podman-rootless-purple)
![apps](https://img.shields.io/badge/apps-Flatpak%20%7C%20AppImage-blue)

# Debian Workstation — Hyprland & Dev Environment

Aprovisionamiento idempotente para estaciones de trabajo de desarrollo, DevOps e IA sobre **Debian Stable** (`trixie`). Incluye **Hyprland como escritorio principal** (con **GNOME estándar** como fallback limpio en GDM), contenedores **Podman Rootless**, shell productiva y runtimes aislados en user-space.

![Tiling en Hyprland con Zed, btop y Bruno](assets/hyprland-tiling.png)

*Tema `cyber-teal` en Hyprland con Waybar, Zed, `btop` y Bruno en tiling.*

---

## ⚡ Quick Start

### 1. Instalar sobre Debian Stable existente

```bash
sudo apt update && sudo apt install -y git make
git clone https://github.com/fdomerlo/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Instalación estándar (estación completa + Hyprland, GNOME como fallback)
make install

# Otras variantes:
make full-install    # Estación completa + Hyprland + snapshots Timeshift
make base-install    # Solo estación base + GNOME estándar (sin Hyprland)
```

> Todos los targets son idempotentes y pueden re-ejecutarse de forma segura. Ejecuta `make help` para ver todas las opciones.

### 2. Configuración inicial de usuario y validación

```bash
make gitconfig       # Configura user.name / user.email en ~/.config/git/local.gitconfig (sin tocar el repo)
make github-auth     # Autenticación SSH + GitHub CLI (opcional)
make verify          # Chequeo integral de estado del sistema
```

### 3. Instalación desatendida desde cero (opcional: `preseed.cfg`)

Para aprovisionar un equipo nuevo con [`preseed.cfg`](preseed.cfg), reemplaza antes en una copia local los placeholders:
- `<WIFI_SSID>` y `<WIFI_PASSWORD>`
- `<PASSWORD_HASH_SHA512>` (generado con `openssl passwd -6`)

---

## 🧰 Qué incluye

| Capa | Herramientas principales |
| :--- | :--- |
| **Escritorio (Hyprland + GNOME fallback)** | `hyprland`, `quickshell` (shell residente unificado estilo Material 3: Barra superior multi-monitor, Quick Settings acoplado con esquinas cóncavas, Centro de Notificaciones y toasts, OSD de volumen/brillo/bloqueos, Calendario, Lanzador Unificado y Overview/Actividades), `fuzzel` (`--dmenu` para submenús), `foot`, `hyprlock`/`hypridle`, `grim`+`slurp`+`swappy`, `wf-recorder`, `tesseract-ocr`, tema único **Cyber-Teal Material 3** (`dark` / `light` en caliente), fuentes Debian (`Inter`, `Atkinson Hyperlegible`, `JetBrains Mono`) y cursor `Bibata-Modern-Classic` |
| **Sistema & Contenedores** | Debian Stable + Backports, `zRAM` (`zstd`), Podman Rootless (`crun` + `pasta`, socket Docker-compat), `Timeshift` opcional, Flatpak + Flathub, AppImage (`~/Aplicaciones` en `$PATH`) |
| **Shell & CLI** | Zsh + Oh My Zsh, `starship`, `atuin`, `zoxide`, `tmux`, `ripgrep`, `fd`, `fzf`, `bat`, `btop`, `yazi`, `mc`, `lazydocker`, `direnv`, `devctl` |
| **Runtimes (user-space)** | Python ([uv](https://astral.sh/uv)), Node.js ([fnm](https://github.com/Schniz/fnm)), Java ([sdkman](https://sdkman.io)) |
| **Navegadores, Editores & IA** | Firefox (Flatpak, predeterminado), Google Chrome (soporte PWA), VS Code, Zed, Neovim (`lazy.nvim`), OpenCode CLI con asistente integrado en Hyprland (`Super+Shift+A` / `Super+Shift+I`), Antigravity IDE/CLI, DBeaver, Bruno, Remmina, Wireshark, Obsidian, LibreOffice |

---

## 🛠️ Comandos diarios (`Makefile` y `devctl`)

| Comando | Uso |
| :--- | :--- |
| `make install` | Aprovisionamiento completo con Hyprland y GNOME estándar como fallback |
| `make full-install` | Igual que `make install` más configuración de snapshots Timeshift |
| `make base-install` | Estación base sin Hyprland (solo GNOME estándar + CLI/Tooling/Podman) |
| `make hyprland` | Instala o re-aplica solo el stack y la configuración de Hyprland |
| `make hypr-desktop` / `make hypr-laptop` | Aplica plantilla local de desktop o notebook en `~/.config/hypr/conf/local.conf` |
| `make refresh` | Re-enlaza configs/scripts de Hyprland y recarga la sesión activa tras un `git pull` |
| `make devai` | Instala OpenCode, Antigravity y la skill de contexto de la estación |
| `make virt` | (Opcional) Instala Quickemu + QEMU/KVM para VMs sin daemon ni autostart |
| `make update` / `devctl update` | Actualiza paquetes APT (`packages/`), herramientas user-space y Flatpaks |
| `make verify` / `devctl doctor` | Verifica salud del entorno, enlaces, Podman y Hyprland |
| `make clean` / `make clean-deep` | Limpieza estándar o profunda (`rc`, huérfanos, cachés y logs) |
| `devctl webapp install "<Nombre>" "<URL>"` | Crea una Web App (PWA) aislada en Chrome con icono e integración en Hyprland |

---

## 🤖 IA integrada (OpenCode)

La estación **no ejecuta modelos locales**. OpenCode consume modelos cloud
(OpenCode Zen/Console, Google AI Studio u otro proveedor conectado con
`/connect`) y la integración con el escritorio es una capa de curaduría:
atajos, menús y una skill con el contexto del repo.

| Acción | Cómo |
| :--- | :--- |
| Menú de acciones IA | `Super+Shift+A` (o `Dev & IA` en el Centro Unificado / Lanzador) |
| Abrir TUI de OpenCode | `Super+Shift+I` (o `c` en terminal; `Super+Shift+A` abre el menú) |
| Explicar selección o portapapeles | `Super+Ctrl+I` |
| Continuar sesión / TUI mínima | `cc` / `cm` (`opencode mini --standalone`) |
| Pipes en Zsh | `git diff \| ai commit` o `cmd \| ai explain` |
| Encender/apagar servicio de fondo | `oc-on`, `oc-off`, `oc-st` (o clic derecho en el indicador IA de Waybar / `Dev & IA`) |
| Forzar un modelo puntual | `AI_MODEL=provider/modelo ai ...` |

`hypr/scripts/ai.sh` permite preguntar, explicar selección primaria o
portapapeles, analizar errores, resumir, traducir, capturar ventanas o
imágenes, revisar el diff del repo Git activo y generar mensajes de commit
(también desde `stdin` por pipe en Zsh). Sus diálogos corren en `footclient`
flotante (`ai-float`) con salida renderizada en Markdown (`batcat`). Por
defecto usa `opencode run --archived --standalone` (servidor efímero que muere
con el proceso); solo reutiliza `opencode service` cuando ya está encendido, sin
auto-iniciarlo, y rutea el modelo por tarea salvo override con `AI_MODEL`.

Así, el servicio de fondo de OpenCode queda **apagado** por defecto. El
indicador `󰚩 IA` de Waybar está siempre visible: atenuado cuando el servicio
está apagado y en verde cuando corre. El clic derecho alterna encendido/apagado
(`ai.sh service toggle`) y el clic izquierdo abre el menú IA; también se
enciende bajo demanda con `oc-on`, `ai.sh service start` o desde `Dev & IA`.
`oc-off` lo apaga. Los alias `c`, `cc` y `cm` pasan `--standalone` para no
levantar el servicio accidentalmente.

`make devai` enlaza `ai/opencode/opencode.json` en `~/.config/opencode/opencode.json`
para fijar la configuración base entre estaciones, junto con cada skill en
`ai/skills/<id>/SKILL.md` (`workstation/SKILL.md` + reglas propias del repo en
`AGENTS.md`), tanto en OpenCode (`~/.config/opencode/skills/<id>`) como en
Antigravity (`~/.gemini/config/skills/<id>` y perfiles activos).

### Otros agentes (no aprovisionados)

El repo no instala Claude Code, Codex CLI ni Pi: se solapan con OpenCode y
Antigravity y agregarían runtimes y mantenimiento sin aportar valor al
aprovisionamiento base. Si los necesitás, se instalan aparte con su instalador
oficial y su propio login:

```bash
curl -fsSL https://claude.ai/install.sh | bash         # Claude Code
curl -fsSL https://chatgpt.com/codex/install.sh | sh   # Codex CLI
curl -fsSL https://pi.dev/install.sh | sh              # Pi (requiere Node 22.19+)
```

---

## 🖥️ Virtualización opcional (Quickemu)

Para pruebas esporádicas de software, drivers y paridad con estaciones
Windows/Ubuntu/Zorin/Fedora, **sin libvirtd ni daemons permanentes**:

```bash
make virt
quickget windows 10        # o ubuntu 24.04, zorin 17, fedora <release>
quickemu --vm ~/VMs/windows-10.conf
quickemu --vm ~/VMs/windows-10.conf --snapshot create base
```

Cada VM es un proceso QEMU del usuario que termina al apagarla. Las imágenes
viven en `~/VMs` (override con `VMS_DIR`) y no hay autostart ni red NAT
administrada. La capacidad depende de cada estación: conviene una VM liviana a
la vez y verificar la RAM libre antes de levantarla. Windows 11 no es un
objetivo realista.

---

## 🪟 Guía rápida de Hyprland

Tras ejecutar `make install` (o `make hyprland`), elige **Hyprland** en GDM. **GNOME estándar** queda intacto en el selector de sesión como fallback.

### Atajos esenciales

| Atajo | Acción |
| :--- | :--- |
| `Super` / `Super+D` / `Super+Space` | **Centro Unificado** (`Apps`, `Dashboard`, `Media`, `Dev & IA`, `Sistema` — `Tab` cambia de pestaña y las flechas navegan el contenido) |
| `Super+Alt+1..5` | Abrir el **Dashboard** directo en `Apps`, `Dashboard`, `Media`, `Dev & IA` o `Sistema` |
| `Super+Alt+T` | **Apariencia**: popout de tema, barra y wallpapers |
| `Super+A` | **Actividades / Overview** (workspaces + previews en vivo + búsqueda de ventanas abiertas) |
| `Super+F1` | **Cheatsheet interactivo** con todos los atajos activos (teclado + mouse) |
| `Super+Return` / `Super+Shift+Return` | Terminal (`foot`) / terminal con sesión `tmux` persistente |
| `Super+B` / `Super+E` / `Super+Y` | Navegador predeterminado (`firefox`) / archivos (`nautilus`) / `yazi` TUI |
| `Super+C` | Editor de código predeterminado (`zed`, con respaldo `code` y `nvim` en Foot) |
| `Super+Shift+S` / `Super+Ctrl+S` | Mostrar/ocultar terminal flotante (scratchpad) / enviar ventana al scratchpad |
| `Super+Q` / `Super+F` / `Super+M` / `Super+S` | Cerrar / pantalla completa / maximizar / alternar flotante |
| `Super+Shift+C` / `Super+Ctrl+Tab` | Calculadora / alternar con la última ventana |
| `Super+1..0` / `Super+Shift+1..0` | Cambiar de workspace / mover ventana (`1–6` monitor 1, `7–0` monitor 2; `11–12` con `Av.Pág` o Actividades) |
| `Super+Av.Pág` / `Super+Re.Pág` | Ciclar workspaces cubriendo todos los monitores |
| `Super+V` / `Super+Shift+T` / `Super+W` | Historial portapapeles / cambiar tema / siguiente wallpaper |
| `Print` / `Ctrl+Print` / `Shift+Print` | Captura + `swappy` / captura directa al portapapeles / pantalla completa |
| `Super+Shift+R` / `Super+Shift+P` / `Super+Ctrl+O` | Grabar pantalla / selector color HEX / OCR de región |
| `Super+Shift+A` / `Super+Shift+I` / `Super+Ctrl+I` | Menú del asistente IA / abrir TUI de OpenCode / explicar selección o portapapeles |
| `Super+L` / `Super+N` / `Super+Ctrl+N` | Bloquear pantalla / notificaciones / luz nocturna (`4000K`) |
| **Touchpad (3 dedos)** | Horizontal: workspaces · Arriba: Centro Unificado · Abajo: Actividades |

### Tema único (Cyber-Teal Material 3 · Oscuro / Claro) y wallpapers

```bash
~/.config/hypr/scripts/theme-switch.sh toggle     # Alterna dark <-> light en caliente (Super+Shift+T)
~/.config/hypr/scripts/theme-switch.sh menu       # Selector interactivo (Fuzzel)
```

- **Diseño unificado:** geometría, animaciones Material 3, tipografía (`Inter` + `JetBrains Mono`) y barra superior con popouts acoplados mediante esquinas cóncavas (`QtQuick.Shapes`) viven en una sola base (`hypr/conf/appearance.conf` + `hypr/quickshell/Theme.qml`). Al alternar entre `dark` y `light`, Quickshell transiciona en caliente (`ColorAnimation` por IPC, sin reinicio) y acompaña GTK/libadwaita (`teal`), Qt6CT, Foot, Fuzzel, Hyprlock y los bordes de Hyprland.
- **`dark` (por defecto):** superficies grafito/pizarra tonales + acento cyan-teal (`#22d3ee`) y wallpaper [`northern-lights.jpg`](hypr/themes/dark/wallpapers/northern-lights.jpg).
- **`light`:** superficies hielo/niebla tonales + acento petrol-teal (`#006d80`) y wallpaper [`glacier-mist.jpg`](hypr/themes/light/wallpapers/glacier-mist.jpg).
- **Wallpapers propios:** coloca imágenes en `~/.config/hypr/wallpapers/` y, si querés separarlas por polaridad, en `~/.config/hypr/wallpapers/dark/` o `light/`. Ambas carpetas se suman al pool de rotación; rota con `Super+W`.

### Personalización local (sin ensuciar Git)

- **Git:** `~/.config/git/local.gitconfig` (`user.name`, `user.email`, firma, etc.).
- **Hyprland por equipo:** `~/.config/hypr/conf/local.conf` (monitores, sensibilidad, binds locales; inicializado con `make hypr-desktop` / `make hypr-laptop`).
- **Quickshell:** `~/.config/quickshell/local.json` (altura de barra u opciones locales por equipo).
- **Paquetes:** edita los manifiestos en [`packages/`](packages/) si haces un fork para tu equipo.

### Rollback a GNOME

Hyprland no modifica tu sesión GNOME: basta con elegir **GNOME** en GDM. Si además quieres quitar los symlinks del escritorio Hyprland:

```bash
find ~/.config/hypr ~/.config/fuzzel ~/.config/foot ~/.config/quickshell ~/.config/swappy ~/.config/fontconfig/conf.d \
  -maxdepth 2 -type l -lname '*/.dotfiles/hypr/*' -delete 2>/dev/null || true
```

---

## 📂 Estructura del repositorio

```text
~/.dotfiles/
├── Makefile          # Orquestador de instalación, actualización y perfiles
├── preseed.cfg       # Instalador desatendido de Debian Stable
├── packages/         # Listas declarativas de paquetes (apt, backports, flatpak, externos)
├── host/             # Configuración del sistema base y Podman Rootless
├── scripts/          # Instaladores modulares, actualización (update.sh) y salud (verify.sh)
├── shell/            # Dotfiles de zsh, git, tmux, nvim, yazi, mc, btop, zathura y CLI devctl
├── ai/               # Configuración base (opencode.json) y skills globales para OpenCode y Antigravity
└── hypr/             # Escritorio Hyprland (conf, quickshell, foot, fuzzel, temas, scripts)
```
