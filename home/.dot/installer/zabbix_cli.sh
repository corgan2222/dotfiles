#!/bin/bash
# installer: zabbix-cli 3 for the Zabbix API (user tool via uv)
# systems: all
# Installs zabbix-cli (PyPI zabbix-cli-uio) as a uv tool into ~/.local/bin; uv brings its own Python,
# so it also runs where the system Python is too old. Installs uv into ~/.local/bin first when it is missing.
# Usage: zabbix_cli.sh   (safe to run again, upgrades an existing install)
# category: monitoring
# check: zabbix-cli
. "$(dirname "$(readlink -f "$0")")/../lib/os.sh"

UV_DIR="$HOME/.local/bin"

uv=$(command -v uv || echo "$UV_DIR/uv")
[ -x "$uv" ] || dot_uv_install

dot_info "Installing zabbix-cli with uv"
"$uv" tool install --upgrade zabbix-cli-uio || dot_die "uv could not install zabbix-cli-uio"
bin=$("$uv" tool dir --bin)
"$bin/zabbix-cli" --version || dot_die "$bin/zabbix-cli does not run"
case ":$PATH:" in
  *":$bin:"*) ;;
  *) dot_info "$bin is not in PATH yet, ~/.dot/.exports adds ~/.local/bin at the next login; until then run $bin/zabbix-cli" ;;
esac
echo "
Configure it once with the API URL of your Zabbix server:
  zabbix-cli init --url ${ZABBIX_URL:-https://zabbix.example.org}
Credentials come from the prompt or from ZABBIX_USERNAME / ZABBIX_PASSWORD (or ZABBIX_API_TOKEN)."
