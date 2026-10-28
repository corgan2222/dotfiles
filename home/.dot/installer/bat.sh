#!/bin/bash
# installer: bat, cat with syntax highlighting
# systems: all
# Installs bat from the package manager when this system has a package, else the latest release from GitHub:
# the .deb on apt systems, the static (musl) binary into ~/.local/bin elsewhere (sha256 checked).
# Debian and Ubuntu name the binary batcat; ~/.local/bin/bat then links to it. Safe to run again.
#   bat.sh
# category: base
# check: bat|batcat
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
export PATH="$HOME/.local/bin:$PATH"

if [ "$DOT_PKG" != none ] && dot_pkg_install bat; then
  :
else
  dot_need curl tar
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  if [ "$DOT_PKG" = apt ]; then
    arch=$(dpkg --print-architecture)
    dot_info "no bat package on $DOT_OS, installing the latest release .deb ($arch)"
    dot_github_fetch sharkdp/bat "/bat_[0-9.]+_$arch\.deb$" "$tmp/bat.deb" || dot_die "could not download bat"
    dot_pkg_install "$tmp/bat.deb" || dot_die "could not install bat_${DOT_GITHUB_TAG#v}_$arch.deb"
  else
    case $DOT_ARCH in
      amd64) triple=x86_64-unknown-linux-musl ;;
      arm64) triple=aarch64-unknown-linux-musl ;;
      armv7|armv6) triple=arm-unknown-linux-musleabihf ;;
      *) dot_die "bat has no package on $DOT_OS and no release binary for architecture $DOT_ARCH" ;;
    esac
    dot_info "no bat package on $DOT_OS, installing the latest release binary ($triple) into ~/.local/bin"
    dot_github_fetch sharkdp/bat "/bat-v[^/]*-$triple\.tar\.gz$" "$tmp/bat.tar.gz" || dot_die "could not download bat"
    tar -xzf "$tmp/bat.tar.gz" -C "$tmp" && install -D -m 755 "$tmp/bat-$DOT_GITHUB_TAG-$triple/bat" ~/.local/bin/bat ||
      dot_die "could not unpack bat into ~/.local/bin"
  fi
fi

if ! command -v bat >/dev/null && command -v batcat >/dev/null; then
  mkdir -p ~/.local/bin && ln -sf "$(command -v batcat)" ~/.local/bin/bat
fi
bat --version
