#!/bin/bash
# Updates installed dotfiles in place: pulls the castle, links its new files, removes the links of files it no longer
# has (and folders left empty by that), then asks the setup questions of what is new. Safe to run again.
#   dotupdate               the function in .bash_functions.sh: this script, then a new login shell
#   ~/.dot/update.sh        pull, link, clean up, setup
#   ~/.dot/update.sh --links    link and clean up only (deploy_headless.sh after its own pull)
# Leftovers: every file deleted from home/ in the castle's history whose link in your home now points nowhere. Only
# links into the castle are removed, files of your own stay. Updating an install from before this script (28.10.26):
# loadHome or "homeshick pull dotfiles && homeshick link dotfiles" once, then dotupdate.
set -u
castle=$HOME/.homesick/repos/dotfiles
say() { printf '\033[96m==> %s\033[0m\n' "$*"; }
die() { printf '\033[91merror: %s\033[0m\n' "$*" >&2; exit 1; }
[ -d "$castle/.git" ] || die "no dotfiles in $castle: install them with deploy_headless.sh"
[ -r "$HOME/.homesick/repos/homeshick/homeshick.sh" ] || die "homeshick is missing in ~/.homesick/repos/homeshick"

if [ "${1:-}" != --links ]; then
  # files changed by hand in the castle (they are the ones in your home) would make the pull fail half way
  if [ -n "$(git -C "$castle" status --porcelain --untracked-files=no)" ]; then
    git -C "$castle" status --short --untracked-files=no >&2
    die "these files of the dotfiles are changed here: commit them (saveHome) or undo them (git -C $castle checkout -- <file>), then run dotupdate again"
  fi
  old=$(git -C "$castle" rev-parse HEAD)
  say "fetching the dotfiles"
  git -C "$castle" pull -q --ff-only || die "git pull failed in $castle (see above)"
  new=$(git -C "$castle" rev-parse HEAD)
  if [ "$old" = "$new" ]; then
    say "already up to date ($(git -C "$castle" log -1 --format='%h %s' | cut -c1-70))"
  else
    say "$(git -C "$castle" rev-list --count "$old..$new") new commits, the latest:"
    git -C "$castle" log --format='  %h %s' "$old..$new" | head -n 10 | cut -c1-100
  fi
fi

# new files: homeshick link without questions; a file of your own in the way stays and is reported
case $(uname -s) in
  CYGWIN*) export CYGWIN="winsymlinks:nativestrict ${CYGWIN:-}" ;;
  MINGW*|MSYS*) export MSYS="winsymlinks:nativestrict ${MSYS:-}" ;;
esac
# homeshick link takes about 2 minutes on Windows for 257 files (28.10.26): it runs only when a file of the castle is
# not in the home yet, as a link or inside a linked folder
missing=
while IFS= read -r p; do
  [ -e "$HOME/${p#home/}" ] || [ -L "$HOME/${p#home/}" ] || { missing=$p; break; }
done < <(git -C "$castle" -c core.quotepath=off ls-files home/)
if [ -n "$missing" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.homesick/repos/homeshick/homeshick.sh"
  out=$(homeshick link --batch dotfiles 2>&1) || die "homeshick link failed: $out"
  kept=$(sed 's/\x1b\[[0-9;]*m//g' <<<"$out" | grep -c 'BATCH - No')
  [ "${kept:-0}" -eq 0 ] || say "$kept files of your own are in the way of new dotfiles and stay (homeshick link dotfiles asks for each)"
fi

# leftovers of files the castle deleted; a path deleted and added again exists, so its link is not dead.
# --no-renames: git log detects renames by default and lists a renamed file as R with its new name only, so the link
# of the old name stayed (28.10.26)
n=0
while IFS= read -r p; do
  f=$HOME/${p#home/}
  [ -L "$f" ] && [ ! -e "$f" ] || continue
  case $(readlink "$f") in *.homesick/repos/dotfiles/home/*) ;; *) continue ;; esac
  rm -f "$f" && n=$((n + 1))
  # folders that only held such links, up to the home folder
  d=${f%/*}
  while [ "$d" != "$HOME" ] && [ "${d#"$HOME"/}" != "$d" ] && rmdir "$d" 2>/dev/null; do d=${d%/*}; done
done < <(git -C "$castle" log --no-renames --name-only --format= --diff-filter=D -- home/ | sort -u)
[ $n -eq 0 ] || say "removed $n links to files the dotfiles no longer have"

[ "${1:-}" = --links ] || bash "$HOME/.dot/setup.sh" --auto
exit 0
