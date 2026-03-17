#!/usr/bin/env python3
"""
rebrand.py — White-label Open WebUI

Replaces all Open WebUI branding with a custom name, removes logos,
strips social links, community references, and external attribution.

Usage:
    python3 rebrand.py [BRAND_NAME]

Must be run from the root of a cloned open-webui repository.
"""

import re
import os
import sys
import struct
import zlib
import shutil
import glob
import json

BRAND = sys.argv[1] if len(sys.argv) > 1 else "Chat"

# ═══════════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════════

_ok = 0
_miss = 0


def read(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def write(path: str, content: str):
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def write_bin(path: str, data: bytes):
    with open(path, "wb") as f:
        f.write(data)


def patch(path: str, replacements: list[tuple[str, str]]):
    """Apply (old, new) string replacements to a file."""
    global _ok, _miss
    if not os.path.isfile(path):
        print("  SKIP (not found): " + path)
        return
    content = read(path)
    for old, new in replacements:
        if old in content:
            content = content.replace(old, new)
            _ok += 1
        else:
            print("  MISS: " + path + " — " + repr(old[:60]))
            _miss += 1
    write(path, content)


def patch_re(path: str, pattern: str, replacement: str, label: str = "", count: int = 0):
    """Apply regex replacement (DOTALL) to a file."""
    global _ok, _miss
    if not os.path.isfile(path):
        print("  SKIP (not found): " + path)
        return
    content = read(path)
    new_content = re.sub(pattern, replacement, content, count=count, flags=re.DOTALL)
    if new_content != content:
        write(path, new_content)
        _ok += 1
    else:
        print("  MISS (regex): " + (label or path))
        _miss += 1


def apply_re(content: str, pattern: str, replacement: str, label: str) -> str:
    """Apply regex to string, log result, return new string."""
    global _ok, _miss
    new = re.sub(pattern, replacement, content, count=1, flags=re.DOTALL)
    if new != content:
        _ok += 1
    else:
        print("  MISS (regex): " + label)
        _miss += 1
    return new


def create_png(width: int, height: int, rgba: tuple = (0, 0, 0, 0)) -> bytes:
    """Create a minimal valid PNG with a solid RGBA color (stdlib only)."""
    def chunk(ctype, data):
        c = ctype + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    row = struct.pack("BBBB", *rgba) * width
    scanlines = b"".join(b"\x00" + row for _ in range(height))
    idat = zlib.compress(scanlines, 9)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", idat)
        + chunk(b"IEND", b"")
    )


def create_ico(size: int = 16, rgba: tuple = (23, 23, 23, 255)) -> bytes:
    """Create a minimal ICO wrapping a PNG."""
    png = create_png(size, size, rgba)
    header = struct.pack("<HHH", 0, 1, 1)
    entry = struct.pack(
        "<BBBBHHII",
        size if size < 256 else 0,
        size if size < 256 else 0,
        0, 0, 1, 32, len(png), 22,
    )
    return header + entry + png


# ═══════════════════════════════════════════════════════════════════════════════
# 1. Backend configuration
# ═══════════════════════════════════════════════════════════════════════════════

print("\n[1/6] Backend configuration")

# env.py — default name, remove "(Open WebUI)" suffix, local favicon
patch("backend/open_webui/env.py", [
    ('WEBUI_NAME = os.environ.get("WEBUI_NAME", "Open WebUI")',
     'WEBUI_NAME = os.environ.get("WEBUI_NAME", "' + BRAND + '")'),
    ('WEBUI_FAVICON_URL = "https://openwebui.com/favicon.png"',
     'WEBUI_FAVICON_URL = "/static/favicon.png"'),
])
patch_re(
    "backend/open_webui/env.py",
    r'if WEBUI_NAME != "Open WebUI":\n\s+WEBUI_NAME \+= " \(Open WebUI\)"\n',
    "",
    label="env.py — remove suffix logic",
)

# config.py — kill CUSTOM_NAME phoning home to api.openwebui.com
patch_re(
    "backend/open_webui/config.py",
    r"if CUSTOM_NAME:\s*\n\s+try:.*?pass\s*\n",
    "",
    label="config.py — neutralize CUSTOM_NAME",
    count=1,
)

