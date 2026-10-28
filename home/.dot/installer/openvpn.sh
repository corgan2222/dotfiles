#!/bin/bash
# installer: OpenVPN server with its own PKI and a first client profile (.ovpn)
# systems: ubuntu debian amd64
# modes: native
# category: network
# check: /etc/openvpn/server/server.conf
# ports: OPENVPN_PORT=1194/udp
# ask: OPENVPN_HOST "Public host name or IP the VPN clients connect to, e.g. vpn.example.org or 192.0.2.10"
# OpenVPN and Easy-RSA from the distro, server "server" under /etc/openvpn/server (service openvpn-server@server):
# own CA (EC keys, 10 years), tls-crypt, UDP, clients in 10.8.0.0/24 with all their traffic through the VPN (NAT on
# this host, service openvpn-nat), DNS pushed to the clients.
#   OPENVPN_HOST=vpn.example.org openvpn.sh   host name or IP in the client profile (default: this host's first IP)
#   OPENVPN_PORT=1194                         UDP port (first run)
#   OPENVPN_DNS="1.1.1.1 9.9.9.9"             DNS servers pushed to the clients (first run)
#   OPENVPN_CLIENT=client1                    name of the client; running again with another name adds that client
# The client profile ~/openvpn-<client>.ovpn (0600, owner: the calling user) holds the client's private key: copy it
# to the device and delete it here. Running again updates the packages and keeps PKI, config and profiles.
# Revoke a client: cd /etc/openvpn/server && sudo EASYRSA_PKI=pki easyrsa revoke <client> && sudo EASYRSA_PKI=pki
# EASYRSA_CRL_DAYS=3650 easyrsa gen-crl && sudo install -m 644 pki/crl.pem crl.pem
# Native only (28.10.26): no maintained image; kylemanna/openvpn was last built in 12.2020, alekslitvinenk/openvpn
# (dockovpn) in 03.2024, d3vilh/openvpn-server in 12.2024, linuxserver/openvpn-as is gone from Docker Hub.
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

dir=/etc/openvpn/server
pki=$dir/pki
host=${OPENVPN_HOST:-$(hostname -I 2>/dev/null | awk '{print $1}')}
client=${OPENVPN_CLIENT:-client1}
[ -n "$host" ] || dot_die "set OPENVPN_HOST to the host name or IP the clients connect to"
dot_secret_ok "$host" || dot_die "OPENVPN_HOST must not contain spaces, quotes, \$ or backslashes"
case $client in ''|*[!A-Za-z0-9_-]*) dot_die "OPENVPN_CLIENT may only contain letters, digits, _ and -" ;; esac
[ -d /run/systemd/system ] || dot_die "openvpn.sh needs systemd (services openvpn-server@server and openvpn-nat)"

dot_epel
dot_pkg_install openvpn easy-rsa iptables || dot_die "installing openvpn and easy-rsa failed"
easyrsa=$(command -v easyrsa || ls /usr/share/easy-rsa/easyrsa /usr/share/easy-rsa/3/easyrsa 2>/dev/null | head -n 1)
[ -n "$easyrsa" ] || dot_die "easyrsa not found after installing easy-rsa"
ipt=$(PATH=$PATH:/usr/sbin:/sbin command -v iptables) || dot_die "iptables not found"

# runs easyrsa in $dir (it reads a "vars" file from the current directory), without questions
ersa() {
  local out
  out=$(cd "$dir" && dot_sudo env EASYRSA_BATCH=1 EASYRSA_PKI="$pki" EASYRSA_ALGO=ec EASYRSA_CA_EXPIRE=3650 \
    EASYRSA_CERT_EXPIRE=3650 EASYRSA_CRL_DAYS=3650 "$easyrsa" "$@" 2>&1) || { echo "$out" >&2; dot_die "easyrsa $* failed"; }
}

dot_sudo install -d -m 0755 "$dir"
if ! dot_sudo test -f "$pki/ca.crt"; then
  dot_info "creating the PKI in $pki"
  ersa init-pki
  ersa --req-cn=openvpn-ca build-ca nopass
  ersa build-server-full server nopass
  ersa gen-crl
  # the server reads the revocation list after dropping to nobody, the pki folder is root-only
  dot_sudo install -m 0644 "$pki/crl.pem" "$dir/crl.pem"
  dot_sudo sh -c "umask 077; openvpn --genkey secret '$dir/tc.key'" || dot_die "could not create $dir/tc.key"
