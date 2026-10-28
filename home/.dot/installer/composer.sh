#!/bin/bash
# installer: Composer, PHP package manager
# systems: debian arch fedora rhel
# Installs the latest Composer to /usr/local/bin/composer with the official installer, checked against
# its published signature; installs php-cli and unzip first. Run again to update.
# category: dev
# check: composer
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

dot_need curl unzip
dot_php_cli
tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
sig=$(curl -fsSL https://composer.github.io/installer.sig) &&
  curl -fsSL -o "$tmp/composer-setup.php" https://getcomposer.org/installer || dot_die "downloading the Composer installer failed"
echo "$sig  $tmp/composer-setup.php" | sha384sum -c --quiet || dot_die "invalid Composer installer signature, aborting"
dot_sudo php "$tmp/composer-setup.php" --install-dir=/usr/local/bin --filename=composer --quiet ||
  dot_die "the Composer installer failed"
composer --version
