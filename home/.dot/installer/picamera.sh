#!/bin/bash
# installer: Pi camera stream with rpicam-apps and go2rtc
# systems: raspi
# Installs rpicam-apps and go2rtc (through go2rtc.sh) and runs go2rtc as go2rtc.service for the calling user,
# with the Pi camera as stream "picam" (H.264 from rpicam-vid) and "picam_mjpeg" (transcoded by ffmpeg):
#   RTSP    rtsp://<pi>:8554/picam
#   WebRTC  http://<pi>:1984/  (web UI, links per stream)
#   MJPEG   http://<pi>:1984/api/stream.mjpeg?src=picam_mjpeg
# The config /etc/go2rtc/go2rtc.yaml is written on the first run only. Picture settings for that first run:
#   PICAM_ARGS="--width 1280 --height 720 --framerate 15" picamera.sh
# DOT_FORCE_RASPI=1 installs on a system that is not a Raspberry Pi (for tests).
# category: raspberry
# check: rpicam-vid go2rtc
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

dir=$(dirname "$(readlink -f "$0")")
conf=/etc/go2rtc/go2rtc.yaml
args=${PICAM_ARGS:---width 1920 --height 1080 --framerate 25}
user=$(dot_user)

[ "$DOT_OS" = raspi ] || [ "${DOT_FORCE_RASPI:-}" = 1 ] || dot_die "this is not a Raspberry Pi (set DOT_FORCE_RASPI=1 to install anyway)"

# rpicam-apps comes from archive.raspberrypi.com; Raspberry Pi OS Lite has rpicam-apps-lite with the same tools
command -v rpicam-vid >/dev/null 2>&1 || dot_pkg_install rpicam-apps ||
  dot_die "could not install rpicam-apps (it comes from the Raspberry Pi OS repository archive.raspberrypi.com)"
dot_need ffmpeg

# go2rtc: installed by go2rtc.sh into ~/.local/bin (not in the PATH of every shell); older setups used ~/go2rtc
find_go2rtc() {
  command -v go2rtc 2>/dev/null || { [ -x "$HOME/.local/bin/go2rtc" ] && echo "$HOME/.local/bin/go2rtc"; } ||
    ls "$HOME"/go2rtc/go2rtc_linux_* 2>/dev/null | head -n 1
}
bin=$(find_go2rtc)
if [ -z "$bin" ]; then
  [ -f "$dir/go2rtc.sh" ] || dot_die "go2rtc is missing and there is no go2rtc.sh next to this installer"
  bash "$dir/go2rtc.sh" || dot_die "go2rtc.sh failed"
  bin=$(find_go2rtc)
  [ -n "$bin" ] || dot_die "go2rtc.sh ran, but no go2rtc binary was found in the PATH, ~/.local/bin or ~/go2rtc"
fi
bin=$(readlink -f "$bin")

# the Pi 5 has no H.264 hardware encoder, rpicam-vid encodes with libav there
codec="--inline"
grep -qs 'Raspberry Pi 5' /proc/device-tree/model && codec="--codec libav --libav-format h264"

if [ ! -f "$conf" ]; then
  dot_sudo install -d -m 0755 /etc/go2rtc
  dot_sudo tee "$conf" >/dev/null <<EOF
# go2rtc config, docs: https://github.com/AlexxIT/go2rtc
# Restart after a change: sudo systemctl restart go2rtc
api:
  listen: ":1984"
rtsp:
  listen: ":8554"
webrtc:
  listen: ":8555"
streams:
  picam: exec:rpicam-vid -t 0 -n $codec $args -o -
  picam_mjpeg: ffmpeg:picam#video=mjpeg
EOF
  # the web UI saves its changes into this file
  dot_sudo chown "$user": "$conf"
  dot_info "wrote $conf"
else
  dot_info "keeping $conf"
fi

dot_sudo tee /etc/systemd/system/go2rtc.service >/dev/null <<EOF
[Unit]
Description=go2rtc streaming server (Pi camera)
Wants=network-online.target
After=network-online.target

[Service]
User=$user
SupplementaryGroups=video
ExecStart=$bin -config $conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

if [ -d /run/systemd/system ]; then
  dot_sudo systemctl daemon-reload && dot_sudo systemctl enable go2rtc && dot_sudo systemctl restart go2rtc ||
    dot_die "could not start go2rtc.service, see: journalctl -u go2rtc"
  dot_info "go2rtc is running: http://$(hostname -I 2>/dev/null | cut -d' ' -f1):1984/  (rpicam-hello --list-cameras shows the camera)"
else
  dot_info "no systemd running: enable it later with: sudo systemctl enable --now go2rtc"
fi
