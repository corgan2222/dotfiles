#!/bin/bash
# installer: KrakenD Community Edition API gateway, with an example health endpoint
# systems: debian fedora rhel amd64 arm64
# modes: native compose portainer
# Natively: package krakend from KrakenD's apt or rpm repository (amd64 only, the vendor builds no arm64 packages),
# key trusted only with the fingerprint below (Devops Faith Package Manager, checked 28.10.26); enables
# krakend.service, which runs as user krakend. On arm64 use --docker.
#   krakend.sh --docker | --portainer   image krakend:3 (Docker official image) as compose project or Portainer stack
#                                       "krakend" from /opt/krakend, config /opt/krakend/krakend.json (keep
#                                       "port": 8080 there, compose.yaml publishes it on KRAKEND_PORT)
#   KRAKEND_PORT=7200 krakend.sh        port of the first run (default 7200: upstream's 8080 is taken too often)
#   --public / --local                  all interfaces (default, a gateway is there for others) or this host only
# The config (/etc/krakend/krakend.json, Docker: /opt/krakend/krakend.json) is written on the first run only, before
# the package goes in, so the package keeps it (dpkg and rpm leave an existing config alone). It holds one example:
# GET /health, proxied to KrakenD's own /__health. Later runs keep it and update KrakenD or its image. After an edit:
#   krakend check -c /etc/krakend/krakend.json && sudo systemctl restart krakend
#   Docker: sudo docker run --rm -v /opt/krakend/krakend.json:/etc/krakend/krakend.json:ro krakend:3 \
#             check -c /etc/krakend/krakend.json && sudo docker restart krakend
# KrakenD CE has no login and no admin UI; the config is the whole state. Docs: https://www.krakend.io/docs/
# category: server
# ports: KRAKEND_PORT=7200
# check: krakend.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

fpr=5B270F2E01E375FD9D5635E25DE6FD698AD6FDD2
key="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x$fpr"
port=${KRAKEND_PORT:-7200}
case $port in ''|*[!0-9]*) dot_die "KRAKEND_PORT must be a number, got '$port'" ;; esac

# prints the config: $1 the port KrakenD listens on, $2 the address (empty: all interfaces). The example endpoint
# asks KrakenD itself, so it answers without any other service.
krakend_json() {
  local back=${2:-127.0.0.1}
  [ "$back" = 0.0.0.0 ] && back=127.0.0.1
  cat <<EOF
{
  "\$schema": "https://www.krakend.io/schema/v3.0/krakend.json",
  "version": 4,
  "name": "KrakenD written by krakend.sh",
  "port": $1,${2:+
  \"listen_ip\": \"$2\",}
  "timeout": "3s",
  "endpoints": [
    {
      "endpoint": "/health",
      "method": "GET",
      "backend": [
        {
          "host": ["http://$back:$1"],
          "url_pattern": "/__health",
          "encoding": "json"
        }
      ]
    }
  ]
}
EOF
}

if [ "$DOT_MODE" != native ]; then
  dest=/opt/krakend
  dot_mode_guard krakend krakend "$port"
  # the address of an earlier run, so that running again keeps it
  old=$(dot_sudo sed -n 's/^ *- "\(.*\):[0-9]*:8080"$/\1/p' "$dest/compose.yaml" 2>/dev/null)
  dot_bind 0.0.0.0 "$old"
  dot_sudo install -d -m 0755 "$dest" || exit 1
  # inside the container KrakenD listens on 8080 on all interfaces, Docker publishes it on the chosen port
  krakend_json 8080 | dot_put_new "$dest/krakend.json"
  if [ -z "${DOT_NO_START:-}" ]; then
    dot_docker_ready krakend
    # a broken config would only show as a container that restarts over and over
    dot_sudo docker run -q --rm -v "$dest/krakend.json:/etc/krakend/krakend.json:ro" krakend:3 \
      check -c /etc/krakend/krakend.json >/dev/null || dot_die "krakend check rejects $dest/krakend.json"
  fi
  dot_deploy krakend "services:
  krakend:
    image: krakend:3
    container_name: krakend
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:$port:8080\"
    volumes:
      - $dest/krakend.json:/etc/krakend/krakend.json:ro"
  # "[address:]port" as written on the first run; a different answer now is only reported
  pub=$(dot_sudo sed -n 's/^ *- "\(.*\):8080"$/\1/p' "$dest/compose.yaml")
  case $pub in *:*) bound=${pub%:*} ;; *) bound=0.0.0.0 ;; esac
  port=${pub##*:}
  if [ "$bound" != "$DOT_BIND" ]; then
    echo "warning: KrakenD keeps listening on $bound (set on the first run), edit $dest/compose.yaml to change it" >&2
    DOT_BIND=$bound
  fi
  here=$([ "$bound" = 0.0.0.0 ] && echo localhost || echo "$bound")
  [ -n "${DOT_NO_START:-}" ] || dot_wait_http "http://$here:$port/__health" 60 ||
    dot_die "KrakenD does not answer on port $port, see: sudo docker logs krakend"
  dot_summary krakend "http://localhost:$port/health" "none (KrakenD CE has no login; config $dest/krakend.json)"
  exit 0
fi

[ "$DOT_ARCH" = amd64 ] ||
  dot_die "KrakenD's apt and rpm repositories have amd64 packages only, run krakend.sh --docker on $DOT_ARCH"
case $DOT_PKG in
  apt|dnf|yum) ;;
  *) dot_die "krakend.sh needs apt or dnf natively, not $DOT_OS; or run it with --docker" ;;
