#!/bin/bash
# installer: nginx with PHP-FPM and MariaDB, or as a Docker stack
# systems: debian arch fedora rhel
# modes: native compose portainer
# Installs nginx, php-fpm with the MySQL extension and MariaDB in the distro's current versions,
# enables the services where systemd runs. The nginx site config stays as packaged; see the hint at the end.
#   --public / --local          nginx on all interfaces (default) or on this host only (its listen lines)
#   MARIADB_BIND=127.0.0.1      address of MariaDB (default 127.0.0.1; Docker: not published unless set)
#   nginx.sh --docker           in Docker instead: nginx (nginx:stable-alpine), PHP-FPM (php:8.5-fpm with mysqli
#                               and pdo_mysql) and MariaDB (mariadb:lts) under /opt/nginx, the site in
#                               /opt/nginx/html with a test page, its config in /opt/nginx/conf.d; --portainer as a stack
#   NGINX_PORT=8080             HTTP port (default 80; natively the listen lines of the packaged site, a later run
#                               without it keeps the port they have)
# Natively MariaDB's root logs in through the unix socket (sudo mariadb); the stack keeps the generated root and
# app passwords in /opt/nginx/.env (root only).
# category: server
# ports: NGINX_PORT=80
# check: nginx.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
dot_bind 0.0.0.0
db_bind=${MARIADB_BIND:-127.0.0.1}

# Runs nginx, PHP-FPM and MariaDB as the stack nginx from /opt/nginx; config and site are written on the first run
# only and mounted read-only. The official PHP image has no MySQL extensions: the container builds them once from
# the PHP sources in the image when it is created (a minute), so the stack needs no image build of its own.
deploy_docker() {
  local dest=/opt/nginx port=${NGINX_PORT:-80} db_ports=
  case $port in ''|*[!0-9]*) dot_die "NGINX_PORT must be a number, got '$port'" ;; esac
  dot_mode_guard nginx nginx "$port"
  dot_sudo install -d -m 0755 "$dest/conf.d" "$dest/html" || exit 1
  dot_sudo test -f "$dest/conf.d/default.conf" || dot_sudo tee "$dest/conf.d/default.conf" >/dev/null <<'EOF' || exit 1
server {
    listen 80;
    root /var/www/html;
    index index.php index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass php:9000;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
EOF
  dot_sudo test -f "$dest/html/index.php" || dot_sudo tee "$dest/html/index.php" >/dev/null <<'EOF' || exit 1
<?php
// test page of the nginx stack: PHP runs and reaches MariaDB with the app user from /opt/nginx/.env
try {
    $db = new PDO('mysql:host=' . getenv('DB_HOST') . ';dbname=' . getenv('DB_NAME'), getenv('DB_USER'), getenv('DB_PASSWORD'));
    $status = 'MariaDB ' . $db->query('SELECT VERSION()')->fetchColumn() . ' connected';
} catch (Throwable $e) {
    $status = 'no database connection (yet)';
}
?><!doctype html>
<meta charset="utf-8"><title>nginx stack</title>
<h1>It works</h1>
<p>nginx, PHP <?= PHP_VERSION ?>, <?= htmlspecialchars($status) ?></p>
EOF
  [ -n "${MARIADB_BIND:-}" ] && db_ports="
    ports:
      - \"$db_bind:3306:3306\""
  dot_deploy nginx "services:
  nginx:
    image: nginx:stable-alpine
    container_name: nginx
    restart: unless-stopped
    ports:
      - \"$DOT_BIND:$port:80\"
    volumes:
      - $dest/conf.d:/etc/nginx/conf.d:ro
      - $dest/html:/var/www/html:ro
    depends_on:
      - php
  php:
    image: php:8.5-fpm
    container_name: nginx-php
    restart: unless-stopped
    command: sh -c \"php -m | grep -qx pdo_mysql || docker-php-ext-install mysqli pdo_mysql >/dev/null; exec php-fpm\"
    environment:
      DB_HOST: mariadb
      DB_NAME: app
      DB_USER: app
      DB_PASSWORD: \${MARIADB_PASSWORD}
    volumes:
      - $dest/html:/var/www/html:ro
    depends_on:
      - mariadb
  mariadb:
    image: mariadb:lts
    container_name: nginx-mariadb
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: \${MARIADB_ROOT_PASSWORD}
      MARIADB_DATABASE: app
      MARIADB_USER: app
      MARIADB_PASSWORD: \${MARIADB_PASSWORD}$db_ports
    volumes:
      - mariadb_data:/var/lib/mysql
volumes:
  mariadb_data:" "MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD:-$(dot_password 24)}
MARIADB_PASSWORD=$(dot_password 24)"
  dot_info "the PHP container builds its MySQL extensions on its first start, give it a minute"
  dot_summary nginx "http://localhost:$port" "MariaDB root and app (database app) passwords: sudo cat $dest/.env"
}

if [ "$DOT_MODE" != native ]; then
  deploy_docker
  exit 0
fi
dot_mode_guard nginx nginx

