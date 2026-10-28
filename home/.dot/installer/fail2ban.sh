#!/bin/bash
# installer: fail2ban, bans addresses after failed SSH logins (sshd and recidive jails)
# systems: debian arch fedora rhel
# modes: native
# Installs fail2ban from the distro (Fedora and the RHEL family: EPEL) and writes /etc/fail2ban/jail.local with
#   sshd       on the port sshd listens on (sshd -T), from the systemd journal where systemd runs
#   recidive   bans for a week whoever was banned 5 times within a day, read from fail2ban's own log
# Bans go through nftables (package nftables), with a running firewalld through firewalld (fail2ban-firewalld).
# An existing jail.local stays as it is; delete it to get this one again. Running again updates the package.
#   FAIL2BAN_BANTIME=1h      ban time of the sshd jail (fail2ban time syntax: 10m, 1h, 1d; default 1h)
#   FAIL2BAN_MAXRETRY=5      failed logins within 10 minutes before a ban (default 5)
# Addresses of this host (127.0.0.1, ::1) are never banned; more in ignoreip in jail.local.
# category: sysop
# check: fail2ban.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

bantime=${FAIL2BAN_BANTIME:-1h}
[[ $bantime =~ ^[0-9]+[smhdw]?$ ]] || dot_die "FAIL2BAN_BANTIME must be a time like 10m, 1h or 1d, not '$bantime'"
maxretry=${FAIL2BAN_MAXRETRY:-5}
case $maxretry in ''|*[!0-9]*) dot_die "FAIL2BAN_MAXRETRY must be a number, got '$maxretry'" ;; esac
systemd=; [ -d /run/systemd/system ] && systemd=1
firewalld=; [ -n "$systemd" ] && systemctl is-active -q firewalld 2>/dev/null && firewalld=1

# the systemd backend needs the Python bindings of the journal, which the distros only recommend
case $DOT_PKG in
  apt) pkgs=(fail2ban python3-systemd) ;;
  dnf|yum) dot_epel || dot_die "turning on EPEL failed"; pkgs=(fail2ban-server fail2ban-systemd) ;;
  pacman) pkgs=(fail2ban python-systemd) ;;
  *) dot_die "no fail2ban package set up for $DOT_OS" ;;
esac
if [ -n "$firewalld" ]; then
  # brings jail.d/00-firewalld.conf with banaction firewallcmd-rich-rules
  [ "$DOT_PKG" = apt ] || pkgs+=(fail2ban-firewalld)
else
  pkgs+=(nftables)
fi
# apt-get, dnf and pacman -S --needed also update an installed package
dot_pkg_install "${pkgs[@]}" || dot_die "installing fail2ban failed"

# the port sshd listens on; a missing sshd leaves the service name ssh (22)
sshd=$(PATH=$PATH:/usr/sbin:/sbin command -v sshd)
port=$( [ -n "$sshd" ] && dot_sudo "$sshd" -T 2>/dev/null | awk 'tolower($1) == "port" { print $2 }' | paste -sd,)
[ -n "$port" ] || { port=ssh; dot_info "no sshd found: the sshd jail watches port 22, install the server with ssh.sh"; }

jail=/etc/fail2ban/jail.local
banaction=
# nftables as Debian's jail.d/defaults-debian.conf names it; not with firewalld: jail.local is read after
# jail.d/*.conf and would override 00-firewalld.conf
[ -n "$firewalld" ] || banaction="banaction = nftables
banaction_allports = nftables[type=allports]"
backend=auto; [ -n "$systemd" ] && backend=systemd
# recidive reads fail2ban's own log file: where fail2ban logs to the journal instead it reads the journal
logtarget=$(dot_sudo sh -c 'cat /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.d/*.conf /etc/fail2ban/fail2ban.local 2>/dev/null' |
  sed -n 's/^logtarget *= *//p' | tail -n 1)
case $logtarget in
  /*) recidive="backend = auto
logpath = $logtarget"
      # fail2ban creates its log on the first start, but "fail2ban-client -t" below wants it already (AlmaLinux 10,
      # 28.10.26: "Have not found any log file for recidive jail")
      # a file made by install gets the SELinux type of /var/log (var_log_t), fail2ban may then not write it
      # (28.10.26): restorecon sets fail2ban_log_t where the policy has it
      if ! dot_sudo test -e "$logtarget"; then
        dot_sudo install -m 0600 /dev/null "$logtarget"
        dot_sudo restorecon "$logtarget" 2>/dev/null
      fi ;;
  *) recidive="backend = systemd
journalmatch = _SYSTEMD_UNIT=fail2ban.service" ;;
esac
dot_put_new "$jail" <<EOF
# written by the dotfiles installer fail2ban.sh on the first run; kept on later runs
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
findtime = 10m
maxretry = $maxretry
$banaction

[sshd]
enabled = true
port = $port
backend = $backend
bantime = $bantime

[recidive]
enabled = true
$recidive
bantime = 1w
findtime = 1d
maxretry = 5
EOF
dot_sudo fail2ban-client -t >/dev/null || dot_die "fail2ban rejects its configuration, see: sudo fail2ban-client -t"

if [ -n "$systemd" ]; then
  dot_sudo systemctl enable fail2ban >/dev/null 2>&1 && dot_sudo systemctl restart fail2ban || dot_die "fail2ban does not start, see: journalctl -u fail2ban"
  # the socket appears a moment after the start
  for _ in $(seq 20); do dot_sudo fail2ban-client ping >/dev/null 2>&1 && break; sleep 1; done
  jails=$(dot_sudo fail2ban-client status 2>/dev/null | sed -n 's/.*Jail list:[[:space:]]*//p')
  dot_info "fail2ban $(dot_sudo fail2ban-client version 2>/dev/null) runs, jails: ${jails:-none}"
  [[ ,$jails, == *sshd* ]] || echo "warning: the sshd jail is not active, see: sudo fail2ban-client status" >&2
else
  dot_info "no systemd running: start fail2ban by hand: sudo fail2ban-client start"
fi
dot_summary fail2ban "" "none; status: sudo fail2ban-client status sshd (or recidive), unban: sudo fail2ban-client unban <ip>"
