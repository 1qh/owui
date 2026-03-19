#!/usr/bin/env bash
set -euo pipefail

BRAND_NAME="${1:-Chat}"
HOST_PORT="${2:-3000}"
INSTALL_DIR="${3:-$(pwd)/owui-server}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRAND_FILE="${INSTALL_DIR}/.owui_brand"

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

INCLUDE_MARIADB="${OWUI_INCLUDE_MARIADB:-0}"
if [[ "$INCLUDE_MARIADB" != "0" && "$INCLUDE_MARIADB" != "1" ]]; then
    echo "  ✗ Invalid OWUI_INCLUDE_MARIADB='$INCLUDE_MARIADB' (expected: 0|1)"
    exit 1
fi

NEED_BOOTSTRAP=1
if [[ -d "${INSTALL_DIR}/build/backend" && -f "$BRAND_FILE" ]]; then
    EXISTING_BRAND=$(cat "$BRAND_FILE" 2>/dev/null || true)
    if [[ "$EXISTING_BRAND" == "$BRAND_NAME" ]]; then
        NEED_BOOTSTRAP=0
    fi
fi

if [[ "$NEED_BOOTSTRAP" == "1" ]]; then
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
    fi
    SRC_DIR=$(bash "${SCRIPT_DIR}/setup.sh" "${BRAND_NAME}" "${INSTALL_DIR}")
    printf '%s\n' "$BRAND_NAME" > "$BRAND_FILE"

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
else
    SRC_DIR="${INSTALL_DIR}/build"
    MODULE=$(echo "${BRAND_NAME}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr '-' '_')
    cd "$SRC_DIR/backend"
    source .venv/bin/activate
fi

if [[ ! -f "${SRC_DIR}/backend/${MODULE}/main.py" ]]; then
    echo "  ✗ Cannot find backend module: ${SRC_DIR}/backend/${MODULE}/main.py"
    echo "    Remove ${INSTALL_DIR} and rerun with your desired brand."
    exit 1
fi

cd "${SRC_DIR}/backend"

echo "▸ Starting ${BRAND_NAME} on port ${HOST_PORT}..."
echo "  PID file: ${SRC_DIR}/backend/.pid"
echo ""

export PORT="${HOST_PORT}"
export DATA_DIR="${SRC_DIR}/backend/data"
mkdir -p "${DATA_DIR}"

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
