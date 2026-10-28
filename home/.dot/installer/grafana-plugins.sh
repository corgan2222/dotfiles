#!/bin/bash
# installer: Grafana plugins (panels and data sources, Grafana 12+)
# systems: debian fedora rhel
# modes: native compose portainer
# Installs the plugins below into an installed Grafana (grafana.sh) and restarts it once.
# A plugin that fails is reported at the end, the others are still installed. Safe to run again.
#   grafana-plugins.sh                         native Grafana: grafana cli plugins install
#   grafana-plugins.sh --docker | --portainer  Grafana from "grafana.sh --docker/--portainer": adds the plugins to
#                                              GF_PLUGINS_PREINSTALL in /opt/grafana/.env and redeploys the stack
# Angular-only plugins (removed in Grafana 12) and plugins deprecated or missing in the catalog
# (https://grafana.com/api/plugins/<id>) are no longer in the list.
# Natively the installed plugins are listed in /etc/grafana/grafana-plugins.list: the menu runs as the calling user and
# cannot look into /var/lib/grafana/plugins (0750 grafana), and that folder exists without any plugin (28.10.26).
# In Docker the menu sees the Grafana stack only, the plugins live in its volume.
# category: monitoring
# check: /etc/grafana/grafana-plugins.list stack:grafana
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

plugins=(
  alexanderzobnin-zabbix-app
  briangann-datatable-panel
  digrich-bubblechart-panel
  fetzerch-sunandmoon-datasource
  grafana-clock-panel
  grafana-polystat-panel
  jdbranham-diagram-panel
  larona-epict-panel
  pr0ps-trackmap-panel
  simpod-json-datasource
  vonage-status-panel
)

grafana=/usr/sbin/grafana
dest=/opt/grafana

# Docker: Grafana installs GF_PLUGINS_PREINSTALL itself in the background at start (GF_INSTALL_PLUGINS is deprecated);
# the _SYNC variant would keep Grafana from starting when one plugin fails
if [ "$DOT_MODE" != native ]; then
  dot_sudo test -f "$dest/compose.yaml" || dot_die "Grafana does not run in Docker here ($dest/compose.yaml missing): grafana.sh --$DOT_MODE first"
  dot_sudo grep -q GF_PLUGINS_PREINSTALL "$dest/compose.yaml" ||
    dot_die "$dest/compose.yaml does not pass GF_PLUGINS_PREINSTALL to Grafana: add it under environment: and run again"
  # keeps plugins added to the list by hand; one entry per plugin id (id or id@version)
  old=$(dot_sudo sed -n 's/^GF_PLUGINS_PREINSTALL=//p' "$dest/.env" 2>/dev/null)
  list=$(printf '%s\n' ${old//,/ } "${plugins[@]}" | awk -F@ 'NF && !seen[$1]++' | paste -sd, -)
  dot_env_set "$dest/.env" GF_PLUGINS_PREINSTALL "$list" || dot_die "could not write $dest/.env"
  dot_deploy grafana ""
  if [ -z "${DOT_NO_START:-}" ]; then
    [ -t 1 ] || dot_info "waiting for Grafana to install the plugins (up to 3 minutes)"
    for i in $(seq 90); do
      have=$(dot_sudo docker exec grafana grafana cli plugins ls 2>&1)
      missing=()
      for p in "${plugins[@]}"; do grep -q "^$p " <<<"$have" || missing+=("$p"); done
      dot_progress $((${#plugins[@]} - ${#missing[@]})) ${#plugins[@]} "Grafana installs the plugins"
      [ ${#missing[@]} -eq 0 ] && break
      sleep 2
    done
    dot_progress_end
    [ ${#missing[@]} -eq 0 ] || dot_die "these plugins are not installed: ${missing[*]} (see: sudo docker logs grafana)"
  fi
  dot_info "${#plugins[@]} plugins in GF_PLUGINS_PREINSTALL ($dest/.env)"
  # its own name: "grafana" would replace Grafana's login in the recap and in Bitwarden
  dot_summary grafana-plugins "http://localhost:3000/plugins" "Grafana's (grafana.sh)"
  exit 0
fi

if [ ! -x "$grafana" ] && dot_sudo test -f "$dest/compose.yaml"; then
  dot_die "Grafana runs in Docker here ($dest): grafana-plugins.sh --docker (or --portainer)"
fi
[ -x "$grafana" ] || dot_die "Grafana is not installed ($grafana missing), run grafana.sh first"

failed=()
for p in "${plugins[@]}"; do
  dot_info "plugin $p"
  # grafana cli logs a lot, show its output only when it fails
  if ! out=$(dot_sudo "$grafana" cli plugins install "$p" 2>&1); then
    echo "$out" | tail -n 3 >&2
    failed+=("$p")
  fi
done

if [ -d /run/systemd/system ]; then
  dot_sudo systemctl restart grafana-server || echo "warning: could not restart grafana-server" >&2
else
  dot_info "no systemd running: restart Grafana by hand to load the plugins"
fi
for p in "${plugins[@]}"; do [[ " ${failed[*]} " == *" $p "* ]] || echo "$p"; done |
  dot_sudo tee /etc/grafana/grafana-plugins.list >/dev/null
[ ${#failed[@]} -eq 0 ] || dot_die "these plugins failed: ${failed[*]}"
dot_info "installed ${#plugins[@]} plugins"
dot_summary grafana-plugins "http://localhost:3000/plugins" "Grafana's (grafana.sh)" grafana-server
