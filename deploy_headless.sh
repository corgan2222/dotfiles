#!/bin/bash
# Installs the dotfiles with one call:
#   bash <(curl -fsSL https://corgan2222.github.io/dotfiles/deploy_headless.sh)
#   bash ~/path/to/a/checkout/deploy_headless.sh      the committed state of that checkout instead of GitHub
# What it does, in this order:
#   1. installs git when it is missing, and sudo when it runs as root (the aliases apuu, apr, ap ... call sudo);
#      without sudo as a normal user, and on Windows, it needs git to be there and installs nothing
#   2. fetches homeshick and this repository (castle corgan2222/dotfiles)
#   3. moves every file it would replace to ~/.dotfiles-backup/<date>/ with the same relative path (~/.bashrc,
#      ~/.profile, own files in ~/.dot), and ~/.bash_profile and ~/.bash_login, which would hide ~/.profile from bash;
#      remove_dotfiles.sh puts them back. It tries a link in your home first: without the right to link, nothing moves
#   4. links ~/.bashrc, ~/.profile and ~/.dot into your home (homeshick link); the folders for special systems in
#      ~/.dot (raspi, proxmox, synology, ...) load only on those systems. A link that fails puts everything back
#   5. runs ~/.dot/setup.sh: git identity, editor, MOTD, then it offers the installer menu
# Without a terminal (curl | bash in a script) it asks nothing.
set -u
CASTLE=corgan2222/dotfiles
REPOS=$HOME/.homesick/repos
say() { printf '\033[96m==> %s\033[0m\n' "$*"; }
die() { printf '\033[91merror: %s\033[0m\n' "$*" >&2; exit 1; }

# --- 1. git and sudo: git fetches the dotfiles, sudo is used by aliases such as apuu, apr and ap
# sudo is required only to install a missing package as a normal user: a missing sudo stopped the deploy even with git
# in place, so Git Bash, Cygwin and users without sudo could not install (28.10.26)
case $(uname -s) in CYGWIN*|MINGW*|MSYS*) win=1 ;; *) win= ;; esac
need=
command -v git >/dev/null 2>&1 || need=git
# Windows has no sudo, Asuswrt (opkg) and Synology run as admin without it; root installs it for the aliases
if [ -z "$win" ] && ! command -v sudo >/dev/null 2>&1 && ! command -v opkg >/dev/null 2>&1; then
  if [ "$(id -u)" -eq 0 ]; then need="${need:+$need }sudo"
  else say "no sudo here: the dotfiles work, aliases such as apuu, apr and ap need it later"; fi
fi
if [ -n "$need" ]; then
  [ -z "$win" ] || die "git is missing: install Git for Windows, or git in the Cygwin setup, and run this again"
  sudo=
  if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 ||
      die "$need is missing and there is no sudo: run this once as root, or install $need by hand"
    sudo=sudo
  fi
  say "installing what is missing: $need"
  if command -v apt-get >/dev/null; then $sudo apt-get update -qq && $sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $need ca-certificates
  elif command -v dnf >/dev/null; then $sudo dnf install -y -q $need
  elif command -v pacman >/dev/null; then $sudo pacman -Sy --noconfirm --needed $need
  elif command -v zypper >/dev/null; then $sudo zypper -n -q install $need
  elif command -v apk >/dev/null; then $sudo apk add -q $need
  elif command -v opkg >/dev/null; then opkg update && opkg install git-http
  fi
  command -v git >/dev/null 2>&1 || die "could not install git, install it by hand and run this again"
fi

# --- 2. homeshick and the castle
say "homeshick and the dotfiles"
[ -f "$REPOS/homeshick/homeshick.sh" ] || git clone -q https://github.com/andsens/homeshick.git "$REPOS/homeshick" ||
  die "could not fetch homeshick"
# shellcheck disable=SC1091
. "$REPOS/homeshick/homeshick.sh"
# started from a checkout (not through curl): take that one, so a local state can be tried before it is pushed.
# "curl | bash" has no script file: ${BASH_SOURCE[0]} stopped the deploy under set -u, and an empty name would make
# the current folder the checkout (28.10.26)
src=
[ -z "${BASH_SOURCE[0]:-}" ] || src=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)
if [ -n "$src" ] && [ -r "$src/home/.dot/lib/detect.sh" ] && git -C "$src" rev-parse --git-dir >/dev/null 2>&1 &&
   [ "$src" != "$REPOS/dotfiles" ]; then
  say "using the checkout $src ($(git -C "$src" log -1 --format='%h %s' | cut -c1-60))"
  if [ -d "$REPOS/dotfiles/.git" ]; then
    git -C "$REPOS/dotfiles" pull -q "$src" "$(git -C "$src" rev-parse --abbrev-ref HEAD)" || die "could not update the castle"
  else
    # --no-hardlinks: Cygwin's git stops a local clone of a checkout made by Git for Windows with "hardlink different
    # from source" (28.10.26)
    git clone -q --no-hardlinks "$src" "$REPOS/dotfiles" || die "could not copy the checkout"
  fi
