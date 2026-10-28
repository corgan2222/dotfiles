#!/bin/bash
# installer: Samba file server with a share for your home directory
# systems: debian arch fedora rhel
# Installs Samba, writes a minimal smb.conf only when there is none, and adds a share named after
# the calling user for their home directory (an existing smb.conf is backed up first, never replaced).
# The samba password is not asked for; set it afterwards with: sudo smbpasswd -a <user>
#   --public / --local   all interfaces (default) or loopback only (else asked); loopback writes "interfaces = lo" and
#                        "bind interfaces only = yes" to [global]: only this host or an SSH tunnel reaches the shares then
# category: server
# check: smbd.service|smb.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; DOT_MODE=native
dot_bind 0.0.0.0

conf=/etc/samba/smb.conf
backup=$conf.bak-$(date +%Y%m%d%H%M%S)
case $DOT_PKG in
  apt) dot_pkg_install samba smbclient || dot_die "installing samba failed" ;;
  pacman) dot_pkg_install samba || dot_die "installing samba failed" ;;
  dnf|yum) dot_pkg_install samba samba-client || dot_die "installing samba failed" ;;
  *) dot_die "no samba package for $DOT_OS" ;;
esac

# the calling user: ourselves, or the user behind "sudo samba.sh"
user=$(dot_user)

if [ ! -f "$conf" ]; then
  dot_info "writing a minimal $conf"
  dot_sudo install -m 0755 -d /etc/samba
  printf '[global]\n   workgroup = WORKGROUP\n   server role = standalone server\n   map to guest = never\n' |
    dot_sudo tee "$conf" >/dev/null
fi

# an interface limit already in smb.conf is kept: it decides, whatever was answered
if grep -Eqi '^[[:space:]]*bind interfaces only[[:space:]]*=[[:space:]]*(yes|true|1)[[:space:]]*$' "$conf"; then
  ifaces=$(grep -Ei '^[[:space:]]*interfaces[[:space:]]*=' "$conf" | head -n 1 | sed 's/^[^=]*=[[:space:]]*//')
  if [ "$ifaces" = lo ]; then
    [ "$DOT_BIND" = 127.0.0.1 ] ||
      echo "warning: $conf keeps Samba on loopback, remove 'interfaces = lo' and 'bind interfaces only' from [global] to share on the network" >&2
    DOT_BIND=127.0.0.1
  else
    dot_info "$conf limits Samba to its interfaces ($ifaces), keeping that"
    DOT_BIND=
  fi
elif [ "$DOT_BIND" = 127.0.0.1 ]; then
  dot_sudo test -e "$backup" || dot_sudo cp -p "$conf" "$backup" || dot_die "could not back up $conf"
  dot_info "limiting Samba to loopback in $conf (backup: $backup)"
  dot_sudo sed -i 's/^[[:space:]]*\[global\][[:space:]]*$/&\n   interfaces = lo\n   bind interfaces only = yes/I' "$conf"
  grep -qi '^[[:space:]]*bind interfaces only = yes' "$conf" || dot_die "no [global] section in $conf, add the lines by hand"
fi

if [ "$user" = root ]; then
  dot_info "running as root: no share added, run samba.sh as the user whose home should be shared"
elif ! grep -q "^\[$user\]" "$conf"; then
  home=$(dot_user_home "$user")
  dot_sudo test -e "$backup" || dot_sudo cp -p "$conf" "$backup" || dot_die "could not back up $conf"
  dot_info "adding the share [$user] for $home to $conf (backup: $backup)"
  printf '\n[%s]\n   path = %s\n   valid users = %s\n   read only = no\n' "$user" "$home" "$user" |
    dot_sudo tee -a "$conf" >/dev/null
  # SELinux (Fedora, RHEL family) keeps smbd out of home directories unless this boolean is on
  if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
    dot_sudo setsebool -P samba_enable_home_dirs on || echo "warning: could not set the SELinux boolean samba_enable_home_dirs" >&2
  fi
fi
dot_sudo testparm -s "$conf" >/dev/null 2>&1 || dot_die "$conf has errors, check it with: testparm $conf"

if [ -d /run/systemd/system ]; then
  # Debian names the services smbd/nmbd, Arch, Fedora and the RHEL family smb/nmb
  for s in smbd nmbd smb nmb; do
    systemctl list-unit-files --no-legend "$s.service" | grep -q . && { dot_sudo systemctl enable "$s"; dot_sudo systemctl restart "$s"; }
  done
else
  dot_info "no systemd running: start smbd by hand"
fi
if [ "$user" = root ]; then
  dot_summary samba "smb://localhost" "no share added" "$([ "$DOT_PKG" = apt ] && echo smbd || echo smb)"
else
  dot_summary samba "\\\\localhost\\$user smb://localhost/$user" \
    "user $user with the samba password, set or change it: sudo smbpasswd -a $user" \
    "$([ "$DOT_PKG" = apt ] && echo smbd || echo smb)"
fi
