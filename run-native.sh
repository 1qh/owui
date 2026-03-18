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

TORCH_FLAVOR="${OWUI_TORCH_FLAVOR:-auto}"
if [[ "$TORCH_FLAVOR" != "auto" && "$TORCH_FLAVOR" != "cuda" && "$TORCH_FLAVOR" != "cpu" ]]; then
    echo "  ✗ Invalid OWUI_TORCH_FLAVOR='$TORCH_FLAVOR' (expected: auto|cuda|cpu)"
    exit 1
fi

BACKEND_PROFILE="${OWUI_BACKEND_PROFILE:-full}"
if [[ "$BACKEND_PROFILE" != "full" && "$BACKEND_PROFILE" != "light" ]]; then
    echo "  ✗ Invalid OWUI_BACKEND_PROFILE='$BACKEND_PROFILE' (expected: full|light)"
    exit 1
fi

INCLUDE_MARIADB="${OWUI_INCLUDE_MARIADB:-0}"
if [[ "$INCLUDE_MARIADB" != "0" && "$INCLUDE_MARIADB" != "1" ]]; then
    echo "  ✗ Invalid OWUI_INCLUDE_MARIADB='$INCLUDE_MARIADB' (expected: 0|1)"
    exit 1
fi

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
bun install

echo "▸ Building frontend..."
bun run build

echo "▸ Installing backend dependencies..."
cd backend
uv venv .venv --python ">=3.11,<3.13" --python-preference only-system
source .venv/bin/activate

if [[ "$TORCH_FLAVOR" == "cpu" ]]; then
    if [[ "$BACKEND_PROFILE" == "light" ]]; then
        echo "▸ Skipping PyTorch install (OWUI_BACKEND_PROFILE=light)..."
    else
        echo "▸ Installing CPU PyTorch (forced by OWUI_TORCH_FLAVOR=cpu)..."
        uv pip install 'torch<=2.9.1' torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    fi
elif [[ "$TORCH_FLAVOR" == "cuda" ]]; then
    if [[ "$BACKEND_PROFILE" == "light" ]]; then
        echo "▸ Skipping PyTorch install (OWUI_BACKEND_PROFILE=light)..."
    else
        echo "▸ Installing CUDA PyTorch (forced by OWUI_TORCH_FLAVOR=cuda)..."
        uv pip install 'torch<=2.9.1' torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
    fi
elif nvidia-smi >/dev/null 2>&1; then
    if [[ "$BACKEND_PROFILE" == "light" ]]; then
        echo "▸ Skipping PyTorch install (OWUI_BACKEND_PROFILE=light)..."
    else
        echo "▸ Installing CUDA PyTorch..."
        uv pip install 'torch<=2.9.1' torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
    fi
else
    if [[ "$BACKEND_PROFILE" == "light" ]]; then
        echo "▸ Skipping PyTorch install (OWUI_BACKEND_PROFILE=light)..."
    else
        echo "▸ Installing CPU PyTorch..."
        uv pip install 'torch<=2.9.1' torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    fi
fi

echo "▸ Installing requirements..."
REQ_FILE="requirements.txt"
if [[ "$INCLUDE_MARIADB" == "0" ]]; then
    python3 - <<'PY'
from pathlib import Path

src = Path("requirements.txt")
dst = Path("requirements.owui.txt")
lines = src.read_text(encoding="utf-8").splitlines()
filtered = [line for line in lines if not line.strip().startswith("mariadb==")]
dst.write_text("\n".join(filtered) + "\n", encoding="utf-8")
PY
    REQ_FILE="requirements.owui.txt"
    echo "  ✓ Skipping mariadb Python package (OWUI_INCLUDE_MARIADB=0)"
fi

uv pip install -r "$REQ_FILE"

echo "▸ Starting ${BRAND_NAME} on port ${HOST_PORT}..."
echo "  PID file: ${SRC_DIR}/backend/.pid"
echo ""

export PORT="${HOST_PORT}"
export WEBUI_AUTH="False"
export WEBUI_ADMIN_EMAIL="${WEBUI_ADMIN_EMAIL:-admin@local.invalid}"
export WEBUI_ADMIN_PASSWORD="${WEBUI_ADMIN_PASSWORD:-ChangeMe_12345!}"
export WEBUI_ADMIN_NAME="${WEBUI_ADMIN_NAME:-Admin}"
export DEFAULT_USER_ROLE="admin"
export ENABLE_COMMUNITY_SHARING="False"
export ENABLE_MESSAGE_RATING="False"
export OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
export DATA_DIR="${SRC_DIR}/backend/data"
mkdir -p "${DATA_DIR}"
if [[ "$BACKEND_PROFILE" == "light" ]]; then
    export RAG_EMBEDDING_ENGINE="${RAG_EMBEDDING_ENGINE:-ollama}"
fi

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
