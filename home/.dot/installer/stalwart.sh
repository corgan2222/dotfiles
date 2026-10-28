#!/bin/bash
# installer: Stalwart mail server (SMTP, IMAP, POP3, JMAP, Sieve) with web admin, native or in Docker
# systems: debian arch fedora rhel
# modes: native compose portainer
# Stalwart 1.x (stalw.art): one binary for mail, calendars and contacts plus its web admin.
#   stalwart.sh                 natively in the layout of upstream's install.sh: the binary of the newest GitHub
#                               release (sha256 checked) in /usr/local/bin, user stalwart, config and stalwart.env in
#                               /etc/stalwart, data /var/lib/stalwart, systemd unit stalwart; running again updates it
#   stalwart.sh --docker        image stalwartlabs/stalwart:v1 as compose project "stalwart" from /opt/stalwart,
#                               config and data in its volumes etc and data; --portainer as a stack
#   STALWART_DOMAIN=example.org         first run: finish the setup unattended, mail domain example.org, admin
#   STALWART_HOSTNAME=mail.example.org  admin@example.org with a generated password (host name default mail.<domain>).
#                               Without a domain the setup wizard at /admin asks, logged in as admin with the
#                               temporary password Stalwart prints at every start until the setup is done.
#   STALWART_PORT=7180          plain HTTP of the web admin and setup wizard (upstream 8080, taken here)
#   STALWART_TLS_PORT=7143      Docker: host port of HTTPS for web admin and JMAP (upstream 443)
#   --public / --local          Docker: web ports on all interfaces or this host only (first run, default this host).
#                               The mail ports 25 465 993 995 4190 are on all interfaces: other servers deliver there.
# Natively Stalwart binds every listener on all interfaces itself, and after the setup its web admin moves to its
# default listeners HTTPS 443 and HTTP 8080; a port another service holds is skipped and named in the summary,
# change it in the web admin (Settings > Network > Listeners). Its unit conflicts with postfix, exim4 and sendmail.
# category: server
# ports: STALWART_PORT=7180 25 465 993 995 4190 INSTALL_MODE=compose,portainer:STALWART_TLS_PORT=7143
# check: stalwart.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
case ${1:-} in
  -h|--help) sed -n '5,21s/^# \{0,1\}//p' "$0"; exit 0 ;;
  "") ;;
  *) dot_die "unknown option $1" ;;
esac

domain=${STALWART_DOMAIN:-}
host=${STALWART_HOSTNAME:-${domain:+mail.$domain}}
case $domain$host in
  *[!A-Za-z0-9.-]*) dot_die "STALWART_DOMAIN and STALWART_HOSTNAME may hold letters, digits, . and - only" ;;
esac
port=${STALWART_PORT:-} tls=${STALWART_TLS_PORT:-}
case $port$tls in *[!0-9]*) dot_die "STALWART_PORT and STALWART_TLS_PORT must be numbers" ;; esac
mail_ports="25 465 993 995 4190"
dot_need curl jq
dot_mode_guard stalwart stalwart $mail_ports ${port:-7180} ${tls:-7143}

# prints the temporary admin password of the newest bootstrap start from the log on stdin
boot_pw() { sed -n 's/^ *password: *\([^ ]*\).*/\1/p' | tail -n 1; }

if [ "$DOT_MODE" = native ]; then
  dir=/etc/stalwart env=/etc/stalwart/stalwart.env unitf=/etc/systemd/system/stalwart.service
  [ -d /run/systemd/system ] || dot_die "Stalwart natively needs a running systemd, use --docker"
  case $DOT_ARCH in
    amd64) triple=x86_64-unknown-linux-gnu ;;
    arm64) triple=aarch64-unknown-linux-gnu ;;
    armv7) triple=armv7-unknown-linux-gnueabihf ;;
    armv6) triple=arm-unknown-linux-gnueabihf ;;
    *) dot_die "Stalwart has no build for $DOT_ARCH" ;;
  esac
  # port 25 takes one mail server only: the unit's Conflicts= would stop postfix or exim4 without a word
  if ! systemctl is-active -q stalwart && dot_port_busy 25; then
    dot_die "port 25 is taken (postfix, exim4?): remove that mail server first"
  fi
  [ "${BIND_ADDR:-}" != 127.0.0.1 ] ||
    dot_info "natively Stalwart listens on all interfaces, limit its listeners in the web admin"
  DOT_BIND=0.0.0.0
  [ -n "$port" ] || port=$(dot_sudo sed -n 's/^STALWART_RECOVERY_MODE_PORT=//p' "$env" 2>/dev/null)
  port=${port:-7180}
  changed=
  tag=$(dot_github_latest stalwartlabs/stalwart) || dot_die "cannot read the latest Stalwart release from GitHub"
  have=$(/usr/local/bin/stalwart --version 2>/dev/null)
  if [ "${have##* }" = "${tag#v}" ]; then
    dot_info "Stalwart $tag is installed"
  else
    dot_need tar
    tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
    dot_info "Downloading Stalwart $tag ($triple)"
    dot_github_fetch stalwartlabs/stalwart "/stalwart-$triple\.tar\.gz$" "$tmp/stalwart.tar.gz" "$tag" || exit 1
    tar -xzf "$tmp/stalwart.tar.gz" -C "$tmp" stalwart || dot_die "could not unpack the Stalwart release"
    dot_sudo install -m 0755 "$tmp/stalwart" /usr/local/bin/stalwart.new &&
      dot_sudo mv -f /usr/local/bin/stalwart.new /usr/local/bin/stalwart || dot_die "could not install the binary"
    changed=1
  fi
  id stalwart >/dev/null 2>&1 || dot_sudo useradd stalwart -s /usr/sbin/nologin -M -r -U ||
    dot_die "could not create the user stalwart"
  dot_sudo install -d -m 0750 -o stalwart -g stalwart "$dir" /var/lib/stalwart /var/log/stalwart || exit 1
  # the port of the wizard (recovery mode); systemd reads the env file as root, so it stays root's (0600)
  if [ "$(dot_sudo sed -n 's/^STALWART_RECOVERY_MODE_PORT=//p' "$env" 2>/dev/null)" != "$port" ]; then
    dot_env_set "$env" STALWART_RECOVERY_MODE_PORT "$port" || exit 1
    changed=1
  fi
  # upstream's unit (install.sh, 28.10.26); CAP_NET_BIND_SERVICE for the ports below 1024
  unit="[Unit]
