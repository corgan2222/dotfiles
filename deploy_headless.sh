#!/bin/bash

# bootstrap script to install Homeshick and you preferred castles to a new
# system.

tmpfilename="/tmp/${0##*/}.XXXXX"

if type mktemp >/dev/null; then
  tmpfile=$(mktemp $tmpfilename)
else
  tmpfile=$(echo $tmpfilename | sed "s/XX*/$RANDOM/")
fi

trap 'rm -f "$tmpfile"' EXIT

castles+=("corgan2222/dotfiles")


if [[ ! -f $HOME/.homesick/repos/homeshick/homeshick.sh ]]; then
  if command -v git >/dev/null; then
      git clone https://github.com/andsens/homeshick.git $HOME/.homesick/repos/homeshick
  else
    echo "no git found... path?"    
  fi    
fi

source $HOME/.homesick/repos/homeshick/homeshick.sh

for castle in "${castles[@]}"; do
  homeshick clone "$castle" --force
done

source $HOME/.bashrc 
source $HOME/.dot/.bash_aliases 
source $HOME/.dot/.bash_functions.sh 
homeshick link --force

exec "$SHELL" -l
