#!/bin/sh -x 
 
echo -n "Delete all? (y/n)? "
old_stty_cfg=$(stty -g)
stty raw -echo ; answer=$(head -c 1) ; stty $old_stty_cfg # Careful playing with stty
if echo "$answer" | grep -iq "^y" ;then
    echo Yes 
    delete
else
    #
fi

 delete(){
  rm -r "$HOME"/.dot/ -f
  rm -r "$HOME"/.homesick/ -f
  rm .profile 
  rm .bashrc
  bash <(curl https://corgan2222.github.io/dotfiles/deploy_homeshick.sh)
  git config credential.helper store
  git pull
  source "$HOME"/.bashrc
}
