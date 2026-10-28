#!/bin/bash
# installer: Frigate NVR in Docker (Coral or /dev/dri when present, else CPU)
# systems: amd64 arm64
# modes: compose portainer
# Runs Frigate (docs.frigate.video) as compose project or Portainer stack "frigate" from /opt/frigate (default:
# compose, --portainer for a stack); installs Docker through docker.sh when it is missing. Frigate states no minimum;
# plan 2 GB RAM or more plus the shared memory, a 64-bit CPU (x86 with AVX/AVX2) and a few GB of disk for the image.
# Frigate does not officially support LXC: prefer a VM.
# The compose file and config/config.yml are written on the first run only; running again pulls the newest image.
# Device mappings are added when found: Coral USB (/dev/bus/usb), Coral PCIe (/dev/apex_0), GPU (/dev/dri/renderD128).
# The new config uses the Coral as detector when there is one, else OpenVINO on the CPU, and has no cameras.
#   frigate.sh                    install and start
#   frigate.sh --no-start         write compose file and config only: no Docker, no image pull, no start
#   FRIGATE_MEDIA=/srv/nvr        recordings and snapshots (default /opt/frigate/media)
#   FRIGATE_PORT=8971 FRIGATE_RTSP_PORT=8554 FRIGATE_WEBRTC_PORT=8555 FRIGATE_SHM=512mb   for the first run
#   --public / --local            ports on all interfaces or this host only (first run, else asked, default all)
# Login: Frigate creates the user admin with a random password and prints it in its log on the first start.
# category: server
# ports: FRIGATE_PORT=8971 FRIGATE_RTSP_PORT=8554 FRIGATE_WEBRTC_PORT=8555
# check: stack:frigate
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
[ "$DOT_MODE" = native ] && DOT_MODE=compose

dest=/opt/frigate
compose=$dest/compose.yaml
config=$dest/config/config.yml
media=${FRIGATE_MEDIA:-$dest/media}
nostart=
case ${1:-} in
  --no-start) nostart=1 ;;
  -h|--help) sed -n '5,17s/^# \{0,1\}//p' "$0"; exit 0 ;;
  "") ;;
  *) dot_die "unknown option $1" ;;
esac
case $DOT_ARCH in amd64|arm64) ;; *) dot_die "Frigate images exist for amd64 and arm64 only, not $DOT_ARCH" ;; esac
dot_bind 0.0.0.0

