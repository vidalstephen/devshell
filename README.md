# DevShell — Ubuntu 24.04 Development Container for Synology NAS

A containerized Ubuntu 24.04 development environment running on a Synology NAS, accessible via VS Code Remote SSH from any machine.

## Features

- **Ubuntu 24.04 LTS** base image
- **SSH-only authentication** (key-based, no passwords)
- **Docker CLI + Compose v2** via host socket passthrough
- **Full `/volume1` access** — NAS files accessible at the same path inside the container, so `docker compose` file references resolve correctly
- **Persistent VS Code Server** — named volume survives container restarts (no re-download on reconnect)
- **User identity mirroring** — UID/GID matches Synology user account
- **GitHub Actions CI/CD** — image built externally to avoid DS220+ CPU load, pushed to GHCR

## Architecture

```
VS Code (Windows)
  └─ SSH ProxyCommand
       └─ ssh synology (port 54321)
            └─ docker exec devshell nc localhost 22
                 └─ devshell container (Ubuntu 24.04)
                      ├─ /var/run/docker.sock → host Docker
                      └─ /volume1 → NAS storage
```

Traffic flow for web services:
```
Internet → Cloudflare Tunnel → cloudflared container → Traefik (:8080) → services
```

## Prerequisites

### On Synology NAS

```bash
# Get Docker socket GID
stat -c %g /var/run/docker.sock

# Create stack directory and SSH keys directory
mkdir -p /volume1/docker/stacks/devshell/ssh

# Add your public SSH key
cat ~/.ssh/id_ed25519.pub >> /volume1/docker/stacks/devshell/ssh/authorized_keys
chmod 600 /volume1/docker/stacks/devshell/ssh/authorized_keys
```

## Deployment

### 1. Clone / copy files to NAS

```bash
mkdir -p /volume1/docker/stacks/devshell
cd /volume1/docker/stacks/devshell
# Copy docker-compose.yml here
```

### 2. Create `.env`

```bash
cp .env.example .env
nano .env
```

```env
GITHUB_USERNAME=vidalstephen
USERNAME=msn0624c
USER_UID=1026
USER_GID=100
ADMIN_GID=101
DOCKER_GID=968        # use value from: stat -c %g /var/run/docker.sock
DOCKER_API_VERSION=1.43
```

### 3. Deploy

```bash
cd /volume1/docker/stacks/devshell
/usr/local/bin/docker compose pull
/usr/local/bin/docker compose up -d
```

## VS Code Remote SSH Setup

### `~/.ssh/config`

```
Host synology
  HostName ngaged.synology.me
  User msn0624c
  Port 54321
  IdentityFile ~/.ssh/id_ed25519

Host devshell
  HostName localhost
  Port 22
  User msn0624c
  IdentityFile ~/.ssh/id_ed25519
  ProxyCommand ssh -p 54321 msn0624c@ngaged.synology.me "/usr/local/bin/docker exec -i devshell nc localhost 22"
```

### VS Code Settings

Add to `settings.json` (required — devshell downloads the server binary directly from Microsoft's CDN):

```json
"remote.SSH.localServerDownload": "off"
```

### Connect

In VS Code: **Remote Explorer → SSH → devshell**

First connection downloads the VS Code Server (~112MB) into the persistent `devshell-vscode-server` volume. Subsequent connections are instant.

## Updating

```bash
cd /volume1/docker/stacks/devshell
/usr/local/bin/docker compose pull
/usr/local/bin/docker compose up -d
```

## Troubleshooting

```bash
# Container logs
/usr/local/bin/docker compose logs devshell

# Verify Docker socket access from inside container
/usr/local/bin/docker exec devshell docker ps

# Check SSH keys are mounted
/usr/local/bin/docker exec devshell ls -la /home/msn0624c/.ssh/

# Check user identity
/usr/local/bin/docker exec devshell id msn0624c
```

### VS Code Server download fails

If VS Code shows `ServerDownloadFailed`:
- Confirm `"remote.SSH.localServerDownload": "off"` is set in VS Code settings
- Test CDN access: `docker exec devshell curl -sI https://update.code.visualstudio.com`
- Check `.vscode-server` ownership: `docker exec devshell ls -la ~`  — must be owned by `msn0624c`, not `root`

## Security Notes

- SSH key authentication only — password auth disabled
- Root SSH login disabled
- Port `2222` is bound to `127.0.0.1` only — not directly reachable from outside the NAS
- Docker socket access is intentional for this dev environment
- `DOCKER_API_VERSION` is set to match the Synology Docker daemon version

## Directory Structure

```
devshell/
├── .github/workflows/build-and-push.yml   # CI/CD
├── Dockerfile                              # Container image
├── entrypoint.sh                           # Runtime setup (users, perms, sshd)
├── docker-compose.yml                      # Stack definition
├── .env.example                            # Environment variable template
└── README.md

# On NAS:
/volume1/docker/stacks/devshell/
├── docker-compose.yml
├── .env                                    # Credentials — never commit
└── ssh/
    └── authorized_keys                     # SSH public keys
```
