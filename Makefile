# ==============================================================================
# Debian Stable Workstation - Dev Environment Setup
# ==============================================================================

SHELL := /bin/bash

export RUNZSH=no
export CHSH=no
export KEEP_ZSHRC=yes
export PATH := $(HOME)/.local/bin:$(PATH)

.PHONY: help install base-install full-install update refresh host timeshift podman shell devtools tooling devai virt desktop hyprland hypr-desktop hypr-laptop verify clean clean-deep gitconfig github-auth

# Target por defecto: mostrar ayuda
help:
	@echo "Opciones de aprovisionamiento (Debian Stable Workstation):"
	@echo "  make install         - Aprovisionamiento completo con Hyprland (GNOME estándar como fallback)"
	@echo "  make full-install    - Igual que 'make install' más configuración de snapshots Timeshift"
	@echo "  make base-install    - Estación base sin Hyprland (host + podman + shell + devtools + tooling + devai + GNOME estándar)"
	@echo "  make update          - Actualiza la estación (APT only-upgrade incl. perfil Hyprland + self-updates + flatpak)"
	@echo "  make refresh         - Re-sincroniza configs/scripts de Hyprland desde el repo y recarga la sesión (tras git pull)"
	@echo "  make host            - Configura APT (Backports), CLI moderna, AppImage, Flatpak y Podman"
	@echo "  make podman          - Configura Podman en modo Rootless con backend pasta (systemd --user)"
	@echo "  make shell           - Configura Zsh, Oh My Zsh y enlaza dotfiles (.zshrc, .gitconfig, devctl, btop, yazi, nvim, zathura, lazydocker)"
	@echo "  make devtools        - Instala gh, uv, fnm, sdkman, yazi, lazydocker y sincroniza SSH de GitHub"
	@echo "  make tooling         - Instala navegadores, editores y suite sysadmin/productividad (Firefox default, Chrome para PWAs, LibreOffice, VS Code, Zed, Neovim, Remmina, Wireshark, DBeaver, Bruno, Obsidian, Super Productivity)"
	@echo "  make devai           - Instala OpenCode CLI, Antigravity CLI y Core/IDE"
	@echo "  make virt            - (Opcional) Instala Quickemu + QEMU/KVM para VMs sin daemon"
	@echo "  make desktop         - Mantiene GNOME Shell estándar (sin extensiones/extras) y directorios de trabajo"
	@echo "  make timeshift       - (Opcional) Instala y configura Timeshift sin crear snapshots automáticos iniciales"
	@echo "  make hyprland        - Instala y configura el escritorio Hyprland (mantiene GNOME como fallback)"
	@echo "  make hypr-desktop    - Aplica plantilla local de estación desktop en ~/.config/hypr/conf/local.conf (con backup)"
	@echo "  make hypr-laptop     - Aplica plantilla local de estación notebook en ~/.config/hypr/conf/local.conf (con backup)"
	@echo "  make verify          - Ejecuta diagnóstico de salud del sistema"
	@echo "  make clean           - Limpia paquetes residuales de APT y temporales"
	@echo "  make clean-deep      - Limpieza profunda post-upgrade: purga configs residuales (rc), dependencias, logs y cachés"

# Instalación completa con Hyprland como escritorio principal y GNOME estándar como fallback
install: host podman shell devtools tooling devai desktop hyprland clean
	@echo -e "\n✅ Instalación finalizada (Hyprland + GNOME fallback). Reinicia la sesión o elige Hyprland en GDM."
	@echo -e "💡 Tip: Para habilitar respaldos del sistema, ejecuta: make timeshift (o usa 'make full-install')."

# Estación base sin Hyprland (solo GNOME estándar + CLI/Tooling/Podman)
base-install: host podman shell devtools tooling devai desktop clean
	@echo -e "\n✅ Instalación base finalizada. Reinicia la sesión gráfica o terminal para aplicar todos los cambios."
	@echo -e "💡 Tip: Para sumar Hyprland luego: make hyprland | Para respaldos: make timeshift"

# Instalación completa con Hyprland + Timeshift
full-install: host podman shell devtools tooling devai desktop timeshift hyprland clean
	@echo -e "\n✅ Instalación completa finalizada (Hyprland + Timeshift + GNOME fallback). Elige Hyprland en GDM."

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
	mkdir -p $(HOME)/Proyectos $(HOME)/Aplicaciones $(HOME)/.config/git
	@# Si ~/.gitconfig es un archivo previo (no symlink al repo), migrar identidad y respaldar antes de enlazar.
	@if [ -e $(HOME)/.gitconfig ] && [ ! -L $(HOME)/.gitconfig ]; then \
		if [ ! -f $(HOME)/.config/git/local.gitconfig ]; then \
			cur_name="$$(git config --file $(HOME)/.gitconfig --get user.name 2>/dev/null || true)"; \
			cur_email="$$(git config --file $(HOME)/.gitconfig --get user.email 2>/dev/null || true)"; \
			[ -n "$$cur_name" ] && git config --file $(HOME)/.config/git/local.gitconfig user.name "$$cur_name"; \
			[ -n "$$cur_email" ] && git config --file $(HOME)/.config/git/local.gitconfig user.email "$$cur_email"; \
		fi; \
		[ -f $(HOME)/.gitconfig.pre-dotfiles ] || mv $(HOME)/.gitconfig $(HOME)/.gitconfig.pre-dotfiles; \
	fi
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
	ln -sf $(ROOT_DIR)/shell/yazi/init.lua $(HOME)/.config/yazi/init.lua
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

# 6b. Virtualización opcional (Quickemu + QEMU/KVM, sin daemon ni autostart)
virt:
	@echo "==> Configurando virtualización opcional (Quickemu)..."
	bash scripts/virt.sh

# 7. Entorno de Escritorio (GNOME fallback estándar)
desktop:
	@echo "==> Manteniendo escritorio GNOME estándar y directorios de trabajo..."
	bash scripts/desktop.sh

# 7b. Escritorio principal Hyprland (mantiene GNOME estándar como fallback; solo Debian Stable)
hyprland:
	@echo "==> Configurando escritorio Hyprland..."
	bash scripts/hyprland.sh

# 7c. Perfiles locales de estación (no versionados; generan respaldo previo)
hypr-desktop:
	@echo "==> Aplicando perfil local de estación desktop..."
	bash hypr/scripts/station-profile.sh apply desktop --force

hypr-laptop:
	@echo "==> Aplicando perfil local de estación notebook..."
	bash hypr/scripts/station-profile.sh apply laptop --force

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
