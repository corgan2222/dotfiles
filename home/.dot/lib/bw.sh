#!/bin/bash
# Bitwarden CLI (bw) for the installers: install, a guided setup in the terminal, and storing logins in the vault.
# Needs lib/os.sh. installer.sh offers the setup before Docker; dot_summary stores each login (addresses, user,
# password, other secrets as hidden fields) as login item "<host>_<service>" in the folder "dotfiles", while
# BW_SESSION is set. The session key stays on tmpfs until the reboot or "bw lock" (_bw_cache); bw keeps the vault
# encrypted on disk.

# installs or updates bw in ~/.local/bin: Bitwarden's release binary for amd64 and arm64 (sha256 checked), npm elsewhere
dot_bw_install() {
  local tag tmp a rc
  export PATH="$HOME/.local/bin:$PATH"
  case $DOT_ARCH in
    amd64) a=bw-linux ;;
    arm64) a=bw-linux-arm64 ;;
    *) dot_node_min 20 && dot_sudo npm install -g @bitwarden/cli >/dev/null; return ;;
  esac
  dot_need curl unzip
  # the latest release of bitwarden/clients is the web vault or the desktop app: Bitwarden's download link names the
  # tag of the CLI (cli-v2026.10.0 on 28.10.26)
  tag=$(curl -fsSI 'https://vault.bitwarden.com/download/?app=cli&platform=linux' | tr -d '\r' |
    sed -n 's#^location: *.*/releases/download/\([^/]*\)/.*#\1#Ip')
  [ -n "$tag" ] || { echo "cannot read the latest bw version from vault.bitwarden.com" >&2; return 1; }
  tmp=$(mktemp -d)
  dot_github_fetch bitwarden/clients "/$a-[0-9.]+\.zip\$" "$tmp/bw.zip" "$tag" &&
    unzip -qo "$tmp/bw.zip" -d "$tmp" && install -D -m 755 "$tmp/bw" "$HOME/.local/bin/bw"
  rc=$?
  rm -rf "$tmp"
  return $rc
}

# prints missing, unauthenticated, locked or unlocked
dot_bw_status() {
  command -v bw >/dev/null 2>&1 || { echo missing; return; }
  bw status 2>/dev/null | jq -r '.status // "unauthenticated"' 2>/dev/null || echo unauthenticated
}

# Questions as dialog boxes in the middle of the screen, like the installer menu (28.10.26: the read prompts stuck to
# the bottom under the apt output); plain read without dialog or terminal.
# _bw_input <title> <text> <default> [password]: prints the answer, fails on Cancel
_bw_input() {
  local a box=--inputbox
  [ -n "${4:-}" ] && box=--passwordbox
  if command -v dialog >/dev/null 2>&1; then
    dialog --title "$1" ${4:+--insecure} $box "$2" 14 76 "$3" 2>&1 >/dev/tty </dev/tty
  else
    printf '\n%s\n' "$2" >&2
    if [ -n "${4:-}" ]; then read -rs -p "> " a </dev/tty; echo >&2; else read -r -p "> [$3] " a </dev/tty; fi
    printf '%s' "${a:-$3}"
  fi
}
# _bw_yes <title> <text>: true on Yes; Enter is Yes
_bw_yes() {
  local a
  if command -v dialog >/dev/null 2>&1; then dialog --title "$1" --yesno "$2" 14 76 </dev/tty >/dev/tty 2>&1
  else printf '\n%s\n' "$2" >&2; read -r -p "[Y/n] " a </dev/tty; case $a in [nN]*) return 1 ;; esac; fi
}

