#!/bin/sh
set -eu

USER_NAME="${USER_NAME:-user}"
USER_PASSWORD="${USER_PASSWORD:-asdf}"

if id "${USER_NAME}" >/dev/null 2>&1; then
    echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd
fi

mkdir -p "/home/${USER_NAME}/Obsidian Vault"
mkdir -p "/home/${USER_NAME}/.config/obsidian"
mkdir -p "/home/${USER_NAME}/.local/share/obsidian"
mkdir -p "/home/${USER_NAME}/.cache"
mkdir -p "/home/${USER_NAME}/.config/openbox"
mkdir -p /run/dbus

touch "/home/${USER_NAME}/.Xauthority"

chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}"

rm -f /var/run/xrdp/xrdp-sesman.pid /var/run/xrdp/xrdp.pid
rm -f /run/dbus/pid

dbus-daemon --system --fork

/usr/sbin/xrdp-sesman --nodaemon &
exec /usr/sbin/xrdp --nodaemon