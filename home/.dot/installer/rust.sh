#!/bin/bash
# installer: Rust and cargo with rustup
# systems: all
# Installs Rust and cargo with rustup into ~/.rustup and ~/.cargo; when rustup is already there, updates instead.
# Shell rc files stay untouched (--no-modify-path), ~/.profile loads ~/.cargo/env.
#   rust.sh
# category: dev
# check: ~/.cargo/bin/rustup
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

cargo_bin="${CARGO_HOME:-$HOME/.cargo}/bin"

case $DOT_ARCH in
  amd64) triple=x86_64-unknown-linux-gnu ;;
  arm64) triple=aarch64-unknown-linux-gnu ;;
  armv7) triple=armv7-unknown-linux-gnueabihf ;;
  armv6) triple=arm-unknown-linux-gnueabihf ;;
  *) dot_die "rustup has no build for architecture $DOT_ARCH" ;;
esac
dot_need curl
# cargo needs a C linker (cc) to build anything
if ! command -v cc >/dev/null 2>&1; then
  if [ "$DOT_PKG" = apt ]; then dot_pkg_install build-essential; else dot_pkg_install gcc; fi ||
    dot_die "could not install a C compiler, cargo needs one"
fi

if [ -x "$cargo_bin/rustup" ]; then
  dot_info "rustup is installed, updating"
  "$cargo_bin/rustup" update || dot_die "rustup update failed"
else
  url="https://static.rust-lang.org/rustup/dist/$triple/rustup-init"
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  dot_info "Downloading rustup-init ($triple)"
  curl -fsSL -o "$tmp/rustup-init" "$url" && curl -fsSL -o "$tmp/rustup-init.sha256" "$url.sha256" ||
    dot_die "download of $url failed (no network?)"
  echo "$(cut -d' ' -f1 "$tmp/rustup-init.sha256")  $tmp/rustup-init" | sha256sum -c --quiet ||
    dot_die "checksum of rustup-init does not match, aborting"
  chmod +x "$tmp/rustup-init" && "$tmp/rustup-init" -y --no-modify-path || dot_die "rustup-init failed"
fi
"$cargo_bin/cargo" --version
