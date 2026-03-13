#!/bin/sh
set -eu

USER_NAME="${USER_NAME:-user}"
USER_HOME="/home/${USER_NAME}"

export HOME="${USER_HOME}"
export USER="${USER_NAME}"
export LOGNAME="${USER_NAME}"
export DISPLAY="${DISPLAY:-:10}"
export XDG_RUNTIME_DIR="/tmp/runtime-${USER_NAME}"
export XAUTHORITY="${USER_HOME}/.Xauthority"
export XDG_CONFIG_HOME="${USER_HOME}/.config"
export XDG_DATA_HOME="${USER_HOME}/.local/share"
export XDG_CACHE_HOME="${USER_HOME}/.cache"

run_as_user() {
    if [ "$(id -un)" = "${USER_NAME}" ]; then
        sh -lc "$1"
    else
        su -s /bin/sh -c "$1" "${USER_NAME}"
    fi
}

WINDOWS="$(run_as_user 'wmctrl -lx 2>/dev/null | awk '\''BEGIN { IGNORECASE = 1 } /obsidian/ { print $1 }'\''' || true)"

[ -n "${WINDOWS}" ] || exit 1

FOCUS_DONE=0
for WINDOW_ID in ${WINDOWS}; do
    run_as_user "wmctrl -ir ${WINDOW_ID} -b remove,hidden >/dev/null 2>&1 || true"
    run_as_user "wmctrl -ir ${WINDOW_ID} -b add,maximized_vert,maximized_horz >/dev/null 2>&1 || true"

    if [ "${FOCUS_DONE}" -eq 0 ]; then
        run_as_user "wmctrl -ia ${WINDOW_ID} >/dev/null 2>&1 || true"
        FOCUS_DONE=1
    fi
done

exit 0
