# ==============================================================================
# Debian Stable Workstation - Dev Environment Setup
# ==============================================================================

SHELL := /bin/bash

export RUNZSH=no
export CHSH=no
export KEEP_ZSHRC=yes
export PATH := $(HOME)/.local/bin:$(PATH)

.PHONY: help install full-install update refresh host timeshift podman shell devtools tooling devai desktop hyprland verify clean clean-deep gitconfig github-auth

# Target por defecto: mostrar ayuda
help:
	@echo "Opciones de aprovisionamiento (Debian Stable Workstation):"
	@echo "  make install         - Aprovisiona la estación de trabajo completa (host + podman + shell + devtools + tooling + devai + desktop)"
	@echo "  make full-install    - Aprovisiona la estación de trabajo completa con Hyprland como escritorio"
	@echo "  make update          - Actualiza la estación (APT only-upgrade incl. perfil Hyprland + self-updates + flatpak)"
	@echo "  make refresh         - Re-sincroniza configs/scripts de Hyprland desde el repo y recarga la sesión (tras git pull)"
	@echo "  make host            - Configura APT (Backports), CLI moderna, AppImage, Flatpak y Podman"
	@echo "  make podman          - Configura Podman en modo Rootless con backend pasta (systemd --user)"
	@echo "  make shell           - Configura Zsh, Oh My Zsh y enlaza dotfiles (.zshrc, .gitconfig, devctl, btop, yazi, nvim, zathura, lazydocker)"
	@echo "  make devtools        - Instala gh, uv, fnm, sdkman, yazi, lazydocker y sincroniza SSH de GitHub"
	@echo "  make tooling         - Instala navegadores, editores y suite sysadmin/productividad (Firefox, Chrome, VS Code, Zed, Neovim, Remmina, Wireshark, DBeaver, Bruno, Obsidian, Super Productivity)"
	@echo "  make devai           - Instala OpenCode CLI, Antigravity CLI y Core/IDE"
	@echo "  make desktop         - Configura tipografías, botones de ventana, directorios de trabajo y extensiones GNOME"
	@echo "  make timeshift       - (Opcional) Instala y configura Timeshift sin crear snapshots automáticos iniciales"
	@echo "  make hyprland        - (Opcional) Instala y configura el perfil Hyprland sin reemplazar GNOME"
	@echo "  make verify          - Ejecuta diagnóstico de salud del sistema"
	@echo "  make clean           - Limpia paquetes residuales de APT y temporales"
	@echo "  make clean-deep      - Limpieza profunda post-upgrade: purga configs residuales (rc), dependencias, logs y cachés"

# Instalación completa desatendida (idempotente: re-ejecutable; Timeshift es opcional vía 'make timeshift')
install: host podman shell devtools tooling devai desktop clean
	@echo -e "\n✅ Instalación finalizada. Reinicia la sesión gráfica o terminal para aplicar todos los cambios."
	@echo -e "💡 Tip: Si deseas habilitar respaldos del sistema en este equipo, ejecuta: make timeshift"

# Instalación completa desatendida + Hyprland
full-install: host podman shell devtools tooling devai desktop timeshift hyprland clean
	@echo -e "\n✅ Instalación finalizada. Reinicia la sesión gráfica o terminal para aplicar todos los cambios."
	@echo -e "💡 Tip: Si deseas habilitar respaldos del sistema en este equipo, ejecuta: make timeshift"

# Actualización idempotente (no reconfigura SSH/gh auth, /opt, chsh ni registros)
update:
	@echo "==> Actualizando estación (APT only-upgrade + user-space)..."
	bash scripts/update.sh

# Re-sincronizar configs/scripts de Hyprland y recargar la sesión (sin instalar)
refresh:
	@echo "==> Refrescando configuración de Hyprland..."
	bash scripts/hyprland-refresh.sh

# 1. Host (requiere sudo)
host:
	@echo "==> Configurando Host..."
	sudo bash host/setup.sh

# 1b. Timeshift opcional posterior (requiere sudo; solo configura, no crea snapshot)
timeshift:
	@echo "==> Configurando Timeshift (opcional)..."
	sudo bash host/timeshift.sh

