#!/bin/bash
set -euxo pipefail

systemctl stop project-showcase || true

rm -rf /opt/project-showcase/app
mkdir -p /opt/project-showcase/app
