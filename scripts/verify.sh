#!/usr/bin/env bash

set -euo pipefail

echo "====================================="
echo "  Post-Installation Health Check"
echo "====================================="

check_status() {
    if [ "$1" -eq 0 ]; then
        echo -e "[ \033[32mOK\033[0m ] $2"
    else
        echo -e "[ \033[31mFAIL\033[0m ] $2"
    fi
}

# 1. Kernel and amdgpu module load
echo -n "Checking amdgpu kernel module... "
if lsmod | grep -q "^amdgpu"; then
    check_status 0 "amdgpu is loaded"
else
    check_status 1 "amdgpu is NOT loaded"
fi

# 2. zRAM status
echo -n "Checking zRAM status... "
if grep -q "zram" /proc/swaps || command -v zramctl >/dev/null 2>&1 && zramctl >/dev/null 2>&1; then
    check_status 0 "zRAM is active"
else
    check_status 1 "zRAM is NOT active"
fi

# 3. Font installation recognition
echo -n "Checking font installation (Fira)... "
if fc-list : family | grep -iq "Fira"; then
    check_status 0 "Fira fonts are installed and recognized"
else
    check_status 1 "Fira fonts are NOT recognized"
fi

# 4. Dotfile symlink integrity
echo -n "Checking dotfile symlinks... "
all_linked=0
for f in .zshrc .gitconfig .functions.sh; do
    if [ ! -L "$HOME/$f" ]; then
        all_linked=1
        echo -e "\n  -> Missing symlink: $HOME/$f"
    fi
done
if [ $all_linked -eq 0 ]; then
    check_status 0 "Core dotfiles are symlinked correctly"
else
    check_status 1 "Some dotfiles are missing or not symlinked"
fi

# 5. mise execution and path availability
echo -n "Checking mise availability... "
export PATH="$HOME/.local/bin:$PATH"
if command -v mise >/dev/null 2>&1; then
    check_status 0 "mise is installed and executable"
    echo "  -> mise version: $(mise --version)"
else
    check_status 1 "mise is NOT found in PATH"
fi

echo "====================================="
echo "Health check complete."
