#!/bin/bash
# installer: atuin shell history
# systems: amd64 arm64
# Installs atuin from the Arch package, elsewhere the latest static (musl) release binary from GitHub into
# ~/.local/bin (sha256 checked). Shell rc files stay untouched: the line to enable it is printed at the end.
#   atuin.sh
# category: sysop
# check: atuin
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

if [ "$DOT_PKG" = pacman ]; then
  dot_pkg_install atuin || dot_die "could not install the atuin package"
  bin=$(command -v atuin)
else
  case $DOT_ARCH in
    amd64) triple=x86_64-unknown-linux-musl ;;
    arm64) triple=aarch64-unknown-linux-musl ;;
    *) dot_die "atuin has no release binary for architecture $DOT_ARCH" ;;
  esac
  dot_need curl tar
  # the latest/download URL needs no GitHub API call (rate limit)
  file="atuin-$triple.tar.gz"
  url="https://github.com/atuinsh/atuin/releases/latest/download/$file"
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  dot_info "Downloading $file"
  curl -fsSL -o "$tmp/$file" "$url" && curl -fsSL -o "$tmp/$file.sha256" "$url.sha256" ||
    dot_die "download of $url failed"
  echo "$(cut -d' ' -f1 "$tmp/$file.sha256")  $tmp/$file" | sha256sum -c --quiet ||
    dot_die "checksum of $file does not match, aborting"
  tar -xzf "$tmp/$file" -C "$tmp" && install -D -m 755 "$tmp/atuin-$triple/atuin" ~/.local/bin/atuin ||
    dot_die "could not unpack atuin into ~/.local/bin"
  bin=~/.local/bin/atuin
fi
"$bin" --version
dot_info 'To enable atuin in bash, add this line to your bashrc (bash needs bash-preexec or ble.sh, see docs.atuin.sh):'
echo '  eval "$(atuin init bash)"'