# Coral USB: Google 18d1:9302 after the firmware load, Global Unichip 1a6e:089a before
coral_usb=
for d in /sys/bus/usb/devices/*; do
  case $(cat "$d/idVendor" 2>/dev/null):$(cat "$d/idProduct" 2>/dev/null) in
    18d1:9302|1a6e:089a) coral_usb=1 ;;
  esac
done
devices=
[ -z "$coral_usb" ] || devices+=$'\n      - /dev/bus/usb:/dev/bus/usb'
[ ! -e /dev/apex_0 ] || devices+=$'\n      - /dev/apex_0:/dev/apex_0'
[ ! -e /dev/dri/renderD128 ] || devices+=$'\n      - /dev/dri/renderD128:/dev/dri/renderD128'

dot_sudo install -d -m 0755 "$dest" "$dest/config" || exit 1
dot_sudo install -d -m 0755 "$media" || exit 1

# no "privileged": the devices found are mapped one by one; port 5000 (UI without login) stays unpublished.
# /etc/localtime only when the host has it: minimal images without tzdata lack it, Docker would then create a directory
# there and fail to mount it onto the image's file (28.10.26)
tz=; [ -f /etc/localtime ] && tz=1
yaml="services:
  frigate:
    image: ghcr.io/blakeblackshear/frigate:stable
    container_name: frigate
    restart: unless-stopped
    stop_grace_period: 30s
    shm_size: \"${FRIGATE_SHM:-512mb}\"
    ports:
      - \"$DOT_BIND:${FRIGATE_PORT:-8971}:8971\"
      - \"$DOT_BIND:${FRIGATE_RTSP_PORT:-8554}:8554\"
      - \"$DOT_BIND:${FRIGATE_WEBRTC_PORT:-8555}:8555/tcp\"
      - \"$DOT_BIND:${FRIGATE_WEBRTC_PORT:-8555}:8555/udp\"${devices:+
    devices:$devices}
    volumes:${tz:+
      - /etc/localtime:/etc/localtime:ro}
      - $dest/config:/config
      - $media:/media/frigate
      - type: tmpfs
        target: /tmp/cache
        tmpfs:
          size: 1000000000"
[ -z "$devices" ] || dot_sudo test -f "$compose" || dot_info "mapping the devices:$devices"

if [ ! -f "$config" ]; then
  if [ -n "$coral_usb" ]; then
    detector=$'detectors:\n  coral:\n    type: edgetpu\n    device: usb'
  elif [ -e /dev/apex_0 ]; then
    detector=$'detectors:\n  coral:\n    type: edgetpu\n    device: pci'
  else
    # Frigate's own default for new setups; an Intel GPU can take over with device: GPU
    detector=$'detectors:\n  ov:\n    type: openvino\n    device: CPU\nmodel:\n  width: 300\n  height: 300\n  input_tensor: nhwc\n  input_pixel_format: bgr\n  path: /openvino-model/ssdlite_mobilenet_v2.xml\n  labelmap_path: /openvino-model/coco_91cl_bkgr.txt'
  fi
  dot_sudo tee "$config" >/dev/null <<EOF
mqtt:
  enabled: false

$detector

# add cameras in the UI (Settings > Cameras) or here, for example:
#  front:
#    ffmpeg:
#      inputs:
#        - path: rtsp://user:password@camera-address:554/stream
#          roles:
#            - detect
#            - record
#    detect:
#      width: 1280
#      height: 720
cameras: {}

version: 0.18-0
EOF
  dot_info "wrote $config"
else
  dot_info "keeping $config"
fi
if [ -n "$nostart" ]; then
  # what dot_deploy would write, without Docker
  dot_sudo test -f "$compose" || printf '%s\n' "$yaml" | dot_sudo tee "$compose" >/dev/null
  dot_info "--no-start: wrote $compose; start Frigate later with: frigate.sh --$DOT_MODE"
  exit 0
fi
dot_deploy frigate "$yaml"

# "[address:]port" as written on the first run; a different answer now is only reported
pub=$(dot_sudo sed -n 's/^ *- "\(.*\):8971"$/\1/p' "$compose")
rtsp=$(dot_sudo sed -n 's/^ *- "\(.*\):8554"$/\1/p' "$compose")
case $pub in *:*) bound=${pub%:*} ;; *) bound=0.0.0.0 ;; esac
if [ "$bound" != "$DOT_BIND" ]; then
  echo "warning: Frigate keeps listening on $bound (set on the first run), edit $compose to change it" >&2
  DOT_BIND=$bound
fi
dot_info "the web UI uses a self-signed certificate"
port=${pub##*:} rtsp=${rtsp##*:}

# Frigate prints the first admin password once, in its log ("Password: …"); kept in $pwfile so the summary can show it
pwfile=$dest/admin-password pw=
if ! dot_sudo test -s "$pwfile"; then
  [ -t 1 ] || dot_info "waiting for Frigate's first admin password in its log (up to 3 minutes)"
  for _ in $(seq 90); do
    pw=$(dot_sudo docker logs frigate 2>&1 | sed -n 's/.*Password: *\([^ *]*\).*/\1/p' | tail -n 1)
    [ -n "$pw" ] && break
    dot_progress 0 0 "Frigate starts, waiting for its first admin password"
    sleep 2
  done
  dot_progress_end
  [ -z "$pw" ] || printf '%s\n' "$pw" | dot_sudo sh -c "umask 077; cat > '$pwfile'"
fi
if dot_sudo test -s "$pwfile"; then
  login="user admin, first password: sudo cat $pwfile (a changed one lives in Frigate's database only)"
else
  login="user admin, first password in the log: sudo docker logs frigate 2>&1 | grep -i password"
fi
dot_summary frigate "https://localhost:${port:-8971} rtsp://localhost:${rtsp:-8554}" "$login"
