#!/bin/bash
# installer: GIMP image editor
# systems: desktop
# Installs gimp with the package manager of this system; safe to run again.
# category: desktop
# check: gimp
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

dot_pkg_install gimp || dot_die "installing gimp failed"
dot_info "gimp installed"