# main.py — FastAPI title + nuke license call
patch("backend/open_webui/main.py", [
    ('title="Open WebUI"', 'title="' + BRAND + '"'),
])
patch_re(
    "backend/open_webui/main.py",
    r"if LICENSE_KEY:\s*\n\s+get_license_data\(app, LICENSE_KEY\)",
    "",
    label="main.py — remove license check call",
)

# auth.py — gut the license validation function
patch_re(
    "backend/open_webui/utils/auth.py",
    r"def get_license_data\(app, key\):.*?\n    return False\n",
    "def get_license_data(app, key):\n    return False\n",
    label="auth.py — nuke license validation",
    count=1,
)

# pyproject.toml
patch("pyproject.toml", [
    ('description = "Open WebUI"', 'description = "' + BRAND + '"'),
    ('email = "tim@openwebui.com"', 'email = ""'),
])

# hatch_build.py
patch("hatch_build.py", [
    ("Building Open Webui frontend", "Building " + BRAND + " frontend"),
])


# ═══════════════════════════════════════════════════════════════════════════════
# 2. Frontend configuration
# ═══════════════════════════════════════════════════════════════════════════════

print("\n[2/6] Frontend configuration")

patch("src/lib/constants.ts", [
    ("export const APP_NAME = 'Open WebUI'", "export const APP_NAME = '" + BRAND + "'"),
])

patch("src/app.html", [
    ("<title>Open WebUI</title>", "<title>" + BRAND + "</title>"),
])

patch("static/opensearch.xml", [("Open WebUI", BRAND)])
patch("static/static/site.webmanifest", [("Open WebUI", BRAND)])


# ═══════════════════════════════════════════════════════════════════════════════
# 3. Remove social links, community refs, attribution
# ═══════════════════════════════════════════════════════════════════════════════

print("\n[3/6] Social links & attribution removal")

# ── About.svelte ──────────────────────────────────────────────────────────────
about = "src/lib/components/chat/Settings/About.svelte"
if os.path.isfile(about):
    c = read(about)

    # Remove {:else} block containing discord/twitter/github badges
    c = apply_re(
        c,
        r"\{:else\}\s*\n.*?\n\s*\{/if\}",
        "\t\t{/if}",
        "About.svelte — social badges block",
    )

    # Remove copyright (Open WebUI Inc.)
    c = apply_re(
        c,
        r"\s*<div>\s*\n\s*<pre\s*\n\s*class=\"text-xs text-gray-400.*?Copyright.*?</pre>\s*\n\s*</div>",
        "",
        "About.svelte — copyright block",
    )

    # Remove "Created by Timothy J. Baek"
    c = apply_re(
        c,
        r"""\s*<div class="mt-2 text-xs text-gray-400 dark:text-gray-500">\s*\n\s*\{\$i18n\.t\('Created by'\)\}.*?</div>""",
        "",
        "About.svelte — Created by block",
    )

    # Dead-link the version update check
    c = c.replace(
        "https://github.com/open-webui/open-webui/releases/tag/v{version.latest}", "#"
    )
    write(about, c)


# ── Admin Settings/General.svelte ─────────────────────────────────────────────
gen = "src/lib/components/admin/Settings/General.svelte"
if os.path.isfile(gen):
    c = read(gen)

    # Remove the entire social badges container (div.mt-1 wrapping div.flex.space-x-1
    # containing <a><img/></a> badges). Previous regex failed because [^/]* can't
    # match URLs containing /. Using .*? with DOTALL instead.
    c = apply_re(
        c,
        r'\s*<div class="mt-1">\s*<div class="flex space-x-1">.*?</div>\s*</div>',
        "",
        "General.svelte — social badges container",
    )
    write(gen, c)


