#!/bin/bash
# installer: Python 3.x side by side with uv, choose from the newest versions
# systems: all
# Installs Python with uv (https://docs.astral.sh/uv), side by side with the system Python, no compiler needed.
# Offers the 4 newest stable minor versions; installs uv into ~/.local/bin first when it is missing.
#   python.sh           numbered menu
#   python.sh 3.13      install Python 3.13, run it as python3.13
#   python.sh --list    only print the offered versions
# category: dev
# check: ~/.local/share/uv/python
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

UV_DIR="$HOME/.local/bin"

# prints the stable CPython minor versions uv can download, newest first;
# pre-releases (3.16.0a1) and variants (+freethreaded, +debug) do not match the pattern
py_versions() {
  "$uv" python list --all-versions --only-downloads 2>/dev/null |
    sed -n 's/^cpython-\(3\.[0-9]*\)\.[0-9]*-.*/\1/p' | sort -rVu
}

case ${1:-} in -h|--help) sed -n '4,8s/^# \{0,1\}//p' "$0"; exit 0 ;; esac

uv=$(command -v uv || echo "$UV_DIR/uv")
[ -x "$uv" ] || dot_uv_install
all=$(py_versions)
[ -n "$all" ] || dot_die "uv offers no Python downloads for $DOT_OS on $DOT_ARCH"
offer=$(echo "$all" | head -n 4)

case ${1:-} in
  --list) echo "$offer"; exit 0 ;;
  "")
    PS3="Install which Python version? "
    select ver in $offer; do break; done
    ver=${ver:-$REPLY} ;;
  *) ver=$1 ;;
esac
echo "$all" | grep -qxF -- "$ver" || dot_die "invalid version '$ver', choose one of: $(echo $offer)"

dot_info "Installing Python $ver with uv"
"$uv" python install "$ver" || dot_die "uv could not install Python $ver"
bin=$("$uv" python dir --bin)
[ -x "$bin/python$ver" ] || dot_die "$bin/python$ver is missing after the install"
"$bin/python$ver" --version
# not "uv python update-shell": it appends an export line with the absolute home path to ~/.bashrc and ~/.profile,
# which homeshick links into this repo; ~/.dot/.exports puts ~/.local/bin, uv's default bin dir, into PATH
case ":$PATH:" in
  *":$bin:"*) dot_info "Run it as python$ver ($bin/python$ver)" ;;
  *) [ "$bin" = "$HOME/.local/bin" ] && where="~/.dot/.exports adds it at the next login" || where="add it to PATH in ~/.extra"
     dot_info "$bin is not in PATH yet, $where; until then run $bin/python$ver" ;;
esac
