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
| Event Seeker, as a published image (`ghcr.io/ron45700/event-seeker`) with health endpoints for Uptime Kuma and its own Telegram alerts | `event-seeker` | 2026-10-09 |

## Stage 1 - Testing (desktop PC)

| Tool | What it is for | Stack | Notes |
|---|---|---|---|
| Homarr widgets | Sonarr/Radarr calendar, download queue, Seerr requests | `dashboard` | Integrations are already connected; only board layout. |
| [Dozzle](https://github.com/amir20/dozzle) | Live logs of every container (homelab and streameron) in the browser, to see what happens at the moment playback stalls | `monitoring` | Next to add. Reads Docker through `socket-proxy` (`DOCKER_HOST=tcp://socket-proxy:2375`; the proxy may also need `INFO=1`). Stores nothing, so no `appdata/`. Pick a free port (8080 is Dozzle's default and may be taken). On the dashboard: a Homarr app tile, optionally an iFrame widget. |

## Stage 2 - Home server (dedicated laptop, Linux)

| Tool | What it is for | Stack / place | Notes |
|---|---|---|---|
| Uptime Kuma notifications | Telegram message when a service goes down | `monitoring` | Postponed to the server on purpose: on the test PC every shutdown would trigger alerts. No new container. Reuse the bot and chat id already set up for Event Seeker's alerts (`stacks/event-seeker/.env`). |
| [Restic](https://restic.net/) backups | Nightly encrypted backup of every `appdata/` folder (config and databases, not media) | host, scheduled | Target: an external disk, maybe a second off-site target later. Covers homelab and streameron. |
| [Cockpit](https://cockpit-project.org/) | Web admin for the machine itself (disks, services, logs, updates) | host, not Docker | Linux only. Document under `docs/host-setup.md`. |
| [Tailscale SSH](https://tailscale.com/kb/1193/tailscale-ssh) | SSH into the server through the tailnet, no keys to manage | host, not Docker | Linux only. Document under `docs/host-setup.md`. |
| System metrics: [Beszel](https://github.com/henrygd/beszel) **or** [Dash.](https://github.com/MauriceNino/dashdot) | CPU, RAM, space and I/O per disk, temperatures of the server | `monitoring` | Not decided yet, see Open decisions. Needs real Linux to see the hardware (temperatures, disks). |
| [Scrutiny](https://github.com/AnalogJ/scrutiny) | Disk health (SMART) and disk temperature over time, with a warning before a disk fails | `monitoring` | Needs direct access to the disks, so Linux only. |
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

- **Beszel or Dash. for system metrics.** Beszel: very light, keeps history, alerts, per-container
  usage, but shows in Homarr only as an app tile / iFrame. Dash.: nicer live view and (to be
  verified) feeds Homarr's built-in system health widget, but no real history or alerts.
  Cockpit (above) already gives the host's logs and a live view either way.

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

- **Log viewer (2026-10-09):** Dozzle, in the `monitoring` stack, added already in the testing
  stage because it is needed to debug playback stalls. It shows what containers print (Jellyfin,
  Sonarr, qBittorrent...). It does not show Jellyfin's FFmpeg transcode logs (files, under
  Jellyfin's Dashboard > Logs) or disk errors of the host (Windows Event Viewer now, Cockpit on
  the server). Heavier log stacks (Loki + Grafana) were not chosen: no need to keep or search
  history for a single user.

- **Own projects on the server (2026-10-09):** a project of mine (Event Seeker) is not cloned
  or built on the server. Its repo publishes an image to GitHub's registry (ghcr.io) on every
  push, and a stack here runs that image like any third-party one. Updating is then pull + up
  (Dockge's Update button later), and WUD reports new builds. ghcr.io was chosen over Docker
  Hub because the Action pushes with the repo's built-in token: no extra account or secrets.

## Related, in the streameron repo

- **Maintainerr** - rule-based cleanup of watched or stale media. Belongs to the streaming stack,
  not here.
- **VPN for qBittorrent** (Gluetun + CyberGhost) - pre-wired there, currently disabled.