Description=Stalwart
Conflicts=postfix.service sendmail.service exim4.service
After=network-online.target

[Service]
Type=simple
LimitNOFILE=65536
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
EnvironmentFile=-$env
ExecStart=/usr/local/bin/stalwart --config=$dir/config.json
SyslogIdentifier=stalwart
User=stalwart
Group=stalwart
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target"
  if [ "$(cat "$unitf" 2>/dev/null)" != "$unit" ]; then
    printf '%s\n' "$unit" | dot_sudo tee "$unitf" >/dev/null && dot_sudo systemctl daemon-reload || exit 1
    changed=1
  fi
  dot_sudo systemctl enable -q stalwart || exit 1
  # t0: the log of this start only, the bootstrap password of an earlier start is void
  t0=
  if [ -n "$changed" ] || ! systemctl is-active -q stalwart; then
    t0=$(date +%s)
    dot_sudo systemctl restart stalwart || dot_die "Stalwart does not start, see: journalctl -u stalwart"
  fi
  logs() { dot_sudo journalctl -u stalwart -o cat ${t0:+--since @$t0} 2>/dev/null; }
  # the journal tracer keeps the reason of an event in a field of its own (REASON=), -o cat shows the title only
  events() { dot_sudo journalctl -u stalwart -o verbose ${t0:+--since @$t0} 2>/dev/null; }
  restart() { t0=$(date +%s); dot_sudo systemctl restart stalwart; }
  is_setup() { dot_sudo test -f "$dir/config.json"; }
  logcmd="journalctl -u stalwart"
  bound=127.0.0.1
else
  dir=/opt/stalwart
  # "[address:]port" of the web ports as written on the first run
  old=$(dot_sudo sed -n 's/^ *- "\(.*\):8080"$/\1/p' "$dir/compose.yaml" 2>/dev/null)
  case $old in *:*) dot_bind 127.0.0.1 "${old%:*}" ;; ?*) dot_bind 127.0.0.1 0.0.0.0 ;; *) dot_bind 127.0.0.1 ;; esac
  # the mail ports without an address: Docker publishes them on all interfaces, IPv4 and IPv6
  mp=; for p in $mail_ports; do mp+="
      - \"$p:$p\""; done
  dot_deploy stalwart "services:
  stalwart:
    image: stalwartlabs/stalwart:v1
    container_name: stalwart
    restart: unless-stopped
    init: true
    ports:$mp
      - \"$DOT_BIND:${tls:-7143}:443\"
      - \"$DOT_BIND:${port:-7180}:8080\"
    volumes:
      - etc:/etc/stalwart
      - data:/var/lib/stalwart
