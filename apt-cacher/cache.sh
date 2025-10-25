#!/bin/bash

set -x
set -o errexit
set -o nounset
set -o errtrace
set -o pipefail

CACHE_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd )"
DOCKER_DIR="$(dirname -- "${CACHE_DIR}")"

source "${DOCKER_DIR}/help-steps/variables"
source "${DOCKER_DIR}/help-steps/buildah"
source "${DOCKER_DIR}/help-steps/tmux"

ENGINE="${1}"
CACHER_VOLUME="${2}"
REBUILD_CACHE="${3}"
EXEC_NAME="apt-cacher-systemd"
TARGET_ITEM="apt-cacher"
TMUX_CMD="${ENGINE} exec -it ${EXEC_NAME} tail -f /var/log/apt-cacher-ng/apt-cacher.log"
readarray -t CACHE_SESSIONS <<<"$(tmux_list_sessions "${TARGET_ITEM}-[a-z0-9-]+")"

volume_setup() {
  mkdir --parents -- "${CACHER_VOLUME}"
  sudo -- chown --recursive -- "${HOST_USER}:${HOST_USER}" "${CACHER_VOLUME}"
  sudo -- chmod --recursive -- "770" "${CACHER_VOLUME}"
}

build_apt_cacher_image() {
	buildah_check_image "${CACHER_IMG}" "${REBUILD_CACHE}" || return 0

	if ctr=$(buildah from --format=docker -- "${CACHER_SOURCE}"); then
		buildah run -- "${ctr}" /bin/bash -c "$(cat -- "${CACHE_DIR}/base.sh")"

		buildah copy -- "${ctr}"	\
			"${CACHE_DIR}/acng.conf" "/etc/apt-cacher-ng/acng.conf"

		buildah \
			config \
				--env container="docker" \
				--env init="/lib/systemd/systemd" \
				--author="tabletseeker" \
				--label io.containers.maintainer="tabletseeker" \
				--label io.containers.title="apt-cacher-ng-systemd" \
				--label io.containers.description="Containerization of apt-cacher with systemd" \
				--healthcheck-interval "15s" \
				--healthcheck-retries "3" \
				--healthcheck-timeout "4s" \
				--healthcheck \
					"CMD wget -nv -t1 --spider http://localhost:3142/acng-report.html || exit 1" \
				--entrypoint '[ "/lib/systemd/systemd" ]' \
				-- \
					"${ctr}"

		buildah \
			commit \
				--format=docker \
				--omit-history \
				--rm \
				-- \
					"${ctr}" \
					"${CACHER_IMG}"

	else
		echo "ERROR - ${CACHER_SOURCE} pull or init failed!"

		exit 1
	fi
}

deploy_cacher_container() {
	if engine_check_container "${EXEC_NAME}"; then
		[ -n "${running}" ] || "${ENGINE}" "restart" -- "${ctr}"
	else
	"${ENGINE}" \
		run \
			--name "${EXEC_NAME}" \
			--detach \
			--publish 3142:3142/tcp \
			--tty \
			--interactive \
			--rm \
			--userns=keep-id:uid=0,gid=101 \
			--volume "/sys/fs/cgroup:/sys/fs/cgroup:ro" \
			--volume "${CACHER_VOLUME}:${CACHER_DIR}" \
				"${CACHER_IMG}"
	fi
}

tmux_start_session() {
	if [ -z "${CACHE_SESSIONS[@]}" ]; then
		sleep .4
		${TMUX_EXEC} new -d -s "${TARGET_ITEM}-$(tmux_create_uuid)" -n "${TARGET_ITEM}-win-$(tmux_create_uuid)" "${TMUX_CMD}" \; select-pane -T "${TARGET_ITEM}"
	fi
}

volume_setup

build_apt_cacher_image

deploy_cacher_container

tmux_start_session