# ── UserMenu.svelte ───────────────────────────────────────────────────────────
usermenu = "src/lib/components/layout/Sidebar/UserMenu.svelte"
if os.path.isfile(usermenu):
    c = read(usermenu)
    # Remove the admin-only block containing Documentation + Releases links
    c = apply_re(
        c,
        r"""\{#if \$user\?\.role === 'admin'\}\s*\n\s*<DropdownMenu\.Item\s*\n\s*as="a"\s*\n\s*href="https://docs\.openwebui\.com".*?\{/if\}""",
        "",
        "UserMenu.svelte — docs/releases block",
    )
    write(usermenu, c)


# ── ShareChatModal.svelte ─────────────────────────────────────────────────────
sharechat = "src/lib/components/chat/ShareChatModal.svelte"
if os.path.isfile(sharechat):
    c = read(sharechat)
    # Remove "Share to Open WebUI Community" button
    c = apply_re(
        c,
        r"""\{#if \$config\?\.features\.enable_community_sharing\}.*?\{/if\}""",
        "",
        "ShareChatModal.svelte — community share button",
    )
    # Remove the shareChat() function that redirects to openwebui.com
    c = apply_re(
        c,
        r"""const shareChat = async \(\) => \{.*?\n\t\};""",
        "",
        "ShareChatModal.svelte — shareChat function",
    )
    write(sharechat, c)


# ── error/+page.svelte ────────────────────────────────────────────────────────
patch("src/routes/error/+page.svelte", [
    ("https://github.com/open-webui/open-webui#how-to-install-", "#"),
    ("https://discord.gg/5rJgQTnV4s", "#"),
    ("join our Discord for help.", "check your server configuration."),
    ("See readme.md for instructions", "Check server status"),
])

# ── UpdateInfoToast.svelte ────────────────────────────────────────────────────
patch("src/lib/components/layout/UpdateInfoToast.svelte", [
    ("https://github.com/open-webui/open-webui/releases", "#"),
])

# ── SettingsModal.svelte — easter egg search terms ────────────────────────────
patch("src/lib/components/chat/SettingsModal.svelte", [
    ("'about open webui'", "'about'"),
    ("'aboutopenwebui'", "'about'"),
    ("'timothy jae ryang baek'", "''"),
    ("'timothy j baek'", "''"),
    ("'timothyjaeryangbaek'", "''"),
    ("'timothyjbaek'", "''"),
])

# ── FunctionEditor.svelte — default template metadata ─────────────────────────
patch("src/lib/components/admin/Functions/FunctionEditor.svelte", [
    ("author: open-webui", "author: admin"),
    ("author_url: https://github.com/open-webui", "author_url: "),
    ("funding_url: https://github.com/open-webui", "funding_url: "),
])

# ── SyncStatsModal.svelte — export filename ───────────────────────────────────
patch("src/lib/components/chat/Settings/SyncStatsModal.svelte", [
    ("open-webui-stats-", "stats-"),
])

# ── UserList.svelte — remove entire enterprise/sponsor nag block ──────────────
patch_re(
    "src/lib/components/admin/Users/UserList.svelte",
    r"\{#if !\$config\?\.license_metadata\}.*?\{/if\}\s*\{/if\}\s*$",
    "",
    label="UserList.svelte — enterprise nag block",
)

# ── hatch_build.py — second branding string ───────────────────────────────────
patch("hatch_build.py", [
    ("building Open Webui", "building " + BRAND),
    ("for building Open Webui", "for building " + BRAND),
])

# ── package.json — package name ───────────────────────────────────────────────
SLUG = BRAND.lower().replace(" ", "-")
patch("package.json", [
    ('"name": "open-webui"', '"name": "' + SLUG + '"'),
])

# ── docker-compose.yaml — service/volume/container names ─────────────────────
for dc in glob.glob("docker-compose*.yaml"):
    patch(dc, [
        ("container_name: open-webui", "container_name: " + SLUG),
        ("- open-webui:/app/backend/data", "- " + SLUG + ":/app/backend/data"),
        ("  open-webui: {}", "  " + SLUG + ": {}"),
        ("image: ghcr.io/open-webui/open-webui:${WEBUI_DOCKER_TAG-main}",
         "image: " + SLUG + ":latest"),
        ("OTEL_SERVICE_NAME=open-webui", "OTEL_SERVICE_NAME=" + SLUG),
    ])