volumes:
  etc:
  data:"
  pub=$(dot_sudo sed -n 's/^ *- "\(.*\):8080"$/\1/p' "$dir/compose.yaml")
  tls=$(dot_sudo sed -n 's/^ *- "\(.*\):443"$/\1/p' "$dir/compose.yaml") tls=${tls##*:}
  case $pub in *:*) bound=${pub%:*} ;; *) bound=0.0.0.0 ;; esac
  port=${pub##*:}
  if [ "$bound" != "$DOT_BIND" ]; then
    echo "warning: Stalwart's web ports stay on $bound (set on the first run), edit $dir/compose.yaml to change it" >&2
    DOT_BIND=$bound
  fi
  logs() { dot_sudo docker logs stalwart 2>&1; }
  events() { logs; }
  restart() { dot_sudo docker restart stalwart >/dev/null; }
  is_setup() { dot_sudo docker exec stalwart test -f /etc/stalwart/config.json; }
  logcmd="sudo docker logs stalwart"
fi

read -r ip _ < <(hostname -I 2>/dev/null)
mail="smtp://${ip:-localhost}:25 smtps://${ip:-localhost}:465 imaps://${ip:-localhost}:993"
mail+=" pop3s://${ip:-localhost}:995 sieve://${ip:-localhost}:4190"
if [ "$DOT_MODE" = native ]; then web="http://localhost:$port/admin"
else web="http://localhost:$port/admin https://localhost:$tls/admin"; fi
creds=$dir/admin-credentials bootf=$dir/bootstrap-password
if [ -n "${DOT_NO_START:-}" ]; then
  dot_summary stalwart "$web $mail" "setup wizard at /admin, user admin, temporary password in: $logcmd"
  exit 0
fi
[ "$bound" = 0.0.0.0 ] && url=http://127.0.0.1:$port || url=http://$bound:$port

if ! is_setup; then
  dot_wait_http "$url/healthz/live" 120 || dot_die "Stalwart does not answer on $url, see: $logcmd"
  pw=
  for _ in $(seq 30); do pw=$(logs | boot_pw); [ -n "$pw" ] && break; sleep 1; done
  [ -n "$pw" ] || dot_die "Stalwart printed no temporary admin password, see: $logcmd"
  if [ -n "$domain" ]; then
    # what the wizard sends (x:Bootstrap/set, JMAP), with the wizard's defaults (RocksDB, internal directory, ACME
    # certificate, DKIM keys) and the log to the journal or Docker's log instead of files; the password goes in on
    # stdin, not on curl's command line
    [ "$DOT_MODE" = native ] && tracer=Journal || tracer=Stdout
    body=$(jq -nc --arg h "$host" --arg d "$domain" --arg t "$tracer" '{using: ["urn:ietf:params:jmap:core",
      "urn:stalwart:jmap"], methodCalls: [["x:Bootstrap/set", {update: {singleton: {defaultHostname: $h,
      defaultDomain: $d, tracer: {"@type": $t}}}}, "c1"]]}')
    r=$(printf 'user = "admin:%s"\n' "$pw" | curl -fsS -m 60 -K - -H 'Content-Type: application/json' \
      --data "$body" "$url/jmap/") || dot_die "the setup request to Stalwart failed"
    user=$(jq -r '.methodResponses[0][1].updated.singleton.username // empty' <<<"$r")
    secret=$(jq -r '.methodResponses[0][1].updated.singleton.secret // empty' <<<"$r")
    [ -n "$user" ] && [ -n "$secret" ] ||
      dot_die "Stalwart refused the setup: $(jq -c '.methodResponses[0][1]' <<<"$r")"
    printf '%s:%s\n' "$user" "$secret" | dot_sudo sh -c "umask 077; cat > '$creds'" || exit 1
    dot_sudo rm -f "$bootf"
    dot_info "setup done for $domain (host $host), restarting Stalwart out of bootstrap mode"
    restart || dot_die "Stalwart does not restart, see: $logcmd"
  else
    printf '%s\n' "$pw" | dot_sudo sh -c "umask 077; cat > '$bootf'" || exit 1
  fi
fi

if is_setup || [ -n "$domain" ]; then
  dot_sudo rm -f "$bootf"
  # natively the web admin is now on the default listeners
  [ "$DOT_MODE" != native ] || { url=http://127.0.0.1:8080 web="https://localhost/admin http://localhost:8080/admin"; }
  end=$((SECONDS + 60))
  until banner=$(timeout 5 bash -c 'exec 3<>/dev/tcp/127.0.0.1/25 && head -n 1 <&3' 2>/dev/null) &&
    [[ $banner == 220* ]]; do
    [ "$SECONDS" -lt "$end" ] || { dot_progress_end; banner=; break; }
    dot_progress 0 0 "waiting for SMTP on port 25"
    sleep 1
  done
  dot_progress_end
  if [ -n "$banner" ]; then dot_info "SMTP answers: ${banner%$'\r'}"
  else echo "warning: no SMTP greeting on port 25, see: $logcmd" >&2; fi
  dot_wait_http "$url/healthz/live" 60 || echo "warning: the web admin does not answer on $url" >&2
  # a listener whose port another service holds is skipped, Stalwart starts anyway (docs: server/listener)
  skipped=$(events | grep -o 'Failed to bind to [^"]*' | sort -u)
  [ -z "$skipped" ] || printf 'warning: %s\n' "$skipped" \
    "change these listeners in the web admin (Settings > Network > Listeners) and restart Stalwart" >&2
  if dot_sudo test -s "$creds"; then
    login="user $(dot_sudo cut -d: -f1 "$creds"), password: sudo cat $creds (user:password)"
  else
    login="the admin account the setup wizard made (admin@<your domain>), its password was shown once"
  fi
else
  [ "$DOT_MODE" = native ] && again="sudo systemctl restart stalwart" || again="sudo docker restart stalwart"
  login="setup wizard at /admin: user admin, temporary password: sudo cat $bootf (new at every start until the"
  login+=" setup is done); afterwards: $again"
fi
dot_summary stalwart "$web $mail" "$login; mail ports on all interfaces"
