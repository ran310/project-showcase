#!/bin/bash
# Run on the EC2 nginx host (via SSM). Args: <s3-bucket> <s3-key>
set -euxo pipefail

BUCKET="$1"
KEY="$2"
APP_DIR="/opt/project-showcase/app"
VENV="/opt/project-showcase/venv"
TMP="/tmp/project-showcase-install-$$"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$TMP"
aws s3 cp "s3://${BUCKET}/${KEY}" "${TMP}/app.tgz"
mkdir -p "$APP_DIR"
tar xzf "${TMP}/app.tgz" -C "$APP_DIR"

if command -v python3.11 &>/dev/null; then
  PY=python3.11
elif command -v python3 &>/dev/null; then
  PY=python3
else
  echo "python3.11 and python3 not found; install Python on the host." >&2
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

if [[ ! -f /etc/systemd/system/project-showcase.service ]]; then
  cat > /etc/systemd/system/project-showcase.service <<'UNIT'
[Unit]
Description=Project Showcase (Gunicorn)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/project-showcase/app
EnvironmentFile=/etc/project-showcase.env
ExecStart=/opt/project-showcase/venv/bin/gunicorn --bind 127.0.0.1:8081 app:app
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
fi

# Root `/` → project-showcase (:8081); `/nfl-quiz/` → :8080 (matches ec2-nginx-stack user data).
PROJECT_NAME="${NFL_QUIZ_PROJECT_NAME:-learn-aws}"
QUIZ_PATH="/nfl-quiz"
SHOWCASE_PORT="8081"
NGINX_CONF="/etc/nginx/conf.d/${PROJECT_NAME}-apps.conf"
mkdir -p /var/www/app1 /var/www/app2
cat > "$NGINX_CONF" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location = /nginx-health {
        access_log off;
        default_type text/plain;
        return 200 'ok';
    }

    location = ${QUIZ_PATH} {
        return 301 ${QUIZ_PATH}/;
    }

    location ${QUIZ_PATH}/ {
        proxy_pass http://127.0.0.1:8080/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Prefix ${QUIZ_PATH};
    }

    location /app1/ {
        alias /var/www/app1/;
        index index.html;
    }
    location /app2/ {
        alias /var/www/app2/;
        index index.html;
    }

    location = /project-showcase {
        return 301 /;
    }
    location /project-showcase/ {
        rewrite ^/project-showcase/(.*)\$ /\$1 permanent;
    }

    location / {
        proxy_pass http://127.0.0.1:${SHOWCASE_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Prefix "";
    }
}
EOF
nginx -t
systemctl reload nginx

systemctl daemon-reload
systemctl enable project-showcase
systemctl restart project-showcase
systemctl is-active project-showcase
