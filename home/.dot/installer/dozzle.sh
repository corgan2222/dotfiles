#!/bin/bash
# installer: Dozzle web viewer for Docker container logs
# systems: amd64 arm64 armv7
# modes: compose portainer
# Runs Dozzle (dozzle.dev) as compose project or Portainer stack "dozzle" from /opt/dozzle (default: compose,
# --portainer for a stack); installs Docker through docker.sh when it is missing. Needs about 50 MB RAM.
# The compose file is written on the first run only; running again pulls the newest image.
#   dozzle.sh                                        user admin with a random password (first run)
#   DOZZLE_USER=admin DOZZLE_PASSWORD=… dozzle.sh    that login; running again with both set replaces the password.
#                                                    Dozzle's users file /opt/dozzle/data/users.yml (bcrypt, 0600), the
#                                                    plain login in /opt/dozzle/credentials (0600)
#   DOZZLE_AUTH=none dozzle.sh                       no login (only on a trusted network)
#   DOZZLE_PORT=8890 dozzle.sh                       other HTTP port for the first run (default 9999; 8888 is
#                                                    Chronograf's)
#   --public / --local                               all interfaces or this host only (first run, else asked)
# The Docker socket is mounted read-only, but that does not limit the Docker API: whoever can use Dozzle sees all
# container logs. Container actions and the shell stay off (Dozzle's defaults), anonymous analytics are switched off.
# category: docker
# ports: DOZZLE_PORT=9999
# check: stack:dozzle
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
[ "$DOT_MODE" = native ] && DOT_MODE=compose
dot_bind 0.0.0.0

dest=/opt/dozzle
users=$dest/data/users.yml
image=amir20/dozzle:latest

if [ -n "${DOZZLE_USER:-}${DOZZLE_PASSWORD:-}" ] && { [ -z "${DOZZLE_USER:-}" ] || [ -z "${DOZZLE_PASSWORD:-}" ]; }; then
  dot_die "set both DOZZLE_USER and DOZZLE_PASSWORD, or neither"
fi
dot_sudo install -d -m 0755 "$dest" "$dest/data" || exit 1
# a login by default (28.10.26): the logs show secrets of other containers. The first run makes the user admin with a
# random password, kept in plain text next to the bcrypt file for the summary (and Bitwarden); DOZZLE_AUTH=none: open
creds=$dest/credentials
if [ -z "${DOZZLE_USER:-}" ] && [ "${DOZZLE_AUTH:-simple}" != none ] && ! dot_sudo test -f "$users"; then
  DOZZLE_USER=admin DOZZLE_PASSWORD=$(dot_password 20)
fi

# users file from Dozzle's own generator (bcrypt); the password goes in on stdin, not on the command line
if [ -n "${DOZZLE_USER:-}" ]; then
  dot_docker_ready
  dot_sudo docker pull -q "$image" >/dev/null || dot_die "could not pull $image"
  printf '%s\n' "$DOZZLE_PASSWORD" | dot_sudo docker run -i --rm "$image" generate "$DOZZLE_USER" |
    dot_sudo sh -c "umask 077; cat > '$users.new'" && dot_sudo grep -q 'password:' "$users.new" ||
    { dot_sudo rm -f "$users.new"; dot_die "could not generate the Dozzle users file"; }
  dot_sudo mv "$users.new" "$users"
  printf '%s:%s\n' "$DOZZLE_USER" "$DOZZLE_PASSWORD" | dot_sudo sh -c "umask 077; cat > '$creds'" ||
    dot_die "could not write $creds"
  dot_info "wrote $users for user $DOZZLE_USER"
fi
if dot_sudo test -f "$users"; then auth=simple; else auth=none; fi
if [ "$auth" = simple ] && dot_sudo test -f "$dest/compose.yaml" && ! dot_sudo grep -q 'DOZZLE_AUTH_PROVIDER: simple' "$dest/compose.yaml"; then
  echo "warning: $dest/compose.yaml does not use the users file: set DOZZLE_AUTH_PROVIDER: simple in it and run again" >&2
fi

dot_deploy dozzle "services:
  dozzle:
    image: $image
    container_name: dozzle
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:${DOZZLE_PORT:-9999}:8080\"
    environment:
      DOZZLE_AUTH_PROVIDER: $auth
      DOZZLE_NO_ANALYTICS: \"true\"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - $dest/data:/data"
# Dozzle reads the users file at start
[ -z "${DOZZLE_USER:-}" ] || dot_sudo docker restart dozzle >/dev/null || dot_die "could not restart Dozzle"

# "[address:]port" as written on the first run; a different answer now is only reported
pub=$(dot_sudo sed -n 's/^ *- "\(.*\):8080"$/\1/p' "$dest/compose.yaml")
case $pub in *:*) bound=${pub%:*} ;; *) bound=0.0.0.0 ;; esac
if [ "$bound" != "$DOT_BIND" ]; then
  echo "warning: Dozzle keeps listening on $bound (set on the first run), edit $dest/compose.yaml to change it" >&2
  DOT_BIND=$bound
fi
if [ "$auth" = simple ] && dot_sudo test -f "$creds"; then
  login="user $(dot_sudo cut -d: -f1 "$creds"), password: sudo cat $creds; new one: DOZZLE_USER=<user> DOZZLE_PASSWORD=… dozzle.sh"
elif [ "$auth" = simple ]; then
  login="users in $users (bcrypt); new password: DOZZLE_USER=<user> DOZZLE_PASSWORD=… dozzle.sh"
else
  login="none (anyone who reaches the port sees all logs; DOZZLE_USER/DOZZLE_PASSWORD add a login)"
fi
port=${pub##*:}
dot_summary dozzle "http://localhost:${port:-9999}" "$login"
