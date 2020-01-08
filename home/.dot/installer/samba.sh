#!/bin/bash
    sudo apt-get install samba samba-common smbclient
    sudo mv /etc/samba/smb.conf /etc/samba/smb.conf_alt
    sudo nano /etc/samba/smb.conf
    testparm
    sudo smbpasswd -a pi
    sudo nano /etc/samba/smb.conf
    sudo service smbd restart
    sudo service nmbd restart