#!/bin/bash
# installer: digiKam photo manager
# systems: desktop
# Installs digikam with the package manager of this system (RHEL family: from EPEL); safe to run again.
# category: desktop
# check: digikam
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

dot_epel && dot_pkg_install digikam || dot_die "installing digikam failed"
dot_info "digikam installed"
