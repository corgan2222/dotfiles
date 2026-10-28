#!/bin/bash
# installer: Cloudflare Tunnel connector (cloudflared)
# systems: debian arch fedora rhel alpine
# modes: native compose portainer
# category: network
# check: cloudflared
# ask: compose,portainer CF_TUNNEL_TOKEN "Tunnel token from the Cloudflare dashboard (Networking, Tunnels), e.g. eyJh..."
# Native: cloudflared from Cloudflare's apt or rpm repository (pkg.cloudflare.com), Arch: distro package, elsewhere
# the GitHub release binary (sha256 checked) in /usr/local/bin. A tunnel token installs the systemd service:
#   cloudflared.sh                            install only, the summary says where the token comes from
#   CF_TUNNEL_TOKEN=eyJ… cloudflared.sh       install and run the tunnel as service cloudflared
#   CF_TUNNEL_TOKEN=eyJ… cloudflared.sh --docker | --portainer
#       image cloudflare/cloudflared:latest as compose project or Portainer stack "cloudflared" from /opt/cloudflared,
#       token in /opt/cloudflared/.env (0600); host network, so that localhost in the tunnel's routes means this host
# Native, the token goes to /etc/cloudflared/tunnel.env (0600, TUNNEL_TOKEN) and the unit cloudflared.service of
# cloudflared.sh reads it from there. A unit of "cloudflared service install <token>" (token in its ExecStart, readable
# for every local user) is replaced and its token moves to tunnel.env; a unit of your own without a token stays.
# Running again updates cloudflared; a new token replaces the one in tunnel.env or .env.
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

token=${CF_TUNNEL_TOKEN:-}
dot_secret_ok "$token" || dot_die "CF_TUNNEL_TOKEN must not contain spaces, quotes, \$ or backslashes"
dest=/opt/cloudflared
where="get a token at dash.cloudflare.com: Networking, Tunnels, Create a tunnel, type Cloudflared (older dashboards:
           Zero Trust, Networks, Tunnels); the install command shown there ends in the token (eyJ…)"
dot_mode_guard cloudflared cloudflared

if [ "$DOT_MODE" != native ]; then
  dot_sudo install -d -m 0755 "$dest"
  if [ -n "$token" ]; then
    dot_env_set "$dest/.env" TUNNEL_TOKEN "$token"
  elif ! dot_sudo grep -qs '^TUNNEL_TOKEN=.' "$dest/.env"; then
    dot_die "the Docker tunnel needs a token: CF_TUNNEL_TOKEN=eyJ… cloudflared.sh --docker
       $where"
  fi
  dot_deploy cloudflared "services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    network_mode: host
    command: tunnel --no-autoupdate run
    environment:
      TUNNEL_TOKEN: \${TUNNEL_TOKEN}"
  DOT_BIND='' dot_summary cloudflared "" "token in $dest/.env (0600), routes and hostnames in the Cloudflare dashboard"
  exit 0
fi

# GitHub release binary, for systems without a Cloudflare package
cf_binary() {
  local asset tmp
  case $DOT_ARCH in
    amd64|arm64|386) asset=cloudflared-linux-$DOT_ARCH ;;
    armv7) asset=cloudflared-linux-armhf ;;
    armv6) asset=cloudflared-linux-arm ;;
    *) dot_die "cloudflared has no build for architecture $DOT_ARCH" ;;
  esac
  dot_need curl
  tmp=$(mktemp) && trap 'rm -f "$tmp"' EXIT
  dot_info "Downloading $asset from GitHub"
  dot_github_fetch cloudflare/cloudflared "/$asset\$" "$tmp" || dot_die "download of $asset failed"
  dot_sudo install -m 0755 "$tmp" /usr/local/bin/cloudflared || dot_die "could not install /usr/local/bin/cloudflared"
}

case $DOT_PKG in
  # one suite "any" for every Debian and Ubuntu release
  apt)
    dot_apt_repo cloudflared https://pkg.cloudflare.com/cloudflare-main.gpg https://pkg.cloudflare.com/cloudflared any main
    dot_pkg_install cloudflared || dot_die "installing cloudflared failed" ;;
  dnf|yum)
    dot_rpm_repo cloudflared https://pkg.cloudflare.com/cloudflared.repo
    dot_pkg_install cloudflared || dot_die "installing cloudflared failed" ;;
  pacman) dot_pkg_install cloudflared || dot_die "installing cloudflared failed" ;;
  *) cf_binary ;;
esac
hash -r
cloudflared --version || dot_die "cloudflared does not run"

unit=/etc/systemd/system/cloudflared.service envf=/etc/cloudflared/tunnel.env
mark='# written by cloudflared.sh, the token is in /etc/cloudflared/tunnel.env'
# "cloudflared service install <token>" writes the token into ExecStart of a 0644 unit, systemctl cat shows it to every
# local user (28.10.26): such a unit is replaced by ours, its token moves to $envf unless a new one is given
old=$(sed -n 's/^ExecStart=.* --token \([^ ]*\).*/\1/p' "$unit" 2>/dev/null)
[ -n "$token" ] || token=$old
if [ -n "$token" ]; then
  dot_sudo install -d -m 0755 /etc/cloudflared && dot_env_set "$envf" TUNNEL_TOKEN "$token" ||
    dot_die "could not write $envf"
fi
if [ -f "$unit" ] && [ -z "$old" ] && ! grep -qF "$mark" "$unit"; then
  dot_info "keeping $unit: not written by cloudflared.sh and without a token (a tunnel with a config file?)"
  login="the service cloudflared is your own ($unit)${token:+, token also in $envf}"
elif ! dot_sudo grep -qs '^TUNNEL_TOKEN=.' "$envf"; then
  login="no tunnel yet: $where
           then: CF_TUNNEL_TOKEN=<token> cloudflared.sh"
elif [ ! -d /run/systemd/system ]; then
  dot_info "no systemd running: the tunnel is not installed as a service; run it in the foreground with:
  sudo sh -c 'set -a; . $envf; exec cloudflared tunnel --no-autoupdate run'"
  login="tunnel not started (no systemd), token in $envf (0600)"
else
  # the unit of "cloudflared service install", with the token from the environment file instead of the command line
  dot_sudo tee "$unit" >/dev/null <<EOF || dot_die "could not write $unit"
$mark
[Unit]
Description=cloudflared
After=network-online.target
Wants=network-online.target

[Service]
TimeoutStartSec=15
Type=notify
EnvironmentFile=$envf
ExecStart=$(command -v cloudflared) --no-autoupdate tunnel run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
  dot_sudo systemctl daemon-reload
  dot_sudo systemctl enable cloudflared >/dev/null 2>&1 && dot_sudo systemctl restart cloudflared ||
    dot_die "cloudflared does not start, see: journalctl -u cloudflared"
  login="token in $envf (0600); routes and hostnames in the Cloudflare dashboard"
fi
DOT_BIND='' dot_summary cloudflared "" "$login"
