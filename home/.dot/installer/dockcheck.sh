#!/bin/bash
# installer: dockcheck, lists Docker containers whose images have updates and updates the chosen ones
# systems: amd64 arm64
# Installs dockcheck (github.com/mag37/dockcheck, a bash script) with its notification templates into /opt/dockcheck,
# the command dockcheck.sh into /usr/local/bin, and regctl (github.com/regclient/regclient, sha256 digest checked)
# next to it; dockcheck asks the registries with regctl, which needs no pull and no Docker Hub pull quota.
#   dockcheck.sh                                  installs it
#   DOCKCHECK_NTFY_URL=https://ntfy.sh/my-updates  notices through ntfy (first run), DOCKCHECK_NTFY_TOKEN=tk_… for a
#                                                 protected topic; other channels: /opt/dockcheck/dockcheck.config
#   DOCKCHECK_SCHEDULE="*-*-* 06:00"              when the systemd timer checks (systemd OnCalendar), off: no timer
# Use: sudo dockcheck.sh (asks which containers to update), sudo dockcheck.sh -n (check only), -h for the options.
# The timer dockcheck.timer only checks (dockcheck.sh -n -i) and sends a notice when a channel is configured; the
# result is in journalctl -u dockcheck. Config /opt/dockcheck/dockcheck.config, 0600 (written on the first run, yours
# from then on). Running again keeps the config and the schedule and never replaces a newer dockcheck (dockcheck.sh -u
# updates itself from GitHub's main branch, unchecked).
# Version: dockcheck publishes no release files, so the tag and the sha256 of GitHub's archive of that tag are fixed
# below (checked 28.10.26). Updating: read the changelog in the README, set tag and sum (sha256sum of
# https://github.com/mag37/dockcheck/archive/refs/tags/<tag>.tar.gz). regctl comes from its newest release.
# category: docker
# check: dockcheck.sh
# ask: DOCKCHECK_NTFY_URL=none "ntfy topic URL for update notices, e.g. https://ntfy.sh/my-updates (none: journal only)"
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

tag=v0.8.3
sum=dc2d3d23a422a7af7429b68815b22fba7d913c16229d66fc071de6cbfd1e2c9d
dest=/opt/dockcheck
conf=$dest/dockcheck.config
schedule=${DOCKCHECK_SCHEDULE:-*-*-* 06:00}
[ "${DOCKCHECK_NTFY_URL:-}" = none ] && DOCKCHECK_NTFY_URL=
case $DOT_ARCH in amd64|arm64) ;; *) dot_die "regctl, which dockcheck needs, has no build for $DOT_ARCH" ;; esac
for v in DOCKCHECK_NTFY_URL DOCKCHECK_NTFY_TOKEN; do
  dot_secret_ok "${!v:-}" || dot_die "$v must not contain spaces, quotes, \$ or backslashes"
