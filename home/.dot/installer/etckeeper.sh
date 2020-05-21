#!/bin/bash
    #etckeeper
    sudo -i
    cd /root/.ssh
    ssh-keygen
    cat id_rsa.pub 
    echo "copy into gitlab user settings -Y ssh keys"
    apt-get install etckeeper git
    joe /etc/etckeeper/etckeeper.conf
    echo "VCS=git"
    echo "AVOID_SPECIAL_FILE_WARNING=1"
    echo "PUSH_REMOTE=origin"

    echo "
    git config --global user.name xxx
    git config --global user.email xxx
    git config --global core.editor joe
    git config --global push.default simple"

    cd /etc
    echo "git init"
    echo "git remote add origin ssh://git@xxx:30001/xxx/xxx.git"
    echo "etckeeper commit \"initial commit\""
    echo "git push --set-upstream origin master"
    echo "systemctl enable etckeeper.timer"
    echo "systemctl start etckeeper.timer"

    #etckeeper init -d /srv/data
#    git remote add origin git@gitlab.com:you/data.git
#    etckeeper commit -d /srv/data 'initial sync commit' && git push