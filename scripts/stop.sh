#!/usr/bin/env bash
# Stop the local Flask process started by scripts/start.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIDFILE="${ROOT}/.local/flask.pid"

if [[ ! -f "${PIDFILE}" ]]; then
  echo "No PID file (${PIDFILE}); nothing to stop."
  exit 0
fi

pid="$(cat "${PIDFILE}")"
if kill -0 "${pid}" 2>/dev/null; then
  kill "${pid}"
  echo "Stopped project-showcase (PID ${pid})."
else
  echo "Stale PID file (process ${pid} not running); removed."
fi

rm -f "${PIDFILE}"
