#!/bin/bash
# installer: Portainer CE or BE for this host's Docker (asks which edition)
# systems: all
# modes: compose
# Runs Portainer with Docker compose from /opt/portainer, creates the admin user, the local Docker environment and an
# API token, so that other installers can deploy their services as Portainer stacks (INSTALL_MODE=portainer).
#   portainer.sh [ce|be]          without an argument it asks; PORTAINER_EDITION=ce|be works too
#   PORTAINER_ADMIN_PASSWORD=…    admin password (min. 12 characters), else generated
#   PORTAINER_LICENSE=…           license key for BE (else the web UI asks for it at the first login)
#   PORTAINER_PORT=9443           HTTPS port of the web UI
#   --public / --local            listen on all interfaces or on this host only (else asked, default all)
# Secrets: /etc/portainer/admin-password and /etc/portainer/api-token, root only (0600).
# Portainer manages only this host; switching CE to BE keeps the data, BE back to CE is not supported by Portainer.
# category: docker
# ports: PORTAINER_PORT=9443
# check: stack:portainer
# ask: PORTAINER_EDITION=ce|be "Portainer edition: ce = Community Edition (free), be = Business Edition (free for up to 3 nodes with a license key)"
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

port=${PORTAINER_PORT:-9443}
url=https://localhost:$port
secrets=/etc/portainer

# asks for the edition when neither argument nor PORTAINER_EDITION gives one
choose_edition() {
  local e=${1:-${PORTAINER_EDITION:-}}
  if [ -z "$e" ]; then
    [ -t 0 ] || dot_die "which edition? run: portainer.sh ce  or  portainer.sh be"
    read -r -p "Portainer Community Edition (ce) or Business Edition (be)? [ce/be] " e
  fi
  case ${e,,} in
    ce) echo ce ;;
    be|ee) echo ee ;;
    *) dot_die "unknown edition '$e', use ce or be" ;;
  esac
}

# calls the Portainer API on this host (self-signed certificate) with the JWT in $jwt or the API key in $key
api() {
  local auth=()
  [ -n "${jwt:-}" ] && auth=(-H "Authorization: Bearer $jwt")
  [ -n "${key:-}" ] && auth=(-H "X-API-Key: $key")
  curl -fsSk "${auth[@]}" "$@"
}

dot_mode "$@"; set -- "${DOT_ARGS[@]}"
# dot_die in $( ) ends only the subshell: without "|| exit" it went on with an empty edition (portainer/portainer-:lts)
edition=$(choose_edition "${1:-}") || exit 1
dot_bind 0.0.0.0
if [ "$edition" = ee ]; then label=BE; else label=CE; fi
dot_need curl jq
DOT_MODE=compose

# an existing installation keeps its compose file; only CE -> BE is changed in place
compose=/opt/portainer/compose.yaml
if dot_sudo test -f "$compose"; then
  current=$(dot_sudo sed -n 's#.*image: *portainer/portainer-\(ce\|ee\):.*#\1#p' "$compose")
  if [ "$current" = ee ] && [ "$edition" = ce ]; then
    dot_die "this host runs Portainer BE; Portainer does not support going back to CE"
  elif [ "$current" = ce ] && [ "$edition" = ee ]; then
    dot_info "switching Portainer CE to BE, the data stays"
    dot_sudo sed -i 's#portainer/portainer-ce:#portainer/portainer-ee:#' "$compose"
  fi
fi

dot_deploy portainer "services:
  portainer:
    image: portainer/portainer-$edition:lts
    container_name: portainer
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:$port:9443\"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
volumes:
  portainer_data:"

# Portainer locks itself 5 minutes after the first start without an admin, so set it up right away
dot_wait_http "$url/api/system/status" 120 || dot_die "Portainer does not answer on $url"

