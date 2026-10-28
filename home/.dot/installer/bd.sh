#!/bin/bash
# installer: bd, jump back to a parent directory
# systems: all
# Installs bd (github.com/vigneshwaranr/bd) into ~/.local/bin and its bash completion into
# ~/.local/share/bash-completion/completions. The alias bd='. bd -s' is in ~/.dot/.bash_aliases already.
# The alias sources bd into the shell, so both files come from a fixed commit and are checked against their sha256.
# Updating: read the new bd and bash_completion.d/bd, then set commit and sums below.
# Safe to run again (replaces both files).
#   bd.sh
# category: base
# check: bd
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

# master of 15.09.22, the newest commit on 28.10.26
commit=4277ad8483357ccfa95264f4084fff9cf7887097
raw=https://raw.githubusercontent.com/vigneshwaranr/bd/$commit
dot_need curl
tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
# fetch <file in the repository> <sha256> <target> [mode, default 644]
fetch() {
  curl -fsSL -o "$tmp/f" "$raw/$1" || dot_die "download of $raw/$1 failed"
  [ "$(sha256sum "$tmp/f" | cut -d' ' -f1)" = "$2" ] || dot_die "checksum of bd's $1 does not match, aborting"
  install -D -m "${4:-644}" "$tmp/f" "$3" || dot_die "could not install $3"
}
fetch bd c051e57eae7c06481dc3587f65e50b8ecd9992ba78b565ec05bf75fce7663a41 ~/.local/bin/bd 755
fetch bash_completion.d/bd add5c6d65afe1b1f0a72e187e46e256e20dcebeafbdabd2908b23b2d5ddb083b \
  ~/.local/share/bash-completion/completions/bd
dot_info "bd installed into ~/.local/bin, use it as: bd <parent directory name>"
