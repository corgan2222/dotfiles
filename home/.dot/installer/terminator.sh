#!/bin/bash
# installer: Terminator terminal emulator
# systems: desktop
# Installs terminator with the package manager of this system (RHEL family: from EPEL); safe to run again.
# category: desktop
# check: terminator
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

dot_epel && dot_pkg_install terminator || dot_die "installing terminator failed"
dot_info "terminator installed"
