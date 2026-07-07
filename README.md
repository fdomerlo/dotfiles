# setup_workstation.sh

Script de aprovisionamiento post-instalación para workstations de desarrollo sobre **Debian Testing**. Asume un particionado específico (detallado abajo) y deja el equipo listo para trabajar: Docker, VS Code, runtimes de lenguaje, shell y dotfiles, sin intervención manual salvo la contraseña de `sudo`.

No es un script genérico "para cualquier Debian" — está atado a decisiones de infraestructura concretas que se explican en este documento. Si vas a adaptarlo a tu propia máquina, leé la sección de **Prerrequisitos** antes de correrlo.

## Uso

# Instalación estándar
```bash
curl -fsSL https://raw.githubusercontent.com/fdomerlo/dotfiles/main/setup_workstation.sh | bash
```

# Con apps adicionales de escritorio (Flatpak)
```bash
curl -fsSL <URL> | bash -s -- --full
```

No correr como root. El script pide `sudo` puntualmente para cada operación que lo necesita.

## Prerrequisitos

El script asume que el disco ya fue particionado así (ver `preseed.cfg` en este mismo repo):

| Punto de montaje | Filesystem | Por qué |
|---|---|---|
| `/boot/efi` | FAT32 | Requisito de la spec UEFI, no hay alternativa |
| `/` | **Btrfs** + Snapper | Snapshots automáticos y rollback si una actualización rompe el sistema |
| `/home` | **Ext4** | Evita el overhead de copy-on-write de Btrfs en cargas con muchos archivos chicos (`node_modules`, `venv`, `__pycache__`) |

Esta combinación es intencional, no arbitraria, y **el script depende de ella** en dos puntos concretos (swapfile y Docker data-root, ver abajo). Si tu partición raíz no es Btrfs, esas dos secciones siguen funcionando igual, pero pierden su razón de ser — no hace daño, simplemente sobra la relocación.

## Decisiones de diseño

### 1. Paquetes base antes que repos de terceros

El script instala primero todo lo que ya está en los repos oficiales de Debian (`BASE_PKGS`), y recién después agrega repos de terceros (Docker, VS Code, etc.) e instala lo que depende de ellos (`REPO_PKGS`). El orden no es cosmético: `curl` y `gnupg` tienen que existir en el sistema *antes* de poder descargar y verificar las claves GPG de esos repos externos. Es el límite real que impide bajar todo a una sola llamada de `apt-get install`.

```bash
BASE_PKGS=( zram-tools curl wget git zip unzip stow gnupg fonts-noto ... )
sudo apt-get install -y "${BASE_PKGS[@]}"

# ... se agregan los repos de terceros acá ...

REPO_PKGS=( gh code dbeaver-ce docker-ce ... )
sudo apt-get install -y "${REPO_PKGS[@]}"
```

Con esto quedan **2 `apt-get update` + 2 `apt-get install`** en total — el mínimo posible dada la dependencia. Cualquier versión con 3 o más de cualquiera de los dos está gastando tiempo de red sin necesidad.

### 2. Swapfile en `/home`, nunca en `/`

```bash
SWAPFILE="/home/.swapfile"
```

Un swapfile sobre Btrfs no funciona con el método clásico (`dd` + `mkswap` + `swapon`) sin pasos adicionales: necesita el atributo NOCOW (`chattr +C`) aplicado *antes* de escribir cualquier dato, sin compresión, y sin que el archivo cruce subvolúmenes o quede atrapado en un snapshot. Saltarse esto puede hacer que `swapon` falle directamente, o peor, corromper el archivo por el copy-on-write.

En vez de lidiar con esas excepciones, el swapfile vive en `/home` (Ext4), donde el método tradicional funciona sin ninguna configuración especial. Mismo principio que aplicamos a `node_modules`: todo lo que implica escritura constante o no tolera CoW, fuera de Btrfs.

zRAM sigue siendo la primera línea de memoria virtual (prioridad de swap 100); el swapfile es solo el colchón de caída si zRAM se satura (prioridad 10).

### 3. Docker data-root relocado a `/home/docker-data`

