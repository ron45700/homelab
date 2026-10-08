# Roadmap

What is planned but not installed yet, grouped by the stage it belongs to. Move an item to the
"Stacks" table in the [README](../README.md) once it is running.

There are two stages:

- **Stage 1 - Testing.** The desktop PC (Windows + Docker Desktop) simulates the server. Only
  things that run well there and are easy to move later.
- **Stage 2 - Home server.** The dedicated laptop (i7, 16GB RAM), planned to run Linux, with
  permanent storage. Everything that needs Linux, a fixed disk layout, or is heavy.

## Done

| Tool | Stack | Since |
|---|---|---|
| Homarr (v2) + its own Tailscale machine `dashboard` | `dashboard` | 2026-10-07 |
| Uptime Kuma, with a status page feeding the Homarr integration | `monitoring` | 2026-10-07 |

## Stage 1 - Testing (desktop PC)

| Tool | What it is for | Stack | Notes |
|---|---|---|---|
| Uptime Kuma notifications | Message to the phone when a service goes down | `monitoring` | No new container. Settings -> Notifications (Telegram / Discord). |
| Homarr widgets | Sonarr/Radarr calendar, download queue, Seerr requests | `dashboard` | Integrations are already connected; only board layout. |
| [IT-Tools](https://github.com/CorentinTh/it-tools) | Developer utilities (converters, generators, encoders) | `tools` | One container, no configuration. |
| [WUD](https://github.com/getwud/wud) | Shows which containers have a newer image available | `monitoring` | Needs the Docker socket (read-only). First tool that does; decide before adding. |

## Stage 2 - Home server (dedicated laptop, Linux)

| Tool | What it is for | Stack / place | Notes |
|---|---|---|---|
| [Cockpit](https://cockpit-project.org/) | Web admin for the machine itself (disks, services, logs, updates) | host, not Docker | Linux only. Document under `docs/host-setup.md`. |
| [Tailscale SSH](https://tailscale.com/kb/1193/tailscale-ssh) | SSH into the server through the tailnet, no keys to manage | host, not Docker | Linux only. Document under `docs/host-setup.md`. |
| [Dockge](https://github.com/louislam/dockge) | Web UI to start/stop/edit the compose stacks | `dockge` | Works on one folder per stack, which is this repo's layout. Needs the Docker socket. |
| [FileBrowser](https://github.com/gtsteffaniak/filebrowser) | Browse and manage the server's files from the browser | `tools` | Wait for the final disk layout. |
| Pi-hole | Network-wide ad blocking / DNS | `network` | Moves here from the old Raspberry Pi 3. Host must be wired to the router with a reserved IP. |
| [n8n](https://github.com/n8n-io/n8n) | Workflow automation | `automation` | Later; not needed for the server to be useful. |
| [Nextcloud AIO](https://github.com/nextcloud/all-in-one) | Files sync and sharing (Drive replacement), calendar, contacts | `cloud` | Heaviest item; manages its own containers. Add last. See open decisions. |

## Open decisions

- **Photos: Nextcloud only, or Nextcloud + Immich?** Nextcloud is strong for files and basic for
  photos (phone auto-backup, face recognition and content search are weaker or need extra apps).
  Immich is built only for photos and is closer to Google Photos. Options: Nextcloud alone,
  Nextcloud for files + Immich for photos, or Immich first and Nextcloud later. Decide when the
  permanent storage is in place.
- **Docker socket.** WUD and Dockge need it. Access to the socket is effectively control of the
  host, so each tool that gets it should be a deliberate choice (read-only where possible).
- **Linux distribution** for the dedicated laptop.
- **Backups.** Every stack's `appdata/` (and streameron's config folder) lives on one disk with no
  copy. Pick a backup target and schedule before the server holds anything that matters.

## Related, in the streameron repo

- **Maintainerr** - rule-based cleanup of watched or stale media. Belongs to the streaming stack,
  not here.
- **VPN for qBittorrent** (Gluetun + CyberGhost) - pre-wired there, currently disabled.
