#!/bin/bash
#
#	 
#	The boring stuff first - License
#
#	(c) 2015-2017 David Gressel <dckgdotnet@gmail.com> http://dckg.net
#
#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
# ############################## SETTINGS ############################## 
# User defined warnings (row in red)
# if greater than this value, display corresponding line in red, otherwise in green
status_processes_zombie_warn=0 # (int)
# 1.0 = 100% load on ALL cores
status_cpu_load_warn1m=1.0 # (float) 1minute load average over this value -> red line
status_cpu_load_warn5m=0.7 # (float) 5minute load average over this value -> red line
status_cpu_load_warn15m=0.5 # (float) 15minute load average over this value -> red line
status_mem_usage_warn=80.0 # (float) %used memory(-buffers/cache) to trigger red line
status_swap_usage_warn=80.0 # (float) %used swap to trigger red line
status_disk_usage_warn=80 # (int) warn if % disk usage greater than this value
status_file_descriptor_usage_warn=70.0 # (float) warn if % of available file descriptors is used
cache_max_age=60 # (int) minutes until a background job renews the update and restart lines
# if there is more than one security update, line is red
# ############################## ~~~~~~~ ############################## 
#
#
# #####################################################################################################################################
#
#
# Color Reference https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
# http://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux/5947802#5947802
#
red="\033[0;31m"
redl="\033[1;31m"
green="\033[0;32m"
yellow="\033[0;33m"
cyan="\033[0;36m"
defcolor="\033[0m" # no color

color_no_status_indicator_yet=$defcolor

export PATH=$PATH:/usr/sbin:/usr/bin:/sbin:/bin
missing=
# figlet and bc are needed; lsb_release falls back to os-release, needrestart only adds the restart hints
for t in /usr/bin/figlet:figlet /usr/bin/bc:bc; do
	[ -f "${t%%:*}" ] || missing="$missing ${t#*:}"
done
if [ -n "$missing" ]; then
	echo -e "$red\nmotd: required packages are not installed, install with\napt-get update && apt-get install$missing$defcolor\n"
	# .bashrc sources this file: return, an exit would close the login shell
	return 0 2>/dev/null || exit 0
fi

# relative cpu load warnings (1.0 = 100% on all cores)
status_cpu_load_warn1m=$(bc <<< "$status_cpu_load_warn1m+$(nproc)-1")
status_cpu_load_warn5m=$(bc <<< "$status_cpu_load_warn5m+$(nproc)-1")
status_cpu_load_warn15m=$(bc <<< "$status_cpu_load_warn15m+$(nproc)-1")

# System  welcome message #################################################################################
release_description=$(lsb_release -s -d 2>/dev/null || . /etc/os-release && echo "$PRETTY_NAME")
release_kernel=$(uname -r)
#release_arch=$(uname -m)

# System Load #################################################################################

# awk $value:
#			 total	   used	   free	 shared	buffers	 cached
#Mem:			 8		  9		 10		 11		 12		 13
#-/+ buffers/cache:		 16		 17
#Swap:		   19		 20		 21
#
physical_memory_usage=$(free -m | awk -v RS=", " '{printf("%3.1f", $9/$8*100)}')
#swap_usage=$(free -m | awk -v RS=", " '{printf("%3.1f", $20/$19*100)}')
swap_total=$(cat /proc/meminfo | grep SwapTotal | awk '{print $2}')
if (( $swap_total == 0 )); then
	swap_usage="N/A"
else
	swap_free=$(cat /proc/meminfo | grep SwapFree | awk '{print $2}')
	swap_usage=$(echo $(bc -l <<< "(1-$swap_free/$swap_total)*100") | awk '{printf("%3.1f",$1)}')
fi

if [ $(cat /proc/meminfo | grep MemAvailable | wc -l) -eq 0 ]; then
	mem_usage=$(free | awk -v RS=", " '{printf("%3.1f", $16/$8*100)}') # fallback if MemAvailable is not available
else
	mem_free=$(cat /proc/meminfo | grep MemAvailable | awk '{print $2}')
	mem_total=$(($(cat /proc/meminfo | grep MemTotal | awk '{print $2}')))
	mem_usage=$(echo $(bc -l <<< "(1-$mem_free/$mem_total)*100") | awk '{printf("%3.1f",$1)}')
fi

uptime=$(uptime -p | awk '{print substr($0, 4)}')
users=$(users | wc -w)

processes=$(ps ax | wc -l | awk '{print $1}')
# the state column only: grep 'Z' on all of ps aux also counted names and users with a Z (28.10.26)
processes_zombie=$(ps -eo stat= | grep -c '^Z')

