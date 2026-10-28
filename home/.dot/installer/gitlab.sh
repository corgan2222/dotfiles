#!/bin/bash
# installer: GitLab CE (Omnibus package from packages.gitlab.com, or Docker), needs 4 GB RAM
# systems: ubuntu amd64
# modes: native compose portainer
# Installs GitLab Community Edition from GitLab's apt or rpm repository (Ubuntu, Debian, RHEL family). The first run
# writes a short /etc/gitlab/gitlab.rb and sets the root password; the package then configures and starts GitLab.
# Running it again keeps gitlab.rb, data and password. The first start takes minutes.
#   GITLAB_VERSION=19.5.1   the GitLab version (default: the one below, tested 28.10.26). Fixed on purpose: GitLab
#                      has required upgrade stops, a jump past one breaks the database migrations. Updating: look up the
#                      path at https://docs.gitlab.com/update/upgrade_paths/ and go one stop at a time, waiting for the
#                      background migrations (Admin > Monitoring > Background migrations) before the next stop.
#                      Natively: GITLAB_VERSION=<stop> gitlab.sh. Docker: set the image tag <stop>-ce.0 in
#                      /opt/gitlab/compose.yaml and run gitlab.sh again (later runs keep compose.yaml).
#                      An installed GitLab newer than GITLAB_VERSION stays as it is.
#   EXTERNAL_URL=http://<hostname>   address of GitLab for users and clone links; <hostname> becomes this host's name.
#                      Without a port in it, GITLAB_HTTP_PORT (http) or GITLAB_HTTPS_PORT (https) is added unless it
#                      is 80 or 443. https lets GitLab ask Let's Encrypt for a certificate, the name must resolve then.
#   GITLAB_HTTP_PORT=8929   web UI over http (default 8929, GitLab's Docker docs use it too)
#   GITLAB_HTTPS_PORT=8943  web UI over https (Docker: published to 443 in the container)
#   GITLAB_SSH_PORT=2224    git over SSH (Docker only, natively GitLab uses the host's sshd on 22)
#                      URL and ports count on the first run only, later runs keep gitlab.rb or compose.yaml.
#   gitlab.sh --docker | --portainer   image gitlab/gitlab-ce:<GITLAB_VERSION>-ce.0 as compose project or Portainer
#                      stack "gitlab"
#                      from /opt/gitlab (config, logs and data in /opt/gitlab/config, logs, data)
#   --public / --local listen on all interfaces or on this host only (else asked, default all)
# Login: user root with a random password, kept root-only in /etc/gitlab/root-password (native) or /opt/gitlab/.env.
# GitLab takes it only when it creates its database: an older database keeps its password.
# GitLab's own Prometheus and exporters stay off: they would take ports 9090, 9100 … of prometheus.sh and
# node_exporter.sh. Natively GitLab still takes the ports 8060, 8080 (Puma), 8082, 8092, 8150-8155,
# 9229 and 9236 (28.10.26, GitLab 19.5).
# category: dev
# ports: GITLAB_HTTP_PORT=8929 GITLAB_HTTPS_PORT=8943 GITLAB_SSH_PORT=2224
# check: gitlab-runsvdir.service stack:gitlab
# ask: EXTERNAL_URL=http://<hostname> "Address of GitLab, e.g. http://gitlab.example.org (<hostname>: this host's name; the port is added)"
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"

