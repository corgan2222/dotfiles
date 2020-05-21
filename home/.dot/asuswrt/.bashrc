# If not running interactively, don't do anything
[ -z "$PS1" ] && return

HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
HISTFILESIZE=99999999
HISTSIZE=99999
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"


    # get current branch in git repo
    function parse_git_branch() {
            BRANCH=`git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'`
            if [ ! "${BRANCH}" == "" ]
            then
                    STAT=`parse_git_dirty`
                    echo "[${BRANCH}${STAT}]"
            else
                    echo ""
            fi
    }

    function getmyIP {
          ifconfig | grep ^eth -A2 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1 }'  
    }

    # get current status of git repo
    function parse_git_dirty {
        status=`git status 2>&1 | tee`
        dirty=`echo -n "${status}" 2> /dev/null | grep "modified:" &> /dev/null; echo "$?"`
        untracked=`echo -n "${status}" 2> /dev/null | grep "Untracked files" &> /dev/null; echo "$?"`
        ahead=`echo -n "${status}" 2> /dev/null | grep "Your branch is ahead of" &> /dev/null; echo "$?"`
        newfile=`echo -n "${status}" 2> /dev/null | grep "new file:" &> /dev/null; echo "$?"`
        renamed=`echo -n "${status}" 2> /dev/null | grep "renamed:" &> /dev/null; echo "$?"`
        deleted=`echo -n "${status}" 2> /dev/null | grep "deleted:" &> /dev/null; echo "$?"`
        bits=''
        if [ "${renamed}" == "0" ]; then
                bits=">${bits}"
        fi
        if [ "${ahead}" == "0" ]; then
                bits="*${bits}"
        fi
        if [ "${newfile}" == "0" ]; then
                bits="+${bits}"
        fi
        if [ "${untracked}" == "0" ]; then
                bits="?${bits}"
        fi
        if [ "${deleted}" == "0" ]; then
                bits="x${bits}"
        fi
        if [ "${dirty}" == "0" ]; then
                bits="!${bits}"
        fi
        if [ ! "${bits}" == "" ]; then
                echo " ${bits}"
        else
                echo ""
        fi
    }

    function nonzero_return() {
            RETVAL=$?
            [ $RETVAL -ne 0 ] && echo "$RETVAL"
    }

    export PS1="\`nonzero_return\`_\`parse_git_branch\`_\t~\[\e[31m\]\u\[\e[m\]\[\e[33m\]@\[\e[m\]\[\e[36m\]\`getmyIP\`\[\e[m\] [\H] \[\e[33m\]\w\[\e[m\]  \[\e[35m\]#\[\e[m\] "




