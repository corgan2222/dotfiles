#!/bin/bash
# installer: Firefox Developer Edition
# systems: debian arch fedora amd64 arm64 desktop
# apt systems: Mozilla's official repository packages.mozilla.org/apt (amd64, arm64), package firefox-devedition.
# Fedora: Mozilla's rpm repository packages.mozilla.org/rpm/firefox (x86_64, aarch64), same package; not the RHEL family.
# Arch: firefox-developer-edition from extra. Installs side by side with the normal Firefox; safe to run again.
# category: desktop
# check: firefox-devedition|firefox-developer-edition
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

case $DOT_PKG in
  apt)
    # no "Pin-Priority: 1000" from Mozilla's docs: firefox-devedition exists only in this repository,
    # and the pin would also swap Ubuntu's firefox snap for Mozilla's .deb
    dot_apt_repo mozilla https://packages.mozilla.org/apt/repo-signing-key.gpg https://packages.mozilla.org/apt mozilla main
    dot_pkg_install firefox-devedition || dot_die "installing firefox-devedition failed"
    bin=firefox-devedition ;;
  pacman)
    dot_pkg_install firefox-developer-edition || dot_die "installing firefox-developer-edition failed"
    bin=firefox-developer-edition ;;
  dnf|yum)
    # rpm on the RHEL family refuses Mozilla's signing key ("Hash algorithm SHA1 not available", Rocky 9, 2026-10-27);
    # turning off gpgcheck or the crypto policy is not worth a browser
    [ "$DOT_OS_BASE" = fedora ] ||
      dot_die "rpm on $DOT_OS rejects the key of Mozilla's repository (SHA-1), see https://www.mozilla.org/firefox/developer/"
    # Mozilla's repository: packages signed (gpgcheck), metadata not (repo_gpgcheck=0 in their docs, the dnf default)
    dot_rpm_repo mozilla https://packages.mozilla.org/rpm/firefox https://packages.mozilla.org/rpm/firefox/signing-key.gpg
    dot_pkg_install firefox-devedition || dot_die "installing firefox-devedition failed"
    bin=firefox-devedition ;;
  *) dot_die "no Firefox Developer Edition installer for $DOT_OS, see https://www.mozilla.org/firefox/developer/" ;;
esac
"$bin" --version 2>/dev/null || command -v "$bin"
