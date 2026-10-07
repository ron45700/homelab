# homelab

Everything on the home server that is not the streaming system. The streaming stack
(Jellyfin, *arr, qBittorrent, ...) lives in its own repo, `streameron`, and the two repos do not
depend on each other.

## Layout

One folder per stack under `stacks/`. Each stack is self-contained:

```
stacks/<name>/
  compose.yaml    # the services
  .env.example    # template for secrets/settings -> copy to .env
  appdata/        # the apps' data (git-ignored, created on first run)
```

Run a stack from inside its folder:

```bash
cd stacks/<name>
docker compose up -d
```

## Stacks

| Stack | Services | Address | Status |
|---|---|---|---|
| `dashboard` | Homarr + its Tailscale machine | http://localhost:7575, https://dashboard.<tailnet>.ts.net | in use |

Planned: `monitoring` (Uptime Kuma, WUD), `tools` (IT-Tools, FileBrowser), `dockge`,
`network` (Pi-hole), `automation` (n8n), `cloud` (Nextcloud AIO). Host-level tools that are not
containers (Cockpit, Tailscale SSH) will be documented under `docs/` once the server runs Linux.

## Conventions

- **No shared Docker networks between stacks or with streameron.** A service that needs another
  stack's service reaches it through the host's published port:
  `http://host.docker.internal:<port>`.
- **Remote access** is through the Tailscale app on the host (`http://<host>:<port>`). A
  per-service Tailscale container is the exception, for a service that deserves its own
  easy-to-find name (the dashboard) or is shared with other people.
- **Secrets** go in each stack's `.env`, never in git.
- The Docker socket is not mounted into a container unless a feature really needs it.

## dashboard (Homarr)

### First run

1. `cd stacks/dashboard`, copy `.env.example` to `.env`, fill `SECRET_ENCRYPTION_KEY`.
2. `docker compose up -d`, open http://localhost:7575 and complete onboarding.
3. Add the streameron integrations. For each one:
   - **Integration URL** (used by Homarr itself): `http://host.docker.internal:<port>`
   - **App URL** (what the browser opens): the host's LAN IP or Tailscale name

| Service | Port |
|---|---|
| Jellyfin | 8096 |
| Seerr | 5055 |
| Sonarr | 8989 |
| Radarr | 7878 |
| Bazarr | 6767 |
| Prowlarr | 9696 |
| qBittorrent | 8080 |

### Backup / moving hosts

Stop the stack, copy `stacks/dashboard/appdata/` and the `.env` to the new host. The same
`SECRET_ENCRYPTION_KEY` must come along, otherwise the saved integration keys cannot be read.

`appdata/tailscale/` is the `dashboard` machine's identity (private key, treat as a secret).
Copied along, the machine keeps its name. Never run the same state on two hosts at once.