cpu_load=$(cat /proc/loadavg | awk '{printf "%s %s %s ('$(nproc)' core)", $1, $2, $3}')

file_descriptor_allocated=$(cat /proc/sys/fs/file-nr | awk '{print $1}')
file_descriptor_max=$(cat /proc/sys/fs/file-nr | awk '{print $3}')
file_descriptor_tcp=$(netstat -nat | wc -l)
file_descriptor_usage=$(echo $(bc -l <<< "($file_descriptor_allocated/$file_descriptor_max)*100") | awk '{printf("%3.2f",$1)}')

disk_usage=$(df --total  | grep -v udev | egrep "/dev/*" | awk '{printf "%-20s %-27s %-3s\n", $1, $6, $5}') # -x tmpfs # exclude
# `df --total -x tmpfs | grep -v udev | egrep "/dev/*"` | grep -v -i /dev/shm | awk '{print substr($5,1,2)}'


# Network #################################################################################
# every interface whatever it is called; container and VM links (Docker, LXC, libvirt, ...) only count, one line each
# would push the rest of the MOTD off the screen
interfaces=$(awk 'NR > 2 { sub(/:.*/, "", $1); print $1 }' /proc/net/dev |
	grep -vE '^(lo|docker.*|br-.*|veth.*|virbr.*|lxcbr.*|lxdbr.*|podman.*|cni.*|flannel.*|cali.*|vxlan.*|fwbr.*|fwpr.*|fwln.*|tap.*|hassio)$')
virt_interfaces=$(awk 'NR > 2 { sub(/:.*/, "", $1); print $1 }' /proc/net/dev |
	grep -cE '^(docker.*|br-.*|veth.*|virbr.*|lxcbr.*|lxdbr.*|podman.*|cni.*|flannel.*|cali.*|vxlan.*|fwbr.*|fwpr.*|fwln.*|tap.*|hassio)$')

# Cast to int
#updates_security=$(($updates_security+0))
#processes_zombie=$(($processes_zombie+0))

if (( "$processes_zombie" > "$status_processes_zombie_warn" ))
then
	status_processes_zombie=$red
else
	status_processes_zombie=$green
fi

#if (($(echo `echo $cpu_load | awk '{print $3}'`'>'$status_cpu_load_warn | bc -l))) # awk $1 $2 $3 = 1min 5min 15min avg load

cpu_load1m=$(echo $cpu_load | awk '{print $1}')
cpu_load5m=$(echo $cpu_load | awk '{print $2}')
cpu_load15m=$(echo $cpu_load | awk '{print $3}')
if (( $(bc <<< "$cpu_load1m>$status_cpu_load_warn1m") || $(bc <<< "$cpu_load5m>$status_cpu_load_warn5m") || $(bc <<< "$cpu_load15m>$status_cpu_load_warn15m")  ))
then
	status_cpu_load=$red
else
	status_cpu_load=$green
fi

if (( $(bc <<< "$mem_usage > $status_mem_usage_warn") ))
then
	status_mem_usage=$red
else
	status_mem_usage=$green
fi

if (( $swap_total != 0 )); then
	if (( $(bc <<< "$swap_usage > $status_swap_usage_warn") ))
	then
		status_swap_usage=$red
	else
		status_swap_usage=$green
	fi
else
	status_swap_usage=$green
fi

if (( $(bc <<< "$file_descriptor_usage>$status_file_descriptor_usage_warn") ))
then
	status_file_descriptor_usage=$red
else
	status_file_descriptor_usage=$green
fi

echo -e -n "$red"

figlet -t $(hostname)

echo -e -n "$cyan"

