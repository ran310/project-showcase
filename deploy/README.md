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

### Card images

Cards use a **4:3** image area with **`object-fit: cover`** (same treatment for every experiment). Photos should be **full-bleed landscape hero images**—background and subject reach all four edges. Do **not** use square “app icon” exports with white margins, rounded frames, or gray checkerboard “transparency” baked in; those show visible borders on the card.

**Option A — Unsplash (like NFL Quiz, City Distance Finder):** set **`imageUrl`** to an external URL, e.g.

`https://images.unsplash.com/photo-…?auto=format&fit=crop&w=1200&q=80`

**Option B — Bundled image:** save the file under **`frontend/public/images/`** (e.g. **`magic-cube.jpeg`**), reference it as **`"/images/magic-cube.jpeg"`**, then rebuild:

```bash
cd frontend && VITE_BASE=/ npm run build && cd ..
```

Vite copies **`frontend/public/`** into **`static/`** on build; Flask serves **`/images/…`** in production.

### Nano Banana prompt (custom card art)

In **Nano Banana** (Gemini image), set **aspect ratio 4:3** (or **1200×900**). Avoid “app icon”, “rounded square”, or “transparent background” presets.

**Primary prompt:**

```
Create a wide hero photograph for a project showcase card, not an app icon.

Subject: [your app subject — e.g. A glowing 3D Rubik’s cube, vivid colors, polished and slightly luminous].

Setting: [full-bleed background that extends to all four edges — e.g. deep cosmic space with nebulae and stars].

Composition: Landscape 4:3 aspect ratio (1200x900). Wide shot, subject centered, filling most of the frame. Full-bleed edge-to-edge artwork like a stock photo hero banner.

Style: Cinematic, rich contrast, photorealistic. Dark moody atmosphere similar to a premium tech demo thumbnail.

Technical requirements: No white border, no padding, no letterboxing, no rounded app-icon frame, no drop shadow outside the canvas, no checkerboard transparency pattern, no mockup device. The image should look like one continuous photograph that can be cropped with object-fit cover on a website card.
```

**If the first result still looks like an icon or has margins**, use an edit/follow-up:

```
Edit this image: remove all white margins, gray checkerboard corners, and rounded app-icon framing. Expand the background to fill the entire 4:3 canvas edge to edge. Keep the subject centered and larger. Output as a full-bleed landscape hero image only, not a square app icon.
```

Save the result to **`frontend/public/images/<id>.jpeg`**, set **`imageUrl`** to **`"/images/<id>.jpeg"`**, and rebuild the frontend.

## Nginx `projectName`

The vhost file is **`/etc/nginx/conf.d/<projectName>-apps.conf`**, created by **CDK user data** (default **`learn-aws`** from context **`projectName`**). Change **`projectName`** in **aws-infra** and redeploy the EC2 stack if the path on disk must match.