case $DOT_PKG in
  apt)
    dot_pkg_install nginx php-fpm php-mysql mariadb-server || dot_die "installing the packages failed"
    # Debian versions the binary and socket: /usr/sbin/php-fpm8.2, /run/php/php8.2-fpm.sock
    fpmbin=$(ls /usr/sbin/php-fpm[0-9]* 2>/dev/null | sort -V | tail -n 1)
    sock=/run/php/php${fpmbin##*php-fpm}-fpm.sock site=/etc/nginx/sites-available/default
    dbconf=/etc/mysql/mariadb.conf.d/99-bind.cnf ;;
  pacman)
    dot_pkg_install nginx php-fpm mariadb || dot_die "installing the packages failed"
    # Arch ships the MySQL extensions disabled
    dot_sudo sed -i 's/^;extension=\(mysqli\|pdo_mysql\)$/extension=\1/' /etc/php/php.ini
    # Arch leaves the data directory to the admin
    [ -d /var/lib/mysql/mysql ] || dot_sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql >/dev/null ||
      dot_die "mariadb-install-db failed"
    fpmbin=/usr/bin/php-fpm sock=/run/php-fpm/php-fpm.sock site=/etc/nginx/nginx.conf dbconf=/etc/my.cnf.d/99-bind.cnf ;;
  dnf|yum)
    # php-fpm brings conf.d/php-fpm.conf and default.d/php.conf: the default server runs PHP already;
    # MariaDB creates its data directory on the first service start
    dot_pkg_install nginx php-fpm php-mysqlnd mariadb-server || dot_die "installing the packages failed"
    fpmbin=/usr/sbin/php-fpm sock=/run/php-fpm/www.sock site=/etc/nginx/nginx.conf dbconf=/etc/my.cnf.d/99-bind.cnf ;;
  *) dot_die "no packages for nginx/PHP/MariaDB on $DOT_OS" ;;
esac
# zabbix_server.sh turns the packaged default server off when nginx comes with it: this one serves it
if [ "$DOT_PKG" = apt ]; then
  [ -e /etc/nginx/sites-enabled/default ] || ! dot_pkg_installed zabbix-nginx-conf ||
    dot_sudo ln -s ../sites-available/default /etc/nginx/sites-enabled/default
else
  dot_sudo sed -i 's/^#zabbix_server\.sh: //' "$site"
fi

# the listen lines of the packaged site follow DOT_BIND (IPv6: [::1] unless all interfaces) and NGINX_PORT; their
# port so far is that of the first one (80 as packaged). 28.10.26: NGINX_PORT worked in Docker only, natively it was 80.
old=$(dot_sudo sed -n -E 's/^[[:space:]]*listen[[:space:]]+([0-9.]+:)?([0-9]+)[[:space:];].*/\2/p' "$site" | head -n 1)
port=${NGINX_PORT:-${old:-80}} old=${old:-80}
case $port in ''|*[!0-9]*) dot_die "NGINX_PORT must be a number, got '$port'" ;; esac
[ "$port" = "$old" ] || ! dot_port_busy "$port" || dot_die "port $port is already in use"
if [ "$DOT_BIND" = 0.0.0.0 ]; then v6=::; else v6=::1; fi
dot_sudo sed -i -E -e "s/^([[:space:]]*listen[[:space:]]+)([0-9.]+:)?$old([[:space:];])/\1$DOT_BIND:$port\3/" \
  -e "s/^([[:space:]]*listen[[:space:]]+)\[[0-9a-fA-F:]*\]:$old([[:space:];])/\1[$v6]:$port\2/" "$site" ||
  dot_die "could not set the listen address in $site"
# SELinux lets nginx bind the web ports only (80, 443, 8080 and a few more); a port it knows already stays as it is
if [ "$port" != 80 ] && command -v semanage >/dev/null 2>&1 && selinuxenabled 2>/dev/null; then
  dot_sudo semanage port -a -t http_port_t -p tcp "$port" 2>/dev/null || true
fi
printf '[mysqld]\nbind-address = %s\n' "$db_bind" | dot_sudo tee "$dbconf" >/dev/null || exit 1

if [ -d /run/systemd/system ]; then
  fpm=$(systemctl list-unit-files --no-legend 'php*-fpm.service' | awk '{print $1; exit}')
  dot_sudo systemctl enable nginx mariadb ${fpm:+"$fpm"} && dot_sudo systemctl restart nginx mariadb ${fpm:+"$fpm"} ||
    dot_die "starting the services failed"
else
  dot_info "no systemd running: start nginx, mariadb and php-fpm by hand"
fi
"$fpmbin" -v | head -n 1
dot_sudo nginx -v
mariadb --version
if [ -f /etc/nginx/default.d/php.conf ]; then
  dot_info "PHP in nginx: the default server passes *.php to $sock (/etc/nginx/default.d/php.conf)"
else
  dot_info "PHP in nginx: in $site add a 'location ~ \.php\$' block with fastcgi_pass unix:$sock;"
fi
dot_info "secure MariaDB with: sudo mariadb-secure-installation"
dot_summary nginx "http://localhost:$port" \
  "MariaDB root: sudo mariadb (unix socket, no password); MariaDB on $db_bind:3306"
