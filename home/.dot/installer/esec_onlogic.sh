#!/bin/bash
# installer: OnLogic box setup: basics, MQTT tools, Docker, TeamViewer
# systems: ubuntu
# Runs basics.sh, docker.sh and teamviewer.sh from this folder in turn, plus the MQTT and pip tools the boxes need.
# teamviewer.sh picks the full client on a box with a desktop, TeamViewer Host without; arguments go to it.
#   esec_onlogic.sh          esec_onlogic.sh host
# category: server
# check: teamviewer docker
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

dir=$(dirname "$(readlink -f "$0")")
bash "$dir/basics.sh" || dot_die "basics.sh failed"
# box specific: the boxes talk MQTT and run Python scripts
dot_pkg_install mosquitto-clients python3-pip || dot_die "installing mosquitto-clients and python3-pip failed"
bash "$dir/docker.sh" || dot_die "docker.sh failed"
bash "$dir/teamviewer.sh" "$@" || dot_die "teamviewer.sh failed"
dot_info "OnLogic setup done"
