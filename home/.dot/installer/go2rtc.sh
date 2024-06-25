#!/bin/bash

# Installer script for go2rtc

# Function to fetch the latest release version from GitHub
fetch_latest_release_version() {
    # Uses GitHub API to fetch the latest release tag
    curl -s "https://api.github.com/repos/AlexxIT/go2rtc/releases/latest" |
    grep '"tag_name":' |
    sed -E 's/.*"([^"]+)".*/\1/'
}

# Determine the platform release based on the architecture
determine_platform_release() {
    local arch=$(uname -m)  # get machine architecture
    case "$arch" in
        x86_64) echo "go2rtc_linux_amd64" ;;
        aarch64) echo "go2rtc_linux_arm64" ;;
        *) echo "Unsupported architecture: $arch" && exit 1 ;;
    esac
}

# Main installation function
install_go2rtc() {
    local version=$(fetch_latest_release_version)
    local platform=$(determine_platform_release)

    # Ensure the version and platform could be determined
    if [ -z "$version" ] || [ -z "$platform" ]; then
        echo "Failed to determine release version or platform." >&2
        exit 1
    fi

    local download_url="https://github.com/AlexxIT/go2rtc/releases/download/${version}/${platform}"
    local install_dir="$HOME/go2rtc"
    local binary_name=$(basename "$download_url")

    # Create the directory if it doesn't exist
    mkdir -p "$install_dir"

    # Change to the directory
    cd "$install_dir"

    # Download the binary
    echo "Downloading go2rtc from $download_url"
    if curl -sLO "$download_url"; then
        echo "Download successful."

        # Make the binary executable
        chmod +x "$binary_name"
        echo "go2rtc has been installed successfully to $install_dir"
        echo "You can run it with ./$binary_name"
        echo "default WebGui Port: 1984"

    else
        echo "Failed to download go2rtc."
        exit 1
    fi
}

# Run the installation
install_go2rtc
