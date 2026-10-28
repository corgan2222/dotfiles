#!/bin/bash
# installer: Yarn and pnpm via corepack (needs Node.js)
# systems: debian arch fedora rhel
# Enables corepack system-wide; it runs the yarn/pnpm version a project asks for (packageManager in package.json).
# Runs nodejs.sh first when node is missing. Removes the old yarn apt repository of earlier versions of this installer.
# category: dev
# check: yarn pnpm
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

dot_node_min

# the dl.yarnpkg.com repository used apt-key and an expired key; corepack replaces it
if [ -f /etc/apt/sources.list.d/yarn.list ]; then
  dot_info "removing the old yarn apt repository"
  dpkg -s yarn >/dev/null 2>&1 && dot_sudo apt-get remove -y -qq yarn
  dot_sudo rm -f /etc/apt/sources.list.d/yarn.list
fi

# Node.js 25 and newer no longer bundle corepack
if ! command -v corepack >/dev/null 2>&1; then
  dot_info "corepack is not bundled with node $(node --version), installing it with npm"
  dot_sudo npm install -g corepack || dot_die "npm could not install corepack"
fi
dot_sudo corepack enable || dot_die "corepack enable failed"
# first run downloads yarn into the user's corepack cache; no prompt when unattended
COREPACK_ENABLE_DOWNLOAD_PROMPT=0 yarn --version || dot_die "yarn does not run after corepack enable"
dot_info "yarn and pnpm are enabled; pin a version per project with: corepack use yarn@stable"
