#!/bin/bash -x

[ -z "$PS1" ] && return
# ~/.bashrc: executed by bash(1) for non-login shells.

############# INCLUDE ####################################

source "$HOME/.homesick/repos/homeshick/homeshick.sh"
source "$HOME/.homesick/repos/homeshick/completions/homeshick-completion.bash"

# reload the shell (i.e. invoke as a login shell)
alias reload='exec "$SHELL" -l'
alias load='source "$HOME"/.bashrc && source $HOME/.dot/.bash_aliases && source $HOME/.dot/.bash_functions.sh'

# prints colored text
print_style () {

    if [ "$2" == "info" ] ; then
        COLOR="96m";
    elif [ "$2" == "success" ] ; then
        COLOR="92m";
    elif [ "$2" == "warning" ] ; then
        COLOR="93m";
    elif [ "$2" == "danger" ] ; then
        COLOR="91m";
    else #default color
        COLOR="0m";
    fi

    STARTCOLOR="\e[$COLOR";
    ENDCOLOR="\e[0m";

    printf "$STARTCOLOR%b$ENDCOLOR" "$1";
}

_loadFile()
{
  if [ -r "$1" ]; then
      #LAST=$(stat -c%y "$1" | cut -d'.' -f1) 
        DALTA=$(($(date +%s) - $(date +%s -r "$1"))) 

      LAST=$(date -r "$1" +'%H:%M:%S %d-%m-%Y ') 
      c1=$(print_style " $2" "success")
      c2=$(print_style " $1" "info")
      c3=$(print_style " $DALTA" "success")

      #printf "%5s%35s%50s%55s\n" loading "$c1" "$c2" "$LAST (+$c3 sec)"     
      source "$1"
  fi  
}

#load core system
_loadFile "$HOME"/.dot/core.sh "Core System"

resetHome()
{
  rm -r "$HOME"/.dot/ -f
  rm -r "$HOME"/.homesick/ -f
  rm .profile 
  rm .bashrc
  #bash <(curl https://corgan2222.github.io/dotfiles/deploy_homeshick.sh)
  #source .bashrc
  #gitSaveCredential
}

#OS Check
shootProfile

#load basisc
#printf "\t%s \t%s \n" fresh "Base" 
_loadFile "$HOME"/.dot/.bash_aliases "Base Alias"
_loadFile "$HOME"/.dot/.bash_functions.sh "Base Functions"
_loadFile "$HOME"/.dot/.exports "Base Exports"

if [ "$DIST" = "Ubuntu" ]; then   
  # load the shell dotfiles, and then some:
  # * ~/.path can be used to extend `$PATH`.
  # * ~/.extra can be used for other settings you don’t want to commit.
  #for file in ~/.{config_dotfiles,path,load,colors,exports,icons,aliases,bash_complete,functions,extra,dotfilecheck}; do
  #for file in ~/.dot/ubuntu16/{.bashrc,.exports,.bash_aliases,.srv1.bash_aliases,debian.sh}; do
  #    [ -r "$file" ] && [ -f "$file" ] && _loadFile "$file"
  #done
  printf "\t%s \t%s \n" fresh "Ubuntu" 
  _loadFile "$HOME"/.dot/ubuntu16/.bashrc "Debian Userpromt"
  _loadFile "$HOME"/.dot/ubuntu16/debian.sh "Debian Server Functions"
  _loadFile "$HOME"/.dot/ubuntu16/.exports "Exports"
  _loadFile "$HOME"/.dot/ubuntu16/.bash_aliases "Debian Alias"
  _loadFile "$HOME"/.dot/ubuntu16/.srv1.bash_aliases "srv1"
  reload=yes  
fi  

#PROG="`basename $0`" 
#BASEDIR=$(dirname "$0")
#echo "$BASEDIR"

if [ "$DIST" = "Synology" ]; then 
  _loadFile "$HOME"/.dot/synology/.bashrc "$DIST Userpromt"
  _loadFile "$HOME"/.dot/synology/.exports " $DIST Exports"
  _loadFile "$HOME"/.dot/synology/.bash_aliases "$DIST Alias"
  reload=yes
fi  

if [ "$DIST" = "raspbian" ]; then 
 _loadFile "$HOME"/.dot/raspi/.bashrc "$DIST bashrc"
 _loadFile "$HOME"/.dot/raspi/.exports "$DIST exports"
 _loadFile "$HOME"/.dot/raspi/.bash_aliases "$DIST bash_aliases"  
 _loadFile "$HOME"/.dot/raspi/.raspi_bash_functions.sh "$DIST Functions"  
 reload=yes
fi 


if [ "$MODELL_TYPE" = "ASUSWRT-Merlin" ]; then 
 _loadFile "$HOME"/.dot/asuswrt/.bashrc "$DIST bashrc"
 _loadFile "$HOME"/.dot/asuswrt/.exports "$DIST exports"
 _loadFile "$HOME"/.dot/asuswrt/.bash_aliases "$DIST bash_aliases"  
 _loadFile "$HOME"/.dot/asuswrt/.raspi_bash_functions.sh "$DIST Functions"  
 _loadFile "$HOME"/.dot/asuswrt/EntwareApps.sh "$DIST EntwareApps.sh"  
 _loadFile "$HOME"/.dot/asuswrt/motd_asus.sh "$DIST motd_asus.sh"  
fi 


if [ "$DIST" = "kali" ]; then 
 _loadFile "$HOME"/.dot/kali/.bashrc "$DIST bashrc"
 _loadFile "$HOME"/.dot/kali/.exports "$DIST exports"
 _loadFile "$HOME"/.dot/kali/.bash_aliases "$DIST bash_aliases" 
 _loadFile "$HOME"/.dot/kali/motd_kali.sh "$DIST motd_kali.sh"
 reload=yes   
fi 



tempfile_c="/var/log/apt/apt-updates_count.log"
if [ -f "$tempfile_c" ]; then
  AptCount=$(cat $tempfile_c )  
fi  

if [[ $AptCount -gt 0 ]]; then
    UPDATED="$(print_style " $AptCount" "success") Apt Update available - #apuu"
fi



# printf "\n" 
 #echo "$OS $DIST $_MACH $REV $PSUEDONAME | Kernel $_KERNEL | based on $DistroBasedOn "
 #echo "$MODELL_TYPE $MODELL_SYSTEM | $CPU_CORES'x'$CPU_TYPE"
 #echo "$UPDATED"
# echo 
# ______ ______   _____________________ __________________________
# ___  //_/__  | / /__    |__    |__  //_/__  __ \__  __ \_  ____/
# __  ,<  __   |/ /__  /| |_  /| |_  ,<   _  / / /_  /_/ /  / __  
# _  /| | _  /|  / _  ___ |  ___ |  /| |__/ /_/ /_  _, _// /_/ /  
# /_/ |_| /_/ |_/  /_/  |_/_/  |_/_/ |_|(_)____/ /_/ |_| \____/   


#autojump
[[ -s "$HOME"/.autojump/etc/profile.d/autojump.sh ]] && source "$HOME"/.autojump/etc/profile.d/autojump.sh

 
if [ "$reload" = "yes" ]; then
  homeshick refresh
  homeshick link
fi

#a command-line fuzzy finde
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

#locals
[ -f ~/.dot/.secrets ] && source ~/.dot/.secrets 

if [ -d ~/.dot/bin ] ; then
  export PATH=~/.dot/bin:$PATH
fi

printf "\n" 
# Virtual Environment Wrapper
alias workoncv-3.4.4="source /root/opencv/OpenCV-3.4.4-py3/bin/activate"

complete -C /root/mcc mcc
