#!/bin/bash
# installer: Node.js with npm, a major version from 18 on (NodeSource apt or rpm repo, Arch package)
# systems: debian arch fedora rhel
# Installs Node.js with npm, the major version resolved from the release index of nodejs.org.
# Debian family: NodeSource apt repository (amd64, arm64; armv7 for the LTS lines NodeSource builds for armhf: 18, 20
# and 22 up to 22.15 in 10.2026). Other architectures (armv6) get the distro package (Debian 12: 18, Debian 13: 20).
# Fedora, RHEL family: NodeSource rpm repository (amd64/arm64).
# Arch: nodejs for the newest line, nodejs-lts-<codename> for an older LTS line.
#   nodejs.sh          the newest major version with packages here
#   nodejs.sh 22       Node.js 22.x
#   nodejs.sh lts      newest LTS line; lts-1 the LTS line before it, current the newest line
#   NODE_MAJOR=22 nodejs.sh   the same as an environment variable
#   nodejs.sh --choices       the major versions from 18 on with packages here, newest first (for installer.sh)
# category: dev
# check: node
# ask: NODE_MAJOR=@ "Node.js major version"
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

if [ "${1:-}" = --choices ]; then
  want=--choices
else
  want=${1:-${NODE_MAJOR:-}}
  case $want in ''|lts|lts-1|current|[1-9]|[1-9][0-9]) ;; *) dot_die "usage: nodejs.sh [major version, e.g. 22|lts|lts-1|current]" ;; esac
  dot_need curl
fi
index=$(curl -fsSL https://nodejs.org/dist/index.json) || dot_die "cannot read https://nodejs.org/dist/index.json (no network?)"
# index.json has one release per line, newest version first; reduce it to "<major> <lts codename|false>"
releases=$(sed -n 's/.*"version":"v\([0-9]*\)\..*"lts":\("[^"]*"\|false\).*/\1 \2/p' <<<"$index" | tr -d '"')
newest=$(head -n 1 <<<"$releases" | cut -d' ' -f1)

# true when NodeSource's apt repository of major $1 has a nodejs package for armhf: the Release file lists armhf for
# every line, but from 24 on binary-armhf holds nsolid only (checked 28.10.26)
ns_armhf() {
  curl -fsSL "https://deb.nodesource.com/node_$1.x/dists/nodistro/main/binary-armhf/Packages.gz" 2>/dev/null |
    gzip -dc 2>/dev/null | grep -qx 'Package: nodejs'
}

# prints the major versions from 18 on that install here, newest first: NodeSource has a repository for them (apt and
# dnf, amd64 and arm64; apt armv7 where ns_armhf) or Arch a package (nodejs, nodejs-lts-<codename>); nothing where
# the distro package is taken
node_choices() {
  local m code args=() url
  case $DOT_PKG:$DOT_ARCH in
    apt:amd64|apt:arm64) url='https://deb.nodesource.com/node_@.x/dists/nodistro/Release' ;;
    apt:armv7)
      # LTS lines only: the newest line with armhf packages is the odd 23 (EOL), which Zigbee2MQTT's engines exclude
      for m in $(awk '$1 >= 18 && $2 != "false" && !seen[$1]++ { print $1 }' <<<"$releases"); do
        ns_armhf "$m" && echo "$m"
      done
      return 0 ;;
    dnf:amd64|dnf:arm64) url="https://rpm.nodesource.com/pub_@.x/nodistro/nodejs/$(uname -m)/repodata/repomd.xml" ;;
    pacman:*)
      while read -r m code; do
        [ "$m" = "$newest" ] || { [ "$code" != false ] && pacman -Si "nodejs-lts-${code,,}" >/dev/null 2>&1; } && echo "$m"
      done < <(awk '$1 >= 18 && !seen[$1]++' <<<"$releases")
      return ;;
    *) return 0 ;;
  esac
  for m in $(awk '$1 >= 18 && !seen[$1]++ { print $1 }' <<<"$releases"); do args+=(-o /dev/null "${url//@/$m}"); done
  # one curl for all: HEAD requests over one connection
  curl -sI -w '%{http_code} %{url_effective}\n' "${args[@]}" | awk '$1 == 200' | grep -oE '(node|pub)_[0-9]+' |
    grep -oE '[0-9]+'
}

