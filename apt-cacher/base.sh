#!/bin/bash

set -x
set -o errexit
set -o nounset
set -o errtrace
set -o pipefail

install_packages() {
	apt-get update

	DEBIAN_FRONTEND=noninteractive \
		apt-get install \
			--no-install-recommends \
			--yes \
				systemd apt-cacher-ng wget

	apt-get clean

	rm \
		--recursive \
		--force \
			/var/lib/apt/lists/* \
			/var/cache/apt/*
}

systemd_cleanup() {
	find \
		/etc/systemd/system/*.wants/* \
		/lib/systemd/system/multi-user.target.wants/* \
		/lib/systemd/system/sockets.target.wants/*initctl* \
		! -type d \
		-delete 2>/dev/null

	find \
		/lib/systemd/system/sysinit.target.wants \
		! -type d \
		! -name '*systemd-tmpfiles-setup*' \
		-delete	

	find \
		/lib/systemd \
		-name systemd-update-utmp-runlevel.service \
		-delete

	rm \
		--verbose \
		--force \
			/usr/share/systemd/tmp.mount

	sed \
		--regexp-extended \
		--in-place \
			'/^IPAddressDeny/d' /lib/systemd/system/systemd-journald.service
}

fix_null_entries() {
	SERVICES=(
	"plymouth-start.service"
	"plymouth-quit-wait.service"
	"syslog.socket"
	"syslog.service"
	"display-manager.service"
	"systemd-sysusers.service"
	"tmp.mount"
	"systemd-udevd.service")

  while (( ${#SERVICES[@]} > 0 )); do
		find  \
			/lib/systemd \
		! -type d \
			-exec \
				grep \
					--files-with-matches \
					--binary-files=without-match \
						"${SERVICES[0]}" \
					-- \
						{} \; \
		| \
			xargs \
				sed \
					--regexp-extended \
					--in-place \
					-- \
						's/(.*=.*)'${SERVICES[0]}'(.*)/\1\2/'

    SERVICES=("${SERVICES[@]:1}")
  done
}

service_setup() {
	systemctl enable apt-cacher-ng
	systemctl set-default multi-user.target
}

install_packages
systemd_cleanup
fix_null_entries
service_setup
