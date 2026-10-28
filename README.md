# dotfiles

Bash profile, aliases, functions and an installer menu, managed with [homeshick](https://github.com/andsens/homeshick).
One command installs them; the same aliases then work on Debian, Arch, Red Hat, openSUSE and Alpine based systems, on
a few appliances and on Windows.

105 installers · 423 aliases · 223 functions · 22 systems

## Contents

- [Supported systems](#supported-systems)
- [Installation](#installation)
- [Setup, update, removal](#setup-update-removal)
- [Installer menu](#installer-menu)
- [Shell](#shell)
- [Aliases and functions per system](#aliases-and-functions-per-system)
- [Working on the dotfiles](#working-on-the-dotfiles)
- [How the numbers are counted](#how-the-numbers-are-counted)
- [Thanks](#thanks)

## Supported systems

`home/.dot/lib/detect.sh` reads `/etc/os-release`. A derivative takes the path of its family through `ID_LIKE`, so
Linux Mint follows Ubuntu, Manjaro follows Arch, and Rocky or AlmaLinux follow RHEL. Proxmox VE, Raspberry Pi OS,
Synology DSM, Unraid and Asuswrt-Merlin are detected by their own files and load an extra profile from
`~/.dot/<system>`.

<table>
  <tr>
    <th align="left">Debian, Ubuntu</th>
    <td align="center"><img src="docs/img/distros/ubuntu.png" width="48" height="48" alt="Ubuntu"><br>Ubuntu</td>
    <td align="center"><img src="docs/img/distros/debian.png" width="48" height="48" alt="Debian"><br>Debian</td>
    <td align="center"><img src="docs/img/distros/linuxmint.png" width="48" height="48" alt="Linux Mint"><br>Linux Mint</td>
    <td align="center"><img src="docs/img/distros/kali.png" width="48" height="48" alt="Kali Linux"><br>Kali</td>
    <td></td>
  </tr>
  <tr>
    <th align="left">Arch</th>
    <td align="center"><img src="docs/img/distros/arch.png" width="48" height="48" alt="Arch Linux"><br>Arch</td>
    <td align="center"><img src="docs/img/distros/manjaro.png" width="48" height="48" alt="Manjaro"><br>Manjaro</td>
    <td></td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <th align="left">Red Hat</th>
    <td align="center"><img src="docs/img/distros/fedora.png" width="48" height="48" alt="Fedora"><br>Fedora</td>
    <td align="center"><img src="docs/img/distros/rhel.png" width="48" height="48" alt="Red Hat Enterprise Linux"><br>RHEL</td>
    <td align="center"><img src="docs/img/distros/rocky.png" width="48" height="48" alt="Rocky Linux"><br>Rocky</td>
    <td align="center"><img src="docs/img/distros/almalinux.png" width="48" height="48" alt="AlmaLinux"><br>AlmaLinux</td>
    <td align="center"><img src="docs/img/distros/centos.png" width="48" height="48" alt="CentOS Stream"><br>CentOS Stream</td>
  </tr>
  <tr>
    <th align="left">Other Linux</th>
    <td align="center"><img src="docs/img/distros/opensuse.png" width="48" height="48" alt="openSUSE"><br>openSUSE</td>
    <td align="center"><img src="docs/img/distros/alpine.png" width="48" height="48" alt="Alpine Linux"><br>Alpine</td>
    <td></td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <th align="left">Own profile</th>
    <td align="center"><img src="docs/img/distros/proxmox.png" width="48" height="48" alt="Proxmox VE"><br>Proxmox VE</td>
    <td align="center"><img src="docs/img/distros/raspberrypi.png" width="48" height="48" alt="Raspberry Pi OS"><br>Raspberry Pi OS</td>
    <td align="center"><img src="docs/img/distros/synology.png" width="48" height="48" alt="Synology DSM"><br>Synology DSM</td>
    <td align="center"><img src="docs/img/distros/unraid.png" width="48" height="48" alt="Unraid"><br>Unraid</td>
    <td align="center"><img src="docs/img/distros/asuswrt.png" width="48" height="48" alt="Asuswrt-Merlin"><br>Asuswrt-Merlin</td>
  </tr>
  <tr>
    <th align="left">Windows</th>
    <td align="center"><img src="docs/img/distros/gitforwindows.png" width="48" height="48" alt="Git for Windows"><br>Git Bash</td>
    <td align="center"><img src="docs/img/distros/msys2.png" width="48" height="48" alt="MSYS2"><br>MSYS2</td>
    <td align="center"><img src="docs/img/distros/cygwin.png" width="48" height="48" alt="Cygwin"><br>Cygwin</td>
    <td align="center"><img src="docs/img/distros/wsl.png" width="48" height="48" alt="WSL"><br>WSL</td>
    <td></td>
  </tr>
</table>

WSL runs a Linux distribution, and the dotfiles treat it as that distribution. The installers cover the Debian,
Arch and Red Hat families; 24 of them run on any system, and each one names its systems in its `# systems:` line. The
menu offers only what fits.

## Installation

Requirements: bash, `curl` and, on Windows, `git`. On Linux the script installs `git` itself.

```bash
bash <(curl -fsSL https://corgan2222.github.io/dotfiles/deploy_headless.sh)
```

`deploy_headless.sh` does this, in order:

1. Installs `git` when it is missing, and `sudo` when it runs as root (aliases such as `apuu`, `ap` and `apr` call
   sudo). It uses apt, dnf, pacman, zypper, apk or opkg. As a normal user without sudo, and on Windows, `git` has to be
   there already and nothing is installed.
2. Fetches homeshick and this repository to `~/.homesick/repos/`.
3. Moves every file it would replace to `~/.dotfiles-backup/<date>/`, with the same path below your home: `~/.bashrc`,
   `~/.profile`, files of your own in `~/.dot` with the name of one of ours, and `~/.bash_profile` and `~/.bash_login`,
   which would hide `~/.profile` from bash.
4. Links `~/.bashrc`, `~/.profile` and `~/.dot` into your home. The profile folders in `~/.dot` (raspi, proxmox,
   synology, ...) load only on their system.
5. Runs `~/.dot/setup.sh`, which offers the installer menu at the end.

Without a terminal, for example `curl ... | bash` inside a script, it asks nothing.

### From a local checkout

To try a state that is not on GitHub yet, run the script of a checkout. It installs the committed state of that
checkout:

```bash
bash path/to/dotfiles/deploy_headless.sh
```

### Windows (Git Bash, MSYS2, Cygwin)

The same command runs in Git Bash, MSYS2 and Cygwin. All of them need `git` and `curl`; in Cygwin, pick both in the
setup program.

homeshick links the files into your home folder. The deploy and the shell set `winsymlinks:nativestrict`, so these are
native Windows symlinks. Windows allows them with Developer Mode on (Settings, For developers) or in a shell run as
administrator. Without either, the deploy stops before it moves a file; when a link fails half way, it removes the new
links and puts your files back.

Cygwin packages come from the Cygwin setup program (`setup-x86_64.exe`): run it again to install or upgrade. With
[apt-cyg](https://github.com/transcode-open/apt-cyg) installed, `ap`, `apr`, `apSearch` and `aptList` work as on Linux;
`apuu` points to the setup program.

On Windows the shell adds `open` (and with it `o`), `pbcopy`, `pbpaste`, `winpath` and `unixpath`. The prompt shows the
git branch only, without dirty state and IP, because every process costs 10 to 20 ms there.

## Setup, update, removal

### Setup

```bash
~/.dot/setup.sh            # ask for every value that is still missing
~/.dot/setup.sh --check    # only list what is missing
~/.dot/setup.sh --motd     # show the login screen again and choose whether it stays on
```

The setup asks for git name and e-mail, the editor, delta as git pager (when installed) and the login screen, each
question with an example. It never overwrites a value that is set. Personal values go to `~/.extra` (mode 0600, not in
the repository), git settings to `~/.gitconfig`.

### Update

```bash
dotupdate
```

`dotupdate` pulls the repository, links new files, removes links of files that were deleted, asks the setup questions
of what is new and starts a new login shell. `loadHome` and the alias `l` do the same. At login the shell tells you
when new commits are waiting; it fetches in the background at most every 6 hours.

An install from before `dotupdate` existed updates once by hand:

```bash
homeshick pull dotfiles && homeshick link dotfiles
```

### Removal

```bash
bash ~/.homesick/repos/dotfiles/remove_dotfiles.sh
```

It lists what it will do and asks first. It removes the links, the repository, homeshick when no other castle is left,
and `~/.autojump`, `~/.fzf` and `~/.git-radar`. Then it puts back your files from `~/.dotfiles-backup`; a missing
`~/.bashrc` or `~/.profile` comes from `/etc/skel`. Other castles, `~/.nvm` and files of your own in `~/.dot` go only
after a question of their own. The backups stay.

## Installer menu

```bash
installer                       # dialog checklist, grouped by category
installer --list                # installers that fit this system
installer --list-all            # every installer
installer --list-status         # the menu rows as text: category, ways to install, installed state
installer grafana loki          # run these without the menu
```

The menu shows only installers that fit this system, grouped by category, with what is already installed. On the
first run it preselects the base installers.

Ways to install, shown as `[B|D|P]` per installer:

<table>
  <tr>
    <th align="left">B</th>
    <td></td>
    <td>native (bare metal): packages, a systemd service</td>
  </tr>
  <tr>
    <th align="left">D</th>
    <td align="center"><img src="docs/img/distros/docker.png" width="48" height="48" alt="Docker"><br>Docker</td>
    <td>a Docker compose project in <code>/opt/&lt;name&gt;</code></td>
  </tr>
  <tr>
    <th align="left">P</th>
    <td align="center"><img src="docs/img/distros/portainer.png" width="48" height="48" alt="Portainer"><br>Portainer</td>
    <td>a stack in the local Portainer</td>
  </tr>
</table>

D and P appear only while `docker info` answers; P also needs a Portainer API token, or Portainer chosen in the same
run. An installer that can run in Docker is offered on every system with Docker, even when its own system list does
not match.

Before anything runs, the menu:

- asks once whether the services listen on this host only (`127.0.0.1`, the default) or on all interfaces. Servers
  others connect to keep their own setting: VPN, ssh, samba, the Zabbix agent, reverse proxies, API gateways, MQTT
  brokers, node_exporter and the OpenTelemetry collector. A service that is installed already keeps its address.
- checks the TCP and UDP ports of every chosen installer. When a port is taken by a running service or by another
  installer in the same run, it names the owner and offers the next free port, another port, skipping the installer,
  or trying anyway.
- asks for the values an installer cannot do without, such as versions, ports or passwords.
- offers Bitwarden. With an unlocked vault, every login an installer creates is also stored there: folder `dotfiles`,
  one login per service. Set it up later with `bash ~/.dot/installer/bw.sh`.

At the end it prints a summary per installed service: address, where it listens, the login and the files that hold
its passwords (with their content; `DOT_SHOW_SECRETS=0` hides it), and how to see the service and its logs.

Every dialog is skipped when its answer is in the environment: `INSTALL_CHOICES="alloy grafana"`,
`INSTALL_MODE=native|compose|portainer`, `BIND_ADDR=127.0.0.1|0.0.0.0` and the variables an installer asks for.
Without a terminal, a missing answer stops the menu with the name of its variable.

### Installers

105 installers in 11 categories. 91 install natively, 42 as Docker compose project, 41 as Portainer stack.
Letters after a name list the ways to install; no letters means native only.

| Category | Count | Installers |
|---|--:|---|
| Base | 14 | `basics`, `bat`, `bd`, `btop`, `delta`, `duf`, `eza`, `glow`, `gping`, `lazydocker`, `lazygit`, `lsd`, `nmap`, `rustnet` |
| Sysop | 11 | `ansible`, `atuin`, `bw`, `etckeeper`, `fail2ban`, `onepanel`, `rclone`, `ssh`, `teamviewer`, `tldr`, `wifi-wavemon` |
| Dev | 16 | `aichat`, `claude-code`, `code_server` (B D P), `codex`, `composer`, `cuda`, `gitea` (B D P), `gitlab` (B D P), `go`, `nodejs`, `opencv`, `pm2`, `python`, `rust`, `wpcli`, `yarn` |
| Desktop | 8 | `chrome`, `chromium`, `digikam`, `firefoxdev`, `gimp`, `jetbrains`, `terminator`, `vscode` |
| Docker | 5 | `diun` (D P), `dockcheck`, `docker`, `dozzle` (D P), `portainer` (D) |
| Databases | 5 | `chronograf` (B D P), `garage` (B D P), `influxdb` (B D P), `redis` (B D P), `superset` (D P) |
| Monitoring | 9 | `grafana` (B D P), `grafana-plugins` (B D P), `node_exporter` (B D P), `otel` (B D P), `patchmon` (D P), `prometheus` (B D P), `victoriametrics` (B D P), `zabbix_agent` (B D P), `zabbix_cli` |
| Logs | 2 | `alloy` (B D P), `loki` (B D P) |
| Network/VPN | 8 | `cloudflared` (B D P), `headscale` (B D P), `netbird` (B D P), `openvpn`, `tailscale`, `wg_easy` (D P), `wireguard`, `zerotier` |
| Raspberry Pi | 7 | `picamera`, `raspi-fanSpeed`, `raspi-install-BT`, `raspi_conky`, `raspi_extfat`, `raspi_wiringPI`, `raspi_zigbee2mqtt` (B D P) |
| Server | 20 | `caddy` (B D P), `emqx` (B D P), `esec_onlogic`, `frigate` (D P), `go2rtc`, `krakend` (B D P), `mosquitto` (B D P), `nextcloud` (D P), `nginx` (B D P), `nginx_proxy_manager` (D P), `nodered` (B D P), `restreamer` (D P), `runtipi`, `samba`, `snapotter` (D P), `stalwart` (B D P), `traefik` (D P), `vaultwarden` (D P), `zabbix_server` (B D P), `zipline` (D P) |

`installer --list-all` prints one line per installer with its description and systems. How an installer describes
itself (`# installer:`, `# systems:`, `# modes:`, `# category:`, `# check:`, `# ask:`, `# ports:`) is documented at the
top of `home/.dot/installer/installer.sh`.

## Shell

- **Prompt:** exit status of the last command when it failed, git branch and state, time, user, IP, host and
  directory. Profile folders may set their own.
- **Login screen (MOTD):** system, uptime, load, memory, disk and IP addresses. Proxmox, Unraid, Asuswrt and Kali bring
  their own. Turn it off with `~/.dot/setup.sh --motd`.
- **Modern replacements**, only in interactive shells and only when the tool is installed: `cat` runs `bat`, `ping`
  runs `gping`, `df` runs `duf`, `top` runs `btop` (else `htop`). Extra names: `dux` (`ncdu`), `lzd` (`lazydocker`),
  `netmon` (`rustnet`), `xq` (XML to JSON). `cat` with options (`cat -A`), in a pipe and behind `sudo` stays the
  classic one, and `command cat` always is. Turn them
  off with `DOT_MODERN_ALIASES=0` in `~/.extra`. With `eza` installed, `d`, `da`, `dt` and `lsdir` list with it.
- **Missing commands:** when a command used by an alias or function is missing, the shell names the package and asks
  whether to install it. A table in `home/.dot/lib/cmdpkg.sh` knows 61 commands for apt, dnf, pacman, zypper and apk.
  Turn it off with `DOT_INSTALL_ON_DEMAND=0`.
- **One set of package aliases** for apt, dnf, yum, pacman, zypper, apk and opkg: `ap` installs, `apr` removes,
  `apuu` updates and upgrades, `apSearch` searches, `aptList` lists. `pkg_install` installs in scripts.
- **Lookup:** `h <text>` searches aliases and functions, `hint <topic>` shows a cheat sheet (needs
  `fzf`), `logs` lists the logs under `/var/log` and `logs <name>` opens them.
- `~/.dot/bin` is at the end of the PATH, with 34 helper scripts (port scan, system info, file server, backups and
  more).
- `reload` starts a new login shell. `DOT_TIMING=1 bash -l` prints how long each file of the profile takes to load.

## Aliases and functions per system

Every system loads the base files; a system with its own profile loads its folder on top.

| Profile | Aliases | Functions |
|---|--:|--:|
| base (all systems) | 328 | 203 |
| proxmox | 45 | 13 |
| raspi | 30 | 8 |
| asuswrt | 14 | 5 |
| synology | 17 | 3 |
| unraid | 8 | 7 |
| windows (Git Bash, MSYS2, Cygwin) | 4 | 1 |
| ubuntu16, ubuntu18, ubuntu19 (only on Ubuntu 16.04, 18.04, 19.04) | 19 | 4 |
| kali | 0 | 3 |
| **distinct names in total** | **423** | **223** |

Generated reference lists are in [`home/.dot/docs/`](home/.dot/docs/) (`create_github_docs`); they may lag behind the
code.

## Working on the dotfiles

With the wrapper functions:

```bash
saveHome "message" [path…]   # commit changed files (and new ones you name), push after a question
addToHome <file>             # add a file or folder of your home to the repository
checkHome                    # is the local copy up to date?
gitSaveCredential            # store the git credentials for later pushes
```

With homeshick directly:

```bash
homeshick cd dotfiles                  # go to the repository
homeshick track dotfiles <file>        # add a file or folder
homeshick check dotfiles               # compare with GitHub
homeshick pull dotfiles && homeshick link dotfiles
```

When a pull fails, look at the repository:

```bash
homeshick cd dotfiles
git status
```

## How the numbers are counted

Counted on 2026-10-28 from the files in this repository:

- **Installers:** `home/.dot/installer/*.sh` without `installer.sh`. Category and ways to install come from the
  `# category:` and `# modes:` lines at the top of each file; a file without `# modes:` installs natively.
- **Aliases:** distinct names of `alias <name>=` in `home/.bashrc`, `.bash_aliases`, `.bash_aliases_modern` and, per
  profile folder under `home/.dot/`, its alias files, `.bashrc` and `.exports`, including aliases defined only on
  some systems.
- **Functions:** distinct names defined as `name()` or `function name` in `.bash_functions.sh`, the alias files and
  `.bashrc`, and per profile folder in its `*_bash_functions.sh`, alias files and `.bashrc`; without helpers whose name
  starts with `_`.
- **Systems:** the systems in the table above that `home/.dot/lib/detect.sh` and `home/.bashrc` handle.
- **Helper scripts:** files in `home/.dot/bin`, without `sensible.bash`, which is sourced.

## Thanks

- [homeshick](https://github.com/andsens/homeshick), git dotfiles synchronizer written in bash
- [voku/dotfiles](https://github.com/voku/dotfiles)
- [cowboy/dotfiles](https://github.com/cowboy/dotfiles)
- [alrra/dotfiles](https://github.com/alrra/dotfiles)

Author: [corgan2222](https://github.com/corgan2222)
