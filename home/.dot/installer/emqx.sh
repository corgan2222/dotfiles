#!/bin/bash
# installer: EMQX MQTT broker, edition ee (6.x, BSL, free for one node) or ce (5.8, last Apache-2.0 release)
# systems: amd64 arm64
# modes: native compose portainer
# native: EMQ's apt or rpm (RHEL family) repository on packagecloud.io with the service emqx; where it has no packages
# for this system (Ubuntu 26.04, Arch, Fedora, …) the compose mode is used instead. --docker / --portainer: compose project or Portainer stack
# "emqx" from /opt/emqx. Vendor minimum: 512 MB RAM.
#   emqx.sh [ee]        EMQX 6.x ("Enterprise"): since 5.9 the only maintained edition, Business Source License 1.1,
#                       free in production on a single node, a cluster needs a license key
#   emqx.sh ce          EMQX 5.8.x, the last open source (Apache-2.0) release; frozen, no new releases
#   emqx.sh … --no-start          install and configure only, do not start (no Docker in the container modes)
#   EMQX_DASHBOARD_PASSWORD=…     password of the dashboard user admin (8-64 chars), else one is generated
#   EMQX_MQTT_PORT=1884 EMQX_DASHBOARD_PORT=18083   other ports for the first run (MQTT defaults to 1883)
#   --public / --local            MQTT and dashboard on all interfaces or this host only (first run, else asked)
# Port 1883 is also Mosquitto's (mosquitto.sh): the first run stops when it is taken, set EMQX_MQTT_PORT then.
# Secrets (dashboard password, Erlang cookie) live in /opt/emqx/.env (0600). Dashboard: http://<host>:18083
# category: server
# ports: EMQX_MQTT_PORT=1883 EMQX_DASHBOARD_PORT=18083 8083 8084 8883
# check: emqx.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

dest=/opt/emqx
envf=$dest/.env
compose=$dest/compose.yaml
edition=ee nostart=
for a in "$@"; do
  case $a in
    ee|ce) edition=$a ;;
    --no-start) nostart=1 ;;
    -h|--help) sed -n '5,16s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) dot_die "unknown argument $a, use ee, ce, --no-start, --docker or --portainer" ;;
  esac
done
case $DOT_ARCH in amd64|arm64) ;; *) dot_die "EMQX has packages and images for amd64 and arm64 only, not $DOT_ARCH" ;; esac
dot_bind 0.0.0.0
if [ $edition = ee ]; then
  repo=emqx-enterprise5 pkg=emqx-enterprise other=emqx image=emqx/emqx-enterprise:latest
else
  repo=emqx pkg=emqx other=emqx-enterprise image=emqx/emqx:5.8
fi
dot_need curl openssl

# true when EMQ's repository has the package for this distribution, release and architecture; the rpm repositories
# exist for every release (el/10, Fedora), most of them empty
emqx_has() {
  if [ "$DOT_PKG" = dnf ]; then
    local base="https://packagecloud.io/emqx/$repo/el/${DOT_OS_VERSION%%.*}/$(uname -m)" primary
    [ "$DOT_OS_BASE" = rhel ] || return 1
    primary=$(curl -fsSL "$base/repodata/repomd.xml" 2>/dev/null | grep -o 'repodata/[^"]*primary\.xml\.gz' | head -n 1)
    [ -n "$primary" ] && curl -fsSL "$base/$primary" 2>/dev/null | gunzip 2>/dev/null | grep -q "<name>$pkg</name>"
    return
  fi
  [ "$DOT_PKG" = apt ] && [ -n "$DOT_OS_BASE_CODENAME" ] || return 1
  curl -fsSL "https://packagecloud.io/emqx/$repo/$distro/dists/$DOT_OS_BASE_CODENAME/main/binary-$(dpkg --print-architecture)/Packages" 2>/dev/null |
    grep -qx "Package: $pkg"
}


if [ "$DOT_OS_BASE" = ubuntu ]; then distro=ubuntu; else distro=debian; fi
if [ "$DOT_MODE" = native ]; then
  if dot_sudo test -f "$compose"; then
    dot_info "EMQX runs in Docker here ($compose), staying with compose (--portainer for a Portainer stack)"
    DOT_MODE=compose
  elif ! emqx_has; then
    dot_info "EMQ's repository has no $pkg for $DOT_OS ${DOT_OS_BASE_CODENAME:-$DOT_OS_VERSION}, using Docker compose instead"
    DOT_MODE=compose
  fi
