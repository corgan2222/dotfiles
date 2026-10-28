#!/bin/bash
# installer: OpenSSH server, root login setting and an ed25519 key pair for you
# systems: all
# Installs the OpenSSH server unless one is there already (then it only sets it up), sets PermitRootLogin, creates
# missing host keys and an ed25519 key pair ~/.ssh/id_ed25519 without passphrase for the calling user.
#   ssh.sh
#   SSH_ROOT_LOGIN=no|prohibit-password|yes ssh.sh      root login over SSH; default: the value of an earlier run,
#                      else the value the installed sshd applies now (nothing is written then), else on a new
#                      server prohibit-password (key only) when root runs this or on Proxmox (its cluster needs root
#                      over SSH), else no. A value that takes root's password login away while root has no key in
#                      authorized_keys is applied with a warning.
#   SSH_AUTHORIZED_KEY="ssh-ed25519 AAAA… me@laptop" ssh.sh   also adds this public key to ~/.ssh/authorized_keys
# category: sysop
# modes: native
# check: sshd|/usr/sbin/sshd
# ask: SSH_ROOT_LOGIN=@ "Root login over SSH"
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

conf=/etc/ssh/sshd_config
mark='# set by the dotfiles installer ssh.sh'
# sshd lives in sbin, which is not in a user's PATH on Debian
spath=$PATH:/usr/sbin:/sbin
# runs a command as root without asking for a password (--choices runs while the menu waits): directly, else sudo -n
nopw() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo -n "$@"; fi; }
# Fedora and the RHEL family keep sshd_config.d (0700) and sshd_config (0600) for root only: as a user the earlier
# value was not found and --choices offered "no" first, Enter turned an earlier "yes" into "no" (28.10.26).
# $1 is the command that runs as root: dot_sudo, or nopw for --choices.
# prints PermitRootLogin of an earlier run (drop-in or the marked line in sshd_config), nothing on the first run
earlier() {
  { $1 cat /etc/ssh/sshd_config.d/10-dotfiles.conf; $1 sed -n "/^$mark\$/{n;p;}" "$conf"; } 2>/dev/null |
    awk '$1 == "PermitRootLogin" { print ($2 == "without-password" ? "prohibit-password" : $2); exit }'
}
# prints PermitRootLogin as the installed sshd applies it (sshd -T), nothing without sshd or when it cannot tell
effective() {
  local s
  s=$(PATH=$spath command -v sshd) || return 0
  $1 "$s" -T 2>/dev/null |
    awk 'tolower($1) == "permitrootlogin" { print ($2 == "without-password" ? "prohibit-password" : $2); exit }'
}
# Sets root_login and from where it comes (src): given (SSH_ROOT_LOGIN), earlier (run), effective (what sshd applies
# now, nothing is written: 28.10.26, the drop-in "prohibit-password" of a first run overrode "PermitRootLogin yes" in
# sshd_config and locked root out of a Proxmox node and an LXC that log in with a password), default (a new server:
# root keeps a way in where root runs this and on a Proxmox cluster, whose nodes talk to each other as root)
root_choice() {
  root_login=${SSH_ROOT_LOGIN:-} src=given
  [ -n "$root_login" ] && return
  root_login=$(earlier "$1") src=earlier
  [ -n "$root_login" ] && return
  # a server installed by this run applies the package's default, that is no choice to keep
  [ -n "${new_server:-}" ] || root_login=$(effective "$1") src=effective
  [ -n "$root_login" ] && return
  src=default
  if [ "$(dot_user)" = root ] || [ "$DOT_OS" = proxmox ]; then root_login=prohibit-password; else root_login=no; fi
}
if [ "${1:-}" = --choices ]; then
  # for installer.sh: the default first, a description after a tab. An installed sshd whose setting cannot be read
  # (sudo wants a password) prints nothing: the menu then shows an empty box and the installer keeps the setting
  root_choice nopw
  [ "$src" = default ] && PATH=$spath command -v sshd >/dev/null 2>&1 && exit 1
  d=$root_login
  for v in "$d" no prohibit-password yes; do
    case $v in
      no) t='no root login over SSH' ;;
      prohibit-password) t='root with a key only' ;;
      yes) t='root with a key or a password' ;;
    esac
    printf '%s\t%s\n' "$v" "$t"
  done | awk -F'\t' '!seen[$1]++'
  exit 0
