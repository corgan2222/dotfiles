#!/bin/bash
# Setup after the first deploy: asks once for what the installed tools need and what is not set yet, explains each
# question with an example, and offers the installer menu at the end. Safe to run again; it never overwrites a value
# that is already set. Personal values go to ~/.extra (0600, not in the repo), which .bashrc loads; git settings go
# to ~/.gitconfig through git config --global.
#   setup.sh           ask for every missing value (needs a terminal)
#   setup.sh --check   only list what is missing, ask nothing
#   setup.sh --first   after the deploy: like --auto, and offers the installer menu at the end
#   setup.sh --auto    after the installer menu: asks only for what is missing, quiet when nothing is, silent without
#                      a terminal, never offers the menu again
#   setup.sh --motd    show the login screen (MOTD) again and ask whether it stays on
set -u
mode=${1:-}
extra=$HOME/.extra
missing=0
intro=

say() { printf '\n\033[96m%s\033[0m\n' "$*"; }
# explains a question in grey, before it is asked
explain() { printf '\033[90m  %s\033[0m\n' "$@"; }
# ask <question> [default]: prints the answer, the default on an empty one
ask() {
  local a
  read -r -p "  $1${2:+ [$2]}: " a </dev/tty
  printf '%s' "${a:-${2:-}}"
}
# yes_no <question>: default yes
yes_no() { case $(ask "$1 (Y/n)") in [nN]*) return 1 ;; esac; }
# todo <text>: a missing value; true when we may ask for it now
todo() {
  missing=$((missing + 1))
  [ "$mode" = --check ] && { echo "missing: $1"; return 1; }
  if [ -z "$intro" ]; then
    intro=1
    printf '\n\033[1mSetup of the dotfiles\033[0m: a few questions, each with an example. Enter takes the value in\n'
    printf '[brackets]. Change them later with ~/.dot/setup.sh, see what is still open with ~/.dot/setup.sh --check.\n'
  fi
  return 0
}
# extra_set NAME value: export line in ~/.extra, replaces an earlier one
# umask for all of it: .extra.new was 0644 until the mv, with the secrets of .extra in it (28.10.26, review)
extra_set() {
  (
    umask 077
    touch "$extra"
    # a leftover keeps its mode on ">"
    rm -f "$extra.new"
    grep -v "^export $1=" "$extra" > "$extra.new"; printf 'export %s=%q\n' "$1" "$2" >> "$extra.new"
    mv "$extra.new" "$extra"
  )
}

# a question left empty or answered no is noted in ~/.extra (DOT_SKIP_<key>=1): --auto, which runs after every
# installer menu, does not ask it again; setup.sh by hand and --check still do (28.10.26: the git name, left empty
# after the deploy, came back after the next installer run)
skipped() { [ "$mode" = --auto ] && grep -qs "^export DOT_SKIP_$1=" "$extra"; }
skip() { extra_set "DOT_SKIP_$1" 1; }

first=
[ "$mode" = --first ] && { first=1; mode=--auto; }
if [ "$mode" != --check ] && ! { : </dev/tty; } 2>/dev/null; then
  [ "$mode" = --auto ] || echo "setup.sh needs a terminal; run it again in an interactive shell: ~/.dot/setup.sh" >&2
  exit 0
fi

