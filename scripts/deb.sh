#!/bin/sh

# Builds st-h3nc4_<version>_amd64.deb from the checked out commit into $1, dist by default.
# Build it on trixie. On the sid dev image dpkg-shlibdeps can demand library versions trixie lacks.

set -eu

cd "$(dirname "$0")/../"

out="${1:-dist}"
upstream="$(sed -n 's/^VERSION = //p' config.mk)"
# The commit time sorts every build of one upstream version in order, and the hash identifies the commit.
stamp="$(TZ=UTC git log -1 --format=%cd --date=format-local:%Y%m%d%H%M%S)"
version="${upstream}+git${stamp}.$(git rev-parse --short=8 HEAD)"

umask 022
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
root="${work}/root"
doc="${root}/usr/share/doc/st-h3nc4"

export DEB_BUILD_MAINT_OPTIONS=hardening=+all
make clean
make \
	CFLAGS="$(dpkg-buildflags --get CFLAGS)" \
	CPPFLAGS="$(dpkg-buildflags --get CPPFLAGS)" \
	LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"

install -Dm755 st "${root}/usr/bin/st"
strip --strip-unneeded --remove-section=.comment --remove-section=.note "${root}/usr/bin/st"
mkdir -p "${root}/usr/share/man/man1" "${root}/usr/share/terminfo" "${doc}"
sed "s/VERSION/${upstream}/g" st.1 | gzip -9n >"${root}/usr/share/man/man1/st.1.gz"
tic -x -o "${root}/usr/share/terminfo" st.info
install -m644 LICENSE "${doc}/copyright"
printf '%s\n' \
	"st-h3nc4 (${version}) unstable; urgency=medium" \
	"" \
	"  * Build of commit $(git rev-parse HEAD)." \
	"" \
	" -- Dreamweaver <me@h3nc4.com>  $(git log -1 --format=%cD)" |
	gzip -9n >"${doc}/changelog.gz"

install -d "${root}/DEBIAN"
(cd "${root}" && find usr -type f -exec md5sum {} +) >"${root}/DEBIAN/md5sums"
install -m755 scripts/deb/preinst scripts/deb/postinst scripts/deb/prerm scripts/deb/postrm "${root}/DEBIAN/"

# dpkg-shlibdeps reads debian/control from the directory it runs in, and only for the package list.
mkdir "${work}/debian"
printf 'Source: st-h3nc4\n\nPackage: st-h3nc4\nArchitecture: amd64\n' >"${work}/debian/control"
deps="$(cd "${work}" && dpkg-shlibdeps -O root/usr/bin/st | sed -n 's/^shlibs:Depends=//p')"

printf '%s\n' \
	"Package: st-h3nc4" \
	"Version: ${version}" \
	"Architecture: amd64" \
	"Maintainer: Dreamweaver <me@h3nc4.com>" \
	"Installed-Size: $(du -sk --exclude=DEBIAN "${root}" | cut -f1)" \
	"Depends: ${deps}" \
	"Conflicts: stterm" \
	"Replaces: stterm" \
	"Provides: x-terminal-emulator" \
	"Section: x11" \
	"Priority: optional" \
	"Homepage: https://github.com/h3nc4/st" \
	"Description: simple terminal emulator for X, h3nc4 build" \
	" st ${upstream} from suckless.org with the patches and configuration of the" \
	" h3nc4 fork, as the terminal of Dreamweaver. It also installs the fork's own" \
	" st terminfo entries, which take the place of those in ncurses-term." \
	>"${root}/DEBIAN/control"

mkdir -p "${out}"
dpkg-deb --root-owner-group --build "${root}" "${out}/st-h3nc4_${version}_amd64.deb"