if [ "$want" = --choices ]; then node_choices; exit 0; fi
[ -n "$want" ] || want=$(node_choices | head -n 1)
# the newest line, LTS or not; also where no list exists (other architectures take the distro package)
[ -n "$want" ] || want=current

# the newest release of every line: an LTS line is marked from its newest release on
case $want in
  lts)     read -r major lts < <(awk '$2 != "false" && !seen[$1]++' <<<"$releases" | sed -n 1p) ;;
  lts-1)   read -r major lts < <(awk '$2 != "false" && !seen[$1]++' <<<"$releases" | sed -n 2p) ;;
  current) read -r major lts < <(head -n 1 <<<"$releases") ;;
  *)       read -r major lts < <(awk -v m="$want" '$1 == m {print; exit}' <<<"$releases") ;;
esac
[ -n "$major" ] || dot_die "Node.js $want not found in https://nodejs.org/dist/index.json"
dot_info "Installing Node.js $major.x"

case $DOT_PKG in
  apt)
    if [ "$DOT_ARCH" = armv7 ] && ! ns_armhf "$major"; then
      dot_die "NodeSource has no armhf (32-bit ARM) packages of Node.js $major, lines that have:" \
        "$(node_choices | paste -sd ' ') - or run the program that needs it in Docker"
    fi
    if [ "$DOT_ARCH" = amd64 ] || [ "$DOT_ARCH" = arm64 ] || [ "$DOT_ARCH" = armv7 ]; then
      dot_apt_repo nodesource https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        "https://deb.nodesource.com/node_$major.x" nodistro main
      # the pin NodeSource's own setup script writes: its nodejs wins over the distro package
      printf 'Package: nodejs\nPin: origin deb.nodesource.com\nPin-Priority: 600\n' |
        dot_sudo tee /etc/apt/preferences.d/nodejs >/dev/null
      # the version glob also switches an installed newer major down
      dot_pkg_install --allow-downgrades "nodejs=$major.*" || dot_die "installing nodejs from NodeSource failed"
    else
      dot_info "NodeSource has no $DOT_ARCH packages, installing the distro's Node.js instead (not $major.x)"
      dot_pkg_install nodejs npm || dot_die "installing nodejs failed"
    fi ;;
  dnf)
    [ "$DOT_ARCH" = amd64 ] || [ "$DOT_ARCH" = arm64 ] || dot_die "NodeSource has no $DOT_ARCH rpm packages"
    # the repository NodeSource's setup script writes: priority 9 wins over the distro's Node.js, module_hotfixes
    # keeps the nodejs module streams of the RHEL family from hiding it
    dot_rpm_repo nodesource-nodejs "https://rpm.nodesource.com/pub_$major.x/nodistro/nodejs/\$basearch" \
      https://rpm.nodesource.com/gpgkey/ns-operations-public.key $'priority=9\nmodule_hotfixes=1'
    # distro-sync also switches an installed newer major down
    dot_sudo dnf install -y --allowerasing nodejs && dot_sudo dnf distro-sync -y nodejs ||
      dot_die "installing nodejs from NodeSource failed" ;;
  pacman)
    pkg=nodejs-lts-${lts,,}
    if [ "$lts" != false ] && pacman -Si "$pkg" >/dev/null 2>&1; then
      dot_pkg_install "$pkg" npm || dot_die "installing $pkg failed"
    elif [ "$major" = "$newest" ] || [ "$want" = lts ]; then
      # its nodejs package is the newest Node.js; a fresh LTS line can take a few days to reach Arch
      dot_info "installing Arch's nodejs, the newest Node.js"
      dot_pkg_install nodejs npm || dot_die "installing nodejs failed"
    else
      dot_die "Arch has no package for Node.js $major; its nodejs package carries the newest version"
    fi ;;
  *) dot_die "no installation path for Node.js on $DOT_OS, see https://nodejs.org/en/download" ;;
esac
echo "node $(node --version), npm $(npm --version)"
