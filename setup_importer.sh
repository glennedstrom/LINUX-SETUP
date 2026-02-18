#!/bin/bash

# Setup Importer Script
# This script checks for and installs various tools and configurations
# Optimized for Arch Linux but with fallback support for Debian/Ubuntu

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if a directory exists
directory_exists() {
    [ -d "$1" ]
}

# Check if a package is installed (Arch)
package_installed_arch() {
    pacman -Q "$1" &>/dev/null
}

# Check if a package group is installed (Arch)
package_group_installed_arch() {
    pacman -Qg "$1" &>/dev/null
}

# Install package using the appropriate package manager
install_package() {
    local package=$1
    local apt_package=${2:-$1}  # Use second arg if provided, otherwise use same name
    
    if command_exists pacman; then
        if package_installed_arch "$package"; then
            return 0  # Already installed, skip
        fi
        print_info "Installing $package via pacman..."
        sudo pacman -S --noconfirm "$package"
    elif command_exists apt-get; then
        print_info "Installing $apt_package via apt..."
        sudo apt-get update && sudo apt-get install -y "$apt_package"
    elif command_exists apt; then
        print_info "Installing $apt_package via apt..."
        sudo apt update && sudo apt install -y "$apt_package"
    else
        print_error "No supported package manager found. Please install $package manually."
        return 1
    fi
}