dot_sudo install -d -m 0700 "$secrets"
pw=${PORTAINER_ADMIN_PASSWORD:-$(dot_sudo cat "$secrets/admin-password" 2>/dev/null)}
# 404 = no admin yet, the expected answer on a first install: no error message for it (api uses curl -S)
if ! api -o /dev/null "$url/api/users/admin/check" 2>/dev/null; then
  [ -n "$pw" ] || pw=$(dot_password 20)
  [ ${#pw} -ge 12 ] || dot_die "PORTAINER_ADMIN_PASSWORD needs at least 12 characters"
  # Portainer 2.45 and later accept the first admin only with the setup token it prints to its log at start
  setup=$(dot_sudo docker logs portainer 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | sed -n 's/.*setup_token=\([^[:space:]]*\).*/\1/p' | tail -n 1)
  hdr=(); [ -n "$setup" ] && hdr=(-H "X-Setup-Token: $setup")
  jq -n --arg p "$pw" '{Username: "admin", Password: $p}' |
    api -X POST -H 'Content-Type: application/json' "${hdr[@]}" --data @- "$url/api/users/admin/init" >/dev/null ||
    dot_die "could not create the Portainer admin (more than 5 minutes after the start? restart: docker restart portainer)"
  printf '%s\n' "$pw" | dot_sudo sh -c "umask 077; cat > '$secrets/admin-password'"
  dot_info "admin user created, password in $secrets/admin-password"
fi
[ -n "$pw" ] || dot_die "the Portainer admin exists but its password is unknown: set PORTAINER_ADMIN_PASSWORD"

jwt=$(jq -n --arg p "$pw" '{Username: "admin", Password: $p}' |
  api -X POST -H 'Content-Type: application/json' --data @- "$url/api/auth" | jq -r '.jwt // empty')
[ -n "$jwt" ] || dot_die "login as Portainer admin failed (wrong password in $secrets/admin-password?)"

if [ "$edition" = ee ] && [ -n "${PORTAINER_LICENSE:-}" ]; then
  jq -n --arg k "$PORTAINER_LICENSE" '{key: $k}' |
    api -X POST -H 'Content-Type: application/json' --data @- "$url/api/licenses/add" >/dev/null ||
    echo "warning: the license key was not accepted, add it in the web UI" >&2
fi

# the local Docker environment through the mounted socket; type 1 alone is also a remote Docker API added by hand
# (28.10.26, review): the stacks of dot_portainer_stack would have gone there
envs=$(api "$url/api/endpoints") || dot_die "Portainer does not list its environments"
if ! jq -e --arg s "$DOT_DOCKER_SOCK" 'any(.[]; .Type == 1 and .URL == $s)' <<<"$envs" >/dev/null; then
  # the name has to be unique in Portainer
  n=local; jq -e 'any(.[]; .Name == "local")' <<<"$envs" >/dev/null && n="local-$(hostname)"
  api -X POST -F "Name=$n" -F EndpointCreationType=1 "$url/api/endpoints" >/dev/null ||
    dot_die "could not add the local Docker environment to Portainer $label (BE: add the license first)"
  dot_info "local Docker environment $n added"
fi

# API token for dot_deploy; a stored one is kept as long as it still works
key=$(dot_sudo cat "$secrets/api-token" 2>/dev/null)
if [ -z "$key" ] || ! jwt= api -o /dev/null "$url/api/endpoints"; then
  key=$(jq -n --arg p "$pw" '{password: $p, description: "dotfiles installers"}' |
    api -X POST -H 'Content-Type: application/json' --data @- "$url/api/users/1/tokens" | jq -r '.rawAPIKey // empty')
  [ -n "$key" ] || dot_die "could not create a Portainer API token"
  printf '%s\n' "$key" | dot_sudo sh -c "umask 077; cat > '$secrets/api-token'"
  dot_info "API token stored in $secrets/api-token"
fi

[ "$edition" = ee ] && [ -z "${PORTAINER_LICENSE:-}" ] && dot_info "BE: enter the license key at the first login"
dot_info "other installers deploy as Portainer stacks with --portainer or INSTALL_MODE=portainer"
dot_summary portainer "https://localhost:$port" "user admin, password: sudo cat $secrets/admin-password; API token: $secrets/api-token"