# 2. Podman Rootless (se ejecuta como usuario normal)
podman:
	@echo "==> Configurando Podman Rootless..."
	bash host/podman.sh

ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# 3. Shell y Dotfiles
shell:
	@echo "==> Configurando Zsh y Dotfiles..."
	bash scripts/ohmyzsh.sh
	mkdir -p $(HOME)/Proyectos $(HOME)/Aplicaciones
	ln -sf $(ROOT_DIR)/shell/zshrc $(HOME)/.zshrc
	ln -sf $(ROOT_DIR)/shell/gitconfig $(HOME)/.gitconfig
	ln -sf $(ROOT_DIR)/shell/starship.toml $(HOME)/.config/starship.toml
	ln -sf $(ROOT_DIR)/shell/tmux.conf $(HOME)/.tmux.conf
	mkdir -p $(HOME)/.config/atuin
	ln -sf $(ROOT_DIR)/shell/atuin.toml $(HOME)/.config/atuin/config.toml
	mkdir -p $(HOME)/.config/btop/themes
	ln -sf $(ROOT_DIR)/shell/btop/themes/neutral.theme $(HOME)/.config/btop/themes/neutral.theme
	@# btop reescribe btop.conf al salir: se inicializa si no existe o se asegura el tema neutral si ya existe.
	@if [ ! -f $(HOME)/.config/btop/btop.conf ]; then \
		cp $(ROOT_DIR)/shell/btop/btop.conf $(HOME)/.config/btop/btop.conf; \
	else \
		sed -i 's/^color_theme = .*/color_theme = "neutral"/' $(HOME)/.config/btop/btop.conf; \
		sed -i 's/^theme_background = .*/theme_background = False/' $(HOME)/.config/btop/btop.conf; \
	fi
	mkdir -p $(HOME)/.config/yazi
	ln -sf $(ROOT_DIR)/shell/yazi/yazi.toml $(HOME)/.config/yazi/yazi.toml
	ln -sf $(ROOT_DIR)/shell/yazi/keymap.toml $(HOME)/.config/yazi/keymap.toml
	ln -sf $(ROOT_DIR)/shell/yazi/theme.toml $(HOME)/.config/yazi/theme.toml
	mkdir -p $(HOME)/.config/mc $(HOME)/.local/share/mc/skins
	ln -sf $(ROOT_DIR)/shell/mc/ini $(HOME)/.config/mc/ini
	ln -sf $(ROOT_DIR)/shell/mc/skins/nord.ini $(HOME)/.local/share/mc/skins/nord.ini
	@# mcedit no necesita su propia entrada en el lanzador: F4 abre el editor interno.
	mkdir -p $(HOME)/.local/share/applications $(HOME)/.local/share/icons/hicolor/128x128/apps
	ln -sf $(ROOT_DIR)/shell/mc/mcedit.desktop $(HOME)/.local/share/applications/mcedit.desktop
	ln -sf $(ROOT_DIR)/shell/nvim/nvim.desktop $(HOME)/.local/share/applications/nvim.desktop
	ln -sf $(ROOT_DIR)/shell/lazydocker/lazydocker.desktop $(HOME)/.local/share/applications/lazydocker.desktop
	@[ -f $(HOME)/.local/share/neovim/share/icons/hicolor/128x128/apps/nvim.png ] && \
		ln -sf $(HOME)/.local/share/neovim/share/icons/hicolor/128x128/apps/nvim.png $(HOME)/.local/share/icons/hicolor/128x128/apps/nvim.png || true
	mkdir -p $(HOME)/.config/zathura $(HOME)/.config/lazydocker
	ln -sf $(ROOT_DIR)/shell/zathura/zathurarc $(HOME)/.config/zathura/zathurarc
	ln -sf $(ROOT_DIR)/shell/lazydocker/config.yml $(HOME)/.config/lazydocker/config.yml
	mkdir -p $(HOME)/.config
	ln -sfn $(ROOT_DIR)/shell/nvim $(HOME)/.config/nvim
	mkdir -p $(HOME)/.local/bin
	@# Yazi busca el binario `fd`; Debian lo instala como `fdfind`.
	@if [ -x /usr/bin/fdfind ]; then ln -sf /usr/bin/fdfind $(HOME)/.local/bin/fd; fi
	@# Debian instala el wrapper `imv` en /usr/libexec/imv/imv por colisión de nombre con renameutils.
	@if [ -x /usr/libexec/imv/imv ]; then ln -sf /usr/libexec/imv/imv $(HOME)/.local/bin/imv; fi
	@# Asociación XDG de visores por defecto (PDF -> Zathura, Imágenes -> imv) si xdg-mime está presente.
	@if command -v xdg-mime >/dev/null 2>&1; then \
		xdg-mime default org.pwmt.zathura.desktop application/pdf 2>/dev/null || true; \
		xdg-mime default imv.desktop image/png image/jpeg image/webp image/gif image/bmp image/svg+xml 2>/dev/null || true; \
	fi
	chmod +x shell/devctl
	ln -sf $(ROOT_DIR)/shell/devctl $(HOME)/.local/bin/devctl
	@echo "devctl enlazado en ~/.local/bin/devctl"

# 4. Herramientas de Desarrollo y GitHub
devtools:
	@echo "==> Instalando DevManagers (gh, uv, fnm, sdkman, yazi)..."
	bash scripts/devtools.sh
	bash scripts/setup_gh.sh
	bash scripts/setup_git.sh

# Configuración explícita de identidad Git
gitconfig:
	@echo "==> Configurando identidad global de Git..."
	bash scripts/setup_git.sh

# Autenticación interactiva opcional directa con GitHub CLI
github-auth:
	@echo "==> Autenticación interactiva con GitHub CLI..."
	bash scripts/setup_gh.sh --auth

# 5. Navegadores y Editores Nativos
tooling:
	@echo "==> Instalando navegadores y editores nativos..."
	bash scripts/tooling.sh

# 6. Herramientas de IA
devai:
	@echo "==> Instalando herramientas de IA..."
	bash scripts/devai.sh

# 7. Entorno de Escritorio (GNOME)
desktop:
	@echo "==> Configurando escritorio GNOME..."
	bash scripts/desktop.sh

# 7b. Perfil opcional Hyprland (no reemplaza GNOME; solo Debian Stable)
hyprland:
	@echo "==> Configurando perfil opcional Hyprland..."
	bash scripts/hyprland.sh

# 8. Verificación de salud
verify:
	@echo "==> Verificando instalación..."
	bash scripts/verify.sh

# 9. Limpieza estándar
clean:
	@echo "==> Limpiando paquetes residuales..."
	@if sudo -n true 2>/dev/null; then \
		sudo apt-get autoremove --purge -y && sudo apt-get clean; \
	elif [ "$$EUID" -eq 0 ]; then \
		apt-get autoremove --purge -y && apt-get clean; \
	else \
		echo "  (Omitiendo apt-get autoremove: requiere elevación interactiva con sudo)"; \
	fi
	rm -rf $(HOME)/.oh-my-zsh.tmp 2>/dev/null || true

# 10. Limpieza profunda post-upgrade
clean-deep:
	@echo "==> Ejecutando limpieza profunda del sistema..."
	bash scripts/clean-system.sh
