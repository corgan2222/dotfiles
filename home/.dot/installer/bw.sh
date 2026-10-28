#!/bin/bash
# installer: Bitwarden CLI (bw), stores the passwords of the installers in your vault
# systems: all
# Installs or updates bw (Bitwarden's release binary for amd64 and arm64, sha256 checked, into ~/.local/bin; npm on
# other architectures) and walks through the setup: server (bitwarden.com, bitwarden.eu or your own URL), login,
# unlock. The installer menu then asks at its start to unlock the vault and stores every summary there as a note
# "<host> <service>" in the folder dotfiles. Safe to run again.
#   bw.sh                                   install, then set up (needs a terminal)
#   bw.sh --install                         install or update only
#   BW_SERVER=https://vault.example.org     your own server (Vaultwarden, self-hosted), also as export in ~/.extra
# In a shell: export BW_SESSION=$(bw unlock --raw), then installers started by hand store their summaries too.
# sysop, not base: base installers are preselected on the first run, so the setup came up beside the menu's own
# Bitwarden question, and leaving it showed "failed: bw" (28.10.26, Raspberry Pi)
# category: sysop
# check: bw
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
. "$(dirname "$(readlink -f "$0")")/../lib/bw.sh"
export PATH="$HOME/.local/bin:$PATH"

dot_need curl jq
dot_bw_install || dot_die "could not install bw"
bw --version
[ "${1:-}" = --install ] && exit 0
{ : </dev/tty; } 2>/dev/null || { dot_info "no terminal: set it up later with bw.sh in an interactive shell"; exit 0; }

# set up by hand: the installer menu asks again
[ -f ~/.extra ] && sed -i '/^export DOT_SKIP_BW=/d' ~/.extra
# giving up the setup is an answer, not an error: bw stays installed
dot_bw_setup || { dot_info "Bitwarden is not set up; run bw.sh again when you want it"; exit 0; }
dot_info "server: $(bw status | jq -r '.serverUrl // "https://vault.bitwarden.com"'); the installer menu asks to unlock at its start"
