#!/bin/bash
set -euxo pipefail

APP_DIR="/opt/project-showcase/app"
VENV="/opt/project-showcase/venv"

if command -v python3.11 &>/dev/null; then
  PY=python3.11
elif command -v python3 &>/dev/null; then
  PY=python3
else
  echo "ERROR: python3 not found on the host." >&2
  exit 1
fi

if [[ ! -d "${VENV}" ]]; then
  "${PY}" -m venv "${VENV}"
fi

"${VENV}/bin/pip" install --upgrade pip
"${VENV}/bin/pip" install --no-cache-dir -r "${APP_DIR}/requirements.txt"

if [[ ! -f /etc/project-showcase.env ]]; then
  echo 'APPLICATION_ROOT=/' > /etc/project-showcase.env
elif ! grep -q '^APPLICATION_ROOT=' /etc/project-showcase.env 2>/dev/null; then
  echo 'APPLICATION_ROOT=/' >> /etc/project-showcase.env
else
  sed -i 's|^APPLICATION_ROOT=.*|APPLICATION_ROOT=/|' /etc/project-showcase.env
fi
if ! grep -q '^SECRET_KEY=' /etc/project-showcase.env 2>/dev/null; then
  echo "SECRET_KEY=$(openssl rand -hex 32)" >> /etc/project-showcase.env
fi

echo "AfterInstall complete"
