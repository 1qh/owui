#!/usr/bin/env bash
set -euo pipefail

BRAND_NAME="${1:-Chat}"
HOST_PORT="${2:-3000}"
IMAGE_NAME="private-chat"
CONTAINER_NAME="private-chat"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_CUDA_MODE="${OWUI_DOCKER_CUDA:-auto}"
BACKEND_PROFILE="${OWUI_BACKEND_PROFILE:-full}"
OLLAMA_ENDPOINT="${OLLAMA_BASE_URL:-http://host.docker.internal:11434}"

if [[ "$DOCKER_CUDA_MODE" != "auto" && "$DOCKER_CUDA_MODE" != "on" && "$DOCKER_CUDA_MODE" != "off" ]]; then
    echo "  ✗ Invalid OWUI_DOCKER_CUDA='$DOCKER_CUDA_MODE' (expected: auto|on|off)"
    exit 1
fi

if [[ "$BACKEND_PROFILE" != "full" && "$BACKEND_PROFILE" != "light" ]]; then
    echo "  ✗ Invalid OWUI_BACKEND_PROFILE='$BACKEND_PROFILE' (expected: full|light)"
    exit 1
fi

echo ""
echo "  ┌─────────────────────────────────────────────┐"
echo "  │  Private Chat — Docker                       │"
printf "  │  Brand: %-36s│\n" "${BRAND_NAME}"
printf "  │  Port:  %-36s│\n" "${HOST_PORT}"
echo "  └─────────────────────────────────────────────┘"
echo ""

for cmd in docker python3 git; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "  ✗ Missing: $cmd"; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "  ✗ Docker daemon not running"; exit 1; }

nvidia-smi >/dev/null 2>&1 && echo "  ✓ GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)" || {
    echo "  ⚠ No NVIDIA GPU detected"
}

WORK_DIR=$(mktemp -d)
trap 'echo "▸ Cleaning up..."; rm -rf "$WORK_DIR"' EXIT

SRC_DIR=$(bash "${SCRIPT_DIR}/setup.sh" "${BRAND_NAME}" "$WORK_DIR")
cd "$SRC_DIR"

echo ""
USE_CUDA=false
if [[ "$DOCKER_CUDA_MODE" == "on" ]]; then
    USE_CUDA=true
elif [[ "$DOCKER_CUDA_MODE" == "auto" ]] && nvidia-smi >/dev/null 2>&1; then
    USE_CUDA=true
fi

if [[ "$BACKEND_PROFILE" == "light" ]]; then
    USE_CUDA=false
    echo "▸ OWUI_BACKEND_PROFILE=light active: forcing CPU backend path"
fi

if [[ "$USE_CUDA" == "true" ]]; then
    echo "▸ Building Docker image with CUDA..."
else
    echo "▸ Building Docker image (CPU mode)..."
fi

docker build \
    --build-arg USE_CUDA=${USE_CUDA} \
    --build-arg USE_CUDA_VER=cu128 \
    -t "${IMAGE_NAME}:latest" \
    .
echo "  ✓ Image built"

docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

GPU_FLAG=""
if [[ "$USE_CUDA" == "true" ]] && docker run --rm --gpus all hello-world >/dev/null 2>&1; then
    GPU_FLAG="--gpus all"
    echo "  ✓ GPU passthrough enabled"
else
    echo "  ✓ Running without GPU passthrough"
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
    -e OLLAMA_BASE_URL=${OLLAMA_ENDPOINT} \
    --restart unless-stopped \
    "${IMAGE_NAME}:latest"

echo ""
echo "  ✓ ${BRAND_NAME} running at http://localhost:${HOST_PORT}"
echo "    Logs:    docker logs -f ${CONTAINER_NAME}"
echo "    Stop:    docker stop ${CONTAINER_NAME}"
echo "    Restart: docker restart ${CONTAINER_NAME}"
echo ""
