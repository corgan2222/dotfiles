
[ -z "$PS1" ] && return
# ~/.bashrc: executed by bash(1) for non-login shells.


function _loadFile()
{
  if [ -r "$1" ]; then
      printf "%5s%30s%80s\n" loading "$2" "$1"
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
echo "$OS $DIST $_MACH $REV $PSUEDONAME | Kernel $_KERNEL | based on $DistroBasedOn | $MODELL_TYPE $MODELL_SYSTEM"
echo $CPU_TYPE


#autojump
[[ -s "$HOME"/.autojump/etc/profile.d/autojump.sh ]] && source "$HOME"/.autojump/etc/profile.d/autojump.sh

############# INCLUDE ####################################

source "$HOME/.homesick/repos/homeshick/homeshick.sh"
source "$HOME/.homesick/repos/homeshick/completions/homeshick-completion.bash"
homeshick refresh

