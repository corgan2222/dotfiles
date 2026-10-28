#!/bin/bash
# installer: etckeeper, /etc under git
# systems: debian arch fedora rhel
# Installs etckeeper, puts /etc under git with a first commit and enables the daily autocommit timer.
# A remote is not set up; the hint at the end shows how.
# category: sysop
# check: etckeeper
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

case $DOT_PKG in
  dnf|yum)
    # the RHEL family has etckeeper in EPEL; the dnf plugin commits /etc around every package install, dnf5 has its own
    plugin=etckeeper-dnf
    command -v dnf5 >/dev/null 2>&1 && plugin=etckeeper-dnf5
    dot_epel && dot_pkg_install etckeeper "$plugin" git ;;
  *) dot_pkg_install etckeeper git ;;
esac || dot_die "installing etckeeper failed"
# Debian's package initialises /etc itself, Arch, Fedora and the RHEL family leave it to us
[ -d /etc/.git ] || dot_sudo etckeeper init || dot_die "etckeeper init failed"
# git refuses to commit without a name (root has none on Arch); set one only for the /etc repo, so the
# daily autocommits work too; etckeeper still records the sudo user as author
dot_sudo git -C /etc var GIT_COMMITTER_IDENT >/dev/null 2>&1 ||
  dot_sudo git -C /etc config user.name etckeeper
if dot_sudo etckeeper unclean; then
  dot_sudo etckeeper commit "initial commit" >/dev/null || dot_die "etckeeper commit failed"
fi
dot_sudo git -C /etc log --oneline -1 || dot_die "/etc has no commit"

if [ -d /run/systemd/system ]; then
  systemctl list-unit-files --no-legend etckeeper.timer | grep -q . && dot_sudo systemctl enable --now etckeeper.timer
else
  dot_info "no systemd running: etckeeper still commits on every package install"
fi
dot_info "to push to a remote: sudo git -C /etc remote add origin <url>, set PUSH_REMOTE=\"origin\" in /etc/etckeeper/etckeeper.conf;"
dot_info "root needs an ssh key the remote accepts (sudo ssh-keygen -t ed25519)"
