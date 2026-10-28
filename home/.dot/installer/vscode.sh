#!/bin/bash
# installer: Visual Studio Code
# systems: desktop amd64 arm64 armv7
# apt systems: Microsoft's repository packages.microsoft.com/repos/code (amd64, arm64, armhf), package code.
# Fedora, RHEL family: Microsoft's rpm repository packages.microsoft.com/yumrepos/vscode, package code.
# Arch: the AUR (visual-studio-code-bin) is out of scope, so this installs "code" from extra, the open source
# build without Microsoft's marketplace and branding. Safe to run again.
# category: desktop
# check: code
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

case $DOT_PKG in
  apt)
    case $(dpkg --print-architecture) in amd64|arm64|armhf) ;; *) dot_die "Microsoft ships VS Code only for amd64, arm64 and armhf" ;; esac
    # the code package would otherwise write its own vscode.sources with another key path, and apt refuses
    # two entries of one repository with different Signed-By
    echo 'code code/add-microsoft-repo boolean false' | dot_sudo debconf-set-selections
    dot_apt_repo vscode https://packages.microsoft.com/keys/microsoft.asc https://packages.microsoft.com/repos/code stable main
    dot_pkg_install code || dot_die "installing code failed" ;;
  dnf|yum)
    dot_rpm_repo vscode https://packages.microsoft.com/yumrepos/vscode https://packages.microsoft.com/keys/microsoft.asc
    dot_pkg_install code || dot_die "installing code failed" ;;
  pacman)
    dot_info "Arch: installing the open source build 'code' from extra (Microsoft's build is only in the AUR)"
    dot_pkg_install code || dot_die "installing code failed" ;;
  *) dot_die "no VS Code installer for $DOT_OS, see https://code.visualstudio.com/docs/setup/linux" ;;
esac
# not "code --version": under WSL it stops and asks whether to go on
case $DOT_PKG in apt) dpkg-query -W -f='code ${Version}\n' code ;; *) echo "code $(dot_pkg_version code)" ;; esac