http=${GITLAB_HTTP_PORT:-8929} https=${GITLAB_HTTPS_PORT:-8943} ssh=${GITLAB_SSH_PORT:-2224}
ver=${GITLAB_VERSION:-19.5.1}
[[ $ver =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || dot_die "GITLAB_VERSION must look like 19.5.1, got '$ver'"
case $http:$https:$ssh in *[!0-9:]*) dot_die "GITLAB_HTTP_PORT, GITLAB_HTTPS_PORT and GITLAB_SSH_PORT must be numbers" ;; esac

# EXTERNAL_URL with this host's name and the port: a port given in it moves GITLAB_HTTP_PORT or GITLAB_HTTPS_PORT
url=${EXTERNAL_URL:-http://<hostname>}
url=${url//<hostname>/$(hostname -f 2>/dev/null || hostname)} url=${url%/}
case $url in http://*) def=80 ;; https://*) def=443 ;; *) dot_die "EXTERNAL_URL must start with http:// or https://, got '$url'" ;; esac
dot_secret_ok "$url" || dot_die "EXTERNAL_URL must not contain spaces, quotes, \$ or backslashes"
hostport=${url#*://} hostport=${hostport%%/*}
if [[ $hostport =~ :([0-9]+)$ ]]; then
  if [ $def = 80 ]; then http=${BASH_REMATCH[1]}; else https=${BASH_REMATCH[1]}; fi
else
  p=$([ $def = 80 ] && echo "$http" || echo "$https")
  [ "$p" = $def ] || url=${url/$hostport/$hostport:$p}
fi

dot_mode_guard gitlab gitlab-runsvdir "$http" "$https" "$ssh"
dot_bind 0.0.0.0
dot_need curl
here=$([ "$DOT_BIND" = 0.0.0.0 ] && echo localhost || echo "$DOT_BIND")
mem=$(awk '/^MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)
[ "${mem:-0}" -ge 3900 ] || echo "warning: GitLab needs 4 GB RAM, this system has ${mem} MB: it will be slow or swap" >&2

# waits for the sign-in page at <scheme>://<host>:<port> (minutes on the first start: GitLab creates its database)
gitlab_wait() {
  dot_info "waiting for GitLab to start, the first start takes 3 to 10 minutes"
  dot_wait_http "$1/users/sign_in" 1200 200 || dot_die "GitLab does not answer at $1 after 20 minutes: $2"
}

if [ "$DOT_MODE" != native ]; then
  dest=/opt/gitlab
  dot_sudo install -d -m 0755 "$dest/config" "$dest/logs" "$dest/data" || exit 1
  # A compose.yaml of an older run has image gitlab/gitlab-ce:latest, and dot_deploy pulls on every run: that jumped
  # past the upgrade stops (28.10.26). Pin the version the container runs (never a downgrade, no jump), GITLAB_VERSION
  # when none can be read.
  if dot_sudo grep -q '^ *image: *gitlab/gitlab-ce:latest *$' "$dest/compose.yaml" 2>/dev/null; then
    img=$(dot_sudo docker inspect -f '{{.Image}}' gitlab 2>/dev/null) || img=gitlab/gitlab-ce:latest
    have=$(dot_sudo docker run --rm --pull never --entrypoint cat "$img" \
      /opt/gitlab/embedded/service/gitlab-rails/VERSION 2>/dev/null)
    pin=$ver
    if [[ $have =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [ "$have" != "$ver" ]; then
      pin=$have
      dot_info "GitLab $have runs here, not $ver: keeping $have; update along the stops (GITLAB_VERSION in gitlab.sh)"
    fi
    dot_sudo sed -i "s|^\( *image: *\)gitlab/gitlab-ce:latest *$|\1gitlab/gitlab-ce:$pin-ce.0|" "$dest/compose.yaml" ||
      dot_die "could not pin the image in $dest/compose.yaml"
    dot_info "pinned the image in $dest/compose.yaml: gitlab/gitlab-ce:latest -> gitlab/gitlab-ce:$pin-ce.0"
  fi
  # GitLab inside listens on 80 or 443, Docker publishes the ports; the URL carries the outside port
  dot_deploy gitlab "services:
  gitlab:
    image: gitlab/gitlab-ce:$ver-ce.0
    container_name: gitlab
    restart: unless-stopped
    shm_size: 256m
    environment:
      GITLAB_ROOT_PASSWORD: \${GITLAB_ROOT_PASSWORD}
      GITLAB_OMNIBUS_CONFIG: |
        external_url '$url'
        nginx['listen_port'] = $def
        gitlab_rails['gitlab_shell_ssh_port'] = $ssh
        prometheus_monitoring['enable'] = false
    ports:
      - \"$DOT_BIND:$http:80\"
      - \"$DOT_BIND:$https:443\"
      - \"$DOT_BIND:$ssh:22\"
    volumes:
      - $dest/config:/etc/gitlab
      - $dest/logs:/var/log/gitlab
      - $dest/data:/var/opt/gitlab" "GITLAB_ROOT_PASSWORD=$(dot_password 24)"
  [ -n "${DOT_NO_START:-}" ] && exit 0
  # URL and ports of the first run
  url=$(dot_sudo sed -n "s/^ *external_url '\(.*\)'$/\1/p" "$dest/compose.yaml")
  http=$(dot_sudo sed -n 's/^ *- ".*:\([0-9]*\):80"$/\1/p' "$dest/compose.yaml")
  https=$(dot_sudo sed -n 's/^ *- ".*:\([0-9]*\):443"$/\1/p' "$dest/compose.yaml")
  ssh=$(dot_sudo sed -n 's/^ *- ".*:\([0-9]*\):22"$/\1/p' "$dest/compose.yaml")
  case $url in https:*) gitlab_wait "https://$here:$https" "sudo docker logs gitlab" ;;
    *) gitlab_wait "http://$here:$http" "sudo docker logs gitlab" ;; esac
  dot_summary gitlab "$url localhost:$ssh" "user root, password: GITLAB_ROOT_PASSWORD in $dest/.env"
  exit 0
fi

[ -d /run/systemd/system ] || dot_die "GitLab needs systemd, it is not running here"
case $DOT_PKG in
  apt)
    case $DOT_OS_BASE in ubuntu|debian) ;; *) dot_die "GitLab has packages for Ubuntu and Debian, not $DOT_OS: run it in Docker" ;; esac
    dot_apt_repo gitlab-ce https://packages.gitlab.com/gpgkey/gpg.key \
      "https://packages.gitlab.com/gitlab/gitlab-ce/$DOT_OS_BASE/$DOT_OS_BASE_CODENAME" "$DOT_OS_BASE_CODENAME" main ;;
  dnf|yum)
    [ "$DOT_OS_BASE" = rhel ] || dot_die "GitLab has rpm packages for the RHEL family, not $DOT_OS: run it in Docker"
    dot_rpm_repo gitlab-ce "https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/config_file.repo?os=el&dist=${DOT_OS_VERSION%%.*}" ;;
  *) dot_die "GitLab has no package for $DOT_OS, run it in Docker: gitlab.sh --docker" ;;
