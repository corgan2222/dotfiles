#!/bin/bash
# installer: Garage S3 object storage, single node with a default bucket
# systems: debian arch fedora rhel amd64 arm64 armv7 armv6
# modes: native compose portainer
# Garage (garagehq.deuxfleurs.fr, AGPL-3.0) in single-node mode (no replication); vendor minimum 1 GB RAM.
#   native:    release binary in /usr/local/bin, systemd service garage under the system user garage
#   --docker / --portainer:   image dxflrs/garage:<version> as compose project or Portainer stack "garage"
# Garage creates an S3 key and a bucket at start; the key is taken from the environment or generated on the first run.
#   garage.sh                                   bucket "default", generated key
#   S3_BUCKET=backup garage.sh                  other bucket name (running again with another name adds that bucket)
#   S3_ACCESS_KEY=GK… S3_SECRET_KEY=… garage.sh own key (only on the first run, the key cannot change later)
#   GARAGE_S3_PORT=3900                         other S3 port (first run)
#   GARAGE_VERSION=v2.x.y GARAGE_SHA256=<sum>   another version than the one below; natively with the sha256 of the
#                                               binary for this architecture
#   --public / --local                          S3 API on all interfaces or this host only (first run; else asked,
#                                               default all); RPC and admin API always stay on localhost
# Everything lives in /opt/garage: garage.toml (RPC secret, admin token) and .env (S3 key), both 0600, meta/ and data/.
# Running again moves Garage to the version below (never back to an older one) and keeps config, key and data.
# No web console: use the garage CLI or any S3 client.
# Version: Garage publishes neither checksums nor signatures for its binaries, and its forge names a new release the
# day it is out. So the version and the sha256 of each binary are fixed below; the sums are those of the binaries in
# the official image dxflrs/garage:<version> on Docker Hub, the same file from a second source. Copying the binary
# out of the image instead would need Docker on every native host. Updating: read the release notes (a node cannot go
# back to an older version), take the sums of the new binaries from
# https://garagehq.deuxfleurs.fr/_releases/<version>/<target>/garage, compare them with /garage in the image of each
# platform, set version, sums and the image digest (docker buildx imagetools inspect dxflrs/garage:<version>).
# category: db
# ports: GARAGE_S3_PORT=3900
# check: garage.service
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"
dot_mode "$@"; set -- "${DOT_ARGS[@]}"
dot_bind 0.0.0.0

dest=/opt/garage
conf=$dest/garage.toml
envf=$dest/.env
bin=/usr/local/bin/garage
port=${GARAGE_S3_PORT:-3900}
dot_need curl openssl

# checked 28.10.26, see "Version" above; the image digest is that of the multi-platform index
pinned=v2.5.0
declare -A sums=(
  [x86_64-unknown-linux-musl]=2ff667286217cd73ebcb1c03af993822365000441dfe31a80cb64c5189a9dea8
  [aarch64-unknown-linux-musl]=69b6040cef428b993500c17dd0d0c1240acf2f3f667b9b05ceba4b9660db4e8c
  [armv6l-unknown-linux-musleabihf]=2967ddf0924402558cbc1474832e4c6f1ca3b09c4458be918b1669fb4df362c3
)
digest=sha256:677e5b758e4425a325b811c425c026bf35a4bf42f7ddbaa773de3f4fd779a5a5
version=${GARAGE_VERSION:-$pinned}
[[ $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || dot_die "GARAGE_VERSION must look like v2.5.0, got '$version'"
# true when version $1 is newer than $2
newer() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" = "$1" ]; }

# one installation per host: native and container would share /opt/garage with different owners
if [ "$DOT_MODE" = native ] && dot_sudo test -f "$dest/compose.yaml"; then
  dot_info "Garage runs in Docker here ($dest/compose.yaml), staying with compose (--portainer for a Portainer stack)"
  DOT_MODE=compose
fi
if [ "$DOT_MODE" = native ]; then
  case $DOT_ARCH in
    amd64) target=x86_64-unknown-linux-musl ;;
    arm64) target=aarch64-unknown-linux-musl ;;
    armv7|armv6) target=armv6l-unknown-linux-musleabihf ;;
    *) dot_die "Garage has no release binary for architecture $DOT_ARCH" ;;
  esac
  getent passwd garage >/dev/null ||
    dot_sudo useradd --system --home-dir "$dest" --no-create-home --shell /usr/sbin/nologin garage ||
    dot_die "could not create the user garage"
  owner=garage
