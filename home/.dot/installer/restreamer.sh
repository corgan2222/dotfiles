#!/bin/bash
# installer: datarhei Restreamer 2 in Docker
# systems: amd64 arm64 armv7
# modes: compose portainer
# Runs datarhei Restreamer (docs.datarhei.com/restreamer) with Docker compose from /opt/restreamer (--portainer: as a
# stack in the local Portainer); installs Docker through docker.sh when it is missing. The compose file is written on
# the first run only; running again pulls the newest image and recreates the container. Config and data stay in
# /opt/restreamer/{config,data}.
# Login: user admin, password $RESTREAMER_PASSWORD or generated, kept in /opt/restreamer/.env (root only).
# Restreamer cannot open the Pi camera on Bookworm and newer (no legacy camera stack): use picamera.sh and add
# rtsp://<pi>:8554/picam as a network source in Restreamer.
#   RESTREAMER_PORT=8090 restreamer.sh    other HTTP port for the first run (default 8080)
#   --public / --local                    ports on all interfaces (default) or on this host only
# category: server
# ports: RESTREAMER_PORT=8080 8181 1935 1936 6000/udp
# check: stack:restreamer
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
# there is no native variant
[ "$DOT_MODE" = native ] && DOT_MODE=compose

dest=/opt/restreamer
port=${RESTREAMER_PORT:-8080}
case $port in ''|*[!0-9]*) dot_die "RESTREAMER_PORT must be a number, got '$port'" ;; esac
dot_mode_guard restreamer restreamer "$port" 8181 1935 1936
dot_bind 0.0.0.0

# published: 8080 HTTP, 8181 HTTPS, 1935 RTMP, 1936 RTMPS, 6000/udp SRT
dot_deploy restreamer "services:
  restreamer:
    image: datarhei/restreamer:latest
    container_name: restreamer
    restart: always
    environment:
      CORE_API_AUTH_ENABLE: \"true\"
      CORE_API_AUTH_USERNAME: admin
      CORE_API_AUTH_PASSWORD: \${RESTREAMER_PASSWORD}
    ports:
      - \"$DOT_BIND:$port:8080\"
      - \"$DOT_BIND:8181:8181\"
      - \"$DOT_BIND:1935:1935\"
      - \"$DOT_BIND:1936:1936\"
      - \"$DOT_BIND:6000:6000/udp\"
    volumes:
      - $dest/config:/core/config
      - $dest/data:/core/data" \
  "RESTREAMER_PASSWORD=${RESTREAMER_PASSWORD:-$(dot_password 24)}"

dot_summary restreamer "http://localhost:$port/ui rtmp://localhost:1935 srt://localhost:6000" \
  "user admin, password: sudo cat $dest/.env (an older compose.yaml: the admin created in the web UI)"