fi
dot_sudo test -f "$pki/issued/$client.crt" || { dot_info "creating the client certificate $client"; ersa build-client-full "$client" nopass; }

conf=$dir/server.conf
{
  printf '%s\n' "# written by openvpn.sh" "port ${OPENVPN_PORT:-1194}" "proto udp" "dev tun" \
    "ca $pki/ca.crt" "cert $pki/issued/server.crt" "key $pki/private/server.key" "dh none" "tls-crypt $dir/tc.key" \
    "crl-verify $dir/crl.pem" "topology subnet" "server 10.8.0.0 255.255.255.0" \
    'push "redirect-gateway def1 bypass-dhcp"'
  for d in ${OPENVPN_DNS:-1.1.1.1 9.9.9.9}; do printf 'push "dhcp-option DNS %s"\n' "$d"; done
  printf '%s\n' "keepalive 10 120" "user nobody" "group $(id -gn nobody)" "persist-key" "persist-tun" "verb 3" \
    "explicit-exit-notify 1"
} | dot_put_new "$conf"
port=$(dot_sudo sed -n 's/^port //p' "$conf")

# clients reach the internet and the LAN through this host
echo 'net.ipv4.ip_forward = 1' | dot_put_new /etc/sysctl.d/99-openvpn.conf
dot_sudo sysctl -q -w net.ipv4.ip_forward=1 || echo "warning: could not switch on IP forwarding (container?)" >&2
net=10.8.0.0/24
printf '%s\n' "[Unit]" "Description=NAT and forwarding for the OpenVPN clients (openvpn.sh)" \
  "Before=openvpn-server@server.service" "" "[Service]" "Type=oneshot" "RemainAfterExit=yes" \
  "ExecStart=$ipt -t nat -A POSTROUTING -s $net ! -d $net -j MASQUERADE" \
  "ExecStart=$ipt -I FORWARD -s $net -j ACCEPT" \
  "ExecStart=$ipt -I FORWARD -d $net -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT" \
  "ExecStop=$ipt -t nat -D POSTROUTING -s $net ! -d $net -j MASQUERADE" \
  "ExecStop=$ipt -D FORWARD -s $net -j ACCEPT" \
  "ExecStop=$ipt -D FORWARD -d $net -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT" "" \
  "[Install]" "WantedBy=multi-user.target" | dot_put_new /etc/systemd/system/openvpn-nat.service
dot_sudo systemctl daemon-reload
dot_sudo systemctl enable --now openvpn-nat >/dev/null 2>&1 || dot_die "could not start openvpn-nat, see: journalctl -u openvpn-nat"
dot_sudo systemctl enable openvpn-server@server >/dev/null 2>&1
dot_sudo systemctl restart openvpn-server@server || dot_die "could not start openvpn-server@server, see: journalctl -u openvpn-server@server"
dot_firewall_open "$port/udp"

# the client profile with everything inline; its name must not look like a secret file, so that the summary names
# the path but does not print the private key
u=$(dot_user) home=$(dot_user_home)
prof=$home/openvpn-$client.ovpn
if [ -e "$prof" ]; then
  dot_info "keeping $prof"
else
  {
    printf '%s\n' client dev\ tun proto\ udp "remote $host $port" resolv-retry\ infinite nobind persist-key persist-tun \
      remote-cert-tls\ server verb\ 3 "<ca>"
    dot_sudo cat "$pki/ca.crt"
    echo "</ca>"; echo "<cert>"
    dot_sudo sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "$pki/issued/$client.crt"
    echo "</cert>"; echo "<key>"
    dot_sudo cat "$pki/private/$client.key"
    echo "</key>"; echo "<tls-crypt>"
    dot_sudo cat "$dir/tc.key"
    echo "</tls-crypt>"
  } | dot_sudo install -m 0600 -o "$u" -g "$(id -gn "$u")" /dev/stdin "$prof" || dot_die "could not write $prof"
  dot_info "wrote $prof"
fi
DOT_BIND='' dot_summary openvpn "$host:$port/udp" \
  "client profile $prof (0600, holds the client's key: copy it to the device, then delete it here); more clients: OPENVPN_CLIENT=<name> openvpn.sh" \
  openvpn-server@server
