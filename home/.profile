# ~/.profile: executed by Bourne-compatible login shells.

if [ "$DIST" != "Synology" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

 if [ -f /bin/mseg ]; then
    mesg n || true
  fi



#[ ! -s ~/.plesk_banner ] || . ~/.plesk_banner
 
 