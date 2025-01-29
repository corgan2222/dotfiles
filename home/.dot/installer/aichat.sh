#!/bin/bash

# Check if aichat command is available
if command -v aichat &> /dev/null; then
    echo "aichat is already installed."
    exit 0
fi

# Get Cargo version
CARGO_VERSION=$(cargo --version | awk '{print $2}')

# Function to compare version numbers
version_gt() {
  [ "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1" ]
}

# Check if Cargo version is greater than 1.71
if version_gt "$CARGO_VERSION" "1.71"; then
    cargo install aichat
else
    # If Cargo is too old, update Rust and install again
    curl -sf https://static.rust-lang.org/rustup.sh | sudo sh
    cargo install aichat
fi
