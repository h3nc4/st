#!/bin/sh

# Installs and purges the .deb in $1, dist by default, as root on a throwaway Debian or Devuan system.
# Fails on a missing dependency, an unregistered alternative, ncurses-term's st entries winning, or a leftover file.

set -eu

cd "$(dirname "$0")/../"

deb="$(ls "${1:-dist}"/st-h3nc4_*_amd64.deb)"
export DEBIAN_FRONTEND=noninteractive

fail() {
	echo "check-deb.sh: $*" >&2
	exit 1
}

snapshot() {
	find / -xdev \( -path /proc -o -path /tmp -o -path /var/cache -o -path /var/lib/apt \
		-o -path /var/lib/dpkg -o -path /var/log -o -path "${PWD}" \) -prune -o -print | sort
}

apt-get update -qq
apt-get install -y -qq --no-install-recommends ncurses-term >/dev/null
snapshot >/tmp/before
apt-get install -y -qq --no-install-recommends "./${deb}"

# st prints its version through die(), which exits 1.
version="$(st -v 2>&1 || true)"
case "${version}" in
	"st $(sed -n 's/^VERSION = //p' config.mk)") echo "${version}" ;;
	*) fail "st -v printed '${version}'" ;;
esac

[ "$(readlink -f /usr/bin/x-terminal-emulator)" = /usr/bin/st ] ||
	fail "x-terminal-emulator points at $(readlink -f /usr/bin/x-terminal-emulator)"
update-alternatives --query x-terminal-emulator

# Tc is in the fork's st-256color and absent from ncurses-term's.
infocmp -x st-256color >/tmp/st-256color
grep -q 'Tc,' /tmp/st-256color || fail "infocmp st-256color is not the fork's entry"
infocmp -x st-meta-256color >/dev/null
dpkg --verify ncurses-term st-h3nc4

apt-get purge -y -qq --autoremove st-h3nc4
snapshot >/tmp/after
diff /tmp/before /tmp/after || fail "purge left the paths above"
case "$(dpkg-divert --list)" in
	*st-h3nc4*) fail "purge left a diversion" ;;
esac
dpkg --verify ncurses-term
echo "${deb} installs and purges cleanly"
