#!/usr/bin/env bash
#
# setup.sh — Clone, strip, and rebrand Open WebUI
#
# Called by run-docker.sh and run-native.sh
# Outputs the rebranded source directory path to stdout (last line)
#

set -euo pipefail

BRAND_NAME="${1:-Chat}"
DEST_DIR="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/rebrand.py" ]]; then
    echo "  ✗ rebrand.py not found next to this script" >&2
    exit 1
fi

REPO="https://github.com/open-webui/open-webui.git"
SAFE_FALLBACK_TAG="${OWUI_SAFE_TAG:-v0.8.8}"

select_latest_tag() {
    local latest
    latest=$(git ls-remote --tags --sort=-v:refname "$REPO" 'refs/tags/v*' 2>/dev/null | sed -n '1s|.*refs/tags/||p')
    if [[ -z "$latest" ]]; then
        latest="$SAFE_FALLBACK_TAG"
    fi
    printf '%s\n' "$latest"
}

TAG="${OWUI_TAG:-$(select_latest_tag)}"

if [[ -z "$DEST_DIR" ]]; then
    DEST_DIR=$(mktemp -d)
fi
mkdir -p "$DEST_DIR"

echo "▸ Cloning Open WebUI ${TAG}..." >&2
git clone --depth 1 --branch "$TAG" "$REPO" "$DEST_DIR/build" 2>&1 | grep -v "^remote:" >&2 || true
cd "$DEST_DIR/build"
echo "  ✓ Cloned ${TAG} ($(git log -1 --format='%h %cs'))" >&2

if [[ -f backend/requirements.txt ]] && grep -q '^ddgs==9\.11\.2$' backend/requirements.txt; then
    python3 - <<'PY'
from pathlib import Path

req = Path("backend/requirements.txt")
text = req.read_text(encoding="utf-8")
req.write_text(text.replace("ddgs==9.11.2", "ddgs==9.10.0"), encoding="utf-8")
print("  ✓ Patched backend/requirements.txt: ddgs==9.11.2 -> ddgs==9.10.0")
PY
fi

# ── Strip non-essential files (keep CHANGELOG.md — Dockerfile COPYs it) ───────
echo "▸ Stripping non-essential files..." >&2
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
echo "  ✓ Done" >&2

echo "▸ Rebranding..." >&2
python3 "${SCRIPT_DIR}/rebrand.py" "${BRAND_NAME}" >&2

echo "$DEST_DIR/build"
