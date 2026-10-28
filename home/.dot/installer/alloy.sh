#!/bin/bash
# installer: Grafana Alloy, ships the systemd journal to Loki
# systems: debian fedora rhel
# modes: native compose portainer
# Installs Grafana Alloy from Grafana's apt or rpm repository with a config that sends the systemd journal
# (labels job, unit, host) to Loki, and enables the service where systemd runs. Replaces Promtail (EOL).
#   alloy.sh http://loki-host:3100              Loki base URL or full push URL
#   LOKI_URL=http://loki-host:3100 alloy.sh
#   alloy.sh … --docker | --portainer   image grafana/alloy:latest as compose project or Portainer stack "alloy" from
#              /opt/alloy with the same config (/opt/alloy/config.alloy); host network, journal mounted read-only
#   --public / --local   Alloy's web UI (port 12345, no login) on all interfaces or this host only (default local;
#                        a later run keeps the address of the earlier one)
# Overwrites /etc/alloy/config.alloy, the shipped one is kept once as config.alloy.orig. Safe to run again.
# category: logs
# ports: 12345
# check: alloy.service
# ask: LOKI_URL "Loki URL, e.g. http://loki-host:3100"
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

conf=/etc/alloy/config.alloy
dest=/opt/alloy
url=${1:-${LOKI_URL:-}}
[ -n "$url" ] || dot_die "the Loki URL is required: alloy.sh http://loki-host:3100  or  LOKI_URL=http://loki-host:3100 alloy.sh"
case $url in
  *[[:space:]\"\\]*) dot_die "invalid Loki URL '$url'" ;;
  http://*|https://*) ;;
  *) dot_die "the Loki URL must start with http:// or https://, got '$url'" ;;
esac
case $url in */loki/api/v1/push) ;; *) url=${url%/}/loki/api/v1/push ;; esac

dot_mode_guard alloy alloy 12345
# the UI address of an earlier run stays when none is given (28.10.26: a second run moved a public UI back to
# 127.0.0.1); natively in the package's defaults file, in Docker in the kept compose file
def=/etc/default/alloy
[ "$DOT_PKG" = apt ] || def=/etc/sysconfig/alloy
old=$(dot_sudo sed -n 's/.*--server\.http\.listen-addr=\([^ "]*\):12345.*/\1/p' "$def" "$dest/compose.yaml" \
  2>/dev/null | head -n 1)
dot_bind 127.0.0.1 "$old"

config="// written by alloy.sh: systemd journal -> Loki

loki.relabel \"journal\" {
  forward_to = []

  rule {
    source_labels = [\"__journal__systemd_unit\"]
    target_label  = \"unit\"
  }
}

loki.source.journal \"journal\" {
  max_age       = \"12h\"
  relabel_rules = loki.relabel.journal.rules
  labels        = {job = \"systemd-journal\", host = constants.hostname}
  forward_to    = [loki.write.default.receiver]
}

loki.write \"default\" {
  endpoint {
    url = \"$url\"
  }
}"

# Docker: host network, so that the host name, localhost Loki URLs and the UI port behave as with the package;
# the container runs as root and reads the journal through read-only mounts (the journal files are found by
# /etc/machine-id). Only journal directories that exist are mounted, Docker would create the others on the host.
if [ "$DOT_MODE" != native ]; then
  dot_sudo install -d -m 0755 "$dest"
  changed=
  if dot_sudo test -f "$dest/config.alloy" && [ "$(dot_sudo cat "$dest/config.alloy")" != "$config" ]; then changed=1; fi
  # tee keeps the inode, so the bind mount of the running container sees the new content
  printf '%s\n' "$config" | dot_sudo tee "$dest/config.alloy" >/dev/null || dot_die "could not write $dest/config.alloy"
  journal=
  for d in /var/log/journal /run/log/journal; do [ -d "$d" ] && journal+="
      - $d:$d:ro"; done
  [ -n "$journal" ] || dot_die "no systemd journal on this host (/var/log/journal, /run/log/journal)"
  dot_deploy alloy "services:
  alloy:
    image: grafana/alloy:latest
    container_name: alloy
    restart: unless-stopped
    network_mode: host
    command:
      - run
      - /etc/alloy/config.alloy
      - --storage.path=/var/lib/alloy/data
      - --server.http.listen-addr=$DOT_BIND:12345
    volumes:
      - $dest/config.alloy:/etc/alloy/config.alloy:ro
      - data:/var/lib/alloy/data
      - /etc/machine-id:/etc/machine-id:ro$journal
volumes:
  data:"
  if [ -z "${DOT_NO_START:-}" ]; then
    [ -z "$changed" ] || dot_sudo docker restart alloy >/dev/null || dot_die "could not restart alloy"
    out=$(dot_sudo docker exec alloy /bin/alloy validate /etc/alloy/config.alloy 2>&1) ||
      { echo "$out" >&2; dot_die "Alloy does not accept its config, see: sudo docker logs alloy"; }
  fi
  dot_summary alloy "http://localhost:12345" "none (UI without login); sends the journal to $url"
  exit 0
fi

# grafana.sh may have added the repository with the beta channel already, keep it
case $DOT_PKG in
  apt)
    [ -f /etc/apt/sources.list.d/grafana.sources ] ||
      dot_apt_repo grafana https://apt.grafana.com/gpg.key https://apt.grafana.com stable main ;;
  dnf|yum)
    [ -f /etc/yum.repos.d/grafana.repo ] ||
      dot_rpm_repo grafana https://rpm.grafana.com https://rpm.grafana.com/gpg.key repo_gpgcheck=1 ;;
  *) dot_die "alloy.sh supports Debian-based systems, Fedora and the RHEL family, not $DOT_OS" ;;
esac
dot_pkg_install alloy || dot_die "installing the alloy package failed"

if [ ! -f "$conf.orig" ] && dot_sudo test -f "$conf" && ! dot_sudo grep -q 'written by alloy.sh' "$conf"; then
  dot_sudo cp -p "$conf" "$conf.orig"
fi
printf '%s\n' "$config" | dot_sudo tee "$conf" >/dev/null
out=$(dot_sudo alloy validate "$conf" 2>&1) || { echo "$out" >&2; dot_die "$conf is not valid"; }

# listen address of the UI in the package's CUSTOM_ARGS ($def), other arguments there stay
if dot_sudo grep -q -- '--server.http.listen-addr=' "$def"; then
  dot_sudo sed -i "s|--server.http.listen-addr=[^ \"]*|--server.http.listen-addr=$DOT_BIND:12345|" "$def"
else
  dot_sudo sed -i "s|^CUSTOM_ARGS=\"|CUSTOM_ARGS=\"--server.http.listen-addr=$DOT_BIND:12345 |" "$def"
fi
dot_sudo grep -q -- "--server.http.listen-addr=$DOT_BIND:12345" "$def" || dot_die "could not set the listen address in $def"

# the package adds alloy to systemd-journal today; make sure, without it the journal stays unreadable
id -nG alloy | grep -qw systemd-journal || dot_sudo usermod -aG systemd-journal alloy ||
  dot_die "could not add the user alloy to the group systemd-journal"

if [ -d /run/systemd/system ]; then
  dot_sudo systemctl enable alloy && dot_sudo systemctl restart alloy || dot_die "could not start alloy"
else
  dot_info "no systemd running: start Alloy with: sudo -u alloy alloy run $conf --storage.path=/var/lib/alloy/data"
fi
dot_info "$(alloy --version | head -n 1) installed, sends the journal to $url"
dot_summary alloy "http://localhost:12345" "none (UI without login)"
