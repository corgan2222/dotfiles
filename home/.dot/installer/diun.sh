#!/bin/bash
# installer: Diun, notifies when the images of the running Docker containers have updates
# systems: all
# modes: compose portainer
# Runs Diun (crazymax.dev/diun) as compose project or Portainer stack "diun" from /opt/diun (default compose,
# --portainer for a stack); installs Docker through docker.sh when it is missing. No port, no web UI, about 20 MB RAM.
# Watches every container of this host through the Docker socket (read-only mount; label diun.enable=false leaves one
# out) and compares its image with the registry. It changes nothing: updating stays with you.
#   DIUN_SCHEDULE="0 */6 * * *"   when to check, cron format (first run)
#   Notification, first run (later: /opt/diun/config/diun.yml, then run again), without any only the log
#   (sudo docker logs diun):
#   DIUN_NTFY_URL=https://ntfy.sh/my-updates     ntfy topic URL, DIUN_NTFY_TOKEN=… for a protected topic
#   DIUN_GOTIFY_URL=https://gotify.example.org DIUN_GOTIFY_TOKEN=…   Gotify app token
#   DIUN_TELEGRAM_TOKEN=… DIUN_TELEGRAM_CHAT_ID=-1001234567890       Telegram bot and chat
#   DIUN_WEBHOOK_URL=https://example.org/hook    POSTs JSON per update
# Config /opt/diun/config/diun.yml (written on the first run, yours from then on, examples for more notifiers),
# tokens root-only in /opt/diun/config/*-token, database in /opt/diun/data. Running again pulls the newest image.
# Whoever can use the Docker socket owns the host: Diun only reads through it, but needs it.
# category: docker
# check: stack:diun
# ask: DIUN_NTFY_URL=none "ntfy topic URL for update notices, e.g. https://ntfy.sh/my-updates (none: log only)"
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
[ $# -eq 0 ] || dot_die "unknown argument '$1', usage: diun.sh [--docker|--portainer]"
[ "$DOT_MODE" = native ] && DOT_MODE=compose

dest=/opt/diun
conf=$dest/config
schedule=${DIUN_SCHEDULE:-0 */6 * * *}
[ "${DIUN_NTFY_URL:-}" = none ] && DIUN_NTFY_URL=
for v in DIUN_NTFY_URL DIUN_NTFY_TOKEN DIUN_GOTIFY_URL DIUN_GOTIFY_TOKEN DIUN_TELEGRAM_TOKEN DIUN_TELEGRAM_CHAT_ID DIUN_WEBHOOK_URL; do
  dot_secret_ok "${!v:-}" || dot_die "$v must not contain spaces, quotes, \$ or backslashes"
done
[[ $schedule =~ ^[0-9*/,-]+(\ [0-9*/,-]+){4}$ ]] || dot_die "DIUN_SCHEDULE must be cron with 5 fields, got '$schedule'"
[ -z "${DIUN_NTFY_URL:-}" ] || [[ $DIUN_NTFY_URL =~ ^https?://[^/]+/[^/]+$ ]] ||
  dot_die "DIUN_NTFY_URL must be the URL of a topic like https://ntfy.sh/my-updates, got '$DIUN_NTFY_URL'"
[ -z "${DIUN_TELEGRAM_CHAT_ID:-}" ] || [[ $DIUN_TELEGRAM_CHAT_ID =~ ^-?[0-9]+$ ]] ||
  dot_die "DIUN_TELEGRAM_CHAT_ID must be a number, got '$DIUN_TELEGRAM_CHAT_ID'"
[ -z "${DIUN_GOTIFY_URL:-}" ] || [ -n "${DIUN_GOTIFY_TOKEN:-}" ] || dot_die "DIUN_GOTIFY_URL needs DIUN_GOTIFY_TOKEN"
[ -z "${DIUN_TELEGRAM_TOKEN:-}" ] || [ -n "${DIUN_TELEGRAM_CHAT_ID:-}" ] || dot_die "DIUN_TELEGRAM_TOKEN needs DIUN_TELEGRAM_CHAT_ID"

# writes a token root-only to $conf/<name>-token (Diun runs as root and reads it as /etc/diun/<name>-token)
token_file() { printf '%s\n' "$2" | dot_sudo sh -c "umask 077; cat > '$conf/$1-token'" || dot_die "could not write $conf/$1-token"; }

# prints the notif: block for the variables given, commented examples for the others
notif_block() {
  echo "notif:"
  if [ -n "${DIUN_NTFY_URL:-}" ]; then
    printf '  ntfy:\n    endpoint: %s\n    topic: %s\n' "${DIUN_NTFY_URL%/*}" "${DIUN_NTFY_URL##*/}"
    [ -z "${DIUN_NTFY_TOKEN:-}" ] || printf '    tokenFile: /etc/diun/ntfy-token\n'
  else
    printf '  # ntfy:\n  #   endpoint: https://ntfy.sh\n  #   topic: my-updates\n'
  fi
  if [ -n "${DIUN_GOTIFY_URL:-}" ]; then
    printf '  gotify:\n    endpoint: %s\n    tokenFile: /etc/diun/gotify-token\n' "$DIUN_GOTIFY_URL"
  else
    printf '  # gotify:\n  #   endpoint: https://gotify.example.org\n  #   tokenFile: /etc/diun/gotify-token\n'
  fi
  if [ -n "${DIUN_TELEGRAM_TOKEN:-}" ]; then
    printf '  telegram:\n    tokenFile: /etc/diun/telegram-token\n    chatIDs:\n      - %s\n' "$DIUN_TELEGRAM_CHAT_ID"
  else
    printf '  # telegram:\n  #   tokenFile: /etc/diun/telegram-token\n  #   chatIDs:\n  #     - -1001234567890\n'
  fi
  if [ -n "${DIUN_WEBHOOK_URL:-}" ]; then
    printf '  webhook:\n    endpoint: %s\n    method: POST\n    headers:\n      content-type: application/json\n' "$DIUN_WEBHOOK_URL"
  else
    printf '  # webhook:\n  #   endpoint: https://example.org/hook\n  #   method: POST\n  #   headers:\n  #     content-type: application/json\n'
  fi
  printf '  # mail, Discord, Matrix, Slack, Teams, Pushover, MQTT and more: https://crazymax.dev/diun/ (Notifications)\n'
}

dot_sudo install -d -m 0755 "$dest" "$conf" "$dest/data" || exit 1
if dot_sudo test -f "$conf/diun.yml"; then
  dot_info "keeping $conf/diun.yml"
  [ -z "${DIUN_NTFY_URL:-}${DIUN_GOTIFY_URL:-}${DIUN_TELEGRAM_TOKEN:-}${DIUN_WEBHOOK_URL:-}" ] ||
    echo "warning: notification variables only count on the first run: edit $conf/diun.yml and run diun.sh again" >&2
else
  [ -z "${DIUN_NTFY_TOKEN:-}" ] || [ -z "${DIUN_NTFY_URL:-}" ] || token_file ntfy "$DIUN_NTFY_TOKEN"
  [ -z "${DIUN_GOTIFY_URL:-}" ] || token_file gotify "$DIUN_GOTIFY_TOKEN"
  [ -z "${DIUN_TELEGRAM_TOKEN:-}" ] || token_file telegram "$DIUN_TELEGRAM_TOKEN"
  { cat <<EOF
# Diun config, written by diun.sh on the first run and yours from now on. Apply: sudo docker restart diun
# Reference: https://crazymax.dev/diun/config/  Tokens: files next to this one (/etc/diun in the container), 0600.
db:
  path: /data/diun.db

watch:
  workers: 10
  schedule: "$schedule"
  jitter: 30s
  # no notice for every image on the very first check
  firstCheckNotif: false
  runOnStartup: true

defaults:
  notifyOn: [new, update]

providers:
  docker:
    # all containers; label diun.enable=false leaves one out (with false here: only those labelled diun.enable=true)
    watchByDefault: true
    watchStopped: false

EOF
    notif_block; } | dot_put_new "$conf/diun.yml"
  dot_sudo chmod 0644 "$conf/diun.yml"
fi

dot_deploy diun "services:
  diun:
    image: crazymax/diun:4
    container_name: diun
    restart: unless-stopped
    command: serve
    environment:
      LOG_LEVEL: info
      CONFIG: /etc/diun/diun.yml
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /etc/localtime:/etc/localtime:ro
      - $conf:/etc/diun:ro
      - $dest/data:/data"
[ -n "${DOT_NO_START:-}" ] && exit 0
# a changed diun.yml takes effect on the next start (dot_deploy leaves a running container alone)
dot_sudo docker restart diun >/dev/null || dot_die "could not restart Diun"

# Diun exits right after the start when its config is wrong; running for 10 s with no restart is good enough
sleep 10
[ "$(dot_sudo docker inspect -f '{{.State.Running}} {{.RestartCount}}' diun 2>/dev/null)" = "true 0" ] ||
  { dot_sudo docker logs --tail 20 diun >&2; dot_die "Diun does not keep running, see: sudo docker logs diun"; }

sent=$(dot_sudo sed -n '/^notif:/,$ s/^  \([a-z]*\):$/\1/p' "$conf/diun.yml" | paste -sd ' ')
tokens=$(dot_sudo sh -c "ls $conf/*-token 2>/dev/null" | sed 's/^/sudo cat /' | paste -sd ',' | sed 's/,/, /g')
dot_summary diun "" "none (no web UI)${tokens:+; tokens: $tokens}"
printf '  checks:  %s, all containers; notices: %s\n' "$schedule" "${sent:-none, log only (sudo docker logs diun)}"
printf '  config:  %s/diun.yml (apply: sudo docker restart diun); now: sudo docker exec diun diun image list\n' "$conf"
