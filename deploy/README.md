# project-showcase AWS deployment

## Overview

**project-showcase** is a **Flask + React** gallery: experiment cards load from **`experiments.json`** (title, description, image URL, and **`href`** for any target link). The UI is built with Vite into **`static/`** in CI before the release tarball is uploaded.

Hosting matches **nfl-quiz**: GitHub Actions OIDC → **S3** zip artifact → **AWS CodeDeploy** (see **`appspec.yml`** + **`deploy/*.sh`**). The workflow resolves **`Ec2NginxArtifactBucketName`**, **`CodeDeployAppName`**, and **`CodeDeployDeploymentGroupNameProjectShowcase`** from **`AwsInfra-Ec2Nginx`**—nothing is hardcoded.

Nginx routes and upstream ports are declared in **aws-infra** **`lib/config/ec2-nginx-apps.ts`**. After changing routes, redeploy **`AwsInfra-Ec2Nginx`** (or replace the instance).

## IAM for GitHub Actions

Use the same role as nfl-quiz (or equivalent): **`cloudformation:DescribeStacks`**, **S3** write to the artifact bucket, **CodeDeploy** create deployment + read deployment/revision APIs. Set secret **`AWS_ROLE_TO_ASSUME`**. Optional variable **`AWS_REGION`**.

## Deploy

- **CI:** **Deploy to AWS** builds the frontend with **`VITE_BASE=/`** (output **`static/`**), zips the repo excluding **`frontend/`** source, uploads **`s3://…/project-showcase/releases/<sha>.zip`**, and runs CodeDeploy. The instance uses **`APPLICATION_ROOT=/`**.
- **Live URL:** **`http://<elastic-ip>/`** or **`https://<your-domain>/`** (TLS if you use the ALB + ACM setup).

## Local development

Quick run (background, **http://127.0.0.1:8081/**):

```bash
chmod +x scripts/start.sh scripts/stop.sh
./scripts/start.sh   # creates .venv if needed, builds static/ if missing
./scripts/stop.sh
```

Logs: **`.local/flask.log`**. PID: **`.local/flask.pid`**.

Manual setup:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd frontend && npm install && VITE_BASE=/ npm run build && cd ..
python app.py
```

For hot reload on the UI, run Flask on **8081** and in another terminal **`cd frontend && npm run dev`** (Vite proxies **`/api`** to Flask).

## Curating experiments

Edit **`experiments.json`** at repo root. Each item: **`id`**, **`title`**, **`description`**, **`imageUrl`**, **`href`** (any URL — repo, demo, blog, etc.).

## Nginx `projectName`

The vhost file is **`/etc/nginx/conf.d/<projectName>-apps.conf`**, created by **CDK user data** (default **`learn-aws`** from context **`projectName`**). Change **`projectName`** in **aws-infra** and redeploy the EC2 stack if the path on disk must match.
