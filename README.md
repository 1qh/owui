# owui

White-label [Open WebUI](https://github.com/open-webui/open-webui) for private enterprise deployment. One script gives you a fully functional chat platform with zero visible Open WebUI branding.

## Quick Start

### Docker (recommended)

```bash
git clone https://github.com/1qh/owui.git && cd owui
./run-docker.sh
```

### Native (no Docker needed)

```bash
git clone https://github.com/1qh/owui.git && cd owui
./run-native.sh
```

Open `http://localhost:3000`.

## What Gets Removed

- All `Open WebUI` / `OpenWebUI` text across frontend, backend, and 59 i18n locales
- Logos, favicons, splash screens — replaced with a neutral chat bubble icon
- Discord, Twitter, GitHub social links and shield.io badges
- "Share to Community" button and `openwebui.com` redirects
- About page attribution, copyright, "Created by", sponsor links
- License validation (`api.openwebui.com` phone-home)
- `CUSTOM_NAME` remote branding, enterprise nag
- HTTP headers, user-agent strings, Python module name

Zero residuals across all source files after rebranding.

## Usage

```
./run-docker.sh [BRAND_NAME] [HOST_PORT]
./run-native.sh [BRAND_NAME] [HOST_PORT] [INSTALL_DIR]
```

| Arg | Default | Description |
|-----|---------|-------------|
| `BRAND_NAME` | `Chat` | Platform name shown in UI |
| `HOST_PORT` | `3000` | Port exposed on host |
| `INSTALL_DIR` | `./owui-server` | Native only — where to install |

### Pin a specific upstream version

```bash
OWUI_TAG=v0.8.8 ./run-docker.sh "Chat" 3000
```

## Prerequisites

### Docker path

- Docker (with [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) for GPU)
- `git`, `python3`

### Native path

- `git`, `python3`
- [`bun`](https://bun.sh) — frontend build
- [`uv`](https://github.com/astral-sh/uv) — Python package management

## Files

| File | Purpose |
|------|---------|
| `setup.sh` | Shared setup — clone, strip, rebrand |
| `run-docker.sh` | Docker path — build image, run container |
| `run-native.sh` | Native path — bun build, uv pip install, uvicorn |
| `rebrand.py` | All rebranding logic — 8 phases, 50+ patches, asset generation |
