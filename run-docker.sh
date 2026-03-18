#!/usr/bin/env bash
set -euo pipefail

BRAND_NAME="${1:-Chat}"
HOST_PORT="${2:-3000}"
IMAGE_NAME="private-chat"
CONTAINER_NAME="private-chat"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    read -rp "  Continue? [y/N] " yn; [[ "${yn,,}" == "y" ]] || exit 1
}

WORK_DIR=$(mktemp -d)
trap 'echo "▸ Cleaning up..."; rm -rf "$WORK_DIR"' EXIT

SRC_DIR=$(bash "${SCRIPT_DIR}/setup.sh" "${BRAND_NAME}" "$WORK_DIR")
cd "$SRC_DIR"

echo ""
echo "▸ Building Docker image with CUDA..."
docker build \
    --build-arg USE_CUDA=true \
    --build-arg USE_CUDA_VER=cu128 \
    -t "${IMAGE_NAME}:latest" \
    .
echo "  ✓ Image built"

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
echo "  ✓ ${BRAND_NAME} running at http://localhost:${HOST_PORT}"
echo "    Logs:    docker logs -f ${CONTAINER_NAME}"
echo "    Stop:    docker stop ${CONTAINER_NAME}"
echo "    Restart: docker restart ${CONTAINER_NAME}"
echo ""
