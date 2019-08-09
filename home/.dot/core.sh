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
shootProfile(){
	OS1=$(lowercase \`uname\`)
	_KERNEL=$(uname -r)
	_MACH=$(uname -m)


	CPU_CORES=$(cat /proc/cpuinfo | grep "model name" | wc -l)
	CPU_TYPE=$(cat /proc/cpuinfo | grep "model name" -m 1 | cut -d: -f2)

	if [ "${OS1}" == "windowsnt" ]; then
		OS=windows
	elif [ "${OS1}" == "darwin" ]; then
		OS=mac
	else
		OS=$(uname)
		if [ "${OS}" = "SunOS" ] ; then
			OS=Solaris
			ARCH=$(uname -p)
			OSSTR="${OS} ${REV}(${ARCH} $(uname -v))"
		elif [ "${OS}" = "AIX" ] ; then
			OSSTR="${OS} $(oslevel) ($(oslevel -r))"
		elif [ "${OS}" = "Linux" ] ; then
			if [ -f /etc/redhat-release ] ; then
				DistroBasedOn='RedHat'
				DIST=$(cat /etc/redhat-release |sed s/\ release.*//)
				PSUEDONAME=$(cat /etc/redhat-release | sed s/.*\(// | sed s/\)//)
				REV=$(cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//)
			elif [ -f /etc/SuSE-release ] ; then
				DistroBasedOn='SuSe'
				PSUEDONAME=$(cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//)
				REV=$(cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //)
			elif [ -f /etc/mandrake-release ] ; then
				DistroBasedOn='Mandrake'
				PSUEDONAME=$(cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//)
				REV=$(cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//)
			elif [ -f /etc/debian_version ] ; then
				DistroBasedOn='Debian'
				if [ -f /etc/lsb-release ] ; then
			        	DIST=$(cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }')
			                PSUEDONAME=$(cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }')
			                REV=$(cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }')
            			fi
			elif [ -f /etc/VERSION ] ; then
			 	DistroBasedOn='Synology'
				DIST=$(cat /etc.defaults/synoinfo.conf | grep '^company_title' | awk -F=  '{ print $2 }' | sed -e "s/^\"//" -e "s/\"$//")
				PSUEDONAME="DSM"
				REV=$(cat /etc.defaults/VERSION | grep '^productversion' | awk -F=  '{ print $2 }' | sed -e "s/^\"//" -e "s/\"$//")
				MODELL=$(cat /etc.defaults/synoinfo.conf | grep '^product' | awk -F=  '{ print $2 }' | sed -e "s/^\"//" -e "s/\"$//")
				MODELL_TYPE=$(cat /etc.defaults/synoinfo.conf | grep '^upnpmodelname' | awk -F=  '{ print $2 }' | sed -e "s/^\"//" -e "s/\"$//")
				MODELL_SYSTEM=$(cat /etc.defaults/synoinfo.conf | grep '^unique' | awk -F=  '{ print $2 }' | sed -e "s/^\"//" -e "s/\"$//")				
			
				#AsusWRT
			elif [ -f /opt/etc/entware_release ] ; then

				PSUE1=$(cat /proc/version | awk -F" " '{ print $5}')
				PSUE2=$(cat /proc/version | awk -F" " '{ print $6}')
				PSUE3=$(cat /proc/version | awk -F" " '{ print $7}')

	 			DistroBasedOn='Ubuntu'
				DIST=$(cat /proc/version | awk -F" " '{ print $4}')
				PSUEDONAME="$PSUE1 $PSUE2 $PSUE3"

				#REV=$(cat /proc/version | awk -F" " '{ print $3}')

				#MODELL=
				MODELL_TYPE=$(sysinfo | grep ASUS -m1 |  awk -F" " '{ print $1}')
				MODELL_SYSTEM=$(sysinfo | grep ASUS -m1 |  awk -F" " '{ print $2}') $(sysinfo | grep ASUS -m1 |  awk -F" " '{ print $3}')				
			
				CPU_CORES=$(cat /proc/cpuinfo | grep "cpu model" | wc -l)
				CPU_TYPE=$(cat /proc/cpuinfo | grep "cpu model" -m 1 | cut -d: -f2)
# /opt/etc/entware_release
# release=entware



# admin@router:~# cat /proc/version | awk -F" " '{ print $1}'
# Linux
# admin@router:~# 
# 4.1.51
# admin@router:~# 
# (merlin@ubuntu-dev)
# admin@router:~# 
# (gcc
# admin@router:~# cat /proc/version | awk -F" " '{ print $6}'
# version
# admin@router:~# cat /proc/version | awk -F" " '{ print $7}'
# 5.5.0
	
			fi

			if [ -f /etc/os-release ] ; then				
				#DIST=$(cat /etc/os-release | grep '^NAME' | awk -F=  '{ print $2 }' | sed -e "s/^\"//" -e "s/\"$//")
				if [ -z "$DIST" ]; then
					DIST=$(cat /etc/os-release | grep '^ID=' | awk -F=  '{ print $2 }')				
				fi
				
				if [ "$DIST" = "raspbian" ]; then 
					PSUEDONAME=$(cat /etc/os-release| grep '^VERSION_CODENAME' | awk -F=  '{ print $2 }' | sed -e "s/^\"//" -e "s/\"$//")
					REV=$(cat /etc/os-release| grep '^VERSION_ID' | awk -F=  '{ print $2 }' | sed -e "s/^\"//" -e "s/\"$//")								
					MODELL_TYPE=$(cat /etc/os-release | grep '^upnpmodelname' | awk -F=  '{ print $2 }' | sed -e "s/^\"//" -e "s/\"$//")
					
					IFS= read -r -d '' model </proc/device-tree/model || [[ $model ]]
					MODELL_SYSTEM=$(tr -d '\0' </proc/device-tree/model)
				fi	
				#MODELL=$(cat /etc/os-release | grep '^PRETTY_NAME=' | awk -F=  '{ print $2 }' | sed -e "s/^\"//" -e "s/\"$//")
			fi


			if [ -f /etc/UnitedLinux-release ] ; then
				DIST="${DIST}[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
			fi

			OS=$(lowercase $OS)
			DistroBasedOn=$(lowercase $DistroBasedOn)


			export OSSTR
			export CPU_CORES
			export CPU_TYPE
			export OS
			export DIST
			export DistroBasedOn
			export PSUEDONAME
			export REV
			export _KERNEL
			export _MACH
			export MODELL
			export MODELL_TYPE
			export MODELL_SYSTEM
		fi

	fi
}

####################################################################
# Print Menu
####################################################################
printMenu(){
	if [[ "$user" = "" || "$passwd" = "" || "$port" = "" ]]; then
		echo -e "$red Error: USER, PASS AND PORT ARE REQUIRED, PLEASE SET THEM IN CONFIG FILE $endColor"
		echo ""
		echo ""
		exit 1 
	fi
	clear
	echo -e "$cyan Fast and Easy Web Server Installation $endColor"
	echo "Choose an option writing its number and press enter:"
	echo -e "\t1) Create a user"
	echo -e "\t2) Create users profile (color in bash)"
	echo -e "\t3) Update and Install (Apache, PHP, MySQL, SQLite, Django, Subversion)"
	echo -e "\t4) Configurating SSH and IPTABLES"
	echo -e "\t5) Configure and securitizing Apache"
	echo -e "\t6) Configure and securitizing MySQL"
	echo -e "\t7) Create SVN & TRAC repos"
	echo -e "\t8) Create a Mail Server"
	echo -e "\t9) Create a cron backup (mysql, apache, trac & svn)"
	echo -e "\t10) Set DNS and to add Google Apps MX records (Only SliceHost.com)"
	echo -e "\t11) Install Trac and its Plugins"
	echo -e "\t12) I do not know, exit!"
	#echo -e "\t13) Create VirtualHosts"
	read option;
	while [[ $option -gt 12 || ! $(echo $option | grep '^[1-9]$') ]]
	do
		printMenu
	done
	runOption
}

####################################################################
# Run an Option
####################################################################
runOption(){
	case $option in
		1) createUser;;
		2) profileUser;;
		3) updateInstall;;
		4) sshIptables;;
		5) secureApache;;
		6) secureMySQL;;
		7) tracsvn;;
		8) mailServer;;
		9) cronBackup;;
		10) set_dns;;
		11) InstallTrac;;
		12) exit
#		13) CreateVirtualHosts;;
	esac 
	echo "Press any Key to continue"
	read x
	printMenu
}


# shootProfile
#echo "$CPU_CORES x $CPU_TYPE"
# echo "OS: $OS"
# echo "DIST: $DIST"
# echo "PSUEDONAME: $PSUEDONAME"
# echo "REV: $REV"
# echo "DistroBasedOn: $DistroBasedOn"
# echo "KERNEL: $KERNEL"
# echo "MACH: $MACH"
# echo "model: $MODELL"
# echo "type: $MODELL_TYPE"
# echo "system: $MODELL_SYSTEM"
#echo "========"
# printMenu


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
