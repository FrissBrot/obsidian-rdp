#!/bin/sh

USER_NAME="${USER_NAME:-user}"
USER_HOME="/home/${USER_NAME}"

export HOME="${USER_HOME}"
export USER="${USER_NAME}"
export LOGNAME="${USER_NAME}"
export DISPLAY="${DISPLAY:-:10}"
export XDG_CONFIG_HOME="${USER_HOME}/.config"
export XDG_DATA_HOME="${USER_HOME}/.local/share"
export XDG_CACHE_HOME="${USER_HOME}/.cache"

mkdir -p "${USER_HOME}/Obsidian Vault"
mkdir -p "${USER_HOME}/.config/obsidian"
mkdir -p "${USER_HOME}/.local/share/obsidian"
mkdir -p "${USER_HOME}/.cache"
mkdir -p "${USER_HOME}/.config/openbox"

LOG_FILE="${USER_HOME}/obsidian.log"
touch "$LOG_FILE"
touch "${USER_HOME}/.config/obsidian/obsidian.log"
chown "${USER_NAME}:${USER_NAME}" "$LOG_FILE" "${USER_HOME}/.config/obsidian/obsidian.log" 2>/dev/null || true

echo "==== start-obsidian.sh gestartet: $(date) ====" >> "$LOG_FILE"
echo "DISPLAY=$DISPLAY" >> "$LOG_FILE"
echo "HOME=$HOME" >> "$LOG_FILE"
echo "APP_MODE=${APP_MODE:-exit}" >> "$LOG_FILE"

APP_CMD='cd /opt/obsidian && dbus-launch ./obsidian --start-maximized --no-sandbox --disable-gpu --vault "'"${USER_HOME}"'/Obsidian Vault"'

run_as_user() {
    if [ "$(id -un)" = "${USER_NAME}" ]; then
        sh -lc "$1"
    else
        su -s /bin/sh -c "$1" "${USER_NAME}"
    fi
}

maximize_and_clean() {
    for i in 1 2 3 4 5 6 7 8 9 10; do
        WINDOWS="$(run_as_user 'wmctrl -l 2>/dev/null | awk "{print \$1}"')"
        [ -n "$WINDOWS" ] && break
        sleep 1
    done

    echo "=== wmctrl -lx ===" >> "$LOG_FILE"
    run_as_user 'wmctrl -lx' >> "$LOG_FILE" 2>&1 || true

    for W in $(run_as_user 'wmctrl -l 2>/dev/null | awk "{print \$1}"'); do
        run_as_user "wmctrl -i -r $W -b add,maximized_vert,maximized_horz" >> "$LOG_FILE" 2>&1 || true
        run_as_user "wmctrl -i -r $W -b add,above" >> "$LOG_FILE" 2>&1 || true
    done
}

start_once() {
    echo "Starte Obsidian: $(date)" >> "$LOG_FILE"

    run_as_user "$APP_CMD" >> "$LOG_FILE" 2>&1 &
    APP_PID=$!

    maximize_and_clean

    wait $APP_PID
    RC=$?

    echo "Obsidian beendet mit Code $RC: $(date)" >> "$LOG_FILE"

    return $RC
}

if [ "${APP_MODE:-exit}" = "restart" ]; then
    while true; do
        start_once
        sleep 2
    done
else
    start_once
    echo "Beende Openbox-Session: $(date)" >> "$LOG_FILE"
    openbox --exit >> "$LOG_FILE" 2>&1 || true
fi
