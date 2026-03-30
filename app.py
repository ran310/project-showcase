"""
Flask app: JSON experiments API + static React SPA (Vite build → static/).
"""

from __future__ import annotations

import json
import os
import secrets
from pathlib import Path

from flask import Flask, jsonify, send_from_directory
from werkzeug.middleware.proxy_fix import ProxyFix


def create_app() -> Flask:
    root_dir = Path(__file__).resolve().parent
    static_dir = root_dir / "static"
    experiments_path = root_dir / "experiments.json"

    app = Flask(__name__, static_folder=str(static_dir))
    app.secret_key = os.environ.get("SECRET_KEY") or secrets.token_hex(32)

    root = os.environ.get("APPLICATION_ROOT", "/").strip() or "/"
    if root != "/":
        app.config["APPLICATION_ROOT"] = root
        app.config["SESSION_COOKIE_PATH"] = root

    app.wsgi_app = ProxyFix(
        app.wsgi_app,
        x_for=1,
        x_proto=1,
        x_host=1,
        x_prefix=1,
    )

    @app.route("/api/experiments")
    def api_experiments():
        if not experiments_path.is_file():
            return jsonify({"experiments": []})
        with experiments_path.open(encoding="utf-8") as f:
            data = json.load(f)
        return jsonify(data)

    @app.route("/", defaults={"path": ""})
    @app.route("/<path:path>")
    def spa(path: str):
        if path.startswith("api"):
            return jsonify({"error": "not found"}), 404
        # Localhost uses /; a prod-targeted Vite build still references /project-showcase/assets/...
        # Nginx in production strips that prefix before proxying; emulate that here.
        if path.startswith("project-showcase/"):
            path = path[len("project-showcase/") :]
        if path:
            candidate = static_dir / path
            try:
                candidate.resolve().relative_to(static_dir.resolve())
            except ValueError:
                return send_from_directory(static_dir, "index.html")
            if candidate.is_file():
                return send_from_directory(static_dir, path)
        return send_from_directory(static_dir, "index.html")

    return app


app = create_app()


if __name__ == "__main__":
    app.run(debug=True, host="127.0.0.1", port=8081)
