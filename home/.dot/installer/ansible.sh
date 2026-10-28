#!/bin/bash
# installer: Ansible (distro package, or uv when the distro has no ansible-core)
# systems: debian arch fedora rhel
# Installs Ansible from the distro. Distros without an ansible-core package (Ubuntu 20.04, Debian 11) only
# have Ansible 2.9/2.10, there it installs the current Ansible for the calling user with uv into ~/.local/bin.
# category: sysop
# check: ansible
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

UV_DIR="$HOME/.local/bin"

case $DOT_PKG in
  pacman) dot_pkg_install ansible || dot_die "installing ansible failed" ;;
  # Fedora has ansible in its repositories, the RHEL family in EPEL (on top of ansible-core from AppStream)
  dnf|yum) dot_epel && dot_pkg_install ansible || dot_die "installing ansible failed" ;;
  apt)
    dot_apt_update || dot_die "apt-get update failed"
    if apt-cache policy ansible-core 2>/dev/null | grep -q 'Candidate: [0-9]'; then
      dot_pkg_install ansible || dot_die "installing ansible failed"
    else
      dot_info "the distro's Ansible is too old, installing the current one with uv for $(id -un)"
      uv=$(command -v uv || echo "$UV_DIR/uv")
      [ -x "$uv" ] || dot_uv_install
      # the ansible package only pulls in ansible-core, which brings the ansible-* commands;
      # Python pinned, uv's newest (3.15) breaks ansible-core 2.21; raise it once ansible-core supports newer
      "$uv" tool install --upgrade --python 3.13 --with-executables-from ansible-core ansible ||
        dot_die "uv could not install ansible"
      export PATH="$UV_DIR:$PATH"
    fi ;;
  *) dot_die "no Ansible package for $DOT_OS" ;;
esac
ver=$(ansible --version) || dot_die "ansible does not run"
echo "${ver%%$'\n'*}"
