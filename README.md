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

Native mode supports `OWUI_TORCH_FLAVOR=auto|cuda|cpu` (default `auto`).
Use `OWUI_TORCH_FLAVOR=cpu` to avoid CUDA wheel installs on low-disk or CPU-only environments.

Both modes support `OWUI_BACKEND_PROFILE=full|light` (default `full`).
Use `OWUI_BACKEND_PROFILE=light` to skip local heavy torch/CUDA installs and rely on external Ollama.

Native mode defaults to `OWUI_INCLUDE_MARIADB=0`, which skips the optional `mariadb` Python package to avoid
`mariadb_config not found` build failures on machines without MariaDB Connector/C.
Set `OWUI_INCLUDE_MARIADB=1` only if you explicitly need MariaDB Python support.

No-auth mode is always enabled (`WEBUI_AUTH=False`).
Native mode is clean-first: if the target install directory already exists, it is removed before setup.

### External Ollama (no bundled heavy backend)

This project is designed to use Ollama running outside WebUI.

#### 1) Start local Ollama first

Make sure Ollama is running and has at least one model:

```bash
ollama serve
ollama pull qwen3.5
curl http://127.0.0.1:11434/api/tags
```

Expected: JSON output with your model list.

#### 2) Run WebUI in light backend mode

Native:

```bash
OWUI_BACKEND_PROFILE=light OLLAMA_BASE_URL=http://127.0.0.1:11434 ./run-native.sh
```

Docker (container uses host Ollama):

```bash
OWUI_BACKEND_PROFILE=light OWUI_DOCKER_CUDA=off OLLAMA_BASE_URL=http://host.docker.internal:11434 ./run-docker.sh
```

#### 2.1) Configure embedding model explicitly (recommended for Ollama users)

Chat model and embedding model are different. A chat-only model can work for chatting but fail during
knowledge file indexing.

Recommended local Ollama setup:

```bash
# Chat model
ollama pull qwen3.5

# Embedding model
ollama pull nomic-embed-text
```

Run with explicit embedding config:

```bash
RAG_EMBEDDING_ENGINE=ollama \
RAG_EMBEDDING_MODEL=nomic-embed-text \
RAG_OLLAMA_BASE_URL=http://127.0.0.1:11434 \
OWUI_BACKEND_PROFILE=light \
OLLAMA_BASE_URL=http://127.0.0.1:11434 \
./run-native.sh
```

Docker variant:

```bash
RAG_EMBEDDING_ENGINE=ollama \
RAG_EMBEDDING_MODEL=nomic-embed-text \
RAG_OLLAMA_BASE_URL=http://host.docker.internal:11434 \
OWUI_BACKEND_PROFILE=light \
OWUI_DOCKER_CUDA=off \
OLLAMA_BASE_URL=http://host.docker.internal:11434 \
./run-docker.sh
```

#### 2.2) Known-good command examples

Native + local Ollama + explicit embedding model:

```bash
RAG_EMBEDDING_ENGINE=ollama \
RAG_EMBEDDING_MODEL=nomic-embed-text \
RAG_OLLAMA_BASE_URL=http://127.0.0.1:11434 \
OWUI_BACKEND_PROFILE=light \
OWUI_TORCH_FLAVOR=cpu \
OLLAMA_BASE_URL=http://127.0.0.1:11434 \
./run-native.sh DX2 3001
```

Native + default upstream embedding engine (no forced Ollama embedding):

```bash
OWUI_BACKEND_PROFILE=light \
OWUI_TORCH_FLAVOR=cpu \
OLLAMA_BASE_URL=http://127.0.0.1:11434 \
./run-native.sh Chat 3000
```

Native + remote Ollama host (same LAN/VPN):

```bash
RAG_EMBEDDING_ENGINE=ollama \
RAG_EMBEDDING_MODEL=nomic-embed-text \
RAG_OLLAMA_BASE_URL=http://10.0.0.25:11434 \
OWUI_BACKEND_PROFILE=light \
OLLAMA_BASE_URL=http://10.0.0.25:11434 \
./run-native.sh Chat 3000
```

Docker + host Ollama + explicit embedding model:

```bash
RAG_EMBEDDING_ENGINE=ollama \
RAG_EMBEDDING_MODEL=nomic-embed-text \
RAG_OLLAMA_BASE_URL=http://host.docker.internal:11434 \
OWUI_BACKEND_PROFILE=light \
OWUI_DOCKER_CUDA=off \
OLLAMA_BASE_URL=http://host.docker.internal:11434 \
./run-docker.sh Chat 3000
```

Docker + remote Ollama host:

