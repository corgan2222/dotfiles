#!/bin/bash
# Removes the dotfiles: every link into the castle, the castle itself, homeshick when no other castle is left, and the
# tools the dotfiles install (~/.autojump, ~/.fzf, ~/.git-radar). Then it puts back what the deploy moved to
# ~/.dotfiles-backup/ (the newest copy of each file); a ~/.bashrc or ~/.profile still missing comes from /etc/skel.
# Other castles, ~/.nvm and files of your own in ~/.dot go only after a question of their own. It lists everything
# first and asks before it changes anything; the backups stay.
#   bash ~/.homesick/repos/dotfiles/remove_dotfiles.sh
set -euo pipefail

RED=$'\e[31m' YEL=$'\e[33m' GRN=$'\e[32m' RST=$'\e[0m'

die()  { echo "${RED}error: $*${RST}" >&2; exit 1; }
info() { echo "${GRN}  >>  $*${RST}"; }
warn() { echo "${YEL} [!]  $*${RST}"; }
# ask <question>: true on y, default no
ask() { local a=; printf '%s [y/N] ' "$1"; read -r a || true; [[ $a =~ ^[Yy]$ ]]; }

# ── safety checks ─────────────────────────────────────────────────────────
# root removes its own dotfiles (containers, Proxmox and NAS hosts often have no other user); through sudo HOME would
# be someone else's or root's by chance, so sudo is refused: run it as the user whose dotfiles go
if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
  die "started through sudo: run it as $SUDO_USER without sudo, it removes the dotfiles of the user who runs it"
fi
# bash reads a script while it runs: started from the castle, it would lose itself half way
case $(readlink -f "$0") in
  "$HOME"/.homesick/*) t=$(mktemp); cp "$0" "$t"; DOT_REMOVE_COPY=$t exec bash "$t" "$@" ;;
esac
# the copy removes itself; until 28.10.26 it stayed in /tmp
[ "${DOT_REMOVE_COPY:-}" = "$0" ] && trap 'rm -f "$DOT_REMOVE_COPY"' EXIT
shopt -s nullglob
repos=$HOME/.homesick/repos
backups=$HOME/.dotfiles-backup

# prints each path and, for a path in a folder, also its first folder; in bash, minimal systems lack awk (28.10.26:
# without awk the plan showed 0 links and the castle went anyway, leaving dead links)
first_dirs() { local p; while IFS= read -r p; do echo "$p"; [[ $p == */* ]] && echo "${p%%/*}"; done; return 0; }

