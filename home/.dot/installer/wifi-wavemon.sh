#!/bin/bash
# installer: wavemon Wi-Fi monitor
# systems: debian arch fedora
# Installs wavemon, a terminal monitor for Wi-Fi signal and link quality; start it with: wavemon
# The RHEL family has no wavemon package, not even in EPEL.
# category: sysop
# check: wavemon
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

dot_pkg_install wavemon || dot_die "installing wavemon failed"
dot_info "start it with: wavemon"