```bash
RAG_EMBEDDING_ENGINE=ollama \
RAG_EMBEDDING_MODEL=nomic-embed-text \
RAG_OLLAMA_BASE_URL=http://10.0.0.25:11434 \
OWUI_BACKEND_PROFILE=light \
OWUI_DOCKER_CUDA=off \
OLLAMA_BASE_URL=http://10.0.0.25:11434 \
./run-docker.sh Chat 3000
```

Native + optional MariaDB Python support enabled (only if needed):

```bash
OWUI_INCLUDE_MARIADB=1 \
OWUI_BACKEND_PROFILE=light \
OLLAMA_BASE_URL=http://127.0.0.1:11434 \
./run-native.sh Chat 3000
```

Notes:

- `OWUI_BACKEND_PROFILE=light` skips local heavy torch/CUDA setup inside WebUI.
- Native still builds frontend once (required for a clean fresh run).
- Docker uses `host.docker.internal` so the container can reach host Ollama.
- Embedding engine is not force-overridden by scripts; upstream defaults apply unless you set `RAG_EMBEDDING_ENGINE` explicitly.

#### 3) Verify no-auth + Ollama wiring

```bash
curl http://localhost:3000/health
curl http://localhost:3000/api/config
curl http://127.0.0.1:11434/api/tags
```

Expected:

- `/health` returns `{"status":true}`
- `/api/config` includes `"features":{"auth":false,...}`
- local Ollama `/api/tags` lists your models

Optional embedding check:

```bash
curl -sS http://127.0.0.1:11434/api/tags | grep -E "qwen3.5|nomic-embed-text"
```

Expected: both chat and embedding models are present.

#### 4) Common issues

- `Not authenticated` on model APIs: this can happen on endpoints that still require a session token even when global auth is off. UI chat remains no-auth.
- WebUI cannot reach Ollama in Docker: use `OLLAMA_BASE_URL=http://host.docker.internal:11434` and ensure host Ollama is listening.
- Native startup too heavy: keep `OWUI_BACKEND_PROFILE=light` and `OWUI_TORCH_FLAVOR=cpu`.
- Native install fails with `mariadb_config not found`: leave `OWUI_INCLUDE_MARIADB=0` (default), or install MariaDB Connector/C and set `OWUI_INCLUDE_MARIADB=1`.
- If you explicitly use `RAG_EMBEDDING_ENGINE=ollama`, ensure an embedding-capable Ollama model is configured; chat-only models can cause empty embedding results during knowledge indexing.
- Collection upload fails during indexing: set `RAG_EMBEDDING_ENGINE=ollama` + `RAG_EMBEDDING_MODEL=nomic-embed-text` explicitly and confirm that model exists in `ollama /api/tags`.

If you want MariaDB support (`OWUI_INCLUDE_MARIADB=1`), install Connector/C first so `mariadb_config` exists:

```bash
# Ubuntu / Debian
sudo apt-get update && sudo apt-get install -y libmariadb-dev

# Fedora / RHEL / Rocky / AlmaLinux
sudo dnf install -y mariadb-connector-c-devel

# Arch Linux
sudo pacman -S --needed mariadb-libs

# Alpine
sudo apk add mariadb-connector-c-dev

# macOS (Homebrew)
brew install mariadb-connector-c
```

Then run native with MariaDB package enabled:

```bash
OWUI_INCLUDE_MARIADB=1 ./run-native.sh
```

### Pin a specific upstream version

```bash
OWUI_TAG=v0.8.8 ./run-docker.sh "Chat" 3000
```

### Default upstream selection behavior

- If `OWUI_TAG` is not set, `setup.sh` selects the newest upstream tag.
- If that upstream snapshot contains `ddgs==9.11.2`, setup patches it to `ddgs==9.10.0` automatically for install compatibility.
- If tag lookup fails, fallback is `v0.8.8` (override with `OWUI_SAFE_TAG`).

## Prerequisites

### Docker path

- Docker (with [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) for GPU)
- `git`, `python3`

### Native path

- `git`, `python3` (`>=3.11,<3.13`; Python 3.12 recommended)
- [`bun`](https://bun.sh) — frontend build
- [`uv`](https://github.com/astral-sh/uv) — Python package management

## Files

| File | Purpose |
|------|---------|
| `setup.sh` | Shared setup — clone, strip, rebrand |
| `run-docker.sh` | Docker path — build image, run container |
| `run-native.sh` | Native path — bun build, uv pip install, uvicorn |
| `rebrand.py` | All rebranding logic — 8 phases, 50+ patches, asset generation |