# Main setup function
main() {
    echo "========================================"
    echo "   Arch Setup Importer Starting"
    echo "========================================"
    echo ""
    
    # Detect OS
    if command_exists pacman; then
        print_info "Detected: Arch Linux (pacman)"
    elif command_exists apt-get || command_exists apt; then
        print_info "Detected: Debian/Ubuntu (apt)"
    else
        print_warning "Unknown package manager - limited support"
    fi
    echo ""

    # ============================
    # Core System Tools
    # ============================
    
    # Check for git
    if ! command_exists git; then
        print_warning "Git not found. Installing git..."
        install_package "git" "git"
        print_status "Git installed successfully"
    else
        print_status "Git already installed"
    fi

    # Check for base-devel (Arch) or build-essential (Debian)
    if command_exists pacman; then
        # Check if key base-devel packages are installed (autoconf, automake, binutils, etc.)
        # If make and gcc are installed, base-devel is essentially there
        if pacman -Q make &>/dev/null && pacman -Q gcc &>/dev/null && pacman -Q autoconf &>/dev/null; then
            print_status "base-devel packages already installed"
        else
            print_warning "base-devel not found. Installing..."
            sudo pacman -S --noconfirm --needed base-devel
            print_status "base-devel installed"
        fi
    elif command_exists apt-get; then
        if ! dpkg -l | grep -q build-essential; then
            print_warning "build-essential not found. Installing..."
            sudo apt-get update && sudo apt-get install -y build-essential
            print_status "build-essential installed"
        else
            print_status "build-essential already installed"
        fi
    fi

    # Check for g++
    if ! command_exists g++; then
        print_warning "g++ not found. Installing..."
        if command_exists pacman; then
            install_package "gcc" "g++"
        else
            install_package "g++" "g++"
        fi
        print_status "g++ installed successfully"
    else
        print_status "g++ already installed"
    fi

    # Check for make
    if ! command_exists make; then
        print_warning "make not found. Installing..."
        install_package "make" "make"
        print_status "make installed successfully"
    else
        print_status "make already installed"
    fi

    # Check for cmake
    if ! command_exists cmake; then
        print_warning "cmake not found. Installing..."
        install_package "cmake" "cmake"
        print_status "cmake installed successfully"
    else
        print_status "cmake already installed"
    fi

    # ============================
    # AUR Helper (yay) - Arch only
    # ============================
    
    if command_exists pacman; then
        if ! command_exists yay; then
            print_warning "yay not found. Installing yay..."
            
            # Create temp directory for building yay
            TEMP_DIR=$(mktemp -d)
            cd "$TEMP_DIR"
            
            git clone https://aur.archlinux.org/yay.git
            cd yay
            makepkg -si --noconfirm
            
            # Cleanup
            cd ~
            rm -rf "$TEMP_DIR"
            
            print_status "yay installed successfully"
        else
            print_status "yay already installed"
        fi
    fi

    # ============================
    # Browsers
    # ============================
    
    # Check for Brave browser
    if ! command_exists brave; then
        print_warning "Brave browser not found. Installing..."
        
        if command_exists yay; then
            print_info "Installing Brave via yay..."
            yay -S --noconfirm brave-bin
            print_status "Brave installed successfully"
        elif command_exists pacman; then
            print_error "yay not available. Cannot install Brave from AUR."
            print_info "You can install yay first or install Brave manually."
        elif command_exists apt-get; then
            print_info "Installing Brave via apt..."
            sudo apt-get update
            sudo apt-get install -y curl
            sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
            sudo apt-get update
            sudo apt-get install -y brave-browser
            print_status "Brave installed successfully"
        fi
    else
        print_status "Brave browser already installed"
    fi

    # ============================
    # Development Tools
    # ============================
    
    # Check for neovim
    if ! command_exists nvim; then
        print_warning "Neovim not found. Installing..."
        install_package "neovim" "neovim"
        print_status "Neovim installed successfully"
    else
        print_status "Neovim already installed"
    fi

    # Check for nvim config directory
    NVIM_CONFIG_DIR="$HOME/.config/nvim"
    if ! directory_exists "$NVIM_CONFIG_DIR"; then
        print_warning "Neovim config not found. Cloning custom kickstart config..."
        mkdir -p "$HOME/.config"
        git clone https://github.com/glennedstrom/kickstart.nvim.git "$NVIM_CONFIG_DIR"
        print_status "Neovim kickstart config installed"
    else
        print_status "Neovim config already exists"
    fi

    # Check for curl
    if ! command_exists curl; then
        print_warning "curl not found. Installing..."
        install_package "curl" "curl"
        print_status "curl installed successfully"
    else
        print_status "curl already installed"
    fi

    # Check for wget
    if ! command_exists wget; then
        print_warning "wget not found. Installing..."
        install_package "wget" "wget"
        print_status "wget installed successfully"
    else
        print_status "wget already installed"
    fi

    # Check for GitHub CLI
    if ! command_exists gh; then
        print_warning "GitHub CLI (gh) not found. Installing..."
        install_package "github-cli" "gh"
        print_status "GitHub CLI installed successfully"
    else
        print_status "GitHub CLI already installed"
    fi

    # Check for unzip
    if ! command_exists unzip; then
        print_warning "unzip not found. Installing..."
        install_package "unzip" "unzip"
        print_status "unzip installed successfully"
    else
        print_status "unzip already installed"
    fi

    # Check for tar
    if ! command_exists tar; then
        print_warning "tar not found. Installing..."
        install_package "tar" "tar"
        print_status "tar installed successfully"
    else
        print_status "tar already installed"
    fi

    # ============================
    # Programming Languages
    # ============================
    
    # Check for Python
    if ! command_exists python3; then
        print_warning "Python 3 not found. Installing..."
        install_package "python" "python3"
        print_status "Python 3 installed successfully"
    else
        print_status "Python 3 already installed"
    fi

    # Check for pip
    if ! command_exists pip3; then
        print_warning "pip3 not found. Installing..."
        if command_exists pacman; then
            install_package "python-pip" "python3-pip"
        else
            install_package "python3-pip" "python3-pip"
        fi
        print_status "pip3 installed successfully"
    else
        print_status "pip3 already installed"
    fi

    # Check for uv (fast Python package installer)
    if ! command_exists uv; then
        print_warning "uv not found. Installing..."
        print_info "Installing uv via curl..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        print_status "uv installed successfully"
        print_info "Note: You may need to restart your shell or run 'source ~/.bashrc' to use uv"
    else
        print_status "uv already installed"
    fi

    # Check for Node.js
    if ! command_exists node; then
        print_warning "Node.js not found. Installing..."
        install_package "nodejs" "nodejs"
        print_status "Node.js installed successfully"
    else
        print_status "Node.js already installed"
    fi

    # Check for npm
    if ! command_exists npm; then
        print_warning "npm not found. Installing..."
        install_package "npm" "npm"
        print_status "npm installed successfully"
    else
        print_status "npm already installed"
    fi

    # Check for markdownlint-cli (global npm package)
    if ! command_exists markdownlint; then
        print_warning "markdownlint-cli not found. Installing globally via npm..."
        npm install -g markdownlint-cli
        print_status "markdownlint-cli installed successfully"
    else
        print_status "markdownlint-cli already installed"
    fi

    # ============================
    # Version Control & Utilities
    # ============================
    
    # Check for ripgrep
    if ! command_exists rg; then
        print_warning "ripgrep not found. Installing..."
        install_package "ripgrep" "ripgrep"
        print_status "ripgrep installed successfully"
    else
        print_status "ripgrep already installed"
    fi

    # Check for fd
    if ! command_exists fd; then
        print_warning "fd not found. Installing..."
        install_package "fd" "fd-find"
        print_status "fd installed successfully"
    else
        print_status "fd already installed"
    fi

    # Check for bat
    if ! command_exists bat; then
        print_warning "bat not found. Installing..."
        install_package "bat" "bat"
        print_status "bat installed successfully"
    else
        print_status "bat already installed"
    fi

    # Check for tree
    if ! command_exists tree; then
        print_warning "tree not found. Installing..."
        install_package "tree" "tree"
        print_status "tree installed successfully"
    else
        print_status "tree already installed"
    fi

    # Check for gdb
    if ! command_exists gdb; then
        print_warning "gdb not found. Installing..."
        install_package "gdb" "gdb"
        print_status "gdb installed successfully"
    else
        print_status "gdb already installed"
    fi

    # Check for valgrind
    if ! command_exists valgrind; then
        print_warning "valgrind not found. Installing..."
        install_package "valgrind" "valgrind"
        print_status "valgrind installed successfully"
    else
        print_status "valgrind already installed"
    fi

    # Check for rsync
    if ! command_exists rsync; then
        print_warning "rsync not found. Installing..."
        install_package "rsync" "rsync"
        print_status "rsync installed successfully"
    else
        print_status "rsync already installed"
    fi

    # Check for lazygit
    if ! command_exists lazygit; then
        print_warning "lazygit not found. Installing..."
        if command_exists yay; then
            print_info "Installing lazygit via yay..."
            yay -S --noconfirm lazygit
            print_status "lazygit installed successfully"
        elif command_exists pacman; then
            # Try community repo first
            install_package "lazygit" "lazygit"
            print_status "lazygit installed successfully"
        elif command_exists apt-get; then
            # For Ubuntu/Debian, use PPA or direct binary
            print_info "Installing lazygit via binary..."
            LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
            curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
            tar xf lazygit.tar.gz lazygit
            sudo install lazygit /usr/local/bin
            rm lazygit lazygit.tar.gz
            print_status "lazygit installed successfully"
        fi
    else
        print_status "lazygit already installed"
    fi

    # Check for delta (git-delta)
    if ! command_exists delta; then
        print_warning "git-delta not found. Installing..."
        if command_exists pacman; then
            install_package "git-delta" "git-delta"
            print_status "git-delta installed successfully"
        elif command_exists apt-get; then
            print_info "Installing git-delta via binary..."
            DELTA_VERSION=$(curl -s "https://api.github.com/repos/dandavison/delta/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
            curl -Lo delta.deb "https://github.com/dandavison/delta/releases/latest/download/git-delta_${DELTA_VERSION}_amd64.deb"
            sudo dpkg -i delta.deb
            rm delta.deb
            print_status "git-delta installed successfully"
        fi
        
        # Configure delta for git
        print_info "Configuring git to use delta..."
        git config --global core.pager delta
        git config --global interactive.diffFilter "delta --color-only"
        git config --global delta.navigate true
        git config --global delta.side-by-side true
        git config --global merge.conflictstyle diff3
        git config --global diff.colorMoved default
        print_status "git configured to use delta"
    else
        print_status "git-delta already installed"
    fi

    # Check for xclip
    if ! command_exists xclip; then
        print_warning "xclip not found. Installing..."
        install_package "xclip" "xclip"
        print_status "xclip installed successfully"
    else
        print_status "xclip already installed"
    fi

    # Check for less
    if ! command_exists less; then
        print_warning "less not found. Installing..."
        install_package "less" "less"
        print_status "less installed successfully"
    else
        print_status "less already installed"
    fi

    # Check for tldr
    if ! command_exists tldr; then
        print_warning "tldr not found. Installing..."
        install_package "tldr" "tldr"
        print_status "tldr installed successfully"
        
        # Update tldr cache to ensure it has content
        print_info "Updating tldr cache (this may take a moment)..."
        tldr --update > /dev/null 2>&1 || true
        print_status "tldr cache updated"
    else
        print_status "tldr already installed"
        # Check if cache exists, if not update it
        if [ ! -d "$HOME/.local/share/tldr" ] && [ ! -d "$HOME/.cache/tldr" ]; then
            print_warning "tldr cache not found. Updating..."
            tldr --update > /dev/null 2>&1 || true
            print_status "tldr cache updated"
        fi
    fi

    # ============================
    # Fonts (Nerd Fonts)
    # ============================
    
    # Check for Nerd Fonts - we'll install a popular one (JetBrainsMono)
    NERD_FONT_DIR="$HOME/.local/share/fonts"
    NERD_FONT_INSTALLED="$NERD_FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf"
    
    if [ ! -f "$NERD_FONT_INSTALLED" ]; then
        print_warning "Nerd Font not found. Installing JetBrainsMono Nerd Font..."
        
        # Create fonts directory if it doesn't exist
        mkdir -p "$NERD_FONT_DIR"
        
        # Download and install JetBrainsMono Nerd Font
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        
        print_info "Downloading JetBrainsMono Nerd Font..."
        curl -fLo "JetBrainsMono.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
        
        print_info "Extracting font files..."
        unzip -q JetBrainsMono.zip -d JetBrainsMono
        
        print_info "Installing fonts..."
        cp JetBrainsMono/*.ttf "$NERD_FONT_DIR/"
        
        # Update font cache
        fc-cache -fv > /dev/null 2>&1
        
        # Cleanup
        cd ~
        rm -rf "$TEMP_DIR"
        
        print_status "JetBrainsMono Nerd Font installed successfully"
        print_info "Note: You may need to change your terminal font to 'JetBrainsMono Nerd Font' in your terminal settings"
    else
        print_status "Nerd Font already installed"
    fi

    # ============================
    # System Fonts (for browsers and applications)
    # ============================
    
    print_info "Checking system fonts..."
    
    FONTS_TO_INSTALL=()
    
    # Check each font package
    if command_exists pacman; then
        ! package_installed_arch "ttf-liberation" && FONTS_TO_INSTALL+=("ttf-liberation")
        ! package_installed_arch "noto-fonts" && FONTS_TO_INSTALL+=("noto-fonts")
        ! package_installed_arch "noto-fonts-emoji" && FONTS_TO_INSTALL+=("noto-fonts-emoji")
        ! package_installed_arch "ttf-roboto" && FONTS_TO_INSTALL+=("ttf-roboto")
    elif command_exists apt-get; then
        ! dpkg -l | grep -q fonts-liberation && FONTS_TO_INSTALL+=("fonts-liberation")
        ! dpkg -l | grep -q fonts-noto && FONTS_TO_INSTALL+=("fonts-noto")
        ! dpkg -l | grep -q fonts-noto-color-emoji && FONTS_TO_INSTALL+=("fonts-noto-color-emoji")
        ! dpkg -l | grep -q fonts-roboto && FONTS_TO_INSTALL+=("fonts-roboto")
    fi
    
    if [ ${#FONTS_TO_INSTALL[@]} -gt 0 ]; then
        print_warning "Installing missing system fonts: ${FONTS_TO_INSTALL[*]}"
        if command_exists pacman; then
            sudo pacman -S --noconfirm --needed "${FONTS_TO_INSTALL[@]}"
        elif command_exists apt-get; then
            sudo apt-get update && sudo apt-get install -y "${FONTS_TO_INSTALL[@]}"
        fi
        print_status "System fonts installed"
        
        # Update font cache
        print_info "Updating font cache..."
        fc-cache -fv > /dev/null 2>&1
        print_status "Font cache updated"
    else
        print_status "All system fonts already installed"
    fi

    # ============================
    # Bashrc Customizations
    # ============================
    
    CUSTOM_BASHRC="$HOME/.bashrc_custom"
    BASHRC="$HOME/.bashrc"
    SOURCE_LINE='[ -f "$HOME/.bashrc_custom" ] && source "$HOME/.bashrc_custom"'
    
    # Define the desired content for .bashrc_custom
    BASHRC_CUSTOM_CONTENT='# Custom Bashrc Configuration
# This file is sourced by ~/.bashrc
# Add your custom aliases, functions, and environment variables here

# Neovim alias
alias nv="nvim"

# Example aliases
# alias ll="ls -alh"
# alias gs="git status"
# alias gp="git pull"

# Example functions
# mcd() {
#     mkdir -p "$1" && cd "$1"
# }

# Example environment variables
# export EDITOR=nvim
'
    
    # Calculate checksum of desired content
    DESIRED_CHECKSUM=$(echo "$BASHRC_CUSTOM_CONTENT" | sha256sum | awk '{print $1}')
    
    if [ ! -f "$CUSTOM_BASHRC" ]; then
        print_warning "Custom bashrc file not found. Creating ~/.bashrc_custom..."
        echo "$BASHRC_CUSTOM_CONTENT" > "$CUSTOM_BASHRC"
        print_status "Created ~/.bashrc_custom"
    else
        # File exists, check if content matches
        CURRENT_CHECKSUM=$(sha256sum "$CUSTOM_BASHRC" | awk '{print $1}')
        
        if [ "$CURRENT_CHECKSUM" = "$DESIRED_CHECKSUM" ]; then
            print_status "~/.bashrc_custom already exists with correct content"
        else
            print_warning "~/.bashrc_custom exists but content differs. Updating..."
            echo "$BASHRC_CUSTOM_CONTENT" > "$CUSTOM_BASHRC"
            print_status "Updated ~/.bashrc_custom"
        fi
    fi
    
    # Handle the source line in .bashrc
    if [ -f "$BASHRC" ]; then
        if ! grep -qF "$SOURCE_LINE" "$BASHRC"; then
            print_info "Adding source line to ~/.bashrc..."
            echo "" >> "$BASHRC"
            echo "# Source custom bashrc configurations" >> "$BASHRC"
            echo "$SOURCE_LINE" >> "$BASHRC"
            print_status "Added source line to ~/.bashrc"
        else
            print_status "Source line already exists in ~/.bashrc"
        fi
    else
        print_warning "~/.bashrc not found. Creating it..."
        echo "$SOURCE_LINE" > "$BASHRC"
        print_status "Created ~/.bashrc with source line"
    fi

    echo ""
    echo "========================================"
    echo "   Setup Complete!"
    echo "========================================"
    echo ""
    print_info "All requested packages have been checked and installed if needed."
    print_info "Custom bash configuration available at: ~/.bashrc_custom"
    
    if command_exists pacman && command_exists yay; then
        echo ""
        print_info "You can now use 'yay' to install AUR packages!"
    fi
    
    echo ""
    print_warning "Note: Run 'source ~/.bashrc' or restart your terminal to load bash customizations."
}

# Run main function
main
