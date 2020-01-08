    #for debmatic
    sudo ap apparmor-utils apt-transport-https avahi-daemon ca-certificates curl dbus jq socat software-properties-common

        #debmatic
    wget -q -O - https://www.debmatic.de/debmatic/public.key | sudo apt-key add -
    sudo bash -c 'echo \"deb https://www.debmatic.de/debmatic stable main\" > /etc/apt/sources.list.d/debmatic.list'
    sudo apt update
    sudo apt install build-essential bison flex libssl-dev
    sudo apt install raspberrypi-kernel-headers pivccu-modules-dkms
    sudo apt install debmatic
    sudo apt install xml-api
    
    cd /tmp   
    mkdir backups
    debmatic-backup /tmp/backups/