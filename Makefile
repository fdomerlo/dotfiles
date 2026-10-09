# ==============================================================================
# Debian Trixie Workstation - Dev Environment Setup
# ==============================================================================

SHELL := /bin/bash

export RUNZSH=no
export CHSH=no

.PHONY: help install host docker shell devtools tooling devai desktop fonts verify clean

# Target por defecto: mostrar ayuda
help:
	@echo "Opciones de aprovisionamiento (Debian Trixie):"
	@echo "  make install   - Aprovisiona la estación de trabajo completa (host + docker + shell + devtools + tooling + devai + desktop + fonts)"
	@echo "  make host      - Actualiza APT e instala paquetes base del sistema y dependencias de Docker"
	@echo "  make docker    - Configura Docker Engine en modo Rootless (systemd --user)"
	@echo "  make shell     - Configura Zsh, Oh My Zsh y enlaza dotfiles (.zshrc, .gitconfig, devctl)"
	@echo "  make devtools  - Instala gh, uv, fnm, sdkman y sincroniza SSH de GitHub"
	@echo "  make tooling   - Instala navegadores y editores nativos (VS Code, Chrome, Zed)"
	@echo "  make devai     - Instala OpenCode CLI, Antigravity CLI y Core/IDE"
	@echo "  make desktop   - Configura tipografías y extensiones de GNOME Shell"
	@echo "  make fonts     - Despliega tipografías locales (Google Sans, Google Sans Code)"
	@echo "  make verify    - Ejecuta diagnóstico de salud del sistema"
	@echo "  make clean     - Limpia paquetes residuales de APT y temporales"

# Instalación completa desatendida
install: host docker shell devtools tooling devai desktop fonts clean
	@echo -e "\n✅ Instalación finalizada. Reinicia la sesión gráfica o terminal para aplicar todos los cambios."

# 1. Host (requiere sudo)
host:
	@echo "==> Configurando Host (Debian Trixie)..."
	sudo bash host/setup.sh

# 2. Docker Rootless (se ejecuta como usuario normal)
docker:
	@echo "==> Configurando Docker Rootless..."
	bash host/docker_rootless.sh

ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# 3. Shell y Dotfiles
shell:
	@echo "==> Configurando Zsh y Dotfiles..."
	bash scripts/ohmyzsh.sh
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

# 7. Tipografías locales
fonts:
	@echo "==> Desplegando tipografías..."
	bash scripts/fonts.sh

# 8. Entorno de Escritorio (GNOME)
desktop: fonts
	@echo "==> Configurando escritorio GNOME..."
	bash scripts/desktop.sh
	bash scripts/timeshift.sh

# 9. Verificación de salud
verify:
	@echo "==> Verificando instalación..."
	bash scripts/verify.sh

# 10. Limpieza
clean:
	@echo "==> Limpiando paquetes residuales..."
	sudo apt-get autoremove -y
	sudo apt-get clean
	rm -rf $(HOME)/.oh-my-zsh.tmp 2>/dev/null || true
