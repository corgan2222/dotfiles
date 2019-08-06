
[ -z "$PS1" ] && return
# ~/.bashrc: executed by bash(1) for non-login shells.

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


if [ "$DIST" = "raspi" ]; then 
  for file in ~/.dot/raspi/.{.bashrc,.exports,.bash_aliases}; do
      [ -r "$file" ] && [ -f "$file" ] && source "$file"source
  done
  unset file
fi 


if [ "$DIST" = "asuswrt" ]; then 
  for file in ~/.dot/asuswrt/.{.bashrc,.exports,.bash_aliases}; do
      [ -r "$file" ] && [ -f "$file" ] && source "$file"
  done
  unset file
fi 

function resetHome()
{
  rmd "$HOME"/.dot/ -f
  rmd "$HOME"/.homesick/ -f
  rm .profile 
  rm .bashrc
  bash <(curl https://corgan2222.github.io/dotfiles/deploy_homeshick.sh)
  gitSaveCredential
}

alias scriptinfo="grep -E '^[[:space:]]*([[:alnum:]_]+[[:space:]]*\(\)|function[[:space:]]+[[:alnum:]_]+)'"

printf "\n" 
echo "$OS $DIST $_MACH $REV $PSUEDONAME | Kernel $_KERNEL | based on $DistroBasedOn | $MODELL_TYPE $MODELL_SYSTEM $CPU_TYPE"
printf "\n" 

#autojump
[[ -s "$HOME"/.autojump/etc/profile.d/autojump.sh ]] && source "$HOME"/.autojump/etc/profile.d/autojump.sh

############# INCLUDE ####################################

source "$HOME/.homesick/repos/homeshick/homeshick.sh"
source "$HOME/.homesick/repos/homeshick/completions/homeshick-completion.bash"
homeshick refresh
printf "\n" 
