# #! /bin/bash

cecho(){
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[1;33m"
    # ... ADD MORE COLORS
    NC="\033[0m" # No Color

    printf "${!1}${2} ${NC}\n"
    #printf "\033[0;31m ${2} \033[0m \n"
}

function line() {
  width=$(tput cols)
  str=${1--}
  len=${#str}
  for ((i = 0; i < $width; i += $len)); do
    echo -n "${str:0:$(($width - $i))}"
  done
  echo
}

function box() {
  local t="$1xxxx"
  local c=${2:-"#"}

  cecho "GREEN" ${t//?/$c}
  cecho "GREEN" "$c $1 $c"
  cecho "GREEN" ${t//?/$c}
}

MENU_OPTIONS=
COUNT=0

for i in `ls`
do
       COUNT=$[COUNT+1]
       MENU_OPTIONS="${MENU_OPTIONS} ${COUNT} $i off "
done
cmd=(dialog --separate-output --checklist "Select App to install:" 22 76 16)
options=(${MENU_OPTIONS})
choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

COUNT=0

for j in `ls`
do
       COUNT=$[COUNT+1]

       for choice in $choices
       do
              if [ "$choice" = "$COUNT" ]; then                     
                     box "Install: $j"
                     printf "\n"
                     /bin/bash $j                     
                     line
              fi            
       done
       printf "\n"
done