# ── pyproject.toml — author name (keep package name, it's structural) ────────
patch("pyproject.toml", [
    ('name = "Timothy Jaeryang Baek"', 'name = ""'),
])


# ═══════════════════════════════════════════════════════════════════════════════
# 4. Global branding sweep
# ═══════════════════════════════════════════════════════════════════════════════

print("\n[4/8] Global branding sweep")

DEAD_URLS = [
    "https://discord.gg/5rJgQTnV4s",
    "https://twitter.com/OpenWebUI",
    "https://docs.openwebui.com/enterprise",
    "https://docs.openwebui.com",
    "https://www.openwebui.com",
    "https://openwebui.com",
    "https://github.com/open-webui/open-webui/releases",
    "https://github.com/open-webui/open-webui/blob/main/LICENSE",
    "https://github.com/open-webui/open-webui/blob/main/docs/CONTRIBUTING.md",
    "https://github.com/open-webui/open-webui#troubleshooting",
    "https://github.com/open-webui/openapi-servers",
    "https://github.com/open-webui/open-terminal",
    "https://github.com/open-webui",
    "https://github.com/sponsors/tjbck",
    "https://github.com/tjbck",
]

svelte_count = 0
for filepath in sorted(glob.glob("src/**/*.svelte", recursive=True)):
    content = read(filepath)
    original = content
    for url in DEAD_URLS:
        content = content.replace(url, "#")
    content = re.sub(
        r'src="https://img\.shields\.io/[^"]*"',
        'src="" style="display:none"',
        content,
    )
    content = content.replace("Open WebUI", BRAND)
    content = content.replace("open-webui", SLUG)
    content = re.sub(
        r"""!?\[['"]#['"],\s*['"]#['"],\s*['"]http://localhost:9999['"]\]\.includes\(""",
        "false && (",
        content,
    )
    if content != original:
        write(filepath, content)
        svelte_count += 1
print("  .svelte files patched: " + str(svelte_count))

ts_count = 0
for filepath in sorted(glob.glob("src/**/*.ts", recursive=True)):
    content = read(filepath)
    original = content
    content = content.replace("Open WebUI", BRAND)
    if content != original:
        write(filepath, content)
        ts_count += 1
print("  .ts files patched:     " + str(ts_count))

py_count = 0
for filepath in sorted(glob.glob("backend/**/*.py", recursive=True)):
    if "/test/" in filepath:
        continue
    content = read(filepath)
    original = content

    content = content.replace("Open WebUI", BRAND)

    content = content.replace("https://api.openwebui.com", "#")
    content = content.replace("https://licenses.api.openwebui.com", "#")
    content = content.replace("https://docs.openwebui.com", "#")
    content = content.replace('"https://openwebui.com/"', '"#"')
    content = content.replace('"https://openwebui.com"', '"#"')
    content = content.replace("tim@openwebui.com", "")
    content = content.replace("openwebui.com", "")

    content = content.replace("X-OpenWebUI-", "X-" + SLUG + "-")
    content = content.replace("OpenWebUI-User-", SLUG + "-user-")
    content = content.replace("OpenWebUI-File-", SLUG + "-file-")
    content = content.replace("OpenWebUI-MistralLoader/2.0", SLUG + "/2.0")
    content = content.replace("Removes OpenWebUI specific parameters", "Removes internal parameters")
    content = content.replace("with OpenWebUI parameters removed", "with internal parameters removed")
    content = content.replace("available in OpenWebUI", "available")
    content = content.replace("for OpenWebUI tokens", "for tokens")
    content = content.replace("for an OpenWebUI JWT", "for a JWT")
    content = content.replace("exchange OAuth tokens for OpenWebUI", "exchange OAuth tokens for local")

    content = re.sub(
        r'"User-Agent":\s*"[^"]*open-webui/open-webui[^"]*"',
        '"User-Agent": "' + SLUG + '"',
        content,
    )
    content = content.replace('"open-webui"', '"' + SLUG + '"')

    if content != original:
        write(filepath, content)
        py_count += 1
