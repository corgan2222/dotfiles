#!/bin/bash
# installer: WP-CLI for WordPress
# systems: debian arch fedora rhel
# Installs the latest WP-CLI phar to /usr/local/bin/wp, checked against its published sha512; installs php-cli first.
# Run again to update.
# category: dev
# check: wp
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

url=https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
dot_need curl
dot_php_cli
tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/wp-cli.phar" "$url" && curl -fsSL -o "$tmp/wp-cli.sha512" "$url.sha512" ||
  dot_die "downloading WP-CLI failed"
echo "$(head -c 128 "$tmp/wp-cli.sha512")  $tmp/wp-cli.phar" | sha512sum -c --quiet ||
  dot_die "checksum of wp-cli.phar does not match, aborting"
dot_sudo install -m 0755 "$tmp/wp-cli.phar" /usr/local/bin/wp || dot_die "could not install /usr/local/bin/wp"
wp --version
