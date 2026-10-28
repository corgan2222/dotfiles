#!/bin/bash
# installer: nmap network scanner
# systems: all
# Installs nmap from the package manager of this system. Safe to run again.
#   nmap.sh
# category: base
# check: nmap
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

dot_pkg_install nmap || dot_die "could not install the nmap package"
nmap --version | head -n 1
