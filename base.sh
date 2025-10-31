#!/bin/bash

set -x
set -o errexit
set -o nounset
set -o errtrace
set -o pipefail

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
