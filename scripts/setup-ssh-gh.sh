#!/bin/bash

# Detener el script si ocurre un error
# Iniciar sesion con: gh auth login
# Crear una clave publica con: gh auth refresh -h github.com -s admin:public_key
set -e

echo "=== Configuración SSH Automatizada con GitHub CLI ==="
echo ""

# 1. Validar el estado de autenticación de GitHub CLI
if ! gh auth status &>/dev/null; then
    echo "⚠️ Error: GitHub CLI no está autenticado."
    echo "Ejecuta 'gh auth login' una vez en tu terminal para autorizar esta máquina antes de correr el script."
    exit 1
fi

# 2. Solicitar variables iniciales
read -p "Introduce tu correo asociado a GitHub: " user_email
read -p "Introduce un nombre para identificar esta computadora en GitHub (ej. Servidor-Radix): " key_title

key_path="$HOME/.ssh/id_ed25519"

# 3. Generar la clave SSH
if [ -f "$key_path" ]; then
    echo "⚠️ Ya existe una clave SSH en $key_path. Se omitirá la generación."
else
    echo "Generando clave SSH de forma silenciosa..."
    # Se genera sin contraseña (-N "") para asegurar la automatización total sin pausas
    ssh-keygen -t ed25519 -C "$user_email" -f "$key_path" -N "" >/dev/null 2>&1
    echo "Clave generada con éxito."
fi

# 4. Iniciar el agente y añadir la clave
echo "Configurando ssh-agent..."
eval "$(ssh-agent -s)" >/dev/null
ssh-add "$key_path" 2>/dev/null

# 5. Subir la clave a GitHub automáticamente mediante la API del CLI
echo "Subiendo la clave pública a tu cuenta de GitHub..."
gh ssh-key add "${key_path}.pub" --title "$key_title" --type authentication

# 6. Probar la conexión SSH
echo "Probando la conexión con los servidores de GitHub..."
set +e
ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"
test_result=$?
set -e

# 7. Configurar usuario de git
echo "Configurando usuario de git..."
git config --global user.email "$user_email"
git config --global user.name "$USER"

echo ""
if [ $test_result -eq 0 ]; then
    echo "=== ¡Proceso Finalizado con Éxito! ==="
    echo "Tu equipo está autorizado. Ya puedes clonar y hacer push sin contraseñas."
else
    echo "⚠️ Hubo un problema al verificar la conexión SSH. Revisa tu configuración de red o firewall."
fi
