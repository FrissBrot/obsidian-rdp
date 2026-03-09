# obsidian-rdp

Run **Obsidian** inside a **Docker container** and access it remotely via **RDP**.

This project provides a lightweight Debian-based container that starts an **XRDP session with Openbox** and launches **Obsidian automatically**.
It is useful if you want to run Obsidian on a server, NAS, or remote machine and access it from any device via Remote Desktop.

---

# Features

* Obsidian runs inside a Docker container
* Remote access via **RDP (port 3389)**
* Lightweight **Openbox desktop environment**
* Automatic Obsidian startup
* Customizable user and password via environment variables
* Persistent vault via Docker volumes
* Works on servers, NAS systems, or headless machines

---

# Architecture

The container includes:

* **Debian 12**
* **XRDP + XorgXRDP**
* **Openbox window manager**
* **Obsidian AppImage**
* **DBus session**
* minimal fonts and GUI libraries

Startup flow:

```
docker-entrypoint
        │
        ▼
xrdp-sesman + xrdp
        │
        ▼
Openbox session
        │
        ▼
start-obsidian.sh
        │
        ▼
Obsidian launches automatically
```

---

# Quick Start

## Build the image

```
docker build -t obsidian-rdp .
```

## Run the container

```
docker run -d \
  -p 3389:3389 \
  -e USER_NAME=user \
  -e USER_PASSWORD=asdf \
  -v ./vault:/home/user/Obsidian\ Vault \
  --name obsidian \
  obsidian-rdp
```

---

# Connect

Connect using any **Remote Desktop client**:

```
host: <server-ip>
port: 3389
username: user
password: asdf
```

After login, the Openbox session will start and **Obsidian opens automatically**.

---

# Configuration

## Environment Variables

| Variable           | Description                  | Default  |
| ------------------ | ---------------------------- | -------- |
| `USER_NAME`        | Linux user inside container  | `user`   |
| `USER_PASSWORD`    | Login password               | `asdf`   |
| `APP_MODE`         | `exit` or `restart`          | `exit`   |
| `OBSIDIAN_VERSION` | Obsidian version to download | `1.12.4` |

---

# Persistent Vault

To keep your notes persistent, mount a volume:

```
-v ./vault:/home/user/Obsidian\ Vault
```

Your notes will be stored on the host in the `vault` directory.

---

# Container Ports

| Port | Purpose             |
| ---- | ------------------- |
| 3389 | XRDP remote desktop |

---

# Logs

Obsidian logs are written to:

```
/home/user/obsidian.log
```

---

# Security Notes

This container exposes an **RDP server**.
For production environments consider:

* using a **VPN**
* placing it behind a **reverse proxy**
* restricting access via **firewall**

---

# Updating Obsidian

Change the build argument:

```
docker build --build-arg OBSIDIAN_VERSION=1.13.0 -t obsidian-rdp .
```

---

# License

This project only packages Obsidian for containerized use.

Obsidian is proprietary software.
See:

https://obsidian.md/license
