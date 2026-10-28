#!/bin/bash
# installer: Google Chrome browser
# systems: debian fedora rhel desktop amd64
# Installs google-chrome-stable from Google's signed apt repository; the package then keeps the repository for updates.
# The key is trusted only with the fingerprint below (Google Linux Packages Signing Authority, checked 28.10.26).
# Fedora, RHEL family: Google's rpm repository (the one its .rpm writes), package google-chrome-stable, with the key of
# that fingerprint only.
# Google builds Chrome for Linux only for amd64. Safe to run again: updates from the repository.
# category: desktop
# check: google-chrome-stable
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

case $DOT_PKG in apt|dnf|yum) ;; *) dot_die "this installer needs apt or dnf; on $DOT_OS install Chrome from your distribution (AUR: google-chrome) or use chromium.sh" ;; esac
[ "$DOT_ARCH" = amd64 ] || dot_die "Google ships Chrome for Linux only for amd64, use chromium.sh on $DOT_ARCH"

fpr=EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796 key=https://dl.google.com/linux/linux_signing_key.pub
if [ "$DOT_PKG" != apt ]; then
  # the same check for rpm: dnf -y imports the key of gpgkey= without a question (28.10.26, review). The package
  # then writes google-chrome.repo with Google's key URL, as it does on apt: the package checked with that key decides
  # from there (AlmaLinux 10, 28.10.26)
  k=$(dot_rpm_key google-chrome "$key" "$fpr") || exit 1
  dot_rpm_repo google-chrome https://dl.google.com/linux/chrome/rpm/stable/x86_64 "$k"
  dot_pkg_install google-chrome-stable || dot_die "installing google-chrome-stable failed"
  google-chrome-stable --version
  exit
fi

if dpkg-query -W -f='${Status}' google-chrome-stable 2>/dev/null | grep -q 'ok installed'; then
  # Google's repository is set up by the package already
  dot_info "Google Chrome is installed, updating it from Google's repository"
  dot_pkg_install google-chrome-stable || dot_die "updating google-chrome-stable failed"
else
  dot_need curl gpg
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  curl -fsSL -o "$tmp/google.asc" "$key" || dot_die "could not download the key $key"
  # only the key with that fingerprint: apt trusts every key in a Signed-By file, and Google ships old and new
  # together when it changes its key
  dot_key_only "$tmp/google.asc" "$fpr" >/dev/null ||
    dot_die "$key holds no key with Google's fingerprint $fpr, not trusting it"
  dot_apt_repo google-chrome "file://$tmp/google.asc" https://dl.google.com/linux/chrome/deb stable main amd64
  dot_pkg_install google-chrome-stable || dot_die "installing Google Chrome failed"
  # the package writes its own source with its own copy of the key (28.10.26: it overwrites google-chrome.sources);
  # the same repository with two Signed-By breaks every apt-get update, so ours goes once the package has its own
  src=/etc/apt/sources.list.d/google-chrome
  if [ -f "$src.list" ]; then
    dot_sudo rm -f "$src.sources" /etc/apt/keyrings/google-chrome.asc
  elif ! grep -q /etc/apt/keyrings/google-chrome.asc "$src.sources" 2>/dev/null; then
    dot_sudo rm -f /etc/apt/keyrings/google-chrome.asc
  fi
  dot_apt_update || dot_die "apt-get update fails with Google's own repository source"
fi
google-chrome-stable --version
