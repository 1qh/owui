# owui

White-label [Open WebUI](https://github.com/open-webui/open-webui) for private enterprise deployment. One script gives you a fully functional chat platform with no visible Open WebUI branding, running on NVIDIA GPUs with no authentication required.

## Quick Start

```bash
git clone https://github.com/1qh/owui.git && cd owui
./deploy-chat.sh "Acme AI" 3000
```

That's it. Open `http://localhost:3000`.

## What It Does

`deploy-chat.sh` runs end-to-end:

1. Clones the latest stable Open WebUI release
2. Strips all branding via `rebrand.py` — names, logos, favicons, social links, community features, attribution, license checks, easter eggs, sponsor links
3. Builds a Docker image with CUDA support
4. Starts the container with GPU passthrough, no-auth mode

## What Gets Removed

- All `Open WebUI` / `OpenWebUI` text (frontend, backend, i18n — 59 locales)
- Logos, favicons, splash screens (replaced with neutral chat bubble icon)
- Discord, Twitter, GitHub social links and shield.io badges
- "Share to Community" button and `openwebui.com` redirects
- About page attribution (copyright, "Created by")
- Enterprise nag / sponsor prompts
- License validation (`api.openwebui.com` phone-home)
- `CUSTOM_NAME` remote branding fetch
- `X-OpenWebUI-*` HTTP headers renamed
- User-Agent strings scrubbed
- Python module renamed (`open_webui` → brand slug)

Zero residuals across all source files after rebranding.

## Usage

```bash
./deploy-chat.sh [BRAND_NAME] [HOST_PORT]
```

| Arg | Default | Description |
|-----|---------|-------------|
| `BRAND_NAME` | `Chat` | Your platform name |
| `HOST_PORT` | `3000` | Port exposed on host |

### Pin a specific version

```bash
OWUI_TAG=v0.8.8 ./deploy-chat.sh "Chat" 3000
```

### Use OpenAI-compatible API instead of Ollama

```bash
docker rm -f private-chat
docker run -d --name private-chat --gpus all \
  -p 3000:8080 -v private-chat-data:/app/backend/data \
  -e WEBUI_AUTH=False -e DEFAULT_USER_ROLE=admin \
  -e OPENAI_API_BASE_URL=https://api.example.com/v1 \
  -e OPENAI_API_KEY=sk-your-key \
  --restart unless-stopped private-chat:latest
```

## Prerequisites

- Docker with [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- NVIDIA GPU with drivers
- `git`, `python3`

## Files

| File | Purpose |
|------|---------|
| `deploy-chat.sh` | Orchestrator — clone, strip, rebrand, build, deploy |
| `rebrand.py` | All rebranding logic — string replacement, regex patches, asset generation, module rename |
