#!/bin/bash
# installer: Grafana OSS from apt.grafana.com or rpm.grafana.com (stable, or beta)
# systems: debian fedora rhel
# modes: native compose portainer
# Installs Grafana OSS from Grafana's apt or rpm repository and enables the service where systemd runs.
#   grafana.sh         stable channel
#   grafana.sh beta    beta channel (Loki and Alloy then also come from beta, they share the repository)
#   grafana.sh --docker | --portainer   image grafana/grafana:latest as compose project or Portainer stack "grafana"
#                      from /opt/grafana (data in the volume grafana_data); stable channel only. In the host
#                      network: it reaches Prometheus, VictoriaMetrics, Loki and others of this host on 127.0.0.1,
#                      where they listen by default; prometheus.sh and victoriametrics.sh add their datasource in
#                      /opt/grafana/provisioning/datasources (mounted). An older compose.yaml without it is kept.
#   GRAFANA_ADMIN_PASSWORD=…   password of the user admin on the first start, else generated; stored root-only in
#                      /etc/grafana/admin-password (native) or /opt/grafana/.env (Docker)
#   --public / --local listen on all interfaces or on this host only (else asked, default all)
# Web UI on port 3000. Plugins: grafana-plugins.sh
# category: monitoring
# ports: 3000
# check: grafana-server.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

channel=${1:-stable}
case $channel in stable|beta) ;; *) dot_die "unknown channel '$channel', use stable or beta" ;; esac
pwfile=/etc/grafana/admin-password
pw=${GRAFANA_ADMIN_PASSWORD:-}
dot_secret_ok "$pw" || dot_die "GRAFANA_ADMIN_PASSWORD must not contain spaces, quotes, \$ or backslashes"


dot_mode_guard grafana grafana-server 3000
dot_bind 0.0.0.0

if [ "$DOT_MODE" != native ]; then
  [ "$channel" = stable ] || dot_die "the beta channel is for the native install only"
  [ -n "$pw" ] || pw=$(dot_password 20)
  # Host network, not a published port: the local datasources listen on 127.0.0.1 by default (menu, 28.10.26), which
  # a bridge network cannot reach; extra_hosts with host-gateway reaches the bridge address only, not 127.0.0.1.
  # The installer order (grafana before or after prometheus) then does not matter for reaching them.
  dot_sudo install -d -m 0755 /opt/grafana/provisioning/datasources || exit 1
  dot_deploy grafana "services:
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    network_mode: host
    environment:
      GF_SERVER_HTTP_ADDR: $DOT_BIND
      GF_SECURITY_ADMIN_PASSWORD: \${GF_SECURITY_ADMIN_PASSWORD:-}
      GF_PLUGINS_PREINSTALL: \${GF_PLUGINS_PREINSTALL:-}
    volumes:
      - data:/var/lib/grafana
      - /opt/grafana/provisioning/datasources:/etc/grafana/provisioning/datasources
volumes:
  data:" "GF_SECURITY_ADMIN_PASSWORD=$pw"
  if [ "$(dot_grafana_docker)" = bridge ]; then
    dot_info "Grafana keeps the bridge network of its earlier compose.yaml: it reaches services of this host on their"
    dot_info "  network address only, not on 127.0.0.1; move /opt/grafana/compose.yaml away and run again to change it"
    # the kept file says where it listens
    DOT_BIND=$(dot_sudo sed -n 's/^ *- "\(.*\):3000:3000"$/\1/p' /opt/grafana/compose.yaml)
  else
    DOT_BIND=$(dot_sudo sed -n 's/^ *GF_SERVER_HTTP_ADDR: *//p' /opt/grafana/compose.yaml)
    # the host network passes Docker's own firewall rules by, firewalld and ufw see the port like a native one
    [ "$DOT_BIND" = 127.0.0.1 ] || dot_firewall_open 3000
  fi
  # Grafana takes the password when it creates its database: an older data volume keeps the older password
  dot_summary grafana "http://localhost:3000" "user admin, password: GF_SECURITY_ADMIN_PASSWORD in /opt/grafana/.env"
  exit 0
fi

case $DOT_PKG in
  apt) dot_apt_repo grafana https://apt.grafana.com/gpg.key https://apt.grafana.com "$channel" main ;;
  # the beta channel is a repository of its own there
  dnf|yum) dot_rpm_repo grafana "https://rpm$([ "$channel" = beta ] && echo -beta).grafana.com" https://rpm.grafana.com/gpg.key repo_gpgcheck=1 ;;
  *) dot_die "grafana.sh supports Debian-based systems, Fedora and the RHEL family, not $DOT_OS" ;;
esac
dot_pkg_install grafana || dot_die "installing the grafana package failed"

ini=/etc/grafana/grafana.ini
dot_sudo sed -i "s|^;\{0,1\}http_addr *=.*|http_addr = $DOT_BIND|" "$ini" || dot_die "could not set http_addr in $ini"
# the admin password only counts when Grafana creates its database, so only a fresh install gets one
if ! dot_sudo test -f /var/lib/grafana/grafana.db && ! dot_sudo test -f "$pwfile"; then
  [ -n "$pw" ] || pw=$(dot_password 20)
  printf '%s\n' "$pw" | dot_sudo install -m 0640 -g grafana /dev/stdin "$pwfile" || dot_die "could not write $pwfile"
  dot_sudo sed -i "s|^;\{0,1\}admin_password *=.*|admin_password = \$__file{$pwfile}|" "$ini"
fi

if [ -d /run/systemd/system ]; then
  dot_sudo systemctl daemon-reload
  dot_sudo systemctl enable grafana-server && dot_sudo systemctl restart grafana-server || dot_die "could not start grafana-server"
else
  dot_info "no systemd running: start Grafana with: sudo /usr/sbin/grafana server --homepath /usr/share/grafana --config /etc/grafana/grafana.ini"
fi
dot_info "Grafana $(dot_pkg_version grafana) ($channel) installed, config $ini"
if dot_sudo test -f "$pwfile"; then
  login="user admin, password in $pwfile: sudo cat $pwfile"
else
  login="user admin, password unchanged: Grafana's database is older than this installer (default admin, changed at the first login)"
fi
dot_summary grafana "http://localhost:3000" "$login" grafana-server