# Guides through install, server, login and unlock and exports BW_SESSION. A server that does not answer or a failed
# login asks again with the last answers filled in (28.10.26). Returns 1 when the user gives up; the installers then
# run without Bitwarden.
dot_bw_setup() {
  local s url a key def email pw err log pid
  export PATH="$HOME/.local/bin:$PATH"
  dot_need jq dialog
  err=$(mktemp) log=$(mktemp)
  s=$(dot_bw_status)
  if [ "$s" = missing ]; then
    # apt and the download in a log: the questions start on a clean screen
    dot_bw_install >"$log" 2>&1 &
    pid=$!
    while kill -0 $pid 2>/dev/null; do dot_progress 0 0 "installing the Bitwarden CLI (bw)"; sleep 0.3; done
    dot_progress_end
    wait $pid && bw --version >/dev/null 2>&1 || { tail -n 15 "$log" >&2; echo "could not install bw" >&2; rm -f "$err" "$log"; return 1; }
    s=$(dot_bw_status)
  fi
  if [ "$s" = unauthenticated ]; then
    # BW_SERVER (e.g. in ~/.extra) is the first answer, then a server set before (bw config server)
    url=${BW_SERVER:-$(bw status 2>/dev/null | jq -r '.serverUrl // empty')}
    while :; do
      a=$(_bw_input "Bitwarden 1/2: server" "Which server holds your vault?
  1  bitwarden.com, cloud in the US (most accounts)
  2  bitwarden.eu, cloud in the EU
  or the URL of your own server (Vaultwarden, self-hosted), e.g. https://vault.example.org
No account yet: create one for free at https://vault.bitwarden.com/#/register.
Always the same own server: export BW_SERVER=https://… in ~/.extra." "${url:-1}") || { rm -f "$err" "$log"; return 1; }
      case $a in
        1) url=https://vault.bitwarden.com ;;
        2) url=https://vault.bitwarden.eu ;;
        *) url=${a%/} ;;
      esac
      # a server address: scheme, host name or IP, optional port and path; "user@host" typos are refused (28.10.26)
      if ! [[ $url =~ ^https?://([A-Za-z0-9.-]+|\[[0-9A-Fa-f:]+\])(:[0-9]+)?(/[^[:space:]]*)?$ ]]; then
        _bw_yes "Bitwarden" "\"$url\" is not a server address, e.g. https://vault.example.org

Enter it again?" && continue
        rm -f "$err" "$log"; return 1
      fi
      # plain http only on this host: to another one the login and every vault access would cross the network
      # readable (28.10.26, review)
      if [[ $url == http://* ]] && ! [[ $url =~ ^http://(localhost|127\.0\.0\.1|\[::1\])(:[0-9]+)?(/|$) ]]; then
        _bw_yes "Bitwarden" "$url uses plain http: your login and the vault would go over the network unencrypted.
Use https:// (a reverse proxy with TLS in front of Vaultwarden), or http only for a server on this host
(localhost, 127.0.0.1, [::1]).

Enter another address?" && continue
        rm -f "$err" "$log"; return 1
      fi
      # Bitwarden and Vaultwarden both answer /api/config without a login
      if ! curl -fsS -m 15 -o /dev/null "$url/api/config" 2>"$err"; then
        _bw_yes "Bitwarden" "$url does not answer:
$(tail -n 2 "$err")

Enter another address?" && continue
        rm -f "$err" "$log"; return 1
      fi
      break
    done
    bw config server "$url" >/dev/null || { rm -f "$err" "$log"; return 1; }
    # the e-mail given to git in the setup is the first guess
    email=$(git config --global user.email 2>/dev/null)
    while :; do
      email=$(_bw_input "Bitwarden 2/2: log in to $url" "E-mail of your Bitwarden account" "$email") &&
        [ -n "$email" ] && pw=$(_bw_input "Bitwarden 2/2: log in to $url" "Master password for $email" "" password) ||
        { clear; rm -f "$err" "$log"; return 1; }
      clear
      printf '\033[96mlogging in to %s as %s\033[0m\n' "$url" "$email"
      printf '\033[90m  with two-step login bw asks for the code here; a new device may need a code Bitwarden mails you\033[0m\n'
      # the password goes to bw in its environment, not on the command line; bw's prompts stay on the screen
      key=$(BW_PASSWORD=$pw bw login "$email" --passwordenv BW_PASSWORD --raw </dev/tty 2> >(tee "$err" >&2)) || key=
      pw=
      [ -n "$key" ] && break
      # tee of the process substitution may still be writing
      sleep 0.5
      _bw_yes "Bitwarden" "The login did not work:
$(grep -v 'ServerConfig\|^ \|^}\|^{$' "$err" | tail -n 3)

Try again? Accounts with SSO: log in once by hand with bw login --apikey (API key from the web vault: Settings,
Security, Keys), then run this again." || { clear; rm -f "$err" "$log"; return 1; }
    done
  else
    while :; do
      pw=$(_bw_input "Bitwarden: unlock" "Master password of your vault ($(bw status 2>/dev/null | jq -r '.userEmail // empty'))
It stays unlocked until the next reboot or bw lock." "" password) || { clear; rm -f "$err" "$log"; return 1; }
      clear
      key=$(BW_PASSWORD=$pw bw unlock --passwordenv BW_PASSWORD --raw </dev/tty 2>"$err") || key=
      pw=
      [ -n "$key" ] && break
      _bw_yes "Bitwarden" "Unlocking did not work:
$(grep -v 'ServerConfig\|^ \|^}\|^{$' "$err" | tail -n 3)

Try again?" || { clear; rm -f "$err" "$log"; return 1; }
    done
  fi
  rm -f "$err" "$log"
  export BW_SESSION=$key
  dot_bw_keep
  bw sync >/dev/null 2>&1 || echo "warning: bw sync failed, the logins may be stored next to older ones" >&2
  dot_info "Bitwarden is ready until the next reboot or bw lock: each login goes to the folder dotfiles as" \
    "\"$(hostname 2>/dev/null)_<service>\""
}

# The session of this boot: dot_bw_setup keeps BW_SESSION in the file dotfiles-bw of a folder on tmpfs that only this
# user can enter: XDG_RUNTIME_DIR (/run/user/<uid>), else /dev/shm/dotfiles-bw-<uid> (0700). A second installer run in
# the same boot neither asks nor unlocks again (28.10.26, wish of the Auftraggeber); "bw lock" or a reboot ends it. A
# "No" to unlocking is noted next to it, also until the reboot. installer.sh does not pass BW_SESSION on, dot_summary
# reads it from here. Folder and file are checked before use: in the shared /dev/shm another user can make the name
# first (28.10.26, review). _bw_cache prints the path of the file, fails without such a folder.
_bw_mine() { [ ! -L "$1" ] && [ -O "$1" ] && [ "$(stat -c %a "$1" 2>/dev/null)" = "$2" ]; }
_bw_cache() {
  local d=${XDG_RUNTIME_DIR:-}
  if [ -z "$d" ] || [ ! -d "$d" ] || ! _bw_mine "$d" 700; then
    d=/dev/shm; [ -d "$d" ] || d=/tmp
    d=$d/dotfiles-bw-$(id -u)
    # the session file had this name before (28.10.26)
    [ -f "$d" ] && [ ! -L "$d" ] && [ -O "$d" ] && rm -f "$d"
    mkdir -m 0700 "$d" 2>/dev/null
    [ -d "$d" ] && _bw_mine "$d" 700 || return 1
  fi
  echo "$d/dotfiles-bw"
}

# true and BW_SESSION exported when the session of this boot still unlocks the vault
dot_bw_resume() {
  local k f
  f=$(_bw_cache) && [ -f "$f" ] && _bw_mine "$f" 600 && command -v bw >/dev/null 2>&1 && k=$(cat "$f") &&
    [ -n "$k" ] || return 1
  [ "$(BW_SESSION=$k bw status 2>/dev/null | jq -r .status 2>/dev/null)" = unlocked ] || { rm -f "$f"; return 1; }
  export BW_SESSION=$k
}
dot_bw_keep() { local f; f=$(_bw_cache) && ( umask 077; rm -f "$f"; printf '%s' "$BW_SESSION" > "$f" ); }
dot_bw_declined() { local f; f=$(_bw_cache) && _bw_mine "$f.no" 600; }
dot_bw_decline() { local f; f=$(_bw_cache) && ( umask 077; : > "$f.no" ); }

# Stores the login of a service as a Bitwarden login item "<host>_<name>" in the folder dotfiles and updates it on the
# next run: URIs = the addresses, username and password, every other secret as a hidden field, notes = where it runs.
#   dot_bw_store <name> "<address …>" <login text> <where> <lines of _dot_secret_lines>
# Username: DOT_USER, else "user <name>" in the login text (not "no user needed"), a *USERNAME*/*_USER key
# or the user of a "user:password" credentials file, an S3 *ACCESS_KEY* (not *SECRET_ACCESS_KEY*). Password:
# DOT_PASSWORD, else the best key: admin, root or init passwords before other passwords before an S3 secret key.
# KEY="x y" and KEY='x y' count without the quotes. Stores nothing when the summary has neither user, password nor
# secret. Prints the name of the item it stored, nothing when it stored none.
dot_bw_store() {
  local n f l k K v p best=0 pk= user=${DOT_USER:-} pass=${DOT_PASSWORD:-} rows= t folder id item host
  local ure='(^|[^[:alnum:]_])user[[:space:]]+([A-Za-z0-9_.@-]+)'
  local q1='^"(.*)"[[:space:]]*$' q2="^'(.*)'[[:space:]]*\$"
  host=$(hostname 2>/dev/null || uname -n)
  n=${host}_$1
  # "no user needed" made the user "needed" (28.10.26, review); "dashboard user admin" (emqx) still names one
  if [ -z "$user" ] && [[ $3 =~ $ure ]]; then
    case ${BASH_REMATCH[2]} in needed|with|and|or|is|name|none) ;; *) user=${BASH_REMATCH[2]} ;; esac
  fi
  while IFS=$'\t' read -r f l; do
    [ -n "$l" ] || continue
    case $l in \#*) continue ;; esac
    if [[ $l =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
      k=${BASH_REMATCH[1]} v=${BASH_REMATCH[2]}
      # a quote inside cut the value off before (28.10.26, review)
      [[ $v =~ $q1 || $v =~ $q2 ]] && v=${BASH_REMATCH[1]}
    elif [[ ${f##*/} == *credentials* && $l =~ ^([^:]+):(.+)$ ]]; then
      # mosquitto, nodered, dozzle: user:password
      if [ -z "$user" ] || [ "$user" = "${BASH_REMATCH[1]}" ]; then user=${BASH_REMATCH[1]}; [ -n "$pass" ] || pass=${BASH_REMATCH[2]} best=3
      else rows+="1"$'\t'"${BASH_REMATCH[1]}"$'\t'"${BASH_REMATCH[2]}"$'\n'; fi
      continue
    elif [[ $l == \{* ]] && v=$(jq -r '.token // empty' <<<"$l" 2>/dev/null) && [ -n "$v" ]; then
      k=${f##*/} k=${k%.json}
    elif [[ $l =~ ^([A-Za-z_]+)[[:space:]]+\"?([^[:space:]\"]+)\"?$ ]]; then
      # "key value" configs: requirepass "…" of redis-auth.conf
      k=${BASH_REMATCH[1]} v=${BASH_REMATCH[2]}
    else
      k=${f##*/} v=$l
    fi
    # a cloudflared unit of an older run: ExecStart=… --token <token> (cloudflared.sh now uses tunnel.env)
    [[ $v =~ --token[=[:space:]]+([^[:space:]]+) ]] && k=token v=${BASH_REMATCH[1]}
    [ -n "$v" ] && [ "$v" != "$pass" ] && [ "$v" != "$user" ] || continue
    K=${k^^} K=${K//-/_}
    # secrets first: *ACCESS_KEY* also matched AWS_SECRET_ACCESS_KEY, the secret became the user (28.10.26, review)
    case $K in
      *SECRET*|*PASS*|*TOKEN*) ;;
      *USERNAME*|*_USER|USER|*ACCESS_KEY*) [ -n "$user" ] || { user=$v; continue; } ;;
    esac
    case $K in
      *PASS*) p=2; case $K in *ADMIN*|*ROOT*|*INIT*) p=3 ;; esac ;;
      *SECRET_KEY*|*SECRET_ACCESS_KEY*) p=1 ;;
      *) p=0 ;;
    esac
    if [ -z "${DOT_PASSWORD:-}" ] && [ $p -gt $best ]; then
      # the earlier candidate stays as a hidden field
      [ -z "$pass" ] || rows+="1"$'\t'"$pk"$'\t'"$pass"$'\n'
      pass=$v pk=$k best=$p
      continue
    fi
    case $K in
      *PASS*|*TOKEN*|*SECRET*|*KEY*) t=1 ;;
      *ORG|*BUCKET|*REGION|*DATABASE|*_DB) t=0 ;;
      # other settings of the .env (mode, plugin list, host names) are no login data
      *) continue ;;
    esac
    rows+="$t"$'\t'"$k"$'\t'"$v"$'\n'
  done <<<"$5"
  [ -z "$user" ] && [[ ${pk^^} == *ROOT* ]] && user=root
  # no password and nothing but one secret: that secret is the login (Vaultwarden's admin token, 28.10.26); with more
  # (Chronograf's token next to its org) it stays a field
  if [ -z "$pass" ] && [ "$(grep -c . <<<"$rows")" = 1 ] && [ "$(grep -c $'^1\t' <<<"$rows")" = 1 ]; then
    pass=$(grep $'^1\t' <<<"$rows" | cut -f3-)
    rows=$(grep -v $'^1\t' <<<"$rows"; true)
    [ -z "$rows" ] || rows+=$'\n'
  fi
  # only what helps to log in: no entry for services without a password or secret
  [ -n "$pass$rows" ] || return 0
  folder=$(bw list folders --search dotfiles 2>/dev/null | jq -r '[.[] | select(.name == "dotfiles")][0].id // empty')
  if [ -z "$folder" ]; then
    folder=$(jq -nc '{name: "dotfiles"}' | bw encode | bw create folder 2>/dev/null | jq -r '.id // empty')
    [ -n "$folder" ] || return 1
  fi
  # bw get template needs a login, so the item is written out: type 1 = login, field type 1 = hidden
  # password and hidden fields reach jq through its environment, not as arguments in the process list (28.10.26)
  item=$(DOT_BW_P=$pass DOT_BW_ROWS=$rows jq -nc --arg n "$n" --arg f "$folder" --arg u "$user" --arg notes "$4" \
    --arg uris "$2" 'env.DOT_BW_P as $p | env.DOT_BW_ROWS as $rows |
    {type: 1, name: $n, folderId: $f, notes: $notes, favorite: false, reprompt: 0,
      login: {username: (if $u == "" then null else $u end), password: (if $p == "" then null else $p end), totp: null,
              uris: [$uris | split(" ")[] | select(. != "") | sub("^[A-Za-z-]+="; "") | {match: null, uri: .}]},
      fields: [$rows | split("\n")[] | select(. != "") | split("\t") | {name: .[1], value: .[2], type: (.[0] | tonumber)}]}')
  id=$(bw list items --folderid "$folder" --search "$n" 2>/dev/null |
    jq -r --arg n "$n" '[.[] | select(.name == $n and .type == 1)][0].id // empty')
  if [ -n "$id" ]; then
    jq -sc '.[0] + (.[1] | {notes, login, fields})' <(bw get item "$id" 2>/dev/null) <(printf '%s' "$item") |
      bw encode |
      bw edit item "$id" >/dev/null 2>&1
  else
    bw encode <<<"$item" | bw create item >/dev/null 2>&1
  fi || return 1
  # for the vault line of the summary
  echo "$n"
}
