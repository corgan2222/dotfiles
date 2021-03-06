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

cat <<'EOF' > $tmpfile
# Which Homeshick castles do you want to install?
#
# Each line is passed as the argument(s) to `homeshick clone`.
# Lines starting with '#' will be ignored.
#
# If you remove or comment a line that castle will NOT be installed.
# However, if you remove or comment everything, the script will be aborted.

# Plugin management
corgan2222/dotfiles

# Private castles (commented by default)
#sukima/muttrc
#secret@example.org:securerc.git
EOF

if command -v joe >/dev/null; then
  ${VISUAL:-joe} $tmpfile
else  
  ${VISUAL:-nano} $tmpfile
fi  


code=$?

if [[ $code -ne 0 ]]; then
  echo "Editor returned ${code}." 1>&2
  exit 1
fi

castles=()

while read line; do
  castle=$(echo "$line" | sed '/^[ \t]*#/d;s/^[ \t]*\(.*\)[ \t]*$/\1/')
  if [[ -n $castle ]]; then
    castles+=("$castle")
  fi
done <$tmpfile

if [[ ${#castles[@]} -eq 0 ]]; then
  echo "No castles to install. Aborting."
  exit 0
fi

if [[ ! -f $HOME/.homesick/repos/homeshick/homeshick.sh ]]; then
  if command -v git >/dev/null; then
      git clone git://github.com/andsens/homeshick.git $HOME/.homesick/repos/homeshick
  else
    echo "no git found... path?"    
  fi    
fi

source $HOME/.homesick/repos/homeshick/homeshick.sh

for castle in "${castles[@]}"; do
  homeshick clone "$castle"
done