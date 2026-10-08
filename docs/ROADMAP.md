# Roadmap

What is planned but not installed yet, grouped by the stage it belongs to. Move an item to the
"Stacks" table in the [README](../README.md) once it is running.

There are two stages:

- **Stage 1 - Testing.** The desktop PC (Windows + Docker Desktop) simulates the server. Only
  things that run well there and are easy to move later.
- **Stage 2 - Home server.** The dedicated laptop (i7, 16GB RAM, 512GB NVMe), planned to run
  Linux, with permanent storage. Everything that needs Linux, a fixed disk layout, or is heavy.

## Done

| Tool | Stack | Since |
|---|---|---|
| Homarr (v2) + its own Tailscale machine `dashboard` | `dashboard` | 2026-10-07 |
| Uptime Kuma, with a status page feeding the Homarr integration | `monitoring` | 2026-10-07 |
| IT-Tools | `tools` | 2026-10-08 |
| WUD, reading Docker through a read-only socket proxy | `monitoring` | 2026-10-08 |

## Stage 1 - Testing (desktop PC)

| Tool | What it is for | Stack | Notes |
|---|---|---|---|
| Homarr widgets | Sonarr/Radarr calendar, download queue, Seerr requests | `dashboard` | Integrations are already connected; only board layout. |

## Stage 2 - Home server (dedicated laptop, Linux)

| Tool | What it is for | Stack / place | Notes |
|---|---|---|---|
| Uptime Kuma notifications | Telegram message when a service goes down | `monitoring` | Postponed to the server on purpose: on the test PC every shutdown would trigger alerts. No new container. |
| [Restic](https://restic.net/) backups | Nightly encrypted backup of every `appdata/` folder (config and databases, not media) | host, scheduled | Target: an external disk, maybe a second off-site target later. Covers homelab and streameron. |
| [Cockpit](https://cockpit-project.org/) | Web admin for the machine itself (disks, services, logs, updates) | host, not Docker | Linux only. Document under `docs/host-setup.md`. |
| [Tailscale SSH](https://tailscale.com/kb/1193/tailscale-ssh) | SSH into the server through the tailnet, no keys to manage | host, not Docker | Linux only. Document under `docs/host-setup.md`. |
| [Dockge](https://github.com/louislam/dockge) | Web UI to start/stop/edit the compose stacks | `dockge` | Works on one folder per stack, which is this repo's layout. Needs the Docker socket. |
| [FileBrowser](https://github.com/gtsteffaniak/filebrowser) | Browse and manage the server's files from the browser | `tools` | Wait for the final disk layout. |
| Pi-hole | Network-wide ad blocking / DNS | `network` | Moves here from the old Raspberry Pi 3. Host must be wired to the router with a reserved IP. |
| [n8n](https://github.com/n8n-io/n8n) | Workflow automation | `automation` | Later; not needed for the server to be useful. |
| [Immich](https://github.com/immich-app/immich) | Photos and videos with automatic phone backup (Google Photos replacement) | `photos` | Comes before Nextcloud. Database and thumbnails on the NVMe, original files on the big disk (see storage note). |
| [Nextcloud AIO](https://github.com/nextcloud/all-in-one) | Files sync and sharing (Drive replacement), calendar, contacts | `cloud` | Files only, photos go to Immich. Heaviest item; manages its own containers. Add last. |

## Open decisions

- **Linux distribution** for the dedicated laptop. Not needed before the server is set up.
- **Dockge and the Docker socket.** Dockge must manage containers, so the read-only proxy is not
  enough for it. Decide when it is added.

## Storage note (home server)

The 512GB NVMe holds what benefits from speed: the OS, Docker images, every stack's `appdata/`
(all databases), and Immich's database, thumbnails and transcoded previews. Large files that are
read sequentially go on the big disk: Immich originals, the media library, downloads.

## Decided

- **Photos and files (2026-10-08):** Immich for photos, Nextcloud for files, Immich first.
  Nextcloud is strong for files but basic for photos; Immich is built only for photos.

- **Backups (2026-10-08):** Restic, nightly, set up when the server is built. Only `appdata/`
  (config and databases); media is not backed up. A private git repo was considered and dropped:
  `appdata/` is mostly live SQLite databases and holds secrets (API keys, Tailscale identities).
  Moving `appdata/` from the test PC to the server is a separate one-time copy.

- **Docker socket for read-only tools (2026-10-08):** never mounted into the tool; they go
  through `socket-proxy`.

## Related, in the streameron repo

- **Maintainerr** - rule-based cleanup of watched or stale media. Belongs to the streaming stack,
  not here.
- **VPN for qBittorrent** (Gluetun + CyberGhost) - pre-wired there, currently disabled.
