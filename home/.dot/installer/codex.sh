#!/bin/bash
# installer: Codex CLI, OpenAI's coding agent for the terminal
# systems: amd64 arm64
# Installs the latest standalone Codex binary (static musl build) from the openai/codex GitHub releases into
# ~/.local/bin, checked against the sha256 digest GitHub publishes for the asset, plus bubblewrap from the package
# manager for Codex's Linux sandbox. No Node.js needed. Shell rc files stay untouched. Never asks for API keys.
# Safe to run again: does nothing when the latest version is installed already.
#   codex.sh
# category: dev
# check: codex
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
export PATH="$HOME/.local/bin:$PATH"

case $DOT_ARCH in
  amd64) triple=x86_64-unknown-linux-musl ;;
  arm64) triple=aarch64-unknown-linux-musl ;;
  *) dot_die "Codex has no release binary for architecture $DOT_ARCH" ;;
esac
dot_need curl tar

# the sandbox uses the first bwrap on PATH; without it Codex falls back to a helper that needs user namespaces
command -v bwrap >/dev/null 2>&1 || [ "$DOT_PKG" = none ] || dot_pkg_install bubblewrap ||
  dot_info "could not install bubblewrap, Codex will warn about its sandbox"

tag=$(dot_github_latest openai/codex) || dot_die "cannot read the latest Codex release from GitHub (no network?)"
if [ "$(~/.local/bin/codex --version 2>/dev/null)" = "codex-cli ${tag#rust-v}" ]; then
  dot_info "Codex ${tag#rust-v} is already installed"
else
  dot_info "Installing Codex ${tag#rust-v} ($triple)"
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  dot_github_fetch openai/codex "/codex-$triple\.tar\.gz$" "$tmp/codex.tar.gz" || dot_die "could not download Codex"
  # the archive holds one file named after the target
  tar -xzf "$tmp/codex.tar.gz" -C "$tmp" && install -D -m 755 "$tmp/codex-$triple" ~/.local/bin/codex ||
    dot_die "could not unpack Codex into ~/.local/bin"
fi
~/.local/bin/codex --version
dot_info "Log in: run 'codex' and choose 'Sign in with ChatGPT' (without a browser here: codex login --device-auth)"
