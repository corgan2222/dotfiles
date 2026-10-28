#!/bin/bash
# installer: Claude Code, Anthropic's coding agent for the terminal
# systems: amd64 arm64
# Installs the native Claude Code build, the way Anthropic's install script does it but without piping that script
# into a shell, and with one check more: the release manifest must carry a valid signature of Anthropic's release
# signing key (fingerprint pinned below), the binary must match the manifest's sha256. "claude install" then sets up
# ~/.local/bin/claude (a link into ~/.local/share/claude/versions) and keeps it updated. No Node.js needed.
# Never asks for or stores API keys. Safe to run again: does nothing when that version is installed already.
#   claude-code.sh            latest release
#   claude-code.sh stable     stable channel (about a week behind, skips releases with major regressions)
#   claude-code.sh 2.1.300    this version
# category: dev
# check: claude
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
export PATH="$HOME/.local/bin:$PATH"

base=https://downloads.claude.ai/claude-code-releases
key_url=https://downloads.claude.ai/keys/claude-code.asc
# "Anthropic Claude Code Release Signing <security@anthropic.com>", published in the Claude Code setup docs
fpr=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE

want=${1:-latest}
[[ $want =~ ^(stable|latest|[0-9]+\.[0-9]+\.[0-9]+)$ ]] || dot_die "usage: claude-code.sh [stable|latest|<version>]"

case $DOT_ARCH in
  amd64) platform=linux-x64 ;;
  arm64) platform=linux-arm64 ;;
  *) dot_die "Claude Code has no build for architecture $DOT_ARCH" ;;
esac
# musl systems (Alpine) get the musl build and need its runtime libraries; the bundled ripgrep is glibc-only there
musl=
if [ -e "/lib/libc.musl-$(uname -m).so.1" ] || ldd /bin/ls 2>&1 | grep -q musl; then
  platform+=-musl musl=1
  dot_pkg_install libgcc libstdc++ ripgrep || dot_die "could not install libgcc, libstdc++ and ripgrep"
fi
dot_need curl gpg jq

version=$want
case $want in stable|latest) version=$(curl -fsSL "$base/$want") ;; esac
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]] ||
  dot_die "cannot read the Claude Code $want version from downloads.claude.ai (no network, or not offered in this region)"

if [[ $(claude --version 2>/dev/null) == "$version "* ]]; then
  dot_info "Claude Code $version is already installed"
else
  dot_info "Installing Claude Code $version ($platform)"
  tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
  # a throwaway keyring, the user's own GnuPG setup stays untouched
  export GNUPGHOME=$tmp/gnupg
  mkdir -m 700 "$GNUPGHOME"
  curl -fsSL -o "$tmp/key.asc" "$key_url" && curl -fsSL -o "$tmp/manifest.json" "$base/$version/manifest.json" &&
    curl -fsSL -o "$tmp/manifest.json.sig" "$base/$version/manifest.json.sig" || dot_die "download of the release manifest failed"
  gpg --batch --quiet --import "$tmp/key.asc" 2>/dev/null || dot_die "could not import the Claude Code signing key"
  # VALIDSIG ends with the fingerprint of the primary key: only a good signature of exactly this key counts
  gpg --batch --status-fd 1 --verify "$tmp/manifest.json.sig" "$tmp/manifest.json" 2>/dev/null |
    awk -v f="$fpr" '$2 == "VALIDSIG" && $NF == f { ok = 1 } END { exit !ok }' ||
    dot_die "the Claude Code $version manifest has no valid signature of key $fpr, aborting"
  sum=$(jq -r --arg p "$platform" '.platforms[$p].checksum // empty' "$tmp/manifest.json")
  size=$(jq -r --arg p "$platform" '.platforms[$p].size // empty' "$tmp/manifest.json")
  [[ $sum =~ ^[0-9a-f]{64}$ ]] || dot_die "the manifest lists no $platform build"

  bin=$tmp/claude
  # the zstd download is a third of the size; whichever way, the unpacked binary must match the signed checksum
  if ! { command -v zstd >/dev/null 2>&1 && curl -fsSL "$base/$version/$platform/claude.zst" | zstd -dqc | head -c "$size" >"$bin" &&
         [ "$(sha256sum "$bin" | cut -d' ' -f1)" = "$sum" ]; }; then
    curl -fsSL -o "$bin" "$base/$version/$platform/claude" || dot_die "download of the Claude Code binary failed"
    [ "$(sha256sum "$bin" | cut -d' ' -f1)" = "$sum" ] || dot_die "checksum of the Claude Code binary does not match, aborting"
  fi
  chmod 755 "$bin"
  # sets up the launcher in ~/.local/bin and the version store; ~/.local/bin is on PATH above, so it has nothing to add
  "$bin" install "$want" </dev/null || dot_die "claude install failed"
fi

# Alpine: tell Claude Code to use the system ripgrep; only into a new settings file, an existing one is the user's
if [ -n "$musl" ]; then
  if [ ! -e ~/.claude/settings.json ]; then
    mkdir -p ~/.claude && printf '{\n  "env": {\n    "USE_BUILTIN_RIPGREP": "0"\n  }\n}\n' >~/.claude/settings.json
  elif ! grep -q USE_BUILTIN_RIPGREP ~/.claude/settings.json; then
    dot_info 'add  "env": { "USE_BUILTIN_RIPGREP": "0" }  to ~/.claude/settings.json (musl needs the system ripgrep)'
  fi
fi

claude --version || dot_die "claude is not runnable after the install"
dot_info "Log in: run 'claude' and follow the login flow (browser link; on a server copy the link and paste the code back)."
echo "  Needs a Claude Pro, Max, Team, Enterprise or Console account. Check the setup with: claude doctor"