```bash
sudo systemctl stop docker.service docker.socket 2>/dev/null || true
echo "{\"data-root\": \"/home/docker-data\"}" | sudo tee /etc/docker/daemon.json
```

Por defecto, Docker guarda imágenes, capas y volúmenes en `/var/lib/docker` — que en nuestro esquema cae dentro de `/`, es decir, dentro de Btrfs. Las capas de contenedores son exactamente el patrón de I/O que peor le sienta a Btrfs (muchísimos archivos chicos creándose y destruyéndose todo el tiempo), y además inflan cada snapshot de Snapper con basura de contenedores efímeros que no tiene sentido poder "revertir".

El detalle no obvio: **`docker-ce` arranca el servicio automáticamente al instalarse** (systemd preset de Debian). Si escribís la config nueva después de instalar sin parar el servicio primero, Docker ya alcanzó a inicializar `/var/lib/docker` con la ruta vieja. Por eso el script para el servicio, escribe `daemon.json`, migra cualquier dato residual si lo hubiera, y recién ahí lo habilita.

### 4. Fallback de repo de Docker: `trixie` → `bookworm`

```bash
DOCKER_CODENAME="trixie"
if ! curl -fsSL ".../dists/$DOCKER_CODENAME/" | grep -q "stable"; then
    DOCKER_CODENAME="bookworm"
fi
```

Docker solo publica repos apt para codenames de Debian **ya liberados como Stable** — nunca para el nombre de Testing en curso (hoy "forky"). Este chequeo no es un manejo de errores genérico: es la forma correcta de anticipar que, en algún momento de transición entre releases de Debian, el repo de Docker para el codename más reciente puede no estar listo todavía, y hay que caer a la versión anterior sin que el script se rompa.

### 5. `stow -R` corre siempre, no solo en el primer clone

```bash
if [ ! -d "$HOME/.dotfiles" ]; then
    git clone "https://github.com/${GITHUB_USER}/dotfiles.git" "$HOME/.dotfiles"
fi
cd "$HOME/.dotfiles"
stow -R configs fonts
```

Si una corrida anterior del script falló entre el `git clone` y el `stow` (red caída, Ctrl+C, lo que sea), volver a correr el script no debía dejar el repo clonado pero sin symlinkear. Separar el `clone` (condicional) del `stow -R` (incondicional, siempre re-simboliza) hace que el script sea seguro de re-ejecutar en cualquier punto en el que haya fallado antes.

### 6. `GITHUB_USER` como variable explícita

```bash
GITHUB_USER="fdomerlo"
```

El username del sistema (`$USER`) y el handle de GitHub coinciden hoy, pero son cosas conceptualmente distintas. Si alguien del equipo adapta este script con un usuario de sistema diferente al de su cuenta de GitHub, que dependa de una variable explícita en vez de `$USER` evita un `git clone` a una URL que no existe.

## Estructura del script

| Sección | Qué hace |
|---|---|
| 1. Paquetes base | Todo lo que no depende de repos de terceros |
| 2. Memoria virtual | zRAM (primaria) + swapfile en `/home` (fallback) |
| 3. Repositorios de terceros | Docker, VS Code, Mozilla, GitHub CLI, DBeaver, Chrome |
| 4. Paquetes de terceros + Docker data-root | Instala lo que depende de los repos de arriba, y relocaliza Docker |
| 4.5. Apps de escritorio (`--full`) | Flatpaks opcionales, solo si se pasa el flag |
| 5. Oh My Zsh + dotfiles | Shell, plugins, symlinks vía Stow |
| 6. Runtimes | `uv` (Python), `fnm` (Node), `sdkman` (JVM) |
| 7. GNOME | Fuentes, dock, terminal |

## Qué NO hace este script

- No particiona el disco — eso es responsabilidad de `preseed.cfg`, corrido antes durante la instalación.
- No configura Snapper — también se resuelve en el `late_command` del preseed, antes del primer arranque.
- No es idempotente al 100%: los pasos de instalación de paquetes y configuración de repos son seguros de re-correr, pero no hay manejo de rollback si `apt-get install` falla a mitad de camino por un corte de red. Si el script aborta, revisar en qué sección quedó (`set -euo pipefail` corta la ejecución en el primer error) antes de re-correrlo.
