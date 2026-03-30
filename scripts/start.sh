#!/usr/bin/env bash
# Start Flask locally on 8081 (serves API + built static/).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PID_DIR="${ROOT}/.local"
PIDFILE="${PID_DIR}/flask.pid"
LOGFILE="${PID_DIR}/flask.log"
VENV="${ROOT}/.venv"

mkdir -p "${PID_DIR}"

if [[ -f "${PIDFILE}" ]]; then
  old="$(cat "${PIDFILE}")"
  if kill -0 "${old}" 2>/dev/null; then
    echo "Already running (PID ${old}). Use scripts/stop.sh first."
    exit 1
  fi
  rm -f "${PIDFILE}"
fi

if [[ ! -d "${VENV}" ]]; then
  echo "Creating venv…"
  python3 -m venv "${VENV}"
fi
echo "Installing Python deps…"
"${VENV}/bin/pip" install -q -r "${ROOT}/requirements.txt"

# Always use base "/" for local so asset URLs match how Flask is reached (not /project-showcase/).
if [[ ! -f "${ROOT}/static/index.html" ]] || grep -q 'src="/project-showcase/' "${ROOT}/static/index.html" 2>/dev/null; then
  echo "Building frontend for local (VITE_BASE=/)…"
  (cd "${ROOT}/frontend" && npm install && VITE_BASE=/ npm run build)
fi

nohup "${VENV}/bin/python" "${ROOT}/app.py" >> "${LOGFILE}" 2>&1 &
echo $! > "${PIDFILE}"

echo "Started project-showcase (PID $(cat "${PIDFILE}"))."
echo "  URL:  http://127.0.0.1:8081/"
echo "  Log:  ${LOGFILE}"