else
  [ -f /etc/systemd/system/garage.service ] && dot_die "Garage runs natively here (garage.service): use --native"
  owner=root
fi
# /opt/garage belongs to root (the key file is root's), meta/ and data/ to the user that runs Garage
dot_sudo install -d -m 0750 -g "$owner" "$dest" && dot_sudo install -d -m 0750 -o "$owner" -g "$owner" "$dest/meta" "$dest/data" ||
  exit 1

# config with fresh secrets on the first run only; the RPC and admin ports stay on localhost (single node)
if ! dot_sudo test -f "$conf"; then
  dot_sudo install -m 0600 -o "$owner" -g "$owner" /dev/null "$conf" || exit 1
  dot_sudo tee "$conf" >/dev/null <<EOF
metadata_dir = "$dest/meta"
data_dir = "$dest/data"
db_engine = "sqlite"
replication_factor = 1

rpc_bind_addr = "127.0.0.1:3901"
rpc_public_addr = "127.0.0.1:3901"
rpc_secret = "$(openssl rand -hex 32)"

[s3_api]
s3_region = "garage"
api_bind_addr = "$([ "$DOT_MODE" = native ] && echo "$DOT_BIND:$port" || echo 0.0.0.0:3900)"

[admin]
api_bind_addr = "127.0.0.1:3903"
admin_token = "$(openssl rand -base64 32)"
metrics_token = "$(openssl rand -base64 32)"
EOF
  dot_info "wrote $conf"
else
  dot_info "keeping $conf"
fi

# the default key and bucket: the key is kept from an earlier run, the bucket follows S3_BUCKET
key= secret= bucket=
if dot_sudo test -f "$envf"; then
  key=$(dot_sudo sed -n 's/^GARAGE_DEFAULT_ACCESS_KEY=//p' "$envf")
  secret=$(dot_sudo sed -n 's/^GARAGE_DEFAULT_SECRET_KEY=//p' "$envf")
  bucket=$(dot_sudo sed -n 's/^GARAGE_DEFAULT_BUCKET=//p' "$envf")
fi
key=${key:-${S3_ACCESS_KEY:-GK$(openssl rand -hex 12)}}
secret=${secret:-${S3_SECRET_KEY:-$(openssl rand -hex 32)}}
bucket=${S3_BUCKET:-${bucket:-default}}
[[ $bucket =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]] || dot_die "invalid bucket name '$bucket' (3-63 of a-z 0-9 . -)"
printf 'GARAGE_DEFAULT_ACCESS_KEY=%s\nGARAGE_DEFAULT_SECRET_KEY=%s\nGARAGE_DEFAULT_BUCKET=%s\n' "$key" "$secret" "$bucket" |
  dot_sudo sh -c "umask 077; cat > '$envf.new'" && dot_sudo mv "$envf.new" "$envf" || dot_die "could not write $envf"