print("  .py files patched:     " + str(py_count))

i18n_count = 0
for filepath in sorted(glob.glob("src/lib/i18n/locales/*/translation.json")):
    content = read(filepath)
    original = content
    content = content.replace("Open WebUI", BRAND)
    content = content.replace("Open-WebUI", BRAND)
    content = content.replace("Open WEBUI", BRAND)
    content = content.replace("OpenWebUI", BRAND)
    content = content.replace("open-webui", SLUG)
    if content != original:
        write(filepath, content)
        i18n_count += 1
print("  i18n files patched:    " + str(i18n_count))


# ═══════════════════════════════════════════════════════════════════════════════
# 5. Generate neutral branding assets
# ═══════════════════════════════════════════════════════════════════════════════

print("\n[5/8] Generating neutral branding assets")

DARK = (23, 23, 23, 255)       # #171717 — matches default dark theme
LIGHT = (255, 255, 255, 255)
TRANS = (0, 0, 0, 0)
S = "static/static"

# Chat bubble SVG favicon (primary in modern browsers)
write(
    S + "/favicon.svg",
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500">\n'
    '  <rect width="500" height="500" rx="110" fill="#171717"/>\n'
    '  <path d="M 130 125 h 240 q 45 0 45 45 v 130 q 0 45 -45 45'
    " h -130 l -70 60 v -60 h -40 q -45 0 -45 -45"
    ' v -130 q 0 -45 45 -45 z" fill="#fff" opacity="0.9"/>\n'
    '  <circle cx="210" cy="265" r="18" fill="#171717" opacity="0.5"/>\n'
    '  <circle cx="290" cy="265" r="18" fill="#171717" opacity="0.5"/>\n'
    "  <style>\n"
    "    @media(prefers-color-scheme:dark){"
    'rect{fill:#fff}path{fill:#171717}circle{fill:#fff}}\n'
    "  </style>\n"
    "</svg>\n",
)

# PNG favicons
for name, size in [("favicon.png", 64), ("favicon-96x96.png", 96)]:
    write_bin(S + "/" + name, create_png(size, size, DARK))

write_bin(S + "/favicon-dark.png", create_png(64, 64, LIGHT))
write_bin(S + "/favicon.ico", create_ico(16, DARK))
write_bin(S + "/logo.png", create_png(500, 500, DARK))

# Splash screens — transparent = nothing shown during load
write_bin(S + "/splash.png", create_png(1, 1, TRANS))
write_bin(S + "/splash-dark.png", create_png(1, 1, TRANS))

# Apple / PWA icons
write_bin(S + "/apple-touch-icon.png", create_png(180, 180, DARK))
write_bin(S + "/web-app-manifest-192x192.png", create_png(192, 192, DARK))
write_bin(S + "/web-app-manifest-512x512.png", create_png(512, 512, DARK))

# Root-level favicon copy (served at /favicon.png)
shutil.copy(S + "/favicon.png", "static/favicon.png")

print("  Generated: favicon.svg, favicon.png, favicon-96x96.png,")
print("             favicon-dark.png, favicon.ico, logo.png,")
print("             splash.png, splash-dark.png, apple-touch-icon.png,")
print("             web-app-manifest-192x192.png, web-app-manifest-512x512.png")


# ═══════════════════════════════════════════════════════════════════════════════
# 6. Rewrite manifests
# ═══════════════════════════════════════════════════════════════════════════════

print("\n[6/8] Rewriting manifests")

write(
    S + "/site.webmanifest",
    json.dumps(
        {
            "name": BRAND,
            "short_name": BRAND,
            "icons": [
                {
                    "src": "/static/web-app-manifest-192x192.png",
                    "sizes": "192x192",
                    "type": "image/png",
                    "purpose": "maskable",
                },
                {
                    "src": "/static/web-app-manifest-512x512.png",
                    "sizes": "512x512",
                    "type": "image/png",
                    "purpose": "maskable",
                },
            ],
            "theme_color": "#171717",
            "background_color": "#171717",
            "display": "standalone",
        },
        indent=2,
    ),
)

