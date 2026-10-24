# ==============================================================================
# Debian Workstation - Dev Environment Setup
# ==============================================================================

SHELL := /bin/bash

export RUNZSH=no
export CHSH=no

.PHONY: help install update host timeshift podman docker shell devtools tooling devai desktop verify clean clean-deep

# Target por defecto: mostrar ayuda
help:
	@echo "Opciones de aprovisionamiento (Debian Workstation):"
	@echo "  make install    - Aprovisiona la estación de trabajo completa (host + podman + shell + devtools + tooling + devai + desktop)"
	@echo "  make update     - Actualiza la estación (APT only-upgrade + self-updates user-space + flatpak, idempotente)"
	@echo "  make host       - Configura APT, Backports, FastTrack, paquetes base, CLI moderna, AppImage, Flatpak y Podman"
	@echo "  make timeshift  - (Opcional) Instala y configura Timeshift sin crear snapshots automáticos iniciales"
	@echo "  make podman     - Configura Podman en modo Rootless con backend pasta (systemd --user)"
	@echo "  make shell      - Configura Zsh, Oh My Zsh y enlaza dotfiles (.zshrc, .gitconfig, devctl)"
	@echo "  make devtools   - Instala gh, uv, fnm, sdkman y sincroniza SSH de GitHub"
	@echo "  make tooling    - Instala navegadores y editores nativos (VS Code, Chrome, Zed)"
	@echo "  make devai      - Instala OpenCode CLI, Antigravity CLI y Core/IDE"
	@echo "  make desktop    - Configura tipografías, botones de ventana, directorios de trabajo y extensiones GNOME"
	@echo "  make verify     - Ejecuta diagnóstico de salud del sistema"
	@echo "  make clean      - Limpia paquetes residuales de APT y temporales"
	@echo "  make clean-deep - Limpieza profunda post-upgrade: purga configs residuales (rc), dependencias, logs y cachés"

# Instalación completa desatendida (idempotente: re-ejecutable; Timeshift es opcional vía 'make timeshift')
install: host podman shell devtools tooling devai desktop clean
	@echo -e "\n✅ Instalación finalizada. Reinicia la sesión gráfica o terminal para aplicar todos los cambios."
	@echo -e "💡 Tip: Si deseas habilitar respaldos del sistema en este equipo, ejecuta: make timeshift"

# Actualización idempotente (no reconfigura SSH/gh auth, /opt, chsh ni registros)
update:
	@echo "==> Actualizando estación (APT only-upgrade + user-space)..."
	bash scripts/update.sh

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

# Alias retrocompatible
docker: podman

ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# 3. Shell y Dotfiles
shell:
	@echo "==> Configurando Zsh y Dotfiles..."
	bash scripts/ohmyzsh.sh
	mkdir -p $(HOME)/Proyectos $(HOME)/Aplicaciones
	ln -sf $(ROOT_DIR)/shell/zshrc $(HOME)/.zshrc
	ln -sf $(ROOT_DIR)/shell/gitconfig $(HOME)/.gitconfig
	mkdir -p $(HOME)/.local/bin
	chmod +x shell/devctl
	ln -sf $(ROOT_DIR)/shell/devctl $(HOME)/.local/bin/devctl
	@echo "devctl enlazado en ~/.local/bin/devctl"

# 4. Herramientas de Desarrollo y GitHub
devtools:
	@echo "==> Instalando DevManagers (gh, uv, fnm, sdkman)..."
	bash scripts/devtools.sh
	bash scripts/setup_gh.sh

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

# 10. Limpieza profunda post-upgrade / post-migración
clean-deep:
	@echo "==> Ejecutando limpieza profunda del sistema..."
	bash scripts/clean-system.sh