esac
conf=/etc/krakend/krakend.json
# port and address of an earlier run come from its config (KrakenD's defaults: 8080, all interfaces)
old=
if dot_sudo test -f "$conf"; then
  port=$(dot_sudo sed -n 's/^ *"port": *\([0-9]*\).*/\1/p' "$conf" | head -n 1)
  old=$(dot_sudo sed -n 's/^ *"listen_ip": *"\([^"]*\)".*/\1/p' "$conf" | head -n 1)
  port=${port:-8080} old=${old:-0.0.0.0}
fi
dot_mode_guard krakend krakend "$port"
systemctl is-active -q krakend 2>/dev/null || ! dot_port_busy "$port" ||
  dot_die "port $port is already in use, KrakenD cannot start (KRAKEND_PORT=<port> for another one)"
dot_bind 0.0.0.0 "$old"

if ! dot_sudo test -f "$conf"; then
  dot_sudo install -d -m 0755 /etc/krakend || exit 1
  krakend_json "$port" "$([ "$DOT_BIND" = 0.0.0.0 ] || echo "$DOT_BIND")" | dot_put_new "$conf"
fi

case $DOT_PKG in
  apt)
    dot_need curl gpg
    tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
    curl -fsSL -o "$tmp/krakend.asc" "$key" || dot_die "could not download the key $key"
    # only the key with that fingerprint: apt trusts every key in a Signed-By file
    dot_key_only "$tmp/krakend.asc" "$fpr" >/dev/null ||
      dot_die "$key holds no key with the fingerprint $fpr, not trusting it"
    dot_apt_repo krakend "file://$tmp/krakend.asc" https://repo.krakend.io/apt stable main amd64 ;;
  *)
    # the vendor's krakend-repo rpm writes the same .repo with plain http and its own key file; https and the checked
    # key instead
    k=$(dot_rpm_key krakend "$key" "$fpr") || exit 1
    dot_rpm_repo krakend https://repo.krakend.io/rpm "$k" ;;
esac
dot_pkg_install krakend || dot_die "installing krakend failed"
dot_sudo krakend check -c "$conf" >/dev/null || dot_die "krakend check rejects $conf"

if [ -d /run/systemd/system ]; then
  dot_sudo systemctl enable krakend && dot_sudo systemctl restart krakend ||
    dot_die "krakend does not start, see: journalctl -u krakend"
  here=$DOT_BIND; [ "$here" = 0.0.0.0 ] && here=localhost
  dot_wait_http "http://$here:$port/__health" 30 ||
    dot_die "KrakenD does not answer on port $port, see: journalctl -u krakend"
else
  dot_info "no systemd running: start KrakenD with: krakend run -c $conf"
fi
dot_info "KrakenD $(krakend version 2>&1 | sed -n 's/^KrakenD Version: //p') installed, config $conf"
dot_summary krakend "http://localhost:$port/health" "none (KrakenD CE has no login; config $conf)"