if [ "$DOT_MODE" = native ]; then
  have=$([ -x "$bin" ] && "$bin" --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
  if [ "$have" = "$version" ]; then
    dot_info "Garage $version is already installed"
  elif [ -n "$have" ] && newer "$have" "$version"; then
    echo "warning: Garage $have is newer than $version, keeping it (Garage cannot go back to an older version)" >&2
    version=$have
  else
    sum=${GARAGE_SHA256:-}
    [ "$version" = "$pinned" ] && sum=${sums[$target]}
    [ -n "$sum" ] || dot_die "no sha256 for Garage $version ($target): set GARAGE_SHA256, see the header of $0"
    tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
    dot_info "Downloading Garage $version ($target)"
    curl -fsSL -o "$tmp/garage" "https://garagehq.deuxfleurs.fr/_releases/$version/$target/garage" ||
      dot_die "download of Garage $version for $target failed"
    [ "$(sha256sum "$tmp/garage" | cut -d' ' -f1)" = "$sum" ] ||
      dot_die "checksum of Garage $version ($target) does not match, aborting"
    chmod +x "$tmp/garage" && "$tmp/garage" --version >/dev/null || dot_die "the downloaded binary does not run here"
    dot_sudo install -m 0755 "$tmp/garage" "$bin" || exit 1
  fi
  if [ ! -d /run/systemd/system ]; then
    dot_info "no systemd running: start Garage with:"
    dot_info "  sudo -u garage env \$(sudo cat $envf) $bin -c $conf server --single-node --default-bucket"
    exit 0
  fi
  # the unit is ours: rewritten on every run, like the binary
  dot_sudo tee /etc/systemd/system/garage.service >/dev/null <<EOF
[Unit]
Description=Garage S3 object storage (single node)
Documentation=https://garagehq.deuxfleurs.fr/documentation/
After=network-online.target
Wants=network-online.target

[Service]
User=garage
Group=garage
Environment=RUST_LOG=garage=info GARAGE_CONFIG_FILE=$conf
EnvironmentFile=$envf
ExecStart=$bin server --single-node --default-bucket
Restart=on-failure
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
LimitNOFILE=42000

[Install]
WantedBy=multi-user.target
EOF
  dot_sudo systemctl daemon-reload
  dot_sudo systemctl enable garage >/dev/null 2>&1
  dot_sudo systemctl restart garage || dot_die "Garage does not start, see: journalctl -u garage"
  cli=("$bin" -c "$conf")
else
  # the pinned version also by digest: a tag on Docker Hub can be moved
  image=dxflrs/garage:$version
  [ "$version" = "$pinned" ] && image=$image@$digest
  # running again moves the image of an existing compose file to this version, never back to an older one
  have=$(dot_sudo sed -n 's#^ *image: dxflrs/garage:\(v[0-9.]*\).*#\1#p' "$dest/compose.yaml" 2>/dev/null)
  if [ -n "$have" ] && newer "$have" "$version"; then
    echo "warning: the stack runs Garage $have, newer than $version: keeping it (no way back to an older version)" >&2
    version=$have
  elif [ -n "$have" ]; then
    dot_sudo sed -i "s#image: dxflrs/garage:.*#image: $image#" "$dest/compose.yaml"
  fi
  dot_deploy garage "services:
  garage:
    image: $image
    container_name: garage
    restart: unless-stopped
    command: [\"/garage\", \"server\", \"--single-node\", \"--default-bucket\"]
    environment:
      GARAGE_CONFIG_FILE: $conf
      GARAGE_DEFAULT_ACCESS_KEY: \${GARAGE_DEFAULT_ACCESS_KEY}
      GARAGE_DEFAULT_SECRET_KEY: \${GARAGE_DEFAULT_SECRET_KEY}
      GARAGE_DEFAULT_BUCKET: \${GARAGE_DEFAULT_BUCKET}
    ports:
      - \"$DOT_BIND:$port:3900\"
    volumes:
      - $dest:$dest"
  cli=(docker exec garage /garage)
fi

# the default key and bucket are set up during start, before the API answers
for _ in $(seq 30); do dot_sudo "${cli[@]}" bucket info "$bucket" >/dev/null 2>&1 && break; sleep 1; done
dot_sudo "${cli[@]}" bucket info "$bucket" >/dev/null 2>&1 || dot_die "bucket $bucket is missing after 30 s, see the Garage log"

# address and port as written on the first run ("[address:]port"); a different answer now is only reported
if [ "$DOT_MODE" = native ]; then
  file=$conf pub=$(dot_sudo sed -n '/^\[s3_api\]/,/^\[/s/^api_bind_addr = "\(.*\)"/\1/p' "$conf")
else
  file=$dest/compose.yaml pub=$(dot_sudo sed -n 's/^ *- "\(.*\):3900"$/\1/p' "$dest/compose.yaml")
fi
port=${pub##*:}
case $pub in *:*) bound=${pub%:*} ;; *) bound=0.0.0.0 ;; esac
if [ "$bound" != "$DOT_BIND" ]; then
  echo "warning: the S3 API keeps listening on $bound (set on the first run), edit $file to change it" >&2
  DOT_BIND=$bound
fi
dot_info "Garage $version runs ($DOT_MODE), CLI: sudo ${cli[*]} status"
dot_summary garage "http://localhost:${port:-3900}" \
  "S3 access key and secret (region garage, bucket $bucket): sudo cat $envf; admin token: sudo grep admin_token $conf"
