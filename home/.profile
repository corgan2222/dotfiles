# ~/.profile: executed by Bourne-compatible login shells.

#host files
if [ -f "$HOME/.dot/hosts/.$HOSTNAME" ]; then
  source "$HOME/.dot/hosts/.$HOSTNAME" 
fi

if [ "$DIST" != "Synology" ] || [ "$DIST" != "kali" ] ; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

 if [ -f /bin/mseg ]; then
    mesg n || true
  fi


#[ ! -s ~/.plesk_banner ] || . ~/.plesk_banner
 

export PATH="$HOME/.cargo/bin:$PATH"
