# owui (native only)

One-command native white-label Open WebUI with stock onboarding/auth flow.

## Goal

Match stock Open WebUI runtime experience while removing branding/logos:

- first run asks to create admin account
- admin panel/features work as in stock Open WebUI
- no required startup env vars
- customize only brand and port via script args

## One command

```bash
git clone https://github.com/1qh/owui.git && cd owui
./run-native.sh DX2 3001
```

Open `http://localhost:3001` and complete admin onboarding.

## Script usage

```bash
./run-native.sh [BRAND_NAME] [HOST_PORT] [INSTALL_DIR]
```

- `BRAND_NAME` default: `Chat`
- `HOST_PORT` default: `3000`
- `INSTALL_DIR` default: `./owui-server`

## Behavior

- First run for a brand in an install directory:
  - clone upstream Open WebUI
  - strip unnecessary files
  - apply white-label rebrand
  - build frontend + install backend deps
  - start server
- Later runs with same brand/install dir:
  - reuse existing build and data
  - start server directly
- If brand changes for the same install dir:
  - directory is rebuilt for the new brand

## Stock-like auth defaults

`run-native.sh` no longer forces no-auth mode.

So by default you get upstream onboarding behavior:

- auth enabled
- first user/admin creation flow in UI
- settings/config handled from admin panel after login

## Optional environment variables

No env vars are required for normal use.

Optional:

- `OWUI_INCLUDE_MARIADB=0|1` (default `0`)
  - default skips optional `mariadb` Python package to avoid `mariadb_config` build errors on machines without MariaDB Connector/C
- `OWUI_TAG=vX.Y.Z`
  - pin upstream Open WebUI tag

## Prerequisites

- `python3` (`>=3.11,<3.13`)
- `git`
- `bun`
- `uv`

## Files

- `run-native.sh` — native bootstrap/start script
- `setup.sh` — clone/strip/rebrand pipeline
- `rebrand.py` — branding removal/replacement logic
