#!/bin/sh -x
[ -z "$PS1" ] && return
# ~/.bashrc: executed by bash(1) for non-login shells.

# reload the shell (i.e. invoke as a login shell)
alias reload="exec $SHELL -l"
alias load="source $HOME/.bashrc && source $HOME/.dot/.bash_aliases && source $HOME/.dot/.bash_functions.sh"

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


function _loadFile()
{
  if [ -r "$1" ]; then
      #LAST=$(stat -c%y "$1" | cut -d'.' -f1) 
      DALTA=$(($(date +%s) - $(date +%s -r "$1"))) 

      LAST=$(date -r $1 +'%H:%M:%S %d-%m-%Y ') 
      c1=$(print_style " $2" "success")
      c2=$(print_style " $1" "info")
      c3=$(print_style " $DALTA" "success")
      
      printf "%5s%35s%50s%55s\n" loading "$c1" "$c2" "$LAST (+$c3 sec)" 
      source "$1" 
  fi  
}

_loadFile "$HOME"/.dot/core.sh "Core System"

function resetHome()
{
  rmd "$HOME"/.dot/ -f
  rmd "$HOME"/.homesick/ -f
  rm .profile 
  rm .bashrc
  bash <(curl https://corgan2222.github.io/dotfiles/deploy_homeshick.sh)
  gitSaveCredential
}

#OS Check
shootProfile

#load basisc
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
  _loadFile "$HOME"/.dot/ubuntu16/debian.sh "Debian Server Functions"
  _loadFile "$HOME"/.dot/ubuntu16/.bashrc "Debian Userpromt"
  _loadFile "$HOME"/.dot/ubuntu16/.exports "Exports"
  _loadFile "$HOME"/.dot/ubuntu16/.bash_aliases "Debian Alias"
  _loadFile "$HOME"/.dot/ubuntu16/.srv1.bash_aliases "srv1"
 
  unset file
fi  

#PROG="`basename $0`" 
#BASEDIR=$(dirname "$0")
#echo "$BASEDIR"

#ToDo cat file1 ... fileN > combinedFile;

if [ "$DIST" = "Synology" ]; then 
  #echo "welcome to $DIST"
  #for file in "$HOME"/.dot/synology/.{bashrc,exports,bash_aliases}; do
  #    [ -r "$file" ] && [ -f "$file" ] && source "$file"
  #done
  #unset file
  _loadFile "$HOME"/.dot/synology/.bashrc "$DIST Userpromt"
  _loadFile "$HOME"/.dot/synology/.exports " $DIST Exports"
  _loadFile "$HOME"/.dot/synology/.bash_aliases "$DIST Alias"
fi  

if [ "$DIST" = "raspbian" ]; then 
 _loadFile "$HOME"/.dot/raspi/.bashrc "$DIST bashrc"
 _loadFile "$HOME"/.dot/raspi/.exports "$DIST exports"
 _loadFile "$HOME"/.dot/raspi/.bash_aliases "$DIST bash_aliases"  
 _loadFile "$HOME"/.dot/raspi/.raspi_bash_functions.sh "$DIST Functions"  
fi 


if [ "$MODELL_TYPE" = "ASUSWRT-Merlin" ]; then 
 _loadFile "$HOME"/.dot/asuswrt/.bashrc "$DIST bashrc"
 _loadFile "$HOME"/.dot/asuswrt/.exports "$DIST exports"
 _loadFile "$HOME"/.dot/asuswrt/.bash_aliases "$DIST bash_aliases"  
 _loadFile "$HOME"/.dot/asuswrt/.raspi_bash_functions.sh "$DIST Functions"  
fi 

alias scriptinfo="grep -E '^[[:space:]]*([[:alnum:]_]+[[:space:]]*\(\)|function[[:space:]]+[[:alnum:]_]+)'"

tempfile_c="/var/log/apt/apt-updates_count.log"
if [ -f "$tempfile_c" ]; then
  AptCount=$(cat $tempfile_c )  
  if (( $AptCount > 0 )); then
    UPDATED="$(print_style " $AptCount" "success") Apt Update available - #apuu"
  fi
fi

printf "\n" 
#echo "$OS DIST:$DIST MACH:$_MACH REV:$REV PS:$PSUEDONAME | Kernel $_KERNEL | based on $DistroBasedOn | Type:$MODELL_TYPE System:$MODELL_SYSTEM CPU:$CPU_TYPE"
echo "$OS $DIST $_MACH $REV $PSUEDONAME | Kernel $_KERNEL | based on $DistroBasedOn "
echo "$MODELL_TYPE $MODELL_SYSTEM | $CPU_CORES'x'$CPU_TYPE"
echo "$UPDATED"
   #OS:linux DIST:Ubuntu MACH:x86_64 REV:16.04 PS:xenial | Kernel 4.15.0-45-generic | based on debian | Type: System: CPU: Intel(R) Xeon(R) CPU E3-1246 v3 @ 3.50GHz
printf "\n" 

#autojump
[[ -s "$HOME"/.autojump/etc/profile.d/autojump.sh ]] && source "$HOME"/.autojump/etc/profile.d/autojump.sh

############# INCLUDE ####################################

source "$HOME/.homesick/repos/homeshick/homeshick.sh"
source "$HOME/.homesick/repos/homeshick/completions/homeshick-completion.bash"

if (( $norefresg <= 1 )); then
  homeshick refresh
fi



printf "\n" 
