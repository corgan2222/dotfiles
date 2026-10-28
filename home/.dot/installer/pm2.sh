#!/bin/bash
# installer: pm2 process manager (latest, npm global) started at boot for the calling user
# systems: debian arch fedora rhel
# Installs the latest pm2 globally with npm (Node.js LTS via nodejs.sh when node is missing), runs
# "pm2 startup systemd" for the calling user (unit pm2-<user>.service, starts "pm2 resurrect" at boot)
# and "pm2 save". Running it again updates pm2 and reloads a running daemon with "pm2 update".
# Shell completion for pm2 is already in home/.bashrc.
#   pm2.sh
# category: dev
# check: pm2
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

user=$(dot_user)
home=$(dot_user_home "$user")
[ -d "$home" ] || dot_die "no home directory for $user"

# runs a command as the calling user with its home, also when this script runs as root
as_user() {
  if [ "$(id -un)" = "$user" ]; then "$@"; else sudo -u "$user" -H env PATH="$PATH" "$@"; fi
}

dot_node_min

before=$(npm ls -g --depth=0 pm2 2>/dev/null | sed -n 's/.*pm2@//p')
dot_sudo npm install -g pm2@latest || dot_die "npm install -g pm2 failed"
hash -r
after=$(npm ls -g --depth=0 pm2 2>/dev/null | sed -n 's/.*pm2@//p')
pm2=$(command -v pm2) || dot_die "pm2 is not in PATH after the npm install"
if [ "$before" = "$after" ]; then
  dot_info "pm2 $after is up to date"
else
  dot_info "pm2 ${before:-–} -> $after"
  # an old daemon keeps running the old code until "pm2 update" (save, restart daemon, resurrect)
  [ -n "$before" ] && as_user "$pm2" ping >/dev/null 2>&1 && as_user "$pm2" update
fi

if [ -d /run/systemd/system ]; then
  # the command "pm2 startup" prints for a normal user, run here directly: node must be in the PATH of root
  dot_sudo env PATH="$PATH:$(dirname "$(command -v node)")" "$pm2" startup systemd -u "$user" --hp "$home" ||
    dot_die "pm2 startup failed"
  dot_sudo systemctl start "pm2-$user" || dot_die "could not start pm2-$user.service, see: journalctl -u pm2-$user"
  # saves the running processes for "pm2 resurrect"; with none pm2 skips it and keeps an existing dump
  as_user "$pm2" save
  dot_info "pm2 $after runs as $user under pm2-$user.service; after pm2 start <app> run pm2 save"
else
  dot_info "no systemd running: pm2 is installed, but not started at boot (pm2 startup needs systemd)"
fi
