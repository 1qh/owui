#!/usr/bin/env bash
#
# deploy-chat.sh — Private Enterprise Chat Platform Deployer
#
# Usage: ./deploy-chat.sh [BRAND_NAME] [HOST_PORT]
#   OWUI_TAG env var overrides the auto-detected latest stable tag
#
# rebrand.py must sit next to this script.
#

set -euo pipefail

BRAND_NAME="${1:-Chat}"
HOST_PORT="${2:-3000}"
IMAGE_NAME="private-chat"
CONTAINER_NAME="private-chat"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  ┌─────────────────────────────────────────────┐"
echo "  │  Private Chat Platform Deployer              │"
printf "  │  Brand: %-36s│\n" "${BRAND_NAME}"
printf "  │  Port:  %-36s│\n" "${HOST_PORT}"
echo "  └─────────────────────────────────────────────┘"
echo ""

# ── Prerequisites ──────────────────────────────────────────────────────────────
echo "▸ Checking prerequisites..."

missing=()
command -v git     >/dev/null 2>&1 || missing+=(git)
command -v docker  >/dev/null 2>&1 || missing+=(docker)
command -v python3 >/dev/null 2>&1 || missing+=(python3)

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "  ✗ Missing required tools: ${missing[*]}"
    exit 1
fi
if [[ ! -f "${SCRIPT_DIR}/rebrand.py" ]]; then
    echo "  ✗ rebrand.py not found next to this script (${SCRIPT_DIR})"
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    echo "  ✗ Docker daemon is not running."
    exit 1
fi

if nvidia-smi >/dev/null 2>&1; then
    echo "  ✓ NVIDIA GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
else
    echo "  ⚠ nvidia-smi not found — GPU passthrough may not work."
    read -rp "  Continue anyway? [y/N] " yn
    [[ "${yn,,}" == "y" ]] || exit 1
fi

# ── Clone ──────────────────────────────────────────────────────────────────────
WORK_DIR=$(mktemp -d)
trap 'echo "▸ Cleaning up build directory..."; rm -rf "$WORK_DIR"' EXIT

REPO="https://github.com/open-webui/open-webui.git"
TAG="${OWUI_TAG:-$(git ls-remote --tags --sort=-v:refname "$REPO" 'refs/tags/v*' 2>/dev/null | sed -n '1s|.*refs/tags/||p')}"
echo "▸ Cloning Open WebUI ${TAG}..."
git clone --depth 1 --branch "$TAG" "$REPO" "$WORK_DIR/build" 2>&1 | grep -v "^remote:" || true
cd "$WORK_DIR/build"
echo "  ✓ Cloned ${TAG} ($(git log -1 --format='%h %cs'))"

# ── Strip non-essential files (keep CHANGELOG.md — Dockerfile COPYs it) ───────
echo "▸ Stripping non-essential files..."
rm -rf \
    .git .github .gitignore .gitattributes \
    docs cypress test \
    demo.png banner.png \
    README.md TROUBLESHOOTING.md \
    CODE_OF_CONDUCT.md CONTRIBUTOR_LICENSE_AGREEMENT \
    contribution_stats.py confirm_remove.sh \
    i18next-parser.config.ts cypress.config.ts \
    Makefile .env.example \
    run-compose.sh run-ollama-docker.sh run.sh update_ollama_models.sh \
    docker-compose.a1111-test.yaml docker-compose.amdgpu.yaml \
    docker-compose.api.yaml docker-compose.data.yaml \
    docker-compose.otel.yaml docker-compose.playwright.yaml \
    .eslintignore .eslintrc.cjs .npmrc \
    .prettierignore .prettierrc \
    uv.lock
echo "  ✓ Done"

# ── Rebrand ────────────────────────────────────────────────────────────────────
echo "▸ Rebranding..."
python3 "${SCRIPT_DIR}/rebrand.py" "${BRAND_NAME}"

# ── Build Docker image ─────────────────────────────────────────────────────────
echo ""
echo "▸ Building Docker image with CUDA support..."
echo "  (Expect 15-30 min on first build)"
echo ""

docker build \
    --build-arg USE_CUDA=true \
    --build-arg USE_CUDA_VER=cu128 \
    -t "${IMAGE_NAME}:latest" \
    .

echo ""
echo "  ✓ Image '${IMAGE_NAME}:latest' built"

# ── Deploy ─────────────────────────────────────────────────────────────────────
echo "▸ Stopping existing container (if any)..."
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

GPU_FLAG=""
if docker run --rm --gpus all hello-world >/dev/null 2>&1; then
    GPU_FLAG="--gpus all"
    echo "  ✓ GPU passthrough enabled"
else
    echo "  ⚠ GPU passthrough unavailable, running without"
fi

echo "▸ Starting ${BRAND_NAME}..."
docker run -d \
    --name "${CONTAINER_NAME}" \
    ${GPU_FLAG} \
    -p "${HOST_PORT}:8080" \
    -v "${CONTAINER_NAME}-data:/app/backend/data" \
    -e WEBUI_AUTH=False \
    -e DEFAULT_USER_ROLE=admin \
    -e ENABLE_COMMUNITY_SHARING=False \
    -e ENABLE_MESSAGE_RATING=False \
    --add-host=host.docker.internal:host-gateway \
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
    --restart unless-stopped \
    "${IMAGE_NAME}:latest"

echo ""
echo "  ┌─────────────────────────────────────────────┐"
echo "  │  ✓ Deployment complete!                      │"
echo "  │                                              │"
printf "  │  %-44s│\n" "${BRAND_NAME} is running at:"
printf "  │  %-44s│\n" "http://localhost:${HOST_PORT}"
echo "  │                                              │"
echo "  │  Auth:     DISABLED (no login required)      │"
echo "  │  GPU:      NVIDIA (all GPUs)                 │"
echo "  │  Ollama:   http://host.docker.internal:11434 │"
echo "  │  Data:     ${CONTAINER_NAME}-data volume     │"
echo "  │                                              │"
echo "  │  Logs:     docker logs -f ${CONTAINER_NAME}  │"
echo "  │  Stop:     docker stop ${CONTAINER_NAME}     │"
echo "  │  Restart:  docker restart ${CONTAINER_NAME}  │"
echo "  └─────────────────────────────────────────────┘"
echo ""
