#!/bin/bash
set -euo pipefail


LOG="$HOME/Install-Logs/install-$(date +%d-%H%M%S)_zsh.log"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1

# -----------------------------
# Utility functions
# -----------------------------
command_exists() {
    command -v "$1" &>/dev/null
}

install_package() {
    local pkg="$1"
    if ! pacman -Qi "$pkg" &>/dev/null; then
        echo "[INFO] Installing $pkg..."
        pacman -S --noconfirm --needed "$pkg"
    else
        echo "[INFO] $pkg is already installed. Skipping."
    fi
}

# -----------------------------
# Git & YAY setup
# -----------------------------
if ! command_exists git; then
    echo "[INFO] Git is not installed. Installing..."
    pacman -Sy --noconfirm git
fi

# -----------------------------
# Zsh + Oh My Zsh + plugins
# -----------------------------
zsh_pkg=(
    lsd
    mercurial
    zoxide
    zsh
    zsh-completions
)

zsh_pkg2=(
    fzf
    fd
    fastfetch
    neovim
    unzip
    fontconfig
    curl
)

# Use script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Source global functions
if ! source "$SCRIPT_DIR/Global_functions.sh"; then
    echo "[ERROR] Failed to source Global_functions.sh"
    exit 1
fi

# Install core Zsh packages
echo "[INFO] Installing Zsh packages..."
for pkg in "${zsh_pkg[@]}"; do
    install_package "$pkg"
done

# Clean any leftover zsh-completions folder
[ -d "zsh-completions" ] && rm -rf zsh-completions

# Install Oh My Zsh
if ! command_exists zsh; then
    echo "[ERROR] Zsh is not installed!"
    exit 1
fi

echo "[INFO] Installing Oh My Zsh..."
[ ! -d "$HOME/.oh-my-zsh" ] && sh -c "$(curl -fsSL https://install.ohmyz.sh)" "" --unattended

# Setup custom plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM/plugins"

for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    [ ! -d "$ZSH_CUSTOM/plugins/$plugin" ] && \
        git clone "https://github.com/zsh-users/$plugin" "$ZSH_CUSTOM/plugins/$plugin"
done

# Backup existing configs
for file in .zshrc .zshenv; do
    [ -f "$HOME/$file" ] && cp -b "$HOME/$file" "$HOME/${file}-backup"
done

echo "[INFO] Skipping chsh since root shell is always zsh in WSL."

# Install fzf and other packages
echo "[INFO] Installing additional packages..."
for pkg in "${zsh_pkg2[@]}"; do
    install_package "$pkg"
done

# -----------------------------
# Copy configs and folders
# -----------------------------
CONFIG_SRC="$SCRIPT_DIR/assets"
CONFIG_DEST="$HOME"

for file in zshrc zshenv p10k.zsh fzf.zsh zshrc.pre-oh-my-zsh; do
    src="$CONFIG_SRC/$file"
    dest="$CONFIG_DEST/.$file"
    [ -f "$src" ] && cp -f "$src" "$dest"
done

# Copy entire config folder if it exists
if [ -d "$SCRIPT_DIR/.config" ]; then
    mkdir -p "$HOME/.config"
    cp -rf "$SCRIPT_DIR/.config/." "$HOME/.config/"
fi

# Copy custom Oh My Zsh themes
THEME_SRC="$SCRIPT_DIR/assets/add_zsh_theme"
THEME_DEST="$HOME/.oh-my-zsh/themes"
[ -d "$THEME_SRC" ] && cp -rf "$THEME_SRC/." "$THEME_DEST/"

# -----------------------------
# Neovim configuration
# -----------------------------
echo "[INFO] Cloning Neovim configuration..."
NVIM_DEST="$HOME/.config/nvim"
if [ -d "$NVIM_DEST/.git" ]; then
    git -C "$NVIM_DEST" pull
else
    rm -rf "$NVIM_DEST"
    git clone https://github.com/G00380316/nvim.git "$NVIM_DEST"
fi

# -----------------------------
# Fonts, directories, and utilities
# -----------------------------
dircolors -p > "$HOME/.dircolors"
mkdir -p "$HOME/Github/Projects"

# JetBrains Mono Nerd Font installation
if ! fc-list | grep -i "JetBrainsMono Nerd Font" &>/dev/null; then
    FONT_ZIP="JetBrainsMono.zip"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    curl -LO "$FONT_URL"
    unzip "$FONT_ZIP" -d JetBrainsMono
    mkdir -p "$HOME/.local/share/fonts"
    mv JetBrainsMono/* "$HOME/.local/share/fonts/"
    rm -rf JetBrainsMono "$FONT_ZIP"
    fc-cache -fv
fi

# -----------------------------
# Development tools
# -----------------------------
dev_packages=(
    php lua zoxide neovim
    cmake github-cli lazygit gcc jdk-openjdk ruby
    dotnet-runtime aspnet-runtime dotnet-sdk jdk8-openjdk jdk17-openjdk
    reaper parallel
)

echo "[INFO] Installing development tools..."
for pkg in "${dev_packages[@]}"; do
    install_package "$pkg"
done

# Set JAVA_HOME
echo 'export JAVA_HOME=/usr/lib/jvm/java-8-openjdk' >> "$HOME/.zshrc"
echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> "$HOME/.zshrc"

# -----------------------------
# Python via pyenv
# -----------------------------
if [ ! -d "$HOME/.pyenv" ]; then
    echo "[INFO] Installing pyenv..."
    curl https://pyenv.run | zsh
    echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> "$HOME/.zshrc"
    echo 'eval "$(pyenv init --path)"' >> "$HOME/.zshrc"
    echo 'eval "$(pyenv init -)"' >> "$HOME/.zshrc"
    zsh -i -c "pyenv install 3.11.4 && pyenv global 3.11.4"
    python -m venv "$HOME/venv"
    source "$HOME/venv/bin/activate"
    pip install hyfetch
fi

# -----------------------------
# Node via nvm
# -----------------------------
if [ ! -d "$HOME/.nvm" ]; then
    echo "[INFO] Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | zsh
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"
    nvm install node
    nvm use node
fi

# -----------------------------
# Go
# -----------------------------
if ! command_exists go; then
    GO_VER="1.20.5"
    GO_TARBALL="go${GO_VER}.linux-amd64.tar.gz"
    wget "https://golang.org/dl/${GO_TARBALL}"
    tar -C /usr/local -xzf "$GO_TARBALL"
    rm -f "$GO_TARBALL"
    echo 'export PATH=$PATH:/usr/local/go/bin' >> "$HOME/.zshrc"
fi

# -----------------------------
# Rust
# -----------------------------
if ! command_exists cargo; then
    echo "[INFO] Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    rustup update
fi

# -----------------------------
# Set default shell for root
# -----------------------------
chsh -s /bin/zsh root

echo "[INFO] Zsh setup complete."
