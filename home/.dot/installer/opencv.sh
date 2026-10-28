#!/bin/bash
# installer: OpenCV headless in a Python venv (a release from PyPI), or from the distro packages
# systems: debian arch fedora rhel
# Installs the opencv-python-headless wheel from PyPI into a venv (created when missing, with uv when it is there),
# or OpenCV with its C++ headers and the system Python module from the distro (often older: 4.6 on Ubuntu 24.04).
#   opencv.sh                  newest opencv-python-headless into ~/.venvs/opencv
#   opencv.sh 4.12.0           that release; 4 the newest 4.x, 4.10 the newest 4.10.x
#   opencv.sh distro           distro packages ("4.6.0 (distro)" as well, the form --choices prints)
#   OPENCV_VERSION=4 opencv.sh the same as an environment variable
#   OPENCV_VENV=<path>         another venv (default ~/.venvs/opencv); opencv.sh --pip <venv> is the newest into <venv>
#   opencv.sh --choices        the 6 newest releases on PyPI and the version of the distro packages (for installer.sh)
# category: dev
# check: /usr/include/opencv4|~/.venvs/opencv/bin/python
# ask: OPENCV_VERSION=@ "OpenCV version: PyPI (headless, in ~/.venvs/opencv) or the distro packages"
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

# prints the summary block, also into the recap of installer.sh
opencv_summary() {
  printf '\n\033[92m=== opencv is ready ===\033[0m\n  version: %s\n  use:     %s\n' "$1" "$2" |
    if [ -n "${DOT_SUMMARY_FILE:-}" ]; then tee -a "$DOT_SUMMARY_FILE"; else cat; fi
}

# creates the venv $1 when missing and installs opencv-python-headless into it, version $2 (4, 4.10; empty: newest)
opencv_pip() {
  local venv=$1 spec=opencv-python-headless${2:+==$2.*} uv v
  uv=$(command -v uv || echo "$HOME/.local/bin/uv")
  if [ -x "$uv" ]; then
    [ -x "$venv/bin/python" ] || "$uv" venv "$venv" || dot_die "uv could not create the venv $venv"
    "$uv" pip install --upgrade --python "$venv/bin/python" "$spec" || dot_die "installing $spec failed"
  else
    case $DOT_PKG in apt) dot_pkg_install python3-venv ;; pacman) dot_need python ;; dnf|yum) dot_need python3 ;; esac ||
      dot_die "installing Python failed"
    [ -x "$venv/bin/python" ] || python3 -m venv "$venv" || dot_die "could not create the venv $venv"
    "$venv/bin/python" -m pip install -q --upgrade "$spec" || dot_die "installing $spec failed"
  fi
  v=$("$venv/bin/python" -c 'import cv2; print(cv2.__version__)') || dot_die "cv2 does not load in $venv"
  opencv_summary "OpenCV $v (opencv-python-headless) in $venv" \
    "$venv/bin/python -c 'import cv2'   or   source $venv/bin/activate"
}

# prints the 6 newest opencv-python-headless releases on PyPI as x.y.z, newest first, then the version of the distro
# packages as "x.y.z (distro)" when the package index knows it (read only: apt-cache, dnf from its cache, pacman)
opencv_choices() {
  local v
  # release keys look like "4.12.0.88":[{ ; a release without files ("…":[]) and pre-releases are left out
  curl -fsSL https://pypi.org/pypi/opencv-python-headless/json | grep -oE '"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+":\[\{' |
    grep -oE '^"[0-9]+\.[0-9]+\.[0-9]+' | tr -d '"' | sort -rVu | head -n 6 | sed 's/$/\tPyPI, headless, in a venv/'
  case $DOT_PKG in
    apt) v=$(apt-cache policy python3-opencv 2>/dev/null | sed -n 's/^ *Candidate: //p') ;;
    dnf|yum) v=$("$DOT_PKG" -C -q repoquery --qf '%{version}\n' python3-opencv 2>/dev/null | sort -V | tail -n 1) ;;
    pacman) v=$(pacman -Si python-opencv 2>/dev/null | sed -n 's/^Version *: //p') ;;
  esac
  v=$(grep -oE '^([0-9]+:)?[0-9]+\.[0-9]+(\.[0-9]+)?' <<<"$v" | sed 's/^[0-9]*://')
  [ -z "$v" ] || printf '%s (distro)\tdistro packages, with C++ headers\n' "$v"
}

venv=${OPENCV_VENV:-$HOME/.venvs/opencv}
case ${1:-} in
  --choices) opencv_choices; exit 0 ;;
  --pip) [ -n "${2:-}" ] || dot_die "usage: opencv.sh --pip <venv path>"; venv=$2 ver=latest ;;
  *) ver=${1:-${OPENCV_VERSION:-latest}} ;;
esac

case $ver in
  latest) opencv_pip "$venv" ;;
  [1-9]|[1-9].[0-9]|[1-9].[0-9][0-9]|[1-9].[0-9].[0-9]|[1-9].[0-9][0-9].[0-9]) opencv_pip "$venv" "$ver" ;;
  distro|*" (distro)")
    case $DOT_PKG in
      apt) dot_pkg_install libopencv-dev python3-opencv ;;
      pacman) dot_pkg_install opencv python-opencv ;;
      # the RHEL family has OpenCV in EPEL
      dnf|yum) dot_epel && dot_pkg_install opencv-devel python3-opencv ;;
      *) dot_die "no OpenCV packages for $DOT_OS, install it into a venv: opencv.sh latest" ;;
    esac || dot_die "installing the OpenCV packages failed"
    v=$(python3 -c 'import cv2; print(cv2.__version__)') || dot_die "cv2 does not load in python3"
    opencv_summary "OpenCV $v (distro packages)" "python3 -c 'import cv2'; C++: pkg-config --cflags --libs opencv4" ;;
  *) dot_die "usage: opencv.sh [latest|4|4.10|4.12.0|distro] or opencv.sh --pip <venv path>" ;;
esac
