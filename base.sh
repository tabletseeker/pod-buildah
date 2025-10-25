#!/bin/bash

set -x
set -o errexit
set -o nounset
set -o errtrace
set -o pipefail

cat > /etc/apt/sources.list.d/debian.sources << EOF
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: bookworm bookworm-updates
Components: main non-free-firmware
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://security.debian.org/debian-security
Suites: bookworm-security
Components: main non-free-firmware
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

apt-get update

DEBIAN_FRONTEND=noninteractive \
	apt-get install \
		--no-install-recommends \
		--yes \
			sudo ca-certificates

adduser --quiet --disabled-password --home "${HOME}" --gecos "${USER},,,," "${USER}" || true

printf '%s\n' "${USER} ALL=(ALL) NOPASSWD:ALL" | tee -- /etc/sudoers.d/passwordless_sudo >/dev/null

chmod 440 -- /etc/sudoers.d/passwordless_sudo

apt-get clean

rm -r -f /var/lib/apt/lists/* /var/cache/apt/*

cat > /etc/apt/apt.conf.d/00aptproxy << EOF
Acquire::http::Proxy "http://host.containers.internal:3142";
EOF
