#!/usr/bin/env bash
set -euo pipefail

BRAND_NAME="${1:-Chat}"
HOST_PORT="${2:-3000}"
INSTALL_DIR="${3:-$(pwd)/owui-server}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  ┌─────────────────────────────────────────────┐"
echo "  │  Private Chat — Native                       │"
printf "  │  Brand: %-36s│\n" "${BRAND_NAME}"
printf "  │  Port:  %-36s│\n" "${HOST_PORT}"
printf "  │  Dir:   %-36s│\n" "${INSTALL_DIR}"
echo "  └─────────────────────────────────────────────┘"
echo ""

for cmd in python3 git bun uv; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "  ✗ Missing: $cmd"; exit 1; }
done

if ! python3 - <<'PY'
import sys
ok = (sys.version_info.major, sys.version_info.minor) >= (3, 11) and (sys.version_info.major, sys.version_info.minor) < (3, 13)
raise SystemExit(0 if ok else 1)
PY
then
    CURRENT_PYTHON=$(python3 - <<'PY'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")
PY
)
    echo "  ✗ python3=${CURRENT_PYTHON} is unsupported for native mode"
    echo "    Need Python >=3.11 and <3.13 in your current environment."
    echo "    Example (micromamba): micromamba create -n owui python=3.12 && micromamba activate owui"
    exit 1
fi

SRC_DIR=$(bash "${SCRIPT_DIR}/setup.sh" "${BRAND_NAME}" "${INSTALL_DIR}")
cd "$SRC_DIR"

MODULE=$(echo "${BRAND_NAME}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr '-' '_')

echo "▸ Installing frontend dependencies..."
bun install 2>&1 | tail -1

echo "▸ Building frontend..."
bun run build 2>&1 | tail -1

echo "▸ Installing backend dependencies..."
cd backend
uv venv .venv --python ">=3.11,<3.13" --python-preference only-system
source .venv/bin/activate

if nvidia-smi >/dev/null 2>&1; then
    echo "▸ Installing CUDA PyTorch..."
    uv pip install 'torch<=2.9.1' torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128 2>&1 | tail -1
else
    echo "▸ Installing CPU PyTorch..."
    uv pip install 'torch<=2.9.1' torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu 2>&1 | tail -1
fi

echo "▸ Installing requirements..."
uv pip install -r requirements.txt 2>&1 | tail -1

echo "▸ Starting ${BRAND_NAME} on port ${HOST_PORT}..."
echo "  PID file: ${SRC_DIR}/backend/.pid"
echo ""

export PORT="${HOST_PORT}"
export WEBUI_AUTH="False"
export DEFAULT_USER_ROLE="admin"
export ENABLE_COMMUNITY_SHARING="False"
export ENABLE_MESSAGE_RATING="False"
export OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"

python -m uvicorn "${MODULE}.main:app" \
    --host 0.0.0.0 \
    --port "${HOST_PORT}" \
    --forwarded-allow-ips '*' &

PID=$!
echo "$PID" > .pid

echo ""
echo "  ✓ ${BRAND_NAME} running at http://localhost:${HOST_PORT}"
echo "    PID:  ${PID}"
echo "    Stop: kill \$(cat ${SRC_DIR}/backend/.pid)"
echo ""

wait "$PID"