write(
    "static/opensearch.xml",
    '<OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">\n'
    "<ShortName>" + BRAND + "</ShortName>\n"
    "<Description>Search " + BRAND + "</Description>\n"
    "<InputEncoding>UTF-8</InputEncoding>\n"
    "</OpenSearchDescription>\n",
)


# ═══════════════════════════════════════════════════════════════════════════════
# 7. Rename frontend code identifiers
# ═══════════════════════════════════════════════════════════════════════════════

print("\n[7/8] Renaming frontend code identifiers")

for filepath in sorted(glob.glob("src/**/*.svelte", recursive=True)):
    content = read(filepath)
    original = content
    content = content.replace("required_open_webui_version", "required_version")
    content = content.replace("OPEN_WEBUI_VERSION", "VERSION")
    if content != original:
        write(filepath, content)

for filepath in sorted(glob.glob("src/lib/i18n/locales/*/translation.json")):
    content = read(filepath)
    original = content
    content = content.replace("OPEN_WEBUI_VERSION", "VERSION")
    if content != original:
        write(filepath, content)

print("  required_open_webui_version → required_version")
print("  OPEN_WEBUI_VERSION → VERSION")


# ═══════════════════════════════════════════════════════════════════════════════
# 8. Rename Python module (open_webui → MODULE)
# ═══════════════════════════════════════════════════════════════════════════════

print("\n[8/8] Renaming Python module")

MODULE = BRAND.lower().replace(" ", "_").replace("-", "_")
MODULE_UPPER = MODULE.upper()
MODULE_DIR = "backend/" + MODULE

if MODULE != "open_webui" and os.path.isdir("backend/open_webui"):
    mod_count = 0
    for filepath in sorted(glob.glob("backend/**/*.py", recursive=True)):
        content = read(filepath)
        original = content
        content = content.replace("https://github.com/open-webui/open-webui", "#")
        content = content.replace("https://api.github.com/repos/open-webui/open-webui", "#")
        content = content.replace("OPEN_WEBUI_", MODULE_UPPER + "_")
        content = content.replace("open_webui", MODULE)
        content = content.replace("open-webui", SLUG)
        if content != original:
            write(filepath, content)
            mod_count += 1

    for filepath in sorted(glob.glob("backend/**/*.sh", recursive=True)):
        if os.path.isfile(filepath):
            content = read(filepath)
            content = content.replace("open_webui", MODULE)
            content = content.replace("open-webui", SLUG)
            write(filepath, content)

    patch("pyproject.toml", [
        ('name = "open-webui"', 'name = "' + SLUG + '"'),
        ('open-webui = "open_webui:app"', SLUG + ' = "' + MODULE + ':app"'),
        ('"open_webui/', '"' + MODULE + '/'),
        ('= "open_webui/', '= "' + MODULE + '/'),
    ])

    patch("hatch_build.py", [
        ("open_webui", MODULE),
    ])

    for filepath in sorted(glob.glob("src/**/*.svelte", recursive=True)):
        content = read(filepath)
        original = content
        content = content.replace("open_webui", MODULE)
        if content != original:
            write(filepath, content)

    for dc in glob.glob("docker-compose*.yaml"):
        content = read(dc)
        content = content.replace("  open-webui:\n", "  " + SLUG + ":\n")
        content = content.replace("OPEN_WEBUI_PORT", MODULE_UPPER + "_PORT")
        write(dc, content)

    os.rename("backend/open_webui", MODULE_DIR)
    print("  backend/open_webui/ → backend/" + MODULE + "/")
    print("  " + str(mod_count) + " .py files updated")
else:
    print("  Module name is already '" + MODULE + "', skipping rename")


# ═══════════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════════

print("\n" + "=" * 50)
print("Rebranding complete: " + repr(BRAND))
print("  Patches applied: " + str(_ok))
if _miss:
    print("  Patterns missed:  " + str(_miss) + " (may be OK if handled by global sweep)")
else:
    print("  Patterns missed:  0")
print("=" * 50)
