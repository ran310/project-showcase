#!/bin/bash
set -euo pipefail

systemctl stop project-showcase || true
echo "project-showcase stopped (or was not running)"
