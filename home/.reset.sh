#!/bin/sh -x 
 
echo "delete all bashscript?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) delete break;;
        No ) exit;;
    esac
done

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
