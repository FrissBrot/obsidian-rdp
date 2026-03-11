# obsidian-rdp

Remote Obsidian workspace for RDP/Guacamole, packaged as a small Docker Compose stack.

## Features

- Debian 12 based image with `xrdp`, `xorgxrdp`, `openbox`, and the Obsidian AppImage
- Persistent vault, app config, local share, and cache via bind mounts under `data/`
- Container-side hardening with disabled XRDP root login and Docker `no-new-privileges`
- Guacamole-compatible network attachment via `guacamole_guac_remote`
- Robust process supervision with `tini`, a listener-aware healthcheck, and an Obsidian session watchdog
- Startup tuned for large vaults by avoiding recursive ownership fixes when mounts are already owned correctly

## Repository Layout

- `Dockerfile`: image build, XRDP configuration, and Obsidian install
- `docker-compose.yml`: service definition and runtime configuration
- `skript/`: entrypoint and XRDP/Obsidian session scripts
- `container-config/`: Openbox window manager configuration
- `.env.example`: required environment variables template

## Required Environment Variables

Copy `.env.example` to `.env` and adjust the values:

```env
OBSIDIAN_VERSION=1.12.4
USER_PASSWORD=change-me
APP_MODE=restart
```

`USER_PASSWORD` is required at runtime.
`APP_MODE=restart` restarts Obsidian inside the existing XRDP session after crashes; `exit` closes the session when Obsidian exits.
`OBSIDIAN_VERSION` is used at build time to download the AppImage.

## Run

```bash
cp .env.example .env
docker compose build
docker compose up -d
```

The service joins the external Docker network `guacamole_guac_remote`. Ensure that network exists before starting the stack.

## Remote Access

By default the service is only reachable on the Docker network for Guacamole.
If you want direct RDP access on port `3389`, uncomment the `ports:` block in `docker-compose.yml`.

Login details:

- host: server IP or hostname
- port: `3389`
- username: `user`
- password: value from `.env`

## Hardening and Runtime Notes

- XRDP root logins and XRDP Fuse drive mounts are disabled.
- Docker `no-new-privileges` is enabled in the Compose service.
- The healthcheck verifies both XRDP processes and the local RDP listener on `127.0.0.1:3389`.
- `/dev/shm` remains available to Electron, so Obsidian no longer needs `--disable-dev-shm-usage`.
- Mounted directories are only fixed recursively when their top-level ownership is wrong, which reduces slow startups on large vaults.

## Data Handling

- `./data/Obsidian Vault` -> `/home/user/Obsidian Vault`
- `./data/config` -> `/home/user/.config/obsidian`
- `./data/local-share` -> `/home/user/.local/share/obsidian`
- `./data/cache` -> `/home/user/.cache`

## Logs

- `/home/user/obsidian.log`
- `/home/user/.xsession.log`

## License

This project packages Obsidian for containerized remote use.
Obsidian itself is proprietary software: https://obsidian.md/license