esac

# gitlab.rb and the password before the package: its postinst configures GitLab right away and creates the database
rb=/etc/gitlab/gitlab.rb pwf=/etc/gitlab/root-password
dot_sudo install -d -m 0775 /etc/gitlab || exit 1
dot_sudo test -s "$pwf" || { dot_password 24; echo; } | dot_sudo sh -c "umask 077; cat > '$pwf'" || dot_die "could not write $pwf"
if ! dot_sudo test -f "$rb"; then
  dot_sudo install -m 0600 /dev/stdin "$rb" <<EOF || dot_die "could not write $rb"
# written by gitlab.sh on the first run; all settings: /opt/gitlab/etc/gitlab.rb.template, then: sudo gitlab-ctl reconfigure
external_url '$url'
nginx['listen_addresses'] = ['$([ "$DOT_BIND" = 0.0.0.0 ] && echo '*' || echo "$DOT_BIND")']
# read when GitLab creates its database only
gitlab_rails['initial_root_password'] = File.read('$pwf').strip if File.exist?('$pwf')
prometheus_monitoring['enable'] = false
EOF
  dot_info "wrote $rb"
fi
old=$(dot_pkg_version gitlab-ce)
# apt: 19.5.1-ce.0, rpm: 19.5.1; never older than installed (apt would refuse the downgrade, dnf skip it)
if [ -n "$old" ] && [ "$(printf '%s\n%s\n' "${old%%-*}" "$ver" | sort -V | tail -n 1)" = "${old%%-*}" ]; then
  dot_info "GitLab $old is installed, not older than $ver: keeping it"
else
  case $DOT_PKG in apt) p=gitlab-ce=$ver-ce.0 ;; *) p=gitlab-ce-$ver ;; esac
  dot_info "installing $p, about 1.5 GB; the package configures GitLab, that takes minutes"
  dot_pkg_install "$p" || dot_die "installing $p failed (GitLab's upgrade path: see the header of $0)"
fi
# the postinst skips its configure run without a valid external_url (or with /etc/gitlab/skip-auto-reconfigure)
dot_sudo gitlab-ctl status >/dev/null 2>&1 || dot_sudo gitlab-ctl reconfigure || dot_die "gitlab-ctl reconfigure failed"
new=$(dot_pkg_version gitlab-ce)
[ "$old" = "$new" ] && dot_info "GitLab $new is up to date" || dot_info "GitLab ${old:-–} -> $new"

url=$(dot_sudo sed -n "s/^external_url ['\"]\(.*\)['\"]$/\1/p" "$rb")
p=${url#*://} p=${p%%/*}
case $p in *:*) p=${p##*:} ;; *) case $url in https:*) p=443 ;; *) p=80 ;; esac ;; esac
gitlab_wait "${url%%://*}://$here:$p" "sudo gitlab-ctl status"
dot_summary gitlab "$url" "user root, password: sudo cat $pwf" gitlab-runsvdir
