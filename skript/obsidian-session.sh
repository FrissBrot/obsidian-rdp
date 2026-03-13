#!/bin/sh
set -eu

USER_NAME="${USER_NAME:-user}"
USER_HOME="/home/${USER_NAME}"
LOG_FILE="${USER_HOME}/obsidian.log"
WATCHDOG_REASON_FILE="${USER_HOME}/.cache/obsidian-watchdog.reason"

export HOME="${USER_HOME}"
export USER="${USER_NAME}"
export LOGNAME="${USER_NAME}"
export XDG_CONFIG_HOME="${USER_HOME}/.config"
export XDG_DATA_HOME="${USER_HOME}/.local/share"
export XDG_CACHE_HOME="${USER_HOME}/.cache"
export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"
export LANGUAGE="${LANGUAGE:-C.UTF-8}"
export APP_MODE="${APP_MODE:-restart}"

mkdir -p "${USER_HOME}/.cache"
touch "${LOG_FILE}"

run_as_user() {
    if [ "$(id -un)" = "${USER_NAME}" ]; then
        sh -lc "$1"
    else
        su -s /bin/sh -c "$1" "${USER_NAME}"
    fi
}

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "${LOG_FILE}"
}

find_obsidian_windows() {
    run_as_user 'wmctrl -lx 2>/dev/null | awk '\''tolower($3) ~ /obsidian/ { print $1 }'\'''
}

openbox_running() {
    run_as_user 'pgrep -x openbox >/dev/null 2>&1'
}

restart_openbox() {
    log "Watchdog: Openbox fehlt, versuche Window-Manager neu zu starten."
    run_as_user "DISPLAY=${DISPLAY} openbox-session >/tmp/openbox-recovery.log 2>&1 &"
    sleep 3
    openbox_running
}

kill_obsidian() {
    run_as_user "pkill -TERM -u ${USER_NAME} -f '/opt/obsidian/obsidian' >/dev/null 2>&1 || true"
    sleep 3
    run_as_user "pkill -KILL -u ${USER_NAME} -f '/opt/obsidian/obsidian' >/dev/null 2>&1 || true"
}

root_is_black() {
    if ! command -v import >/dev/null 2>&1; then
        return 1
    fi

    MEAN="$(run_as_user "import -display ${DISPLAY} -window root -resize 64x64 -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null" || true)"
    [ -n "${MEAN}" ] || return 1

    awk -v mean="${MEAN}" 'BEGIN { exit !(mean <= 0.02) }'
}

watchdog() {
    APP_WRAPPER_PID="$1"
    CHECK_INTERVAL="${WATCHDOG_INTERVAL:-5}"
    STARTUP_GRACE="${WATCHDOG_STARTUP_GRACE:-30}"
    WINDOW_GRACE="${WATCHDOG_WINDOW_GRACE:-20}"
    BLACKOUT_GRACE="${WATCHDOG_BLACKOUT_GRACE:-15}"

    START_TS="$(date +%s)"
    WINDOW_MISSING_SINCE=0
    BLACKOUT_SINCE=0

    while kill -0 "${APP_WRAPPER_PID}" 2>/dev/null; do
        NOW="$(date +%s)"
        WINDOWS="$(find_obsidian_windows || true)"

        if ! openbox_running; then
            if ! restart_openbox; then
                printf '%s\n' "window-manager-missing" > "${WATCHDOG_REASON_FILE}"
                log "Watchdog: Openbox konnte nicht neu gestartet werden."
                kill_obsidian
                return 0
            fi

            WINDOWS="$(find_obsidian_windows || true)"
        fi

        if [ -n "${WINDOWS}" ]; then
            WINDOW_MISSING_SINCE=0
            BLACKOUT_SINCE=0
        else
            if [ "${WINDOW_MISSING_SINCE}" -eq 0 ]; then
                WINDOW_MISSING_SINCE="${NOW}"
            fi

            if [ $((NOW - START_TS)) -ge "${STARTUP_GRACE}" ] && [ $((NOW - WINDOW_MISSING_SINCE)) -ge "${WINDOW_GRACE}" ]; then
                printf '%s\n' "obsidian-window-missing" > "${WATCHDOG_REASON_FILE}"
                log "Watchdog: kein sichtbares Obsidian-Fenster mehr, erzwinge Neustart."
                kill_obsidian
                return 0
            fi
        fi

        if root_is_black; then
            if [ "${BLACKOUT_SINCE}" -eq 0 ]; then
                BLACKOUT_SINCE="${NOW}"
            fi

            if [ $((NOW - START_TS)) -ge "${STARTUP_GRACE}" ] && [ $((NOW - BLACKOUT_SINCE)) -ge "${BLACKOUT_GRACE}" ]; then
                printf '%s\n' "root-blackout" > "${WATCHDOG_REASON_FILE}"
                log "Watchdog: Root-Fenster bleibt schwarz, erzwinge Neustart."
                kill_obsidian
                return 0
            fi
        else
            BLACKOUT_SINCE=0
        fi

        sleep "${CHECK_INTERVAL}"
    done
}