# castle_links <castle>: the links in ~ into that castle, for every path it has or had in home/ and the first folder
# of each (an old install linked ~/.dot as a whole)
castle_links() {
  local p t
  while IFS= read -r p; do
    t=$HOME/$p
    # homeshick writes relative links (.homesick/repos/… from ~, ../.homesick/repos/… from ~/.dot)
    [ -L "$t" ] && [[ $(readlink "$t") == *".homesick/repos/$1/"* ]] && echo "$t"
  done < <({ git -C "$repos/$1" ls-files home/
             git -C "$repos/$1" log --no-renames --name-only --format= --diff-filter=D -- home/; } 2>/dev/null |
           sed -n 's|^home/||p' | first_dirs | sort -u)
  return 0
}
# lost <castle>: what exists only here, changed files and commits on no remote
lost() {
  local c u
  c=$(git -C "$repos/$1" status --porcelain 2>/dev/null | wc -l)
  u=$(git -C "$repos/$1" log --oneline --branches --not --remotes 2>/dev/null | wc -l)
  [ $((c + u)) -eq 0 ] || echo " ${RED}($((c)) changed files, $((u)) commits not pushed: they are lost)${RST}"
}
unlink_all() {
  local t d
  for t in "$@"; do
    rm -f "$t"
    # folders that only held such links, up to the home folder
    d=${t%/*}
    while [ "$d" != "$HOME" ] && [ "${d#"$HOME"/}" != "$d" ] && rmdir "$d" 2>/dev/null; do d=${d%/*}; done
  done
}

# ── what is there ─────────────────────────────────────────────────────────
[ -d "$repos/dotfiles/.git" ] || warn "no castle in $repos/dotfiles: only links and backups are handled"
mapfile -t links < <(castle_links dotfiles)
others=()
for d in "$repos"/*/; do
  d=${d%/}; [ -d "$d/.git" ] && [ "${d##*/}" != homeshick ] && [ "${d##*/}" != dotfiles ] && others+=("${d##*/}")
done
own=()
if [ -d "$HOME/.dot" ] && [ ! -L "$HOME/.dot" ]; then
  while IFS= read -r t; do
    [[ -L $t && $(readlink "$t") == *".homesick/repos/"* ]] || own+=("$t")
  done < <(find "$HOME/.dot" ! -type d)
fi
tools=()
for t in "$HOME/.autojump" "$HOME/.fzf" "$HOME/.git-radar" "$HOME/.fzf.bash" "$HOME/.fzf.zsh"; do
  [ -e "$t" ] && tools+=("$t")
done
# the newest copy of each file from all backups (a later deploy saves only what was new in the way)
declare -A from=()
# (read line by line: a home path with spaces split in a for loop, the backup was not found, 28.10.26)
while IFS= read -r b; do
  [ -n "$b" ] || continue
  while IFS= read -r f; do [ -n "${from[$f]:-}" ] || from[$f]=${b%/}; done < <(cd "$b" && find . ! -type d | cut -c3-)
done < <(printf '%s\n' "$backups"/*/ | sort -r)

# ── the questions of their own ────────────────────────────────────────────
drop_others=() drop_nvm= drop_own=
echo ""
for c in ${others[@]+"${others[@]}"}; do
  ask "Remove the other castle $c with its links too?$(lost "$c")" && drop_others+=("$c")
done
[ -d "$HOME/.nvm" ] && ask "Remove ~/.nvm (Node.js versions of nvm, also those you installed yourself)?" && drop_nvm=1
if [ ${#own[@]} -gt 0 ]; then
  echo "Files of your own in ~/.dot (not links into the dotfiles):"
  printf '    %s\n' "${own[@]:0:10}" | sed "s|$HOME|~|"
  [ ${#own[@]} -le 10 ] || echo "    … $(( ${#own[@]} - 10 )) more"
  ask "Delete these ${#own[@]} files?" && drop_own=1
fi
for c in ${drop_others[@]+"${drop_others[@]}"}; do mapfile -t -O ${#links[@]} links < <(castle_links "$c"); done
keep_hs=$(( ${#others[@]} - ${#drop_others[@]} ))
# what ~/.bashrc and ~/.profile will be: a link of ours goes, a real file stays
skel=()
for f in .bashrc .profile; do
  [ -z "${from[$f]:-}" ] || continue
  { [ ! -e "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; } || printf '%s\n' ${links[@]+"${links[@]}"} | grep -qxF "$HOME/$f" && skel+=("$f")
done

# ── the plan ──────────────────────────────────────────────────────────────
echo ""
echo "${RED}This removes:${RST}"
echo "  ${#links[@]} links into the castles in your home (~/.bashrc, ~/.profile, ~/.dot/…)"
[ ! -d "$repos/dotfiles" ] || echo "  the castle ~/.homesick/repos/dotfiles$(lost dotfiles)"
for c in ${drop_others[@]+"${drop_others[@]}"}; do echo "  the castle ~/.homesick/repos/$c$(lost "$c")"; done
if [ "$keep_hs" -eq 0 ]; then echo "  homeshick (~/.homesick)"
else echo "  not homeshick: other castles stay in ~/.homesick/repos"; fi
[ -z "$drop_nvm" ] || echo "  ~/.nvm"
[ -z "$drop_own" ] || echo "  ${#own[@]} files of your own in ~/.dot"
[ ${#tools[@]} -eq 0 ] || echo "  ${tools[*]/#$HOME/\~}"
[ -n "$drop_own" ] || [ ${#own[@]} -eq 0 ] || echo "It keeps ${#own[@]} files of your own in ~/.dot."
if [ ${#from[@]} -gt 0 ]; then
  echo "It puts back from ~/.dotfiles-backup (the backups stay):"
  for f in "${!from[@]}"; do echo "  ~/$f   (${from[$f]##*/})"; done | sort
fi
[ ${#skel[@]} -eq 0 ] || echo "It copies from /etc/skel: ${skel[*]/#/\~/}"
echo ""
ask "Continue?" || { echo "Aborted."; exit 0; }
echo ""

# ── 1. links, then the files of your own ──────────────────────────────────
info "Removing the links..."
unlink_all ${links[@]+"${links[@]}"}
if [ -n "$drop_own" ]; then
  info "Removing your files in ~/.dot..."
  rm -f ${own[@]+"${own[@]}"}
fi
[ ! -d "$HOME/.dot" ] || find "$HOME/.dot" -depth -type d -empty -delete 2>/dev/null || true

# ── 2. castles and homeshick ──────────────────────────────────────────────
for c in dotfiles ${drop_others[@]+"${drop_others[@]}"}; do
  [ ! -d "$repos/$c" ] || { info "Removing the castle $c..."; rm -rf "${repos:?}/$c"; }
done
if [ "$keep_hs" -eq 0 ] && [ -d "$HOME/.homesick" ]; then
  info "Removing ~/.homesick..."
  rm -rf "$HOME/.homesick"
fi

# ── 3. tools installed by the dotfiles ────────────────────────────────────
[ -z "$drop_nvm" ] || tools+=("$HOME/.nvm")
for t in ${tools[@]+"${tools[@]}"}; do info "Removing ${t/#$HOME/\~}..."; rm -rf "$t"; done

# ── 4. put back what the deploy saved ─────────────────────────────────────
for f in "${!from[@]}"; do
  t=$HOME/$f
  if [ -e "$t" ] || [ -L "$t" ]; then
    warn "~/$f exists, it stays; the saved copy is in ${from[$f]/#$HOME/\~}/"
    continue
  fi
  mkdir -p "$(dirname "$t")" && cp -a "${from[$f]}/$f" "$t" && echo "    restored ~/$f"
done

# ── 5. stock .bashrc and .profile where none is left ──────────────────────
if [ ! -e "$HOME/.bashrc" ] && [ ! -L "$HOME/.bashrc" ]; then
  info "Restoring a stock .bashrc..."
  if [ -f /etc/skel/.bashrc ]; then
    cp /etc/skel/.bashrc "$HOME/.bashrc"
    echo "    copied from /etc/skel/.bashrc"
  else
    cat > "$HOME/.bashrc" << 'STOCK_BASHRC'
# ~/.bashrc: executed by bash(1) for non-login shells.
case $- in
    *i*) ;;
      *) return;;
esac

HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize

[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi
STOCK_BASHRC
    echo "    wrote a minimal .bashrc (no /etc/skel here)"
  fi
fi
if [ ! -e "$HOME/.profile" ] && [ ! -L "$HOME/.profile" ] && [ -f /etc/skel/.profile ]; then
  info "Restoring a stock .profile..."
  cp /etc/skel/.profile "$HOME/.profile"
  echo "    copied from /etc/skel/.profile"
fi

# ── done ──────────────────────────────────────────────────────────────────
echo ""
echo "${GRN}Done.${RST} Re-login or run:  exec bash"
echo ""
