#!/bin/sh
set -eu

USER_NAME="${USER_NAME:-user}"
USER_PASSWORD="${USER_PASSWORD:?USER_PASSWORD environment variable must be set}"
HOME_DIR="/home/${USER_NAME}"
RUNTIME_DIR="/tmp/runtime-${USER_NAME}"
USER_UID="$(id -u "${USER_NAME}")"
USER_GID="$(id -g "${USER_NAME}")"

ensure_user_dir() {
    TARGET="$1"

    mkdir -p "${TARGET}"

    if [ "$(stat -c '%u' "${TARGET}")" != "${USER_UID}" ] || [ "$(stat -c '%g' "${TARGET}")" != "${USER_GID}" ]; then
        chown -R "${USER_NAME}:${USER_NAME}" "${TARGET}"
    fi
}

ensure_user_dir "${HOME_DIR}/Obsidian Vault"
ensure_user_dir "${HOME_DIR}/.config/obsidian"
ensure_user_dir "${HOME_DIR}/.local/share/obsidian"
ensure_user_dir "${HOME_DIR}/.cache"
ensure_user_dir "${HOME_DIR}/.config/openbox"

mkdir -p /run/dbus /var/run/xrdp "${RUNTIME_DIR}"
touch "${HOME_DIR}/.Xauthority"

chown "${USER_NAME}:${USER_NAME}" "${HOME_DIR}" "${HOME_DIR}/.Xauthority" "${RUNTIME_DIR}"
chmod 700 "${RUNTIME_DIR}"

echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd

rm -f /var/run/xrdp/xrdp-sesman.pid /var/run/xrdp/xrdp.pid

if [ ! -S /run/dbus/system_bus_socket ]; then
    dbus-daemon --system --fork --nopidfile
fi

/usr/sbin/xrdp-sesman --nodaemon &
SES_PID=$!

/usr/sbin/xrdp --nodaemon &
XRDP_PID=$!

term_handler() {
    kill -TERM "${SES_PID}" "${XRDP_PID}" 2>/dev/null || true
    wait "${SES_PID}" 2>/dev/null || true
    wait "${XRDP_PID}" 2>/dev/null || true
    exit 0
}

trap term_handler INT TERM

while true; do
    if ! kill -0 "${SES_PID}" 2>/dev/null; then
        echo "xrdp-sesman exited"
        kill -TERM "${XRDP_PID}" 2>/dev/null || true
        wait "${XRDP_PID}" 2>/dev/null || true
        exit 1
    fi

    if ! kill -0 "${XRDP_PID}" 2>/dev/null; then
        echo "xrdp exited"
        kill -TERM "${SES_PID}" 2>/dev/null || true
        wait "${SES_PID}" 2>/dev/null || true
        exit 1
    fi

    sleep 2
done