# --- git: identity and defaults, only when git is there
if command -v git >/dev/null; then
  if [ -z "$(git config --global user.name)" ] && ! skipped GIT_NAME && todo "git user.name"; then
    say "git: who you are"
    explain "git writes your name and e-mail into every commit you make, others see them in the history." \
            "Saved in ~/.gitconfig. Use the same ones as on GitHub or GitLab, so commits show up as yours." \
            "Empty: skip, ask again only with ~/.dot/setup.sh"
    v=$(ask "your name, e.g. Erika Mustermann")
    if [ -n "$v" ]; then git config --global user.name "$v"; else skip GIT_NAME; fi
  fi
  if [ -z "$(git config --global user.email)" ] && ! skipped GIT_EMAIL && todo "git user.email"; then
    v=$(ask "your e-mail, e.g. erika@example.org")
    if [ -n "$v" ]; then git config --global user.email "$v"; else skip GIT_EMAIL; fi
  fi
  # delta as pager, only when the delta installer put it there and no pager is chosen yet
  if command -v delta >/dev/null && [ -z "$(git config --global core.pager)" ] && ! skipped DELTA &&
     todo "git pager delta"; then
    say "git: diffs with delta"
    explain "delta shows git diff, git log -p and git show with syntax colours and line numbers." \
            "Without it git uses the plain pager less. Undo: git config --global --unset core.pager"
    if yes_no "use delta for git"; then
      git config --global core.pager delta
      git config --global interactive.diffFilter 'delta --color-only'
      git config --global delta.navigate true
      # zdiff3 needs git 2.35 (Debian 12, Ubuntu 22.04 and older ship less)
      v=$(git version | awk '{print $3}')
      if printf '%s\n' 2.35 "$v" | sort -V -C; then git config --global merge.conflictStyle zdiff3
      else git config --global merge.conflictStyle diff3; fi
    else
      skip DELTA
    fi
  fi
fi

# --- editor: .exports takes joe, else nano, vim or vi; asked only when none of them is there
if [ -z "${DOT_EDITOR_SET:-}" ] && ! command -v "${EDITOR:-joe}" >/dev/null && todo "EDITOR (${EDITOR:-joe} is not installed)"; then
  eds=$(for e in nano vim vi micro joe emacs; do command -v "$e" >/dev/null && printf '%s ' "$e"; done)
  if [ -n "$eds" ]; then
    say "editor"
    explain "git (commit messages), crontab -e, sudoedit and many other tools open this editor." \
            "nano is the easiest to start with (save Ctrl+O, quit Ctrl+X)."
    v=$(ask "editor, installed here: $eds" "${eds%% *}")
    extra_set EDITOR "$v"; extra_set VISUAL "$v"; extra_set DOT_EDITOR_SET 1
  fi
fi

# --- MOTD: shown once here, then the choice goes to ~/.extra as DOT_MOTD (special systems have their own, every
# other Linux the general one, ~/.dot/motd.sh)
if { [ "$mode" = --motd ] || ! grep -qs '^export DOT_MOTD=' "$extra"; } && todo "MOTD on or off"; then
  say "login screen (MOTD)"
  explain "At every login the shell can show a short overview of this machine: system, uptime, load, memory," \
          "disks and IP addresses. This is how it looks here:"
  DOT_MOTD=1 TERM=${TERM:-xterm} bash -lic exit </dev/tty 2>/dev/null
  explain "Change it later with: ~/.dot/setup.sh --motd"
  if yes_no "show it at every login"; then extra_set DOT_MOTD 1; else extra_set DOT_MOTD 0; fi
fi

if [ "$mode" = --check ]; then
  [ $missing -eq 0 ] && echo "nothing missing"
  exit 0
fi
[ $missing -gt 0 ] && say "setup done; a new shell picks up the settings (or now: source ~/.extra)"

# --- installer menu: offered after the deploy (--first) and when setup.sh runs by hand, never when the menu itself
# called it (--auto)
if [ -n "$first" ] || [ "$mode" != --auto ]; then
  say "installer menu"
  explain "Installs tools and services that fit this system: basics (git, curl, htop, bat, eza, ...), Docker," \
          "Grafana, Loki, Zabbix, VPNs and more, natively or in Docker. Start it any time with: installer" \
          "(or: bash ~/.dot/installer/installer.sh)"
  if yes_no "start the installer menu now"; then
    DOT_FROM_SETUP=1 bash "$HOME/.dot/installer/installer.sh" </dev/tty
  fi
fi
exit 0
