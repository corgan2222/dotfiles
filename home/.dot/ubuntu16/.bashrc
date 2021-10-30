# If not running interactively, don't do anything
[ -z "$PS1" ] && return

HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
HISTFILESIZE=99999999
HISTSIZE=99999
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    #    PS1='\t-${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\u\[\033[01;33m\]@\[\033[01;36m\]\h \[\033[01;33m\]\w \[\033[01;35m\]\$ \[\033[00m\]'

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
         ifconfig | grep ^enp2s0 -A2 | grep 'inet ' | awk '{ print $2 }'
    }

    # get current status of git repo
    function parse_git_dirty 
    {
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

    function nonzero_return() 
    {
        RETVAL=$?
        [ $RETVAL -ne 0 ] && echo "$RETVAL"
    }


        if [ -d ~/.git-radar ] ; then
                
                export PS1="\`nonzero_return\` \t \[\e[31m\]\u\[\e[m\]\[\e[33m\]@\[\e[m\]\[\e[36m\]\`getmyIP\`\[\e[m\][\H] [\$(git-radar --bash --fetch)] \[\e[33m\]\w\[\e[m\]  \[\e[35m\]#\[\e[m\] "
        else
                export PS1="\`nonzero_return\`_\`parse_git_branch\`_\t~\[\e[31m\]\u\[\e[m\]\[\e[33m\]@\[\e[m\]\[\e[36m\]\`getmyIP\`\[\e[m\] [\H] \[\e[33m\]\w\[\e[m\]  \[\e[35m\]#\[\e[m\] "
        fi

else
    PS1='\t-${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt


# If this is an xterm set the title to user@host:dir
case "$TERM" in
    xterm*|rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
    *)
    ;;
esac
