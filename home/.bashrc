# ~/.bashrc: executed by bash(1) for non-login shells.
source "$HOME"/.dot/core.sh

#OS Check
shootProfile

echo "$OS $DIST $MACH $REV $PSUEDONAME | Kernel $KERNEL | based on $DistroBasedOn | $MODELL_TYPE $MODELL_SYSTEM"
echo $CPU_TYPE

#load basisc
source "$HOME"/.dot/.bash_aliases
source "$HOME"/.dot/.bash_functions.sh
source "$HOME"/.dot/.exports


if [ "$DIST" = "Ubuntu" ]; then   
  # load the shell dotfiles, and then some:
  # * ~/.path can be used to extend `$PATH`.
  # * ~/.extra can be used for other settings you don’t want to commit.
  #for file in ~/.{config_dotfiles,path,load,colors,exports,icons,aliases,bash_complete,functions,extra,dotfilecheck}; do
  for file in ~/.dot/ubuntu16/.{bashrc,exports,bash_aliases,srv1.bash_aliases}; do
      [ -r "$file" ] && [ -f "$file" ] && source "$file"
  done
  unset file
fi  

if [ "$DIST" = "Synology" ]; then 
  echo "welcome to $DIST"
  for file in "$HOME"/.dot/synology/.{bashrc,exports,bash_aliases}; do
      [ -r "$file" ] && [ -f "$file" ] && source "$file"
  done
  unset file
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

alias scriptinfo="grep -E '^[[:space:]]*([[:alnum:]_]+[[:space:]]*\(\)|function[[:space:]]+[[:alnum:]_]+)'"

#autojump
[[ -s "$HOME"/.autojump/etc/profile.d/autojump.sh ]] && source "$HOME"/.autojump/etc/profile.d/autojump.sh

############# INCLUDE ####################################

source "$HOME/.homesick/repos/homeshick/homeshick.sh"
source "$HOME/.homesick/repos/homeshick/completions/homeshick-completion.bash"
homeshick refresh

