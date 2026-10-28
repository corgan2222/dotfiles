#!/bin/bash

# bootstrap script to install Homeshick and you preferred castles to a new
# system.

tmpfilename="/tmp/${0##*/}.XXXXX"

if type mktemp >/dev/null; then
  tmpfile=$(mktemp $tmpfilename)
else
  tmpfile=$(echo $tmpfilename | sed "s/XX*/$RANDOM/")
fi

trap 'rm -f "$tmpfile"' EXIT

cat <<'EOF' > $tmpfile
# Which Homeshick castles do you want to install?
#
# Each line is passed as the argument(s) to `homeshick clone`.
# Lines starting with '#' will be ignored.
#
# If you remove or comment a line that castle will NOT be installed.
# However, if you remove or comment everything, the script will be aborted.

# Plugin management
corgan2222/dotfiles

# Private castles (commented by default)
#sukima/muttrc
#secret@example.org:securerc.git
EOF

if command -v joe >/dev/null; then
  ${VISUAL:-joe} $tmpfile
else  
  ${VISUAL:-nano} $tmpfile
fi  


code=$?

if [[ $code -ne 0 ]]; then
  echo "Editor returned ${code}." 1>&2
  exit 1
fi

castles=()

while read line; do
  castle=$(echo "$line" | sed '/^[ \t]*#/d;s/^[ \t]*\(.*\)[ \t]*$/\1/')
  if [[ -n $castle ]]; then
    castles+=("$castle")
  fi
done <$tmpfile

if [[ ${#castles[@]} -eq 0 ]]; then
  echo "No castles to install. Aborting."
  exit 0
fi

command -v git >/dev/null || { echo "git is missing: install it and run this again" >&2; exit 1; }
if [[ ! -f $HOME/.homesick/repos/homeshick/homeshick.sh ]]; then
  git clone https://github.com/andsens/homeshick.git $HOME/.homesick/repos/homeshick || exit 1
fi

source $HOME/.homesick/repos/homeshick/homeshick.sh
# Cygwin, Git Bash, MSYS2: native Windows symlinks (Developer Mode or administrator); Git Bash copied the files
# without this, so later updates of the castle never reached the home folder (28.10.26)
case $(uname -s) in
  CYGWIN*) export CYGWIN="winsymlinks:nativestrict ${CYGWIN:-}" ;;
  MINGW*|MSYS*) export MSYS="winsymlinks:nativestrict ${MSYS:-}" ;;
esac

# homeshick clone links after a question, and a "yes" replaced own files without a copy (28.10.26). Every target
# that is not already the castle's file moves to ~/.dotfiles-backup/<date>/ with its relative path, then the castle
# is linked; with a .profile in the castle also ~/.bash_profile and ~/.bash_login, which would hide it from bash.
backup=$HOME/.dotfiles-backup/$(date +%Y-%m-%d_%H%M%S)
# Windows makes symlinks only in Developer Mode or as administrator: without, nothing may move (28.10.26)
probe=$HOME/.dotfiles-linktest.$$
err=$({ mkdir "$probe" && ln -s "$HOME/.homesick/repos/homeshick/homeshick.sh" "$probe/link"; } 2>&1) ||
  { rm -rf "$probe"; echo "cannot create links in $HOME ($err); on Windows turn on Developer Mode (Settings, For" \
    "developers) or run as administrator. Your files are unchanged." >&2; exit 1; }
rm -rf "$probe"
failed=0
link_castle() {
  local repo=$HOME/.homesick/repos/$1 f t bad=0 moved=() new=()
  while IFS= read -r f; do
    t=$HOME/$f
    [ "$t" -ef "$repo/home/$f" ] && continue
    [ ! -e "$repo/home/$f" ] || new+=("$f")
    [ -e "$t" ] || [ -L "$t" ] || continue
    if mkdir -p "$(dirname "$backup/$f")" && mv "$t" "$backup/$f"; then
      moved+=("$f"); echo "  saved ~/$f to ${backup/#$HOME/\~}/$f"
    else
      echo "could not back up ~/$f, $1 is not linked" >&2; bad=1; break
    fi
  done < <(git -C "$repo" ls-files home/ | sed 's|^home/||'
           [ -f "$repo/home/.profile" ] && printf '%s\n' .bash_profile .bash_login)
  [ $bad = 1 ] || homeshick link --batch --force "$1"
  # homeshick link reports success also when ln fails (a read-only folder, no symlink right, 28.10.26): check each
  # link; on a gap the new links go and the saved files come back, as in deploy_headless.sh
  for f in ${new[@]+"${new[@]}"}; do
    [ "$HOME/$f" -ef "$repo/home/$f" ] || { echo "  not linked: ~/$f" >&2; bad=1; }
  done
  [ $bad = 1 ] || return 0
  for f in ${new[@]+"${new[@]}"}; do
    [ -L "$HOME/$f" ] && [[ $(readlink "$HOME/$f") == *.homesick/repos/$1/home/* ]] && rm -f "$HOME/$f"
  done
  for f in ${moved[@]+"${moved[@]}"}; do
    mv "$backup/$f" "$HOME/$f" || echo "  could not put back ~/$f, it is in $backup/$f" >&2
  done
  echo "$1 is not linked, your files are back in place" >&2
  return 1
}

for castle in "${castles[@]}"; do
  # the folder homeshick clones into: the last part of the url without .git
  name=${castle%.git}; name=${name##*[/:]}
  # git clone, not homeshick clone: in batch mode that links every file not yet in the home right away, before the
  # backup and out of reach of the roll back (28.10.26). user/repo is GitHub's short form, as in homeshick.
  url=$castle
  [[ $url =~ ^[^/:@]+/[^/:@]+$ ]] && url=https://github.com/$url.git
  if [ ! -d "$HOME/.homesick/repos/$name" ]; then
    git clone -q --recursive "$url" "$HOME/.homesick/repos/$name" || { failed=1; continue; }
  fi
  link_castle "$name" || failed=1
done
[ ! -d "$backup" ] || find "$backup" -depth -type d -empty -delete 2>/dev/null
[ ! -d "$backup" ] || echo "your previous files are in ${backup/#$HOME/\~}/"
[ $failed = 0 ] || exit 1

# asks for git identity and the like once, only on a terminal
[ ! -r "$HOME/.dot/setup.sh" ] || bash "$HOME/.dot/setup.sh" --first
