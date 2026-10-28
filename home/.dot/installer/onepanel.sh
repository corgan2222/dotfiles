#!/bin/bash
# installer: 1Panel web panel for Linux servers (fit2cloud, international edition)
# systems: ubuntu
# modes: native
# Downloads the 1Panel package of the stable channel from resource.1panel.pro, checks its sha256 against the
# checksums.txt published next to it and runs its install.sh without questions (--non-interactive plus the
# PANEL_* variables install.sh reads). Not quick_start.sh: that one downloads with "curl -k" and checks the checksum
# only for a package that was already on disk. The vendor publishes no signature, only these checksums.
# Docker comes first through docker.sh (Docker's own repository); install.sh then finds it running and keeps it as it
# is: no second Docker, daemon.json untouched (registry mirrors stay off). 1Panel runs its apps there in the network
# 1panel-network, next to other stacks.
#   onepanel.sh
#   ONEPANEL_PORT=10086          panel port (default 10086; the vendor's default is a random one)
#   ONEPANEL_USER=… ONEPANEL_PASSWORD=… ONEPANEL_ENTRANCE=…   login and security entrance (the path after the port),
#                                default random like the vendor's; letters, digits and _ (password also !@#$%*,.?)
# Port, user, password and entrance are kept root-only in /etc/1panel/credentials. Running again installs nothing:
# 1Panel updates itself in its web UI; the run says when a newer version is out.
# Side effects of the vendor's install.sh: it starts an installed but stopped firewalld or ufw to open the port, and
# asks api64.ipify.org for the public address it prints.
# category: sysop
# ports: ONEPANEL_PORT=10086
# check: 1panel-core.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

base=https://resource.1panel.pro/v2/stable
creds=/etc/1panel/credentials
case $DOT_ARCH in amd64|arm64|armv7) arch=$DOT_ARCH ;; *) dot_die "1Panel has no package for $DOT_ARCH" ;; esac
[ -d /run/systemd/system ] || dot_die "1Panel needs systemd here"
dot_need curl tar
DOT_BIND=0.0.0.0
latest=$(curl -fsS -m 20 "$base/latest") && [[ $latest =~ ^v[0-9]+(\.[0-9]+)+$ ]] ||
  dot_die "cannot read the latest 1Panel version from $base/latest"

# prints the value of a key in the credentials file
cred() { dot_sudo sed -n "s/^$1=//p" "$creds" 2>/dev/null; }

if command -v 1pctl >/dev/null 2>&1; then
  have=$(sed -n 's/^ORIGINAL_VERSION=//p' "$(command -v 1pctl)")
  dot_info "1Panel $have is installed${latest:+, newest $latest}; 1Panel updates itself in its web UI"
  systemctl is-active -q 1panel-core || dot_sudo systemctl restart 1panel-core 1panel-agent ||
    dot_die "1Panel does not start, see: journalctl -u 1panel-core"
else
  if ! dot_sudo test -f "$creds"; then
    port=${ONEPANEL_PORT:-10086} user=${ONEPANEL_USER:-$(dot_password 10)}
    pw=${ONEPANEL_PASSWORD:-$(dot_password 24)} entrance=${ONEPANEL_ENTRANCE:-$(dot_password 12)}
    [[ $port =~ ^[1-9][0-9]{0,4}$ ]] && [ "$port" -le 65535 ] || dot_die "ONEPANEL_PORT must be a port number, got '$port'"
    [[ $user =~ ^[a-zA-Z0-9_]{3,30}$ ]] || dot_die "ONEPANEL_USER: 3 to 30 letters, digits or _"
    [[ $pw =~ ^[a-zA-Z0-9_!@#%*,.?]{8,30}$ ]] || dot_die "ONEPANEL_PASSWORD: 8 to 30 letters, digits or _!@#%*,.?"
    [[ $entrance =~ ^[a-zA-Z0-9_]{3,30}$ ]] || dot_die "ONEPANEL_ENTRANCE: 3 to 30 letters, digits or _"
    dot_sudo install -d -m 0755 /etc/1panel &&
      printf 'PANEL_PORT=%s\nPANEL_USERNAME=%s\nPANEL_PASSWORD=%s\nPANEL_ENTRANCE=%s\n' "$port" "$user" "$pw" "$entrance" |
      dot_sudo sh -c "umask 077; cat > '$creds'" || dot_die "could not write $creds"
  fi
  port=$(cred PANEL_PORT)
  dot_port_busy "$port" && dot_die "port $port is taken: set ONEPANEL_PORT and delete $creds"
  dot_sudo test -f /opt/1panel/db/core.db &&
    echo "warning: /opt/1panel holds an earlier installation, install.sh keeps its login instead of $creds" >&2
  dot_docker_ready "1Panel's apps"

  pkg=1panel-$latest-linux-$arch
  tmp=$(mktemp -d) && trap 'dot_sudo rm -rf "$tmp"' EXIT
  dot_info "Downloading 1Panel $latest ($arch)"
  curl -fsSL -o "$tmp/$pkg.tar.gz" "$base/$latest/release/$pkg.tar.gz" &&
    curl -fsSL -o "$tmp/checksums.txt" "$base/$latest/release/checksums.txt" || dot_die "download of $pkg.tar.gz failed"
  sum=$(awk -v f="$pkg.tar.gz" '$2 == f || $2 == "*" f { print $1 }' "$tmp/checksums.txt")
  [ -n "$sum" ] && [ "$(sha256sum "$tmp/$pkg.tar.gz" | cut -d' ' -f1)" = "$sum" ] ||
    dot_die "checksum of $pkg.tar.gz does not match checksums.txt, aborting"
  tar -xzf "$tmp/$pkg.tar.gz" -C "$tmp" || dot_die "could not unpack $pkg.tar.gz"
  # what quick_start.sh of the international edition writes before it calls install.sh
  echo intl > "$tmp/$pkg/.selected_edition"
  # the login comes from the credentials file as environment, not on a command line; TERM=dumb keeps its "clear" quiet
  dot_sudo env TERM=dumb PANEL_LANG=en PANEL_INSTALL_DIR=/opt bash -c \
    'set -a; . "$1"; set +a; cd "$2" && exec bash install.sh --non-interactive' sh "$creds" "$tmp/$pkg" </dev/null ||
    dot_die "the 1Panel install.sh failed, see its log above"
fi

port=$(cred PANEL_PORT) entrance=$(cred PANEL_ENTRANCE)
dot_wait_http "http://localhost:$port/$entrance" 120 || dot_die "1Panel does not answer on port $port, see: journalctl -u 1panel-core"
# 1pctl user-info prints the login from 1Panel's database; it must match the credentials file
info=$(dot_sudo 1pctl user-info 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g; s/ *$//')
if grep -qxF "User: $(cred PANEL_USERNAME)" <<<"$info" && grep -qxF "User password: $(cred PANEL_PASSWORD)" <<<"$info"; then
  dot_info "login checked: 1pctl user-info shows the user and password of $creds"
else
  echo "warning: 1Panel's login differs from $creds (changed in the panel?), see: sudo 1pctl user-info" >&2
fi
dot_summary onepanel "http://localhost:$port/$entrance" \
  "user $(cred PANEL_USERNAME), password: PANEL_PASSWORD in $creds (also port and entrance)" 1panel-core
