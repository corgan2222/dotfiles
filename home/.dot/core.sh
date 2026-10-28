#!/bin/sh -x

cyan='\e[1;37;44m'
red='\e[1;31m'
endColor='\e[0m'
#datetime=$(date +%Y%m%d%H%M%S)

lowercase(){
	echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
}

####################################################################
# Get System Info
####################################################################
# Fills the variables the shell, the motd scripts and the prompts read, from dot_os_detect in lib/detect.sh (the same
# detection the installers use). DIST is the lower-case system: ubuntu, debian, arch, kali, proxmox, raspi, synology,
# asuswrt, unraid, ... (it equals DOT_OS); REV is the version, PSUEDONAME the codename.
shootProfile(){
	. "${BASH_SOURCE[0]%/*}/lib/detect.sh" || return
	dot_os_detect

	# without subprocesses where bash or /proc know it: each one costs on Windows and small routers. /proc/version
	# reads "<name> version <release> ...", also in Cygwin and Git Bash, which have no /proc/sys/kernel (28.10.26)
	# (no OS here: it would overwrite Windows' OS=Windows_NT for every program started from this shell).
	# Cygwin, Git Bash: detect.sh has read it already, each read of /proc there costs 25 ms (28.10.26)
	case $DOT_OS in
		cygwin|msys) _KERNEL=$DOT_OS_VERSION ;;
		*) if [ -r /proc/version ]; then read -r _ _ _KERNEL _ </proc/version; else _KERNEL=$(uname -r); fi ;;
	esac
	_MACH=${HOSTTYPE:-$(uname -m)}
	DIST=$DOT_OS
	REV=$DOT_OS_VERSION
	PSUEDONAME=$DOT_OS_CODENAME
	DistroBasedOn=${DOT_OS_BASE:-${DOT_OS_LIKE%% *}}
	MODELL= MODELL_TYPE= MODELL_SYSTEM=

	# every core has a "processor" line; the name is "model name" on x86 and most ARM boards, "cpu model" on MIPS
	# routers, a Raspberry Pi has neither (its board is MODELL_SYSTEM). mapfile reads the file at once: "read" per
	# line took 182 ms for 32 cores, mapfile 2 ms, an awk 2 ms on Linux but 50 ms on Windows (28.10.26)
	local l a=()
	CPU_CORES=0 CPU_TYPE=
	# Windows names cores and processor in its environment; Cygwin and Git Bash need 90 ms for /proc/cpuinfo (28.10.26)
	case $DOT_OS in
		cygwin|msys) CPU_CORES=${NUMBER_OF_PROCESSORS:-0} CPU_TYPE=${PROCESSOR_IDENTIFIER:-} ;;
		*) [ -r /proc/cpuinfo ] && mapfile -t a </proc/cpuinfo ;;
	esac
	for l in "${a[@]}"; do
		case $l in
			processor*) CPU_CORES=$((CPU_CORES + 1)) ;;
			"model name"*|"cpu model"*) [ -n "$CPU_TYPE" ] || CPU_TYPE=${l#*: } ;;
		esac
	done

	case $DIST in
		proxmox)
			# the pve-manager version; pveversion (perl) needs 0.8 s for the same, dpkg-query 0.01 s (27.10.26)
			MODELL_TYPE=$(dpkg-query -W -f '${Version}' pve-manager 2>/dev/null)
			MODELL_SYSTEM=$_KERNEL ;;
		raspi)
			MODELL_SYSTEM=$(tr -d '\0' </proc/device-tree/model 2>/dev/null) ;;
		synology)
			_syno() { sed -n "s/^$1=\"\{0,1\}\([^\"]*\)\"\{0,1\}$/\1/p" "$2" 2>/dev/null | head -n 1; }
			PSUEDONAME=DSM
			REV=$(_syno productversion /etc.defaults/VERSION)
			MODELL=$(_syno product /etc.defaults/synoinfo.conf)
			MODELL_TYPE=$(_syno upnpmodelname /etc.defaults/synoinfo.conf)
			MODELL_SYSTEM=$(_syno unique /etc.defaults/synoinfo.conf)
			unset -f _syno ;;
		asuswrt)
			MODELL_TYPE=$(nvram get productid 2>/dev/null)
			MODELL_SYSTEM="$(nvram get buildno 2>/dev/null)_$(nvram get extendno 2>/dev/null)" ;;
	esac

	# DIST and REV stay in this shell: programs and build scripts read variables of these names for their own
	# purpose; the scripts started from here (raspi_motd.sh) find their own values
	export PSUEDONAME DistroBasedOn CPU_CORES CPU_TYPE _KERNEL _MACH MODELL MODELL_TYPE MODELL_SYSTEM
}



# shootProfile
# echo "$CPU_CORES x $CPU_TYPE"
# echo "DIST: $DIST"
# echo "PSUEDONAME: $PSUEDONAME"
# echo "REV: $REV"
# echo "DistroBasedOn: $DistroBasedOn"
# echo "KERNEL: $KERNEL"
# echo "MACH: $MACH"
# echo "model: $MODELL"
# echo "type: $MODELL_TYPE"
# echo "system: $MODELL_SYSTEM"
# echo "========"


#upnpmodelname="DS415+"
#cat /etc.defaults/synoinfo.conf | grep '^upnpmodelname' | awk -F=  '{ print $2 }'
#"DS415+"

#unique="synology_avoton_415+"
#cat /etc.defaults/synoinfo.conf | grep '^unique' | awk -F=  '{ print $2 }'

#company_title="Synology"
#cat /etc.defaults/synoinfo.conf | grep '^company_title' | awk -F=  '{ print $2 }'

#product="DiskStation"
#cat /etc.defaults/synoinfo.conf | grep '^product' | awk -F=  '{ print $2 }'

#cat /etc.defaults/VERSION | grep '^productversion' | awk -F=  '{ print $2 }'
#cat /etc.defaults/VERSION | grep '^buildnumber' | awk -F=  '{ print $2 }'

# /etc.defaults$ cat VERSION
# majorversion="6"
# minorversion="2"
# productversion="6.2.2"
# buildphase="GM"
# buildnumber="24922"
# smallfixnumber="2"
# packing="official"
# packing_id="18"
# builddate="2019/07/03"
# buildtime="06:53:28"
