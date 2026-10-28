#!/bin/bash
# Cygwin, Git Bash and MSYS2 (DIST cygwin or msys): .bashrc loads this after the base files.

# open a file, folder or URL with its Windows program; o from .bash_functions.sh uses it (no argument: this folder)
if [ "$DIST" = cygwin ]; then
  open() { cygstart "$@"; }
else
  # Git Bash has no cygstart; start runs cmd's start, whose first quoted argument is the window title
  open() { start "" "$@"; }
fi

# clipboard like on macOS: echo hi | pbcopy, pbpaste > file
# Git Bash (MSYS 3.6.10) empties the clipboard on a write to /dev/clipboard (27.10.26); clip.exe takes UTF-16LE
# without codepage damage to umlauts
if [ "$DIST" = cygwin ]; then
  alias pbcopy='cat >/dev/clipboard'
else
  alias pbcopy='iconv -f UTF-8 -t UTF-16LE | clip.exe'
fi
alias pbpaste='cat /dev/clipboard'

# path conversion: winpath ~/file -> C:\..., unixpath 'C:\Users' -> /cygdrive/c/Users or /c/Users
alias winpath='cygpath -w'
alias unixpath='cygpath -u'