log "==== obsidian-session.sh gestartet ===="
log "DISPLAY=${DISPLAY:-unset} APP_MODE=${APP_MODE}"

RESTART_DELAY_BASE="${RESTART_DELAY_BASE:-2}"
RESTART_DELAY_MAX="${RESTART_DELAY_MAX:-20}"
RESTART_STABLE_SECONDS="${RESTART_STABLE_SECONDS:-45}"
RESTART_DELAY="${RESTART_DELAY_BASE}"

while true; do
    rm -f "${WATCHDOG_REASON_FILE}"

    START_TS="$(date +%s)"
    /usr/local/bin/start-obsidian.sh &
    APP_WRAPPER_PID=$!
    /usr/local/bin/obsidian-window-guardian.sh &
    GUARDIAN_PID=$!
    watchdog "${APP_WRAPPER_PID}" &
    WATCHDOG_PID=$!

    APP_RC=0
    wait "${APP_WRAPPER_PID}" || APP_RC=$?

    kill "${GUARDIAN_PID}" 2>/dev/null || true
    wait "${GUARDIAN_PID}" 2>/dev/null || true
    kill "${WATCHDOG_PID}" 2>/dev/null || true
    wait "${WATCHDOG_PID}" 2>/dev/null || true

    END_TS="$(date +%s)"
    RUNTIME=$((END_TS - START_TS))
    WATCHDOG_REASON=""
    if [ -f "${WATCHDOG_REASON_FILE}" ]; then
        WATCHDOG_REASON="$(cat "${WATCHDOG_REASON_FILE}" 2>/dev/null || true)"
    fi

    log "Obsidian-Lauf beendet: rc=${APP_RC} runtime=${RUNTIME}s watchdog=${WATCHDOG_REASON:-none}"

    if [ -n "${WATCHDOG_REASON}" ]; then
        if [ "${WATCHDOG_REASON}" = "window-manager-missing" ]; then
            log "Window-Manager fehlt dauerhaft, Session wird beendet."
            exit 1
        fi

        if [ "${APP_MODE}" = "exit" ]; then
            log "APP_MODE=exit, trotz Watchdog kein Neustart."
            exit 0
        fi

        RESTART_DELAY=$((RESTART_DELAY * 2))
        if [ "${RESTART_DELAY}" -gt "${RESTART_DELAY_MAX}" ]; then
            RESTART_DELAY="${RESTART_DELAY_MAX}"
        fi
        log "Neustart nach Watchdog in ${RESTART_DELAY}s."
        sleep "${RESTART_DELAY}"
        continue
    fi

    if [ "${APP_RC}" -eq 0 ]; then
        log "Obsidian sauber beendet, X-Session wird geschlossen."
        exit 0
    fi

    if [ "${APP_MODE}" = "exit" ]; then
        log "APP_MODE=exit und Obsidian fehlerhaft beendet, Session endet."
        exit "${APP_RC}"
    fi

    if [ "${RUNTIME}" -ge "${RESTART_STABLE_SECONDS}" ]; then
        RESTART_DELAY="${RESTART_DELAY_BASE}"
    else
        RESTART_DELAY=$((RESTART_DELAY * 2))
        if [ "${RESTART_DELAY}" -gt "${RESTART_DELAY_MAX}" ]; then
            RESTART_DELAY="${RESTART_DELAY_MAX}"
        fi
    fi

    log "Obsidian ist abgestuerzt, Neustart in ${RESTART_DELAY}s."
    sleep "${RESTART_DELAY}"
done
