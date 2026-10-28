#!/bin/bash
# installer: conky system monitor on the Raspberry Pi desktop
# systems: raspi desktop
# Installs conky, writes ~/.config/conky/conky.conf (first run only) and starts conky with the desktop through
# ~/.config/autostart/conky.desktop. Raspberry Pi OS runs labwc (Wayland) by default: conky is an X11 program and
# runs there through XWayland; labwc's autostart on Raspberry Pi OS starts the XDG autostart entries.
# category: raspberry
# check: conky
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

conf_dir=${XDG_CONFIG_HOME:-$HOME/.config}
conf=$conf_dir/conky/conky.conf

dot_pkg_install conky-std || dot_die "could not install conky"

if [ ! -f "$conf" ]; then
  mkdir -p "$(dirname "$conf")" || exit 1
  # layout of the old ~/.dot/raspi/.conkyrc in the conky 1.10+ format; ARGB transparency works under a compositor
  cat >"$conf" <<'EOF'
conky.config = {
    background = true,
    use_xft = true,
    font = 'DejaVu Sans:size=8',
    update_interval = 1,
    total_run_times = 0,
    own_window = true,
    own_window_type = 'normal',
    own_window_transparent = true,
    own_window_argb_visual = true,
    own_window_argb_value = 0,
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    double_buffer = true,
    minimum_width = 250, minimum_height = 5,
    maximum_width = 400,
    draw_shades = false,
    draw_outline = false,
    draw_borders = false,
    draw_graph_borders = false,
    default_color = 'gray',
    alignment = 'top_right',
    gap_x = 10,
    gap_y = 40,
    no_buffers = true,
    cpu_avg_samples = 2,
    net_avg_samples = 1,
    use_spacer = 'right',
};

conky.text = [[
${font DejaVu Sans:size=16}${color Tan1}${nodename}${font}
${font DejaVu Sans:bold:size=10}${color Tan1}SYSTEM ${color DarkSlateGray}${hr 2}
${font}${color DimGray}$sysname $kernel $alignr $machine
Frequency $alignr${freq_g cpu0} GHz
Uptime $alignr${uptime}
${font DejaVu Sans:bold:size=10}${color Tan1}CPU ${color DarkSlateGray}${hr 2}
${font}${color DimGray}Temp $alignr${execi 5 cut -c1-2 /sys/class/thermal/thermal_zone0/temp} °C
${if_existing /tmp/fanSpeed.value}Fan $alignr${cat /tmp/fanSpeed.value} %
${endif}CPU1  ${cpu cpu1}% ${cpubar cpu1}
CPU2  ${cpu cpu2}% ${cpubar cpu2}
CPU3  ${cpu cpu3}% ${cpubar cpu3}
CPU4  ${cpu cpu4}% ${cpubar cpu4}
${cpugraph DimGray DarkSlateGray}
${font DejaVu Sans:bold:size=10}${color Tan1}MEMORY ${color DarkSlateGray}${hr 2}
${font}${color DimGray}MEM $alignc $mem / $memmax $alignr $memperc%
$membar
SWAP $alignc $swap / $swapmax $alignr $swapperc%
$swapbar
${font DejaVu Sans:bold:size=10}${color Tan1}DISK ${color DarkSlateGray}${hr 2}
${font}${color DimGray}/ $alignc ${fs_used /} / ${fs_size /} $alignr ${fs_free_perc /}% free
${fs_bar /}
${font DejaVu Sans:bold:size=10}${color Tan1}TOP PROCESSES ${color DarkSlateGray}${hr 2}
${font}${color DimGray}${top_mem name 1}${alignr}${top_mem mem 1} %
${top_mem name 2}${alignr}${top_mem mem 2} %
${top_mem name 3}${alignr}${top_mem mem 3} %
${top_mem name 4}${alignr}${top_mem mem 4} %
${font DejaVu Sans:bold:size=10}${color Tan2}NETWORK ${color DarkSlateGray}${hr 2}
${font}${color DimGray}${if_up eth0}eth0 $alignr ${addr eth0}
Down ${downspeed eth0} $alignr Up ${upspeed eth0}
${endif}${if_up wlan0}wlan0 $alignr ${addr wlan0}
Down ${downspeed wlan0} $alignr Up ${upspeed wlan0}
${endif}
]];
EOF
  dot_info "wrote $conf"
else
  dot_info "keeping $conf"
fi

# conky -p: wait for the panel and XWayland before the first draw
mkdir -p "$conf_dir/autostart" && cat >"$conf_dir/autostart/conky.desktop" <<EOF || exit 1
[Desktop Entry]
Type=Application
Name=conky
Comment=System monitor on the desktop
Exec=conky -p 5 -c $conf
Terminal=false
EOF
dot_info "conky starts with the next desktop login (~/.config/autostart/conky.desktop); now: conky -c $conf &"
