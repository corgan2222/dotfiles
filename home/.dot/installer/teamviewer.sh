#!/bin/bash
# installer: TeamViewer full client, or TeamViewer Host (argument host)
# systems: debian fedora rhel amd64 arm64 armv7
# Installs TeamViewer from TeamViewer's signed repository, whose package then keeps the repository for updates.
#   teamviewer.sh        full client on a machine with a desktop, TeamViewer Host without one
#   teamviewer.sh full   full client (teamviewer)
#   teamviewer.sh host   TeamViewer Host (teamviewer-host), for boxes that are only accessed remotely
# Full client and Host exclude each other, apt and dnf swap one for the other. Safe to run again: updates from the repository.
# The key is trusted only with the fingerprint below (TeamViewer for Linux, 2023; checked 28.10.26). apt installs from
# the repository with that key. dnf: TeamViewer has a repository for x86_64 only, so the .rpm is downloaded and its
# signature checked against the key (dnf does not check a local .rpm); the .rpm brings the repository for updates.
# category: sysop
# check: teamviewer
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

case ${1:-} in
  -h|--help) sed -n '4,8s/^# \{0,1\}//p' "$0"; exit 0 ;;
  full) pkg=teamviewer ;;
  host) pkg=teamviewer-host ;;
  "")
    # same desktop test as installer.sh
    if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || compgen -G '/usr/share/xsessions/*.desktop' >/dev/null ||
       compgen -G '/usr/share/wayland-sessions/*.desktop' >/dev/null; then pkg=teamviewer; else pkg=teamviewer-host; fi ;;
  *) dot_die "unknown option '$1', use full or host" ;;
esac
fpr=AB2985BDE164897BA46EA69A234FAACB575B15D1
key=https://linux.teamviewer.com/pubkey/currentkey.asc

# downloads TeamViewer's key to $1 and keeps only the key with that fingerprint, dies without it (apt and rpm trust
# every key in the file; at a key change the file holds old and new)
key_fetch() {
  curl -fsSL -o "$1" "$key" || dot_die "could not download the key $key"
  dot_key_only "$1" "$fpr" >/dev/null || dot_die "$key holds no key with TeamViewer's fingerprint $fpr, not trusting it"
}

if [ "$DOT_PKG" = dnf ]; then
  case $DOT_ARCH in amd64) rarch=x86_64 ;; arm64) rarch=aarch64 ;; *) dot_die "TeamViewer ships no rpm for $DOT_ARCH" ;; esac
  if dot_pkg_installed "$pkg"; then
    dot_info "$pkg is installed, updating it from TeamViewer's repository"
    dot_sudo dnf upgrade -y "$pkg" || dot_die "updating $pkg failed"
  else
    # --allowerasing swaps full client and Host; the RHEL family finds libminizip in EPEL
    dot_epel && dot_need curl gpg
    tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
    key_fetch "$tmp/teamviewer.asc"
    dot_sudo rpm --import "$tmp/teamviewer.asc" || dot_die "could not import TeamViewer's key"
    dot_info "Downloading $pkg.$rarch.rpm"
    curl -fsSL -o "$tmp/$pkg.$rarch.rpm" "https://download.teamviewer.com/download/linux/$pkg.$rarch.rpm" ||
      dot_die "download of $pkg.$rarch.rpm failed"
    # an unsigned rpm passes with "digests OK", only "signatures OK" means signed with the imported key
    rpmkeys -K "$tmp/$pkg.$rarch.rpm" | grep -q 'signatures OK' ||
      dot_die "$pkg.$rarch.rpm is not signed with TeamViewer's key, not installing it"
    dot_sudo dnf install -y --allowerasing "$tmp/$pkg.$rarch.rpm" || dot_die "installing $pkg failed"
  fi
  rpm -q "$pkg"
  [ "$pkg" = teamviewer-host ] &&
    dot_info "Assign the box to your account: sudo teamviewer assignment --token <token>, or set a password: sudo teamviewer passwd <pw>"
  exit 0
fi
[ "$DOT_PKG" = apt ] || dot_die "TeamViewer's packages need apt or dnf, see https://www.teamviewer.com/download/linux/"
deb_arch=$(dpkg --print-architecture)
case $deb_arch in amd64|arm64|armhf) ;; *) dot_die "TeamViewer ships no Linux package for $deb_arch" ;; esac

if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'ok installed'; then
  dot_info "$pkg is installed, updating it from TeamViewer's repository"
  dot_pkg_install "$pkg" || dot_die "updating $pkg failed"
else
  # the package imports its repository key with gpg and skips that silently when gpg is missing
  dot_need curl gpg
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  key_fetch "$tmp/teamviewer.asc"
  dot_apt_repo teamviewer "file://$tmp/teamviewer.asc" https://linux.teamviewer.com/deb stable main
  dot_pkg_install "$pkg" || dot_die "installing $pkg failed"
  # the package writes its own teamviewer.list with its own copy of the key; the same repository with two Signed-By
  # breaks every apt-get update ("Conflicting values set for option Signed-By", 28.10.26), so ours goes again
  if [ -f /etc/apt/sources.list.d/teamviewer.list ]; then
    dot_sudo rm -f /etc/apt/sources.list.d/teamviewer.sources /etc/apt/keyrings/teamviewer.asc
    dot_apt_update || dot_die "apt-get update fails with TeamViewer's own repository list"
  fi
fi
dpkg-query -W -f='${Package} ${Version}\n' "$pkg"
[ "$pkg" = teamviewer-host ] &&
  dot_info "Assign the box to your account: sudo teamviewer assignment --token <token>, or set a password: sudo teamviewer passwd <pw>"
exit 0
