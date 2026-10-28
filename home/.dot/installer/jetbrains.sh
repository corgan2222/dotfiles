#!/bin/bash
# installer: JetBrains IDE (PyCharm, IDEA, PhpStorm, ...) or Toolbox App
# systems: desktop amd64 arm64
# Installs the latest release of a JetBrains IDE into /opt/jetbrains/<product>, checked against JetBrains' sha256,
# links the launcher into /usr/local/bin and adds a menu entry. Safe to run again: updates when a newer release exists.
#   jetbrains.sh                    numbered choice
#   jetbrains.sh pycharm            install PyCharm (pycharm-pro is the same unified PyCharm)
#   jetbrains.sh --dry-run goland   only resolve download URL and checksum
#   jetbrains.sh --list             print the products
# category: desktop
# check: /opt/jetbrains
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

# product, JetBrains product code, launcher in bin/, menu name.
# PyCharm Community and IntelliJ IDEA Community ended with 2025.3, both are now one free-to-start product (PCP, IIU)
PRODUCTS='
pycharm   PCP pycharm           PyCharm
phpstorm  PS  phpstorm          PhpStorm
rubymine  RM  rubymine          RubyMine
idea      IIU idea              IntelliJ IDEA
webstorm  WS  webstorm          WebStorm
goland    GO  goland            GoLand
clion     CL  clion             CLion
rider     RD  rider             Rider
datagrip  DG  datagrip          DataGrip
toolbox   TBA jetbrains-toolbox JetBrains Toolbox
'

# prints the field $2 (1-based) of the PRODUCTS line of product $1
jb_field() { awk -v p="$1" -v f="$2" '$1 == p { if (f < 4) print $f; else { $1 = $2 = $3 = ""; sub(/^ +/, ""); print } }' <<<"$PRODUCTS"; }

dry=
case ${1:-} in
  -h|--help) sed -n '4,9s/^# \{0,1\}//p' "$0"; exit 0 ;;
  --list) awk 'NF { print $1 }' <<<"$PRODUCTS"; exit 0 ;;
  --dry-run) dry=1; shift ;;
esac

product=${1:-}
[ "$product" = pycharm-pro ] && product=pycharm
if [ -z "$product" ]; then
  [ -t 0 ] || dot_die "no product given, choose one of: $(awk 'NF { printf "%s ", $1 }' <<<"$PRODUCTS")"
  PS3="Install which JetBrains product? "
  select product in $(awk 'NF { print $1 }' <<<"$PRODUCTS"); do break; done
  product=${product:-$REPLY}
fi
code=$(jb_field "$product" 2)
[ -n "$code" ] || dot_die "unknown product '$product', choose one of: $(awk 'NF { printf "%s ", $1 }' <<<"$PRODUCTS")"
launcher=$(jb_field "$product" 3) name=$(jb_field "$product" 4)

case $DOT_ARCH in
  amd64) dl=linux ;;
  arm64) dl=linuxARM64 ;;
  *) dot_die "JetBrains ships no Linux build for $DOT_ARCH" ;;
esac

dot_need curl jq tar
release=$(curl -fsSL "https://data.services.jetbrains.com/products/releases?code=$code&latest=true&type=release") ||
  dot_die "could not ask JetBrains for the latest $name release (no network?)"
version=$(jq -r --arg c "$code" '.[$c][0].version // empty' <<<"$release")
url=$(jq -r --arg c "$code" --arg d "$dl" '.[$c][0].downloads[$d].link // empty' <<<"$release")
sumurl=$(jq -r --arg c "$code" --arg d "$dl" '.[$c][0].downloads[$d].checksumLink // empty' <<<"$release")
[ -n "$url" ] && [ -n "$sumurl" ] || dot_die "JetBrains lists no $dl download for $name"
sum=$(curl -fsSL "$sumurl" | awk '{ print $1 }')
[[ $sum =~ ^[0-9a-f]{64}$ ]] || dot_die "could not read the checksum $sumurl"

if [ -n "$dry" ]; then
  echo "$name $version ($code, $DOT_ARCH)"
  echo "url:    $url"
  echo "sha256: $sum"
  exit 0
fi

dest=/opt/jetbrains/$product
if [ "$(cat "$dest/.dot-version" 2>/dev/null)" = "$version" ]; then
  dot_info "$name $version is already installed in $dest"
  exit 0
fi

# the archives are 1-2 GB: /var/tmp is on disk, /tmp may be a small tmpfs
tmp=$(mktemp -d -p "${TMPDIR:-/var/tmp}") && trap 'rm -rf "$tmp"; dot_sudo rm -rf "$dest.new"' EXIT
dot_info "Downloading $name $version"
curl -fL --progress-bar -o "$tmp/ide.tar.gz" "$url" || dot_die "download of $url failed"
echo "$sum  $tmp/ide.tar.gz" | sha256sum -c --quiet || dot_die "checksum of $url does not match, aborting"

dot_sudo rm -rf "$dest.new" && dot_sudo mkdir -p "$dest.new" &&
  dot_sudo tar -xzf "$tmp/ide.tar.gz" -C "$dest.new" --strip-components=1 --no-same-owner ||
  dot_die "could not unpack $name into $dest.new"
rm -f "$tmp/ide.tar.gz"
exe=$(cd "$dest.new" && for f in "bin/$launcher" "$launcher" "bin/$launcher.sh"; do [ -x "$f" ] && { echo "$f"; break; }; done)
[ -n "$exe" ] || dot_die "no launcher $launcher in the $name archive"
echo "$version" | dot_sudo tee "$dest.new/.dot-version" >/dev/null
dot_sudo rm -rf "$dest" && dot_sudo mv "$dest.new" "$dest" || dot_die "could not move $name to $dest"
dot_sudo ln -sfn "$dest/$exe" "/usr/local/bin/$launcher"

icon=
for f in "$dest/bin/$launcher.svg" "$dest/bin/$launcher.png" "$dest"/*.svg "$dest"/*.png; do [ -f "$f" ] && { icon=$f; break; }; done
case $launcher in jetbrains-*) wmclass=$launcher ;; *) wmclass=jetbrains-$launcher ;; esac
dot_sudo tee "/usr/share/applications/jetbrains-$product.desktop" >/dev/null <<EOF
[Desktop Entry]
Type=Application
Name=$name
Exec=/usr/local/bin/$launcher %f
Icon=${icon:-$dest/bin/$launcher.svg}
Categories=Development;IDE;
Terminal=false
StartupWMClass=$wmclass
EOF
dot_info "$name $version installed in $dest, start it with: $launcher"