echo -e "Welcome to $release_description ($release_kernel)$defcolor
$cyan# System Load $color_no_status_indicator_yet
Uptime:\t\t$uptime
Users:\t\t$users$status_cpu_load 
CPU Load:\t$cpu_load$status_processes_zombie 
Processes:\t$processes ($processes_zombie zombies)$status_file_descriptor_usage
FDs:\t\t$file_descriptor_usage% ($file_descriptor_allocated [TCP: $file_descriptor_tcp] / $file_descriptor_max)$status_mem_usage 
Memory Usage:\t$mem_usage%$status_swap_usage 
Swap Usage:\t$swap_usage%$color_no_status_indicator_yet 
$cyan# Disk - Device      Mountpoint			 %Usage $color_no_status_indicator_yet "
# Disk Usage #################################################################################
count=1
echo "$disk_usage" | while read disk; do 
	pused=$(echo "$disk" | awk '{print substr($3,1,length($3)-1)}') # % disk used
	
	#pused=`echo $pused | awk '{printf "%d", $0}'` # cast to int
	#status_disk_usage_warn=`echo $status_disk_usage_warn | awk '{printf "%d", $0}'` # cast to int
	#echo $pused;
	#echo $(echo "$pused $status_disk_usage_warn" | awk '{print ($1 > $2)}');
	if (( "$pused" > "$status_disk_usage_warn" )); then
		status_disk_usage=$red
		#echo "$pused > $status_disk_usage_warn"
	else
		status_disk_usage=$green
		#echo "green"
		#echo "$pused < $status_disk_usage_warn"
	fi
	echo -e -n "$status_disk_usage"
	#df --total  | grep -v udev | egrep "/dev/*" | awk '{printf "%-25s %-40s %s\n", $1, $6, $5}' | tail -n$count | head -n1
	echo "$disk"
	#echo -e "$color_no_status_indicator_yet"
	count=$(($count+1))
done
echo -en "$cyan"
echo -e "# Traffic - iface            RX                  TX $color_no_status_indicator_yet"
# Network traffic #################################################################################
echo "$interfaces" | while read iface; do
	rx=$(cat /sys/class/net/$iface/statistics/rx_bytes)
	tx=$(cat /sys/class/net/$iface/statistics/tx_bytes)
# 	echo -e "$iface\t\t\t $(($rx/1024/1024)) MiB\t\t\t$(($tx/1024/1024)) MiB";
	if (( $(($rx+$tx)) > 0 )); then
		printf "%-13s %17s %19s\n" "$iface" "$(bc -l <<< "scale=1; $rx/1024/1024/1024") GiB" "$(bc -l <<< "scale=1; $tx/1024/1024/1024") GiB"
	fi;
done

[ "${virt_interfaces:-0}" -gt 0 ] && echo "+ $virt_interfaces container networks"

echo -e "$cyan# Security$color_no_status_indicator_yet"

if [ $EUID -eq 0 ]; then
	# Security #################################################################################
	[ -f /var/run/reboot-required ] && echo -e "${red}System restart required!$defcolor"

	if [ -f /var/log/auth.log ]; then
		ssh_fails=$(cat /var/log/auth.log | grep -i "fail" | wc -l)
		ssh_first_fail_date=$(head -n1 /var/log/auth.log | awk '{print $1, $2}')
	
		echo -e "$ssh_fails failed SSH logins since $ssh_first_fail_date$defcolor"
	fi

	# needrestart and twice apt-get -s upgrade took 4-7 s at every login, plus an apt-get update once a day
	# (28.10.26). Their lines come from a cache that a background job renews when it is older than
	# cache_max_age; the job runs no apt-get update, so a login never holds the apt lock.
	_kali_checks() {
		local updates updates_security old_services=0 s_upd=$green s_sec=$green
		if command -v needrestart >/dev/null; then
			needrestart -k -r l -b 2>/dev/null | grep -q "NEEDRESTART-KSTA: 1" ||
				echo -e "${red}System restart required!$defcolor"
			old_services=$(needrestart -l -r l -b 2>/dev/null | grep -vc "NEEDRESTART-VER:")
			(( old_services > 0 )) &&
				echo -e "${yellow}${old_services} services might need a restart.$defcolor command: needrestart"
		fi
		updates=$(apt-get -s upgrade 2>/dev/null | grep ^Inst)
		updates_security=$(grep -ci security <<<"$updates")
		updates=$(grep -c . <<<"$updates")
		(( updates > 0 )) && s_upd=$yellow
		(( updates_security > 0 )) && s_sec=$red
		echo -e "$s_upd$updates packages can be updated.$s_sec \n$updates_security updates are security updates.\n$defcolor"
	}
	_cache=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/motd-kali
	mkdir -p "${_cache%/*}"
	if [ -z "$(find "$_cache" -mmin -"$cache_max_age" 2>/dev/null)" ]; then
		# double fork: no job notice in the login shell; exec 255>&-: the job must not hold the stderr of the login
		# shell, which bash keeps on fd 255 (else "bash -lic cmd 2>&1 | ..." waits for the job, 28.10.26)
		( ( exec 255>&-; _kali_checks > "$_cache.$$" 2>/dev/null && mv -f "$_cache.$$" "$_cache" ) \
			</dev/null >/dev/null 2>&1 & )
	fi
	if [ -s "$_cache" ]; then cat "$_cache"; else echo "(updates: collecting, shown at the next login)"; fi
	unset -f _kali_checks
else
	echo -e "This requires root privileges.
	$defcolor"
fi
