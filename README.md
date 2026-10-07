# Debian Workstation Provisioning

Idempotent, modular, and robust post-installation provisioning suite for Debian Stable.
Targeted specifically for thin host architecture on AMD Ryzen 5 5600G.

## Architecture & Rationale

*   **Thin Host Architecture**: The host OS (Debian Stable) remains extremely minimal.
*   **User-Space Developer Runtimes**: Language toolchains (Node.js, Python, Go) are isolated entirely in user-space via [`mise`](https://mise.jdx.dev), avoiding system pollution and package manager conflicts.
*   **Containerized Desktop Apps**: Graphical tools (VS Code, DBeaver) are sandboxed and installed via Flatpak in `--user` scope.
*   **Storage Optimization**: Relies on EXT4 longevity and handles specific setups natively.
*   **Memory Efficiency**: Utilizes zRAM for intelligent swap offloading, maintaining responsiveness on APUs allocating shared memory.
*   **Idempotency**: Execution is safe at any time; steps safely evaluate current system state and skip redundancy.

## Quick Start

Execute these instructions as a normal user immediately after your preseed Debian installation.

```bash
# Clone the repository
git clone <repo_url> ~/.dotfiles
cd ~/.dotfiles

# Run the provisioning bootstrap
./bootstrap.sh
```

## Options & Flags

The `bootstrap.sh` entrypoint supports several optional flags:

*   `--dry-run`: Evaluate scripts without executing them.
*   `--skip-system`: Skips the system-level provision requiring `sudo` (APT operations, zRAM setup).
*   `--skip-flatpak`: Skips Flatpak configuration and heavy graphical app installation.

## Modular Execution

The provisioning steps are broken into distinct shell scripts under `scripts/`. They can be run individually if needed:

1.  `scripts/01-system.sh`: Requires `sudo`. Installs APT packages, GPU drivers, sets up zRAM, and configures TRIM.
2.  `scripts/02-fonts.sh`: User-scope execution. Deploys custom fonts to `~/.local/share/fonts` and updates caches.
3.  `scripts/03-dotfiles.sh`: User-scope execution. Safely backs up existing configurations and creates symlinks. Ensures `/usr/bin/zsh` is the default shell.
4.  `scripts/04-toolchains.sh`: User-scope execution. Installs `mise` and standard developer runtimes (Node.js, Python, Go).
5.  `scripts/05-flatpak.sh`: User-scope execution. Sets up Flathub and installs UI software.

## Verification

Once complete, run the health-check script to validate the integrity of your workstation setup:

```bash
./scripts/verify.sh
```

This will run assertions on:
*   Kernel modules (`amdgpu`).
*   zRAM activation.
*   Font deployments.
*   Dotfile symlink structures.
*   The availability of the `mise` runtime manager.
