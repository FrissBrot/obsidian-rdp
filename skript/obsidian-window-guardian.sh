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

while :; do
    WINDOWS="$(run_as_user 'wmctrl -lx 2>/dev/null | awk '\''BEGIN { IGNORECASE = 1 } /obsidian/ { print $1 }'\''' || true)"

    if [ -n "${WINDOWS}" ]; then
        for WINDOW_ID in ${WINDOWS}; do
            STATE="$(run_as_user "xprop -id ${WINDOW_ID} _NET_WM_STATE 2>/dev/null" || true)"

            case "${STATE}" in
                *_NET_WM_STATE_HIDDEN*)
                    /usr/local/bin/restore-obsidian-window.sh >/dev/null 2>&1 || true
                    break
                    ;;
            esac

            case "${STATE}" in
                *_NET_WM_STATE_MAXIMIZED_VERT*)
                    ;;
                *)
                    run_as_user "wmctrl -ir ${WINDOW_ID} -b add,maximized_vert >/dev/null 2>&1 || true"
                    ;;
            esac

            case "${STATE}" in
                *_NET_WM_STATE_MAXIMIZED_HORZ*)
                    ;;
                *)
                    run_as_user "wmctrl -ir ${WINDOW_ID} -b add,maximized_horz >/dev/null 2>&1 || true"
                    ;;
            esac
        done
    fi

    sleep "${OBSIDIAN_GUARDIAN_INTERVAL:-0.5}"
done