done
[ -z "${DOCKCHECK_NTFY_URL:-}" ] || [[ $DOCKCHECK_NTFY_URL =~ ^https?://[^/]+/[^/]+$ ]] ||
  dot_die "DOCKCHECK_NTFY_URL must be the URL of a topic like https://ntfy.sh/my-updates, got '$DOCKCHECK_NTFY_URL'"
[[ $schedule =~ ^[A-Za-z0-9\ :*/,.~-]+$ ]] || dot_die "DOCKCHECK_SCHEDULE must be a systemd OnCalendar value or off"
command -v docker >/dev/null 2>&1 || dot_die "Docker is not installed here (docker.sh), dockcheck checks its containers"
dot_need curl tar jq
tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT

# dockcheck itself, unless the one in place is newer (VERSION="v0.8.3" in its second line)
have=$(sed -n 's/^VERSION="\(.*\)"$/\1/p' "$dest/dockcheck.sh" 2>/dev/null)
newest=$(printf '%s\n%s\n' "$have" "$tag" | sort -V | tail -n 1)
if [ -n "$have" ] && [ "$have" != "$tag" ] && [ "$newest" = "$have" ]; then
  dot_info "dockcheck $have is installed, newer than $tag: keeping it"
else
  dot_info "Downloading dockcheck $tag"
  curl -fsSL -o "$tmp/dc.tar.gz" "https://github.com/mag37/dockcheck/archive/refs/tags/$tag.tar.gz" ||
    dot_die "download of dockcheck $tag failed"
  [ "$(sha256sum "$tmp/dc.tar.gz" | cut -d' ' -f1)" = "$sum" ] ||
    dot_die "checksum of dockcheck $tag does not match, aborting"
  tar -xzf "$tmp/dc.tar.gz" -C "$tmp" || dot_die "could not unpack dockcheck $tag"
  # the script, its templates and add-ons; dockcheck finds them next to itself (readlink -f of its path)
  dot_sudo install -d -m 0755 "$dest" &&
    dot_sudo cp -r "$tmp/dockcheck-${tag#v}/dockcheck.sh" "$tmp/dockcheck-${tag#v}/notify_templates" \
      "$tmp/dockcheck-${tag#v}/addons" "$tmp/dockcheck-${tag#v}/default.config" "$dest/" &&
    dot_sudo chmod 0755 "$dest/dockcheck.sh" && dot_sudo ln -sfn "$dest/dockcheck.sh" /usr/local/bin/dockcheck.sh ||
    dot_die "could not install dockcheck into $dest"
fi

# regctl next to dockcheck.sh, where dockcheck looks after PATH; without it dockcheck asks to download it unchecked
dot_info "Downloading regctl"
dot_github_fetch regclient/regclient "/regctl-linux-$DOT_ARCH\$" "$tmp/regctl" || dot_die "could not download regctl"
dot_sudo install -m 0755 "$tmp/regctl" "$dest/regctl" || dot_die "could not install $dest/regctl"

if dot_sudo test -f "$conf"; then
  dot_info "keeping $conf"
  [ -z "${DOCKCHECK_NTFY_URL:-}" ] ||
    echo "warning: DOCKCHECK_NTFY_URL only counts on the first run: edit NTFY_* in $conf" >&2
else
  # default.config with the ntfy lines filled in; a token goes in as NTFY_AUTH=":<token>" (dockcheck's format)
  { if [ -n "${DOCKCHECK_NTFY_URL:-}" ]; then
      sed -e 's|^# NOTIFY_CHANNELS=.*|NOTIFY_CHANNELS="ntfy"|' \
        -e "s|^# NTFY_DOMAIN=.*|NTFY_DOMAIN=\"${DOCKCHECK_NTFY_URL%/*}\"|" \
        -e "s|^# NTFY_TOPIC_NAME=.*|NTFY_TOPIC_NAME=\"${DOCKCHECK_NTFY_URL##*/}\"|" \
        -e "s|^# NTFY_AUTH=.*|NTFY_AUTH=\"${DOCKCHECK_NTFY_TOKEN:+:$DOCKCHECK_NTFY_TOKEN}\"|" "$dest/default.config"
    else
      cat "$dest/default.config"
    fi; } | dot_sudo sh -c "umask 077; cat > '$conf'" || dot_die "could not write $conf"
  dot_info "wrote $conf"
fi

timer=
if [ "$schedule" = off ]; then
  dot_sudo rm -f /etc/systemd/system/dockcheck.service /etc/systemd/system/dockcheck.timer
  [ -d /run/systemd/system ] && dot_sudo systemctl disable --now dockcheck.timer 2>/dev/null
elif [ -d /run/systemd/system ]; then
  # the schedule of an earlier run stays unless DOCKCHECK_SCHEDULE is given. HOME: dockcheck runs with "set -u" and
  # reads $HOME/.config/dockcheck.config, systemd sets no HOME (28.10.26: "HOME: unbound variable")
  [ -n "${DOCKCHECK_SCHEDULE:-}" ] || schedule=$(sed -n 's/^OnCalendar=//p' /etc/systemd/system/dockcheck.timer \
    2>/dev/null | grep . || echo "$schedule")
  printf '%s\n' "[Unit]" "Description=dockcheck: check container images for updates" \
    "After=docker.service network-online.target" "Wants=network-online.target" "" \
    "[Service]" "Type=oneshot" "Environment=HOME=/root" "ExecStart=$dest/dockcheck.sh -n -i -m" |
    dot_sudo tee /etc/systemd/system/dockcheck.service >/dev/null &&
  printf '%s\n' "[Unit]" "Description=dockcheck: daily image check" "" "[Timer]" "OnCalendar=$schedule" \
    "RandomizedDelaySec=30m" "Persistent=true" "" "[Install]" "WantedBy=timers.target" |
    dot_sudo tee /etc/systemd/system/dockcheck.timer >/dev/null &&
  dot_sudo systemctl daemon-reload && dot_sudo systemctl enable --now dockcheck.timer >/dev/null 2>&1 ||
    dot_die "could not set up dockcheck.timer"
  timer=1
else
  echo "warning: no systemd here, no timer: run dockcheck.sh -n -i from cron" >&2
fi

# dockcheck checks its dependencies first and exits when one does not work
dot_sudo "$dest/dockcheck.sh" -v >/dev/null 2>&1 && dot_sudo "$dest/regctl" version >/dev/null 2>&1 ||
  dot_die "dockcheck or regctl does not run, see: sudo dockcheck.sh -v"
login="none (command line)"
dot_sudo grep -q '^NTFY_AUTH=".' "$conf" && login="$login; ntfy token: sudo grep NTFY_AUTH $conf"
DOT_BIND= dot_summary dockcheck "" "$login"
channels=$(dot_sudo sed -n 's/^NOTIFY_CHANNELS="\(.*\)"/\1/p' "$conf")
printf '  use:     sudo dockcheck.sh (choose updates), sudo dockcheck.sh -n (check only), -h for the options\n'
[ -z "$timer" ] || printf '  checks:  %s (dockcheck.timer), notices: %s\n' "$schedule" "${channels:-none, journal only}"
printf '  config:  %s\n' "$conf"
