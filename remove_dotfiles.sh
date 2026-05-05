#!/bin/bash
# Remove all dotfile traces and restore a stock Debian environment.
#
# IMPORTANT: copy this script outside ~/.homesick before running it,
# because it deletes ~/.homesick (which contains this repo).
#   cp ~/.homesick/repos/dotfiles/remove_dotfiles.sh /tmp/
#   bash /tmp/remove_dotfiles.sh

set -euo pipefail

RED=$'\e[31m' YEL=$'\e[33m' GRN=$'\e[32m' RST=$'\e[0m'

die()  { echo "${RED}error: $*${RST}" >&2; exit 1; }
info() { echo "${GRN}  >>  $*${RST}"; }
warn() { echo "${YEL} [!]  $*${RST}"; }

# ── safety checks ─────────────────────────────────────────────────────────
[ "$EUID" -eq 0 ] && die "Do not run as root — run as the target user."

echo ""
echo "${RED}This will permanently remove:${RST}"
echo "  ~/.homesick/   (dotfiles repo + homeshick)"
echo "  ~/.dot/        (if real directory)"
echo "  ~/.autojump/   ~/.fzf/   ~/.git-radar/"
echo "  All symlinks in ~ that point into ~/.homesick/"
echo "  ~/.bashrc  ~/.profile  (replaced with Debian stock versions)"
echo ""
printf "Continue? [y/N] "
read -r _ans
[[ "$_ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
echo ""

# ── 1. remove homeshick symlinks from ~ ───────────────────────────────────
# These are the items homeshick links from home/ into ~/.
LINKED=(
    .bashrc
    .cheat
    .dot
    .inputrc
    .profile
    .reset.sh
    .vscode
    deploy_headless.sh
)

info "Removing homeshick symlinks from home directory..."
for item in "${LINKED[@]}"; do
    target="$HOME/$item"
    if [ -L "$target" ]; then
        rm "$target"
        echo "    unlinked: $target"
    elif [ -e "$target" ]; then
        warn "skipping $target — not a symlink, leaving intact"
    fi
done

# ── 2. remove ~/.homesick (repo + homeshick itself) ───────────────────────
if [ -d "$HOME/.homesick" ]; then
    info "Removing ~/.homesick..."
    rm -rf "$HOME/.homesick"
fi

# ── 3. remove ~/.dot if it survived as a real directory ───────────────────
if [ -d "$HOME/.dot" ]; then
    info "Removing ~/.dot (real directory)..."
    rm -rf "$HOME/.dot"
fi

# ── 4. remove tools installed by dotfiles ────────────────────────────────
for tool_dir in "$HOME/.autojump" "$HOME/.fzf" "$HOME/.git-radar" "$HOME/.nvm"; do
    if [ -d "$tool_dir" ]; then
        info "Removing $tool_dir..."
        rm -rf "$tool_dir"
    fi
done

for tool_file in "$HOME/.fzf.bash" "$HOME/.fzf.zsh"; do
    [ -f "$tool_file" ] && rm -f "$tool_file" && echo "    removed: $tool_file"
done

# ── 5. restore stock Debian .bashrc ──────────────────────────────────────
info "Restoring stock Debian .bashrc..."
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
    echo "    wrote minimal stock Debian .bashrc"
fi

# ── 6. restore stock .profile ─────────────────────────────────────────────
if [ ! -f "$HOME/.profile" ]; then
    info "Restoring stock Debian .profile..."
    if [ -f /etc/skel/.profile ]; then
        cp /etc/skel/.profile "$HOME/.profile"
        echo "    copied from /etc/skel/.profile"
    fi
fi

# ── done ──────────────────────────────────────────────────────────────────
echo ""
echo "${GRN}Done.${RST} Re-login or run:  exec bash"
echo ""
