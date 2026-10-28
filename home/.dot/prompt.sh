# Prompt for every system: exit status of the last command when it failed, git branch and state, time, user, IP,
# host and directory. The folders of special systems (raspi, proxmox, synology, …) load after this and may set
# their own PS1.

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# current branch in a git repo, with the state from parse_git_dirty
parse_git_branch() {
  local branch
  branch=$(git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')
  [ -n "$branch" ] && echo "[${branch}$(parse_git_dirty)]"
}

# state of the git repo: ! modified, x deleted, ? untracked, + new file, * ahead, > renamed
parse_git_dirty() {
  local status bits=
  status=$(git status 2>&1)
  grep -q "renamed:" <<<"$status" && bits=">$bits"
  grep -q "Your branch is ahead of" <<<"$status" && bits="*$bits"
  grep -q "new file:" <<<"$status" && bits="+$bits"
  grep -q "Untracked files" <<<"$status" && bits="?$bits"
  grep -q "deleted:" <<<"$status" && bits="x$bits"
  grep -q "modified:" <<<"$status" && bits="!$bits"
  [ -n "$bits" ] && echo " $bits"
}

# first IPv4 address of this host; hostname -I is missing on busybox and some minimal images
# (silent: the prompt calls it on every line, also where awk or ip are missing)
getmyIP() {
  { hostname -I | awk '{print $1; exit}' | grep . ||
    ip -4 -o addr show scope global | awk '{sub(/\/.*/, "", $4); print $4; exit}'; } 2>/dev/null
}

nonzero_return() {
  local rc=$?
  [ $rc -ne 0 ] && echo "$rc"
}

if [ "$DIST" = cygwin ] || [ "$DIST" = msys ]; then
  # Cygwin, Git Bash: every process and every `…` in PS1 costs 10-20 ms there, git itself 70-130 ms (27.10.26).
  # PROMPT_COMMAND reads exit status and branch in bash alone: no dirty state, no IP (voku/dotfiles does the same).
  _dot_prompt() {
    local rc=$? d=$PWD g h
    _dot_rc= _dot_branch=
    [ $rc -ne 0 ] && _dot_rc=$rc
    until [ -e "$d/.git" ]; do [ -n "$d" ] || return; d=${d%/*}; done
    g=$d/.git
    # worktree or submodule: .git is a file "gitdir: <path>", the path may be relative or C:/...
    if [ -f "$g" ]; then read -r h <"$g"; g=${h#gitdir: }; [[ $g == /* || $g == ?:* ]] || g=$d/$g; fi
    read -r h 2>/dev/null <"$g/HEAD" || return
    case $h in
      "ref: refs/heads/"*) _dot_branch="[${h#ref: refs/heads/}]" ;;
      *) _dot_branch="[${h:0:7}]" ;;
    esac
  }
  PROMPT_COMMAND="_dot_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
  # variables, not `…`: a branch name is printed as it is, never run
  PS1="\${_dot_rc}_\${_dot_branch}_\t~\[\e[31m\]\u\[\e[m\]\[\e[33m\]@\[\e[m\]\[\e[36m\]\H\[\e[m\] \[\e[33m\]\w\[\e[m\]  \[\e[35m\]#\[\e[m\] "
elif [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
  if [ -d ~/.git-radar ]; then
    PS1="\`nonzero_return\` \t \[\e[31m\]\u\[\e[m\]\[\e[33m\]@\[\e[m\]\[\e[36m\]\`getmyIP\`\[\e[m\][\H] [\$(git-radar --bash --fetch)] \[\e[33m\]\w\[\e[m\]  \[\e[35m\]#\[\e[m\] "
  else
    PS1="\`nonzero_return\`_\`parse_git_branch\`_\t~\[\e[31m\]\u\[\e[m\]\[\e[33m\]@\[\e[m\]\[\e[36m\]\`getmyIP\`\[\e[m\] [\H] \[\e[33m\]\w\[\e[m\]  \[\e[35m\]#\[\e[m\] "
  fi
else
  PS1='\t-${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi

# If this is an xterm set the title to user@host:dir
case "$TERM" in
  xterm*|rxvt*) PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1" ;;
esac
export PS1