fi

case ${SSH_ROOT_LOGIN:-} in
  ''|no|prohibit-password|yes) ;;
  *) dot_die "SSH_ROOT_LOGIN must be no, prohibit-password or yes, not '$SSH_ROOT_LOGIN'" ;;
esac
key=${SSH_AUTHORIZED_KEY:-}
case $key in *$'\n'*) dot_die "SSH_AUTHORIZED_KEY must be one line" ;; esac

has_unit() { systemctl list-unit-files --no-legend "$@" 2>/dev/null | grep -q .; }
new_server=
if PATH=$spath command -v sshd >/dev/null 2>&1 || has_unit ssh.service sshd.service; then
  dot_info "an SSH server is installed already, only setting it up"
else
  new_server=1
  case $DOT_PKG in
    apt|dnf|yum|zypper) dot_pkg_install openssh-server ;;
    pacman|apk) dot_pkg_install openssh ;;
    *) dot_die "no OpenSSH package for $DOT_OS" ;;
  esac || dot_die "installing the OpenSSH server failed"
fi
sshd=$(PATH=$spath command -v sshd) || dot_die "no sshd found"

# host keys: creates only the missing ones
dot_sudo ssh-keygen -A || dot_die "creating the host keys failed"
# Debian's sshd needs its privilege separation directory, systemd creates it only when it starts the service
[ "$DOT_PKG" = apt ] && dot_sudo install -d -m 0755 /run/sshd

# PermitRootLogin: a drop-in where sshd_config includes sshd_config.d, else a marked line at the top of sshd_config.
# sshd takes the first value it reads, so a file sorted before 10-dotfiles.conf still wins; checked below with sshd -T.
# sudo: Fedora and the RHEL family keep sshd_config readable for root only. sshd -T needs the host keys and /run/sshd.
root_choice dot_sudo
before=$(effective dot_sudo)
if [ "$src" = given ] && [ "$root_login" != yes ] && [ "$before" = yes ] &&
   ! dot_sudo test -s "$(dot_user_home root)/.ssh/authorized_keys"; then
  echo "warning: root has no key in $(dot_user_home root)/.ssh/authorized_keys: with PermitRootLogin $root_login" \
    "root can no longer log in over SSH with its password" >&2
fi
if [ "$src" = earlier ]; then
  dot_info "keeping PermitRootLogin $root_login of an earlier run (SSH_ROOT_LOGIN=… changes it)"
elif [ "$src" = effective ]; then
  dot_info "keeping PermitRootLogin $root_login as sshd applies it now (SSH_ROOT_LOGIN=… sets it)"
elif dot_sudo grep -Eqi '^[[:space:]]*Include[[:space:]].*sshd_config\.d/' "$conf"; then
  printf '%s\nPermitRootLogin %s\n' "$mark" "$root_login" | dot_sudo tee /etc/ssh/sshd_config.d/10-dotfiles.conf >/dev/null
else
  dot_info "$conf has no Include of sshd_config.d, setting PermitRootLogin in $conf"
  dot_sudo sed -i "/^$mark\$/{N;d}" "$conf"
  dot_sudo sed -i "1i $mark\nPermitRootLogin $root_login" "$conf"
fi
dot_sudo "$sshd" -t || dot_die "the sshd configuration has errors, see above"
# sshd -T prints the settings that apply, OpenSSH 10 in CamelCase (PermitRootLogin), older ones in lower case;
# older ones also call prohibit-password without-password
cfg=$(dot_sudo "$sshd" -T 2>/dev/null | awk '{ $1 = tolower($1) } 1')
eff=$(echo "$cfg" | awk '$1 == "permitrootlogin" {print $2}')
[ "$eff" = without-password ] && eff=prohibit-password
[ "$eff" = "$root_login" ] ||
  echo "warning: PermitRootLogin is $eff, another setting comes first: grep -ri permitrootlogin /etc/ssh" >&2

unit=sshd; has_unit ssh.service && unit=ssh
if [ ! -d /run/systemd/system ]; then
  dot_info "no systemd running: start the server by hand (sudo $sshd), or restart it so it reads the new setting"