elif dot_pkg_installed emqx || dot_pkg_installed emqx-enterprise; then
  dot_die "EMQX is installed natively here (package): use --native"
fi

# secrets and ports on the first run only; running again keeps them
if ! dot_sudo test -f "$envf"; then
  mqtt=${EMQX_MQTT_PORT:-1883} dash=${EMQX_DASHBOARD_PORT:-18083}
  if dot_port_busy "$mqtt"; then
    if [ -d /run/systemd/system ] && systemctl is-active -q mosquitto 2>/dev/null; then
      dot_die "Mosquitto already uses port $mqtt: stop it or run with EMQX_MQTT_PORT=1884"
    fi
    dot_die "port $mqtt is taken: free it or run with EMQX_MQTT_PORT=<port>"
  fi
  dot_port_busy "$dash" && dot_die "port $dash is taken: run with EMQX_DASHBOARD_PORT=<port>"
  pw=${EMQX_DASHBOARD_PASSWORD:-$(dot_password 32)}
  [ ${#pw} -ge 8 ] && [ ${#pw} -le 64 ] || dot_die "EMQX_DASHBOARD_PASSWORD must have 8 to 64 characters"
  dot_sudo install -d -m 0755 "$dest" || exit 1
  # the cookie guards the Erlang distribution port 4370, the packaged default is public; the listener addresses are
  # only used natively, the containers keep theirs and publish them on the ports below
  {
    printf 'EMQX_DASHBOARD__DEFAULT_PASSWORD=%s\n' "$pw"
    printf 'EMQX_NODE__COOKIE=%s\n' "$(openssl rand -hex 24)"
    if [ "$DOT_MODE" = native ]; then
      # address:port must reach EMQX as a HOCON string ("…"); the single quotes keep those for systemd and sh
      printf "EMQX_LISTENERS__TCP__DEFAULT__BIND='\"%s\"'\n" "$DOT_BIND:$mqtt"
      printf "EMQX_LISTENERS__SSL__DEFAULT__BIND='\"%s\"'\n" "$DOT_BIND:8883"
      printf "EMQX_LISTENERS__WS__DEFAULT__BIND='\"%s\"'\n" "$DOT_BIND:8083"
      printf "EMQX_LISTENERS__WSS__DEFAULT__BIND='\"%s\"'\n" "$DOT_BIND:8084"
      printf "EMQX_DASHBOARD__LISTENERS__HTTP__BIND='\"%s\"'\n" "$DOT_BIND:$dash"
    fi
  } | dot_sudo sh -c "umask 077; cat > '$envf'" || exit 1
  dot_info "wrote $envf"
  fresh=1
else
  dot_info "keeping $envf"
  fresh=
fi
pw=$(dot_sudo sed -n 's/^EMQX_DASHBOARD__DEFAULT_PASSWORD=//p' "$envf")

if [ "$DOT_MODE" = native ]; then
  dot_pkg_installed "$other" && dot_die "the package $other (other edition) is installed: remove it first with sudo $DOT_PKG remove $other"
  if [ "$DOT_PKG" = dnf ]; then
    # the .repo file packagecloud's script.rpm.sh installs: signed metadata, unsigned packages
    dot_rpm_repo emqx "https://packagecloud.io/install/repositories/emqx/$repo/config_file.repo?os=el&dist=${DOT_OS_VERSION%%.*}&source=script"
  else
    dot_apt_repo emqx "https://packagecloud.io/emqx/$repo/gpgkey" "https://packagecloud.io/emqx/$repo/$distro" "$DOT_OS_BASE_CODENAME" main
  fi
  dot_pkg_install "$pkg" || dot_die "installing the package $pkg failed"
  # the package resets /etc/emqx/* to 0644 on every update, so the secrets come from /opt/emqx through systemd
  dot_sudo install -d -m 0755 /etc/systemd/system/emqx.service.d &&
    printf '[Service]\nEnvironmentFile=%s\n' "$envf" | dot_sudo tee /etc/systemd/system/emqx.service.d/secrets.conf >/dev/null ||
    exit 1
  file=$envf dash=$(dot_sudo sed -n 's/^EMQX_DASHBOARD__LISTENERS__HTTP__BIND=//p' "$envf" | tr -d "'\"")
  mqtt=$(dot_sudo sed -n 's/^EMQX_LISTENERS__TCP__DEFAULT__BIND=//p' "$envf" | tr -d "'\"")
  if [ ! -d /run/systemd/system ]; then
    dot_info "no systemd running: start EMQX with: sudo sh -c 'set -a; . $envf; exec runuser -u emqx -- emqx foreground'"
    exit 0
  fi
  dot_sudo systemctl daemon-reload && dot_sudo systemctl enable emqx >/dev/null 2>&1
  if [ -n "$nostart" ]; then
    dot_info "--no-start: start EMQX later with: sudo systemctl start emqx"
    exit 0
  fi
  dot_sudo systemctl restart emqx || dot_die "EMQX does not start, see: journalctl -u emqx"
else
  # the image runs as uid 1000; port 4370 (Erlang distribution) stays inside
  dot_sudo install -d -m 0750 -o 1000 -g 1000 "$dest/data" "$dest/log" || exit 1
  yaml="services:
  emqx:
    image: $image
    container_name: emqx
    restart: unless-stopped
    environment:
      EMQX_DASHBOARD__DEFAULT_PASSWORD: \${EMQX_DASHBOARD__DEFAULT_PASSWORD}
      EMQX_NODE__COOKIE: \${EMQX_NODE__COOKIE}
    ports:
      - \"$DOT_BIND:${EMQX_MQTT_PORT:-1883}:1883\"
      - \"$DOT_BIND:8083:8083\"
      - \"$DOT_BIND:8084:8084\"
      - \"$DOT_BIND:8883:8883\"
      - \"$DOT_BIND:${EMQX_DASHBOARD_PORT:-18083}:18083\"
    volumes:
      - $dest/data:/opt/emqx/data
      - $dest/log:/opt/emqx/log"
  if dot_sudo test -f "$compose" && ! dot_sudo grep -q "image: $image" "$compose"; then
    echo "warning: $compose uses another EMQX image than $image (other edition?), keeping it" >&2
  fi
  if [ -n "$nostart" ]; then
    # what dot_deploy would write, without Docker
    dot_sudo test -f "$compose" || printf '%s\n' "$yaml" | dot_sudo tee "$compose" >/dev/null
    dot_info "--no-start: wrote $compose; start EMQX later with: emqx.sh $edition --$DOT_MODE"
    exit 0
  fi
  dot_deploy emqx "$yaml"
  file=$compose dash=$(dot_sudo sed -n 's/^ *- "\(.*\):18083"$/\1/p' "$compose")
  mqtt=$(dot_sudo sed -n 's/^ *- "\(.*\):1883"$/\1/p' "$compose")
fi
# dash and mqtt are "[address:]port" as written on the first run; a different answer now is only reported
case $dash in *:*) bound=${dash%:*} ;; *) bound=0.0.0.0 ;; esac
dash=${dash##*:} mqtt=${mqtt##*:}
if [ "$bound" != "$DOT_BIND" ]; then
  echo "warning: EMQX keeps listening on $bound (set on the first run), edit $file to change it" >&2
  DOT_BIND=$bound
fi

api=http://127.0.0.1:${dash:-18083}/api/v5
dot_wait_http "http://127.0.0.1:${dash:-18083}/status" 120 || dot_die "the EMQX dashboard does not answer after 2 minutes"

# data from an earlier installation may still hold admin/public: the default password only applies to a new admin
if [ -n "$fresh" ]; then
  token=$(curl -fs -H 'Content-Type: application/json' -d '{"username":"admin","password":"public"}' "$api/login" |
    sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
  if [ -n "$token" ]; then
    jpw=$(printf '%s' "$pw" | sed 's/[\\"]/\\&/g')
    curl -fs -o /dev/null -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
      -d "{\"old_pwd\":\"public\",\"new_pwd\":\"$jpw\"}" "$api/users/admin/change_pwd" ||
      dot_die "the dashboard still has admin/public and changing it failed: change it in the dashboard now"
    dot_info "replaced the default dashboard password admin/public"
  fi
fi

[ $edition = ce ] || dot_info "license: BSL 1.1 with the built-in single-node license, see https://www.emqx.com/en/content/license-faq"
dot_summary emqx "mqtt://localhost:${mqtt:-1883} http://localhost:${dash:-18083}" \
  "dashboard user admin, password: EMQX_DASHBOARD__DEFAULT_PASSWORD in $envf; MQTT clients: anonymous until you add authentication in the dashboard"
