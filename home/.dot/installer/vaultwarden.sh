#!/bin/bash
# installer: Vaultwarden password manager server, Bitwarden compatible (Docker)
# systems: amd64
# modes: compose portainer
# Runs Vaultwarden (image vaultwarden/server:latest) as compose project or Portainer stack "vaultwarden" from
# /opt/vaultwarden, data in /opt/vaultwarden/data; installs Docker through docker.sh when it is missing.
# Vaultwarden, not the official Bitwarden server: Bitwarden's self-host runs about ten containers with MSSQL and needs
# an installation id and key from bitwarden.com; Vaultwarden is one container with SQLite, about 50 MB RAM, and the
# Bitwarden apps and browser extensions talk to it unchanged.
#   vaultwarden.sh
#   VAULTWARDEN_PORT=8222          HTTP port of the first run (default 8222)
#   VAULTWARDEN_DOMAIN=https://vault.example.org   the public HTTPS address behind the reverse proxy (DOMAIN)
#   VAULTWARDEN_SIGNUPS=false|true  open registration on the first run (default false: accounts come by invitation
#                                   from the admin page; a server reachable from the internet should not let anyone in)
#   --public / --local             all interfaces or this host only (first run, else asked)
# Admin page /admin: a random token, kept in plain text in /opt/vaultwarden/admin-token (0600) and given to
# Vaultwarden as argon2id hash (made by "vaultwarden hash") in /opt/vaultwarden/data/config.json. Settings saved on
# the admin page also land in config.json and win over the compose file from then on.
# Browsers open the web vault only over HTTPS (WebCrypto): run it behind Caddy, Traefik or Nginx Proxy Manager.
# category: server
# ports: VAULTWARDEN_PORT=8222
# check: stack:vaultwarden
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
[ "$DOT_MODE" = native ] && DOT_MODE=compose

dest=/opt/vaultwarden
image=vaultwarden/server:latest
tokf=$dest/admin-token
conf=$dest/data/config.json
port=${VAULTWARDEN_PORT:-8222}
case $port in ''|*[!0-9]*) dot_die "VAULTWARDEN_PORT must be a number, got '$port'" ;; esac
signups=${VAULTWARDEN_SIGNUPS:-false}
case $signups in true|false) ;; *) dot_die "VAULTWARDEN_SIGNUPS must be true or false, not '$signups'" ;; esac
domain=${VAULTWARDEN_DOMAIN:-}
case $domain in ''|https://*) ;; *) dot_die "VAULTWARDEN_DOMAIN must be an https:// address, e.g. https://vault.example.org" ;; esac
dot_need curl
dot_mode_guard vaultwarden vaultwarden "$port"
dot_bind 0.0.0.0
dot_sudo install -d -m 0700 "$dest/data" || exit 1

# admin token on the first run: "vaultwarden hash" reads the password from a terminal only, so script(1) inside the
# image gives it one; the token goes in on stdin, not on a command line. DOT_NO_START (no Docker): the next run does it
if ! dot_sudo test -f "$conf" && [ -z "${DOT_NO_START:-}" ]; then
  dot_docker_ready vaultwarden
  dot_sudo docker pull -q "$image" >/dev/null || dot_die "could not pull $image"
  tok=$(dot_password 48)
  hash=$(printf '%s\n%s\n' "$tok" "$tok" |
    dot_sudo docker run -i --rm --entrypoint script "$image" -qec '/vaultwarden hash --preset owasp' /dev/null |
    sed -n "s/^ADMIN_TOKEN='\(\$argon2id\$[^']*\)'.*/\1/p")
  [ -n "$hash" ] || dot_die "vaultwarden hash made no argon2 hash"
  printf '%s\n' "$tok" | dot_sudo sh -c "umask 077; cat > '$tokf'" &&
    printf '{\n  "admin_token": "%s"\n}\n' "$hash" | dot_sudo sh -c "umask 077; cat > '$conf'" || exit 1
  dot_info "wrote $conf (admin token hash) and $tokf"
fi

dot_deploy vaultwarden "services:
  vaultwarden:
    image: $image
    container_name: vaultwarden
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:$port:80\"
    environment:
      SIGNUPS_ALLOWED: \"$signups\"${domain:+
      DOMAIN: \"$domain\"}
    volumes:
      - $dest/data:/data"

# "[address:]port" as written on the first run; a different answer now is only reported
pub=$(dot_sudo sed -n 's/^ *- "\(.*\):80"$/\1/p' "$dest/compose.yaml")
case $pub in *:*) bound=${pub%:*} ;; *) bound=0.0.0.0 ;; esac
port=${pub##*:}
if [ "$bound" != "$DOT_BIND" ]; then
  echo "warning: Vaultwarden keeps listening on $bound (set on the first run), edit $dest/compose.yaml to change it" >&2
  DOT_BIND=$bound
fi
local_url=http://$([ "$bound" = 0.0.0.0 ] && echo localhost || echo "$bound"):$port
# DOT_NO_START: nothing runs that could answer (28.10.26: it waited for /alive and died)
if [ -n "${DOT_NO_START:-}" ]; then
  dot_summary vaultwarden "$local_url" "admin page /admin, token: sudo cat $tokf (made by a run without DOT_NO_START)"
  exit 0
fi
dot_wait_http "$local_url/alive" 120 || dot_die "Vaultwarden does not answer on $local_url, see: sudo docker logs vaultwarden"

# the admin page takes the stored token when it answers with its session cookie
if dot_sudo test -f "$tokf"; then
  if dot_sudo cat "$tokf" | tr -d '\n' | curl -sS -m 20 -D - -o /dev/null --data-urlencode token@- "$local_url/admin" |
    grep -qi '^set-cookie: *VW_ADMIN='; then
    dot_info "admin token checked: $local_url/admin accepts it"
  else
    echo "warning: the admin page does not accept the token in $tokf (changed on the admin page?)" >&2
  fi
fi

dot_info "the web vault needs HTTPS: browsers refuse it over plain http except on localhost"
dot_summary vaultwarden "$local_url${domain:+ $domain}" \
  "admin page /admin, token: sudo cat $tokf; signups $([ "$(dot_sudo sed -n 's/^ *SIGNUPS_ALLOWED: "\(.*\)"$/\1/p' "$dest/compose.yaml")" = true ] && echo open || echo "off, invite accounts on the admin page"); HTTPS needed: run it behind Caddy, Traefik or Nginx Proxy Manager${domain:+ for $domain}"
