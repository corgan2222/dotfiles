#!/bin/bash
# installer: Tailscale VPN client (WireGuard mesh with login)
# systems: debian arch fedora rhel alpine
# modes: native
# category: network
# check: tailscale
# Installs Tailscale from its apt or rpm repository at pkgs.tailscale.com (Arch, Alpine: distro package) and starts
# tailscaled where systemd runs. Joins the tailnet only with an auth key, else the summary shows how to log in:
#   tailscale.sh                          install only, log in later with: sudo tailscale up
#   TS_AUTHKEY=tskey-auth-… tailscale.sh  install and join with an auth key (admin console: Settings, Keys)
# The node's identity lives in /var/lib/tailscale (tailscaled.state). Safe to run again.
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

key=${TS_AUTHKEY:-}
dot_secret_ok "$key" || dot_die "TS_AUTHKEY must not contain spaces, quotes, \$ or backslashes"

case $DOT_PKG in
  apt)
    dot_need curl
    os=$DOT_OS_BASE code=$DOT_OS_BASE_CODENAME
    [ "$os" = ubuntu ] || os=debian
    # one repository per codename; a release Tailscale does not know yet gets the newest one of its family
    if ! curl -fsS -o /dev/null "https://pkgs.tailscale.com/stable/$os/dists/$code/Release" 2>/dev/null; then
      case $os in ubuntu) code=noble ;; *) code=trixie ;; esac
      dot_info "Tailscale has no repository for '$DOT_OS_BASE_CODENAME', using '$code'"
    fi
    dot_apt_repo tailscale "https://pkgs.tailscale.com/stable/$os/$code.noarmor.gpg" \
      "https://pkgs.tailscale.com/stable/$os" "$code" main
    dot_pkg_install tailscale || dot_die "installing tailscale failed" ;;
  dnf|yum)
    # the .repo files Tailscale publishes: fedora/ for every Fedora release, rhel/<major> for the RHEL family
    if [ "$DOT_OS_BASE" = fedora ]; then
      repo=fedora
    else
      dot_need curl
      repo=rhel/${DOT_OS_VERSION%%.*}
      curl -fsS -o /dev/null "https://pkgs.tailscale.com/stable/$repo/tailscale.repo" 2>/dev/null ||
        { dot_info "Tailscale has no repository for $repo, using rhel/9"; repo=rhel/9; }
    fi
    dot_rpm_repo tailscale "https://pkgs.tailscale.com/stable/$repo/tailscale.repo"
    dot_pkg_install tailscale || dot_die "installing tailscale failed" ;;
  pacman|apk) dot_pkg_install tailscale || dot_die "installing tailscale failed" ;;
  *) dot_die "no Tailscale package for $DOT_OS, see https://tailscale.com/download/linux" ;;
esac
tailscale version | head -n 1
# direct connections between nodes use this UDP port, without it Tailscale falls back to its DERP relays. Not in
# "# ports:": when 41641 is taken, tailscaled binds another port (magicsock's bindSocket, checked 28.10.26)
dot_firewall_open 41641/udp

login="none yet: run sudo tailscale up, it prints a login link to open in a browser (or TS_AUTHKEY=… tailscale.sh)"
if [ ! -d /run/systemd/system ]; then
  if [ "$DOT_PKG" = apk ]; then
    dot_info "no systemd: start the daemon with: sudo rc-update add tailscale default && sudo rc-service tailscale start"
  else
    dot_info "no systemd running: start the daemon by hand (sudo tailscaled &), then log in with: sudo tailscale up"
  fi
  [ -z "$key" ] || dot_info "TS_AUTHKEY was not used: the daemon does not run, join later with: sudo tailscale up --auth-key=<key>"
else
  dot_sudo systemctl enable --now tailscaled || dot_die "starting tailscaled failed"
  if [ -n "$key" ]; then
    # the key goes in through a 0600 file, not on the command line where ps shows it
    tmp=$(mktemp) && trap 'rm -f "$tmp"' EXIT
    printf '%s' "$key" > "$tmp"
    dot_sudo tailscale up --auth-key="file:$tmp" || dot_die "tailscale up with TS_AUTHKEY failed"
    login="joined with TS_AUTHKEY, status: tailscale status"
  elif dot_sudo tailscale ip -4 >/dev/null 2>&1; then
    login="already logged in, status: tailscale status"
  fi
fi
addr=$(dot_sudo tailscale ip -4 2>/dev/null | head -n 1)
# a parent installer (dot_deploy) may have exported its mode and address: Tailscale has neither
DOT_MODE=native DOT_BIND='' dot_summary tailscale "$addr" "$login; node identity in /var/lib/tailscale" tailscaled
