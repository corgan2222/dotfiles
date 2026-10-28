#!/bin/bash
# installer: Redis server (packages.redis.io; Valkey on Arch and Fedora), localhost only by default
# systems: debian arch fedora rhel
# modes: native compose portainer
# Debian family: redis-server and redis-tools from Redis' apt repository packages.redis.io (suite = codename);
#   releases it does not carry (e.g. kali-rolling) get the distribution's redis-server.
# Arch: Arch ships no Redis since its license change, its replacement is valkey (a Redis fork that provides
#   redis, with redis-cli/redis-server names and redis.service); that is installed.
# Fedora, RHEL family: the package redis, which is Redis on RHEL 9 and Valkey with valkey-compat-redis on Fedora.
# Enables the service where systemd runs, port 6379.
#   redis.sh
#   REDIS_PASSWORD=secret redis.sh   sets requirepass; without it an existing password stays, else one is generated.
#                                    Natively it goes with the bind address into a separate file (redis-auth.conf)
#                                    that the main config includes; in Docker into /opt/redis/.env (both root-readable)
#   redis.sh --docker | --portainer  image redis:8-alpine as compose project or Portainer stack "redis" from /opt/redis,
#                                    data in the volume redis_data
#   --public / --local               all interfaces or this host only (else asked, default local)
# category: db
# ports: 6379
# check: redis-server|valkey-server
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

pass=${REDIS_PASSWORD:-}
dot_secret_ok "$pass" || dot_die "REDIS_PASSWORD must not contain spaces, quotes, \$ or backslashes"
dest=/opt/redis


# waits up to 20 s for an answer of the Redis started just now; NOAUTH means running with a password
redis_ping() {
  local i
  for i in $(seq 20); do "$@" 2>&1 | grep -qE 'PONG|NOAUTH' && return 0; sleep 1; done
  return 1
}

case $DOT_PKG in pacman) svc=valkey ;; dnf|yum) svc=redis ;; *) svc=redis-server ;; esac
dot_mode_guard redis "$svc" 6379
dot_bind 127.0.0.1
here=$DOT_BIND; [ "$here" = 0.0.0.0 ] && here=127.0.0.1

# Docker: the password reaches redis-server as --requirepass through compose interpolation from .env
# (an empty one means no password); it is visible in "docker inspect", like any container setting
if [ "$DOT_MODE" != native ]; then
  dot_sudo install -d -m 0755 "$dest"
  [ -n "$pass" ] || dot_sudo grep -q '^REDIS_PASSWORD=.' "$dest/.env" 2>/dev/null || pass=$(dot_password 32)
  [ -z "$pass" ] || dot_env_set "$dest/.env" REDIS_PASSWORD "$pass" || dot_die "could not write $dest/.env"
  dot_deploy redis "services:
  redis:
    image: redis:8-alpine
    container_name: redis
    restart: unless-stopped
    command: [\"redis-server\", \"--requirepass\", \"\${REDIS_PASSWORD:-}\"]
    ports:
      - \"$DOT_BIND:6379:6379\"
    volumes:
      - data:/data
volumes:
  data:"
  [ -n "${DOT_NO_START:-}" ] || redis_ping dot_sudo docker exec redis redis-cli ping || dot_die "redis does not answer, see: sudo docker logs redis"
  dot_summary redis "redis://localhost:6379" "password REDIS_PASSWORD in $dest/.env, no name needed (Redis' default account); redis-cli: REDISCLI_AUTH=<password> redis-cli"
  exit 0
fi

case $DOT_PKG in
  apt)
    conf=/etc/redis/redis.conf owner=redis
    dot_need curl
    # only codenames and architectures the repository carries, else the distribution package
    if curl -fsSL "https://packages.redis.io/deb/dists/$DOT_OS_BASE_CODENAME/Release" 2>/dev/null |
      grep -q "^Architectures:.* $(dpkg --print-architecture)\( \|$\)"; then
      dot_apt_repo redis https://packages.redis.io/gpg https://packages.redis.io/deb "$DOT_OS_BASE_CODENAME" main
    else
      dot_info "packages.redis.io has no packages for '$DOT_OS_BASE_CODENAME', installing the distribution's Redis"
    fi
    dot_pkg_install redis-server redis-tools || dot_die "installing Redis failed" ;;
  pacman)
    conf=/etc/valkey/valkey.conf owner=valkey
    dot_pkg_install valkey || dot_die "installing valkey failed" ;;
  dnf|yum)
    dot_pkg_install redis || dot_die "installing Redis failed"
    if dot_pkg_installed valkey; then
      svc=valkey conf=/etc/valkey/valkey.conf owner=valkey
    else
      conf=/etc/redis/redis.conf owner=redis
    fi ;;
  *) dot_die "redis.sh supports Debian-based systems, Arch, Fedora and the RHEL family, not $DOT_OS" ;;
esac

# a separate file keeps password and bind address out of the packaged config; the include line is the only change
# there, and as the last line it wins over the packaged bind
auth=${conf%/*}/redis-auth.conf
[ -n "$pass" ] || pass=$(dot_sudo sed -n 's/^requirepass "\(.*\)"$/\1/p' "$auth" 2>/dev/null)
[ -n "$pass" ] || pass=$(dot_password 32)
case $DOT_BIND in
  127.0.0.1) bind="127.0.0.1 -::1" ;;
  0.0.0.0) bind="* -::*" ;;
  *) bind=$DOT_BIND ;;
esac
printf '# written by redis.sh\nrequirepass "%s"\nbind %s\n' "$pass" "$bind" | dot_sudo tee "$auth" >/dev/null || exit 1
dot_sudo chown "$owner:" "$auth" && dot_sudo chmod 0640 "$auth"
dot_sudo grep -qxF "include $auth" "$conf" || echo "include $auth" | dot_sudo tee -a "$conf" >/dev/null
dot_info "requirepass and bind $bind set in $auth"

if [ -d /run/systemd/system ]; then
  dot_sudo systemctl enable "$svc" && dot_sudo systemctl restart "$svc" || dot_die "$svc does not start, see: journalctl -u $svc"
  redis_ping redis-cli -h "$here" ping || dot_die "$svc does not answer on $here:6379"
else
  dot_info "no systemd running: start it with: sudo -u $owner redis-server $conf --daemonize yes"
fi
dot_info "$(redis-server --version | cut -d' ' -f1-3) installed, config $conf"
dot_summary redis "redis://localhost:6379" "password: requirepass in $auth, no name needed (Redis' default account); redis-cli: REDISCLI_AUTH=<password> redis-cli" "$svc"