elif systemctl is-enabled --quiet ssh.socket 2>/dev/null; then
  # Ubuntu 22.10 on: ssh.socket starts ssh.service on the first connection, which then reads the new setting
  dot_sudo systemctl enable --now ssh.socket && dot_sudo systemctl try-restart ssh.service || dot_die "starting ssh.socket failed"
else
  dot_sudo systemctl enable "$unit" && dot_sudo systemctl restart "$unit" || dot_die "starting $unit failed"
fi

# key pair and authorized_keys of the calling user, owned by them also when we run as root
user=$(dot_user)
home=$(dot_user_home "$user")
dir=$home/.ssh
own() { dot_sudo chown "$user:$(id -gn "$user")" "$@"; }
dot_sudo install -d -m 0700 "$dir" && own "$dir"
if ! dot_sudo test -e "$dir/id_ed25519"; then
  dot_sudo ssh-keygen -q -t ed25519 -N '' -C "$user@$(uname -n)" -f "$dir/id_ed25519" || dot_die "creating $dir/id_ed25519 failed"
  dot_info "created the key pair $dir/id_ed25519"
fi
dot_sudo chmod 600 "$dir/id_ed25519" && own "$dir/id_ed25519" "$dir/id_ed25519.pub"
auth=$dir/authorized_keys
if [ -n "$key" ]; then
  echo "$key" | ssh-keygen -l -f - >/dev/null 2>&1 || dot_die "SSH_AUTHORIZED_KEY is not a public key: $key"
  # compared by the key itself, the comment may differ
  if dot_sudo grep -qF -- "$(echo "$key" | awk '{print $2}')" "$auth" 2>/dev/null; then
    dot_info "the key is in $auth already"
  else
    # a last line without newline would run into the new key
    [ -n "$(dot_sudo tail -c 1 "$auth" 2>/dev/null)" ] && echo | dot_sudo tee -a "$auth" >/dev/null
    echo "$key" | dot_sudo tee -a "$auth" >/dev/null && dot_info "added the key to $auth"
  fi
fi
dot_sudo test -e "$auth" && { dot_sudo chmod 600 "$auth"; own "$auth"; }

# all interfaces when one listen address is the wildcard; dot_summary then opens the port in the firewall
port=$(echo "$cfg" | awk '$1 == "port" {print $2; exit}')
if echo "$cfg" | grep -Eq '^listenaddress (0\.0\.0\.0|\[::\]):'; then
  DOT_BIND=0.0.0.0 host=$(hostname -I 2>/dev/null | awk '{print $1}')
else
  DOT_BIND=127.0.0.1 host=localhost
fi
p=; [ "${port:-22}" = 22 ] || p="-p $port "
# what sshd -T says applies, not what was asked for: PasswordAuthentication no also turns "yes" into key only
pwauth=$(echo "$cfg" | awk '$1 == "passwordauthentication" {print $2}')
case $eff in
  no) rl="root login: off" ;;
  prohibit-password) rl="root login: with a key only" ;;
  yes) if [ "$pwauth" = no ]; then rl="root login: with a key only (PasswordAuthentication no)"
       else rl="root login: with a key or a password"; fi ;;
  *) rl="root login: $eff" ;;
esac
# ssh-copy-id needs a password login of $user
pw=; [ "$pwauth" != no ] && { [ "$user" != root ] || [ "$eff" = yes ]; } && pw=1
login="ssh $p$user@${host:-<ip>}, $rl"
[ "$user" = root ] && [ "$eff" = no ] &&
  login="none for root (PermitRootLogin no): add a user, or run again with SSH_ROOT_LOGIN=prohibit-password"
dot_summary ssh "ssh://$user@localhost:${port:-22}" "$login" "$unit"
{
  printf '  key:     %s, public part for authorized_keys elsewhere:\n           %s\n' "$dir/id_ed25519" "$(dot_sudo cat "$dir/id_ed25519.pub")"
  if [ -n "$pw" ]; then
    printf '  yours:   ssh-copy-id %s%s@%s   (on your computer, adds your key to %s)\n' \
      "$p" "$user" "${host:-<ip>}" "$auth"
  else
    printf '  yours:   no password login for %s: SSH_AUTHORIZED_KEY="<your public key>" ssh.sh adds it to %s\n' \
      "$user" "$auth"
  fi
} | if [ -n "${DOT_SUMMARY_FILE:-}" ]; then tee -a "$DOT_SUMMARY_FILE"; else cat; fi
