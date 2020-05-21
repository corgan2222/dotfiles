#!/bin/bash
#
# Developed by Rafael Corrêa Gomes
# Contact rafaelcgstz@gmail.com
#

# Index function
proftpd.sh(){
    clear;
    sudo apt-get -y update && sudo apt-get -y upgrade
    sudo apt install proftpd
    
    #sudo joe /etc/proftpd/proftpd.conf
    echo "check sudo joe /etc/proftpd/proftpd.conf"
    #sudo joe /etc/proftpd/conf.d/proftp-custom.conf
   
    sudo touch /etc/proftpd/conf.d/proftp-custom.conf
    sudo echo" 
        # Ftp user doesn't need a valid shell
    <Global>
        RequireValidShell off
    </Global>
    
    # Default directory is ftpusers home
    DefaultRoot ~ ftpuser
    
    # Limit login to the ftpuser group
    #<Limit LOGIN>
    #    DenyGroup !ftpuser
    #</Limit>" >> /etc/proftpd/conf.d/proftp-custom.conf

    echo "check sudo joe /etc/proftpd/conf.d/proftp-custom.conf"
    
    sudo adduser ftpuser --shell /bin/false --home /var/www/upload
    sudo service proftpd restart
}

proftpd.sh