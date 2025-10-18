#!/usr/bin/env bash

# Common functions and variables for installation scripts

# Function to install packages from a given file
install_packages() {
    local package_file="$1"
    if [[ -f "$package_file" ]]; then
        while IFS= read -r package; do
            if [[ -n "$package" ]]; then
                sudo pacman -S --noconfirm "$package" || sudo apt install -y "$package"
            fi
        done < "$package_file"
    else
        echo "Package file not found: $package_file"
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create directories if they do not exist
create_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
}