else
  homeshick clone --batch "$CASTLE" >/dev/null 2>&1 || [ -d "$REPOS/dotfiles" ] || die "could not fetch $CASTLE"
  # a failed pull went unnoticed and the old state was linked (28.10.26); homeshick prints what git says
  homeshick pull --batch dotfiles >/dev/null ||
    die "could not update ~/.homesick/repos/dotfiles: files changed there? git -C $REPOS/dotfiles status lists them"
fi

# --- 3. can links be made here? Cygwin, Git Bash, MSYS2: native Windows symlinks, which need Developer Mode or an
# administrator; nativestrict makes ln fail instead of copying the files. Tried before anything of yours moves.
case $(uname -s) in
  CYGWIN*) export CYGWIN="winsymlinks:nativestrict ${CYGWIN:-}" ;;
  MINGW*|MSYS*) export MSYS="winsymlinks:nativestrict ${MSYS:-}" ;;
esac
hint=
[ -z "$win" ] || hint=": Windows makes symlinks only in Developer Mode (Settings, For developers) or as administrator"
probe=$HOME/.dotfiles-linktest.$$
err=$({ mkdir "$probe" && ln -s "$REPOS/dotfiles/home/.bashrc" "$probe/link"; } 2>&1) ||
  { rm -rf "$probe"; die "cannot create links in $HOME ($err)$hint. Your files are unchanged."; }
rm -rf "$probe"

# --- 4. back up what would be replaced
# link --force replaced every target of home/, not only .bashrc and .profile: a file of your own in ~/.dot was lost
# (28.10.26). Every target that is not already the castle's file moves to the backup with its relative path;
# .bash_profile and .bash_login are not in the castle, but would hide ~/.profile from bash.
backup=$HOME/.dotfiles-backup/$(date +%Y-%m-%d_%H%M%S)
new=() moved=()
# a link that failed half way left ~/.bashrc and ~/.profile in the backup and no links in their place
# (28.10.26). fail <reason> removes the links this run made, with folders left empty, puts the saved files back
# and stops.
fail() {
  local f d left=
  for f in ${new[@]+"${new[@]}"}; do
    [ -L "$HOME/$f" ] && [[ $(readlink "$HOME/$f") == *.homesick/repos/dotfiles/home/* ]] || continue
    rm -f "$HOME/$f"
    d=$f; while [[ $d == */* ]]; do d=${d%/*}; rmdir "$HOME/$d" 2>/dev/null || break; done
  done
  for f in ${moved[@]+"${moved[@]}"}; do
    mkdir -p "$(dirname "$HOME/$f")" && mv "$backup/$f" "$HOME/$f" ||
      { echo "  could not put back ~/$f, it is in $backup/$f" >&2; left=1; }
  done
  [ ! -d "$backup" ] || find "$backup" -depth -type d -empty -delete 2>/dev/null
  rmdir "$HOME/.dotfiles-backup" 2>/dev/null
  [ -n "$left" ] && die "$1: nothing is linked, put back by hand what is listed above"
  die "$1: your files are back in place, nothing is linked"
}
while IFS= read -r f; do
  t=$HOME/$f
  # -ef: the same file, through any link, so an existing install (or ~/.dot linked as a whole) is left alone
  [ "$t" -ef "$REPOS/dotfiles/home/$f" ] && continue
  [ ! -e "$REPOS/dotfiles/home/$f" ] || new+=("$f")
  # a read-only folder let Cygwin move a file out, but not back, and homeshick link fails there (28.10.26)
  [ ! -d "${t%/*}" ] || [ -w "${t%/*}" ] || fail "the folder ${t%/*} is read-only"
  [ -e "$t" ] || [ -L "$t" ] || continue
  if mkdir -p "$(dirname "$backup/$f")" && mv "$t" "$backup/$f"; then
    moved+=("$f"); echo "  saved ~/$f to ${backup/#$HOME/\~}/$f"
  else
    fail "could not back up ~/$f"
  fi
done < <(git -C "$REPOS/dotfiles" ls-files home/ | sed 's|^home/||'; printf '%s\n' .bash_profile .bash_login)

# --- 5. link and set up
say "linking the files into $HOME"
# update.sh --links: homeshick link, and the links of files the dotfiles no longer have go (a run over an older
# install). homeshick link once: on Windows it takes 2 minutes for the 257 files, the deploy ran it twice (28.10.26).
# No --force: after the backup nothing of yours is in the way.
bash "$REPOS/dotfiles/home/.dot/update.sh" --links || fail "linking failed"
# homeshick link reports success also when ln fails (no symlink right, a read-only folder): check each link
for f in ${new[@]+"${new[@]}"}; do
  [ "$HOME/$f" -ef "$REPOS/dotfiles/home/$f" ] || fail "could not link ~/$f (is its folder writable?)"
done
[ -d "$backup" ] && echo "  your previous files are in ${backup/#$HOME/\~}/"

# asks for git identity, editor and MOTD once and offers the installer menu; quiet without a terminal
bash "$HOME/.dot/setup.sh" --first

# a new login shell only on a terminal: without one, exec bash -l ran the rest of stdin as commands
# (echo cmd | bash deploy_headless.sh ran cmd) and ended with its status (28.10.26)
if [ -t 0 ] && [ -t 1 ]; then
  say "done: a new login shell starts now"
  exec bash -l
fi
say "done: the dotfiles load in the next login shell"
exit 0
