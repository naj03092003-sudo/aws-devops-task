"""Sample 3-tier demo app: ALB -> EC2 (Flask/gunicorn) -> RDS MySQL, plus S3 storage.

DB credentials are read at runtime from AWS Secrets Manager (never from env vars or disk).
"""
import json
import os
import socket
import time
import urllib.request
from datetime import datetime, timezone

import boto3
import pymysql
from flask import Flask, jsonify

REGION = os.environ.get("AWS_REGION", "ap-south-1")
SECRET_ARN = os.environ["DB_SECRET_ARN"]
DATA_BUCKET = os.environ["DATA_BUCKET"]

app = Flask(__name__)
_secret_cache = {"value": None, "ts": 0}


def imds(path):
    """Read instance metadata using IMDSv2."""
    try:
        req = urllib.request.Request(
            "http://169.254.169.254/latest/api/token",
            method="PUT",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "60"},
        )
        token = urllib.request.urlopen(req, timeout=2).read().decode()
        req = urllib.request.Request(
            f"http://169.254.169.254/latest/meta-data/{path}",
            headers={"X-aws-ec2-metadata-token": token},
        )
        return urllib.request.urlopen(req, timeout=2).read().decode()
    except Exception:
        return "unknown"


def get_secret():
    # cache for 5 minutes so rotation is picked up without hammering the API
    if _secret_cache["value"] and time.time() - _secret_cache["ts"] < 300:
        return _secret_cache["value"]
    client = boto3.client("secretsmanager", region_name=REGION)
    value = json.loads(client.get_secret_value(SecretId=SECRET_ARN)["SecretString"])
    _secret_cache.update(value=value, ts=time.time())
    return value


def db_connection():
    s = get_secret()
    return pymysql.connect(
        host=s["host"],
        port=int(s["port"]),
        user=s["username"],
        password=s["password"],
        database=s["dbname"],
        connect_timeout=5,
        ssl={"ca": os.environ.get("DB_SSL_CA", "/opt/app/rds-ca-bundle.pem")},
    )


def init_db():
    conn = db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "CREATE TABLE IF NOT EXISTS visits ("
                "id INT AUTO_INCREMENT PRIMARY KEY, "
                "instance_id VARCHAR(32), "
                "visited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)"
            )
        conn.commit()
    finally:
        conn.close()


@app.route("/health")
def health():
    """Liveness only. Used by the ALB target group, so a DB blip does not drain every instance."""
    return jsonify(status="ok"), 200


@app.route("/health/db")
def health_db():
    """Deep check: Secrets Manager + RDS connectivity."""
    try:
        conn = db_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
        conn.close()
        return jsonify(status="ok", database="reachable"), 200
    except Exception as exc:  # noqa: BLE001
        return jsonify(status="degraded", database="unreachable", error=type(exc).__name__), 503


@app.route("/")
def index():
    instance_id = imds("instance-id")
    az = imds("placement/availability-zone")
    try:
        init_db()
        conn = db_connection()
        with conn.cursor() as cur:
            cur.execute("INSERT INTO visits (instance_id) VALUES (%s)", (instance_id,))
            conn.commit()
            cur.execute("SELECT COUNT(*) FROM visits")
            total = cur.fetchone()[0]
        conn.close()
        db_status = f"connected, total visits: {total}"
    except Exception as exc:  # noqa: BLE001
        db_status = f"error ({type(exc).__name__})"
    return (
        "<html><body style='font-family:sans-serif;max-width:640px;margin:40px auto'>"
        "<h1>DevOps Practical Task</h1>"
        f"<p><b>Instance:</b> {instance_id}</p>"
        f"<p><b>Availability Zone:</b> {az}</p>"
        f"<p><b>Hostname:</b> {socket.gethostname()}</p>"
        f"<p><b>RDS MySQL:</b> {db_status}</p>"
        "<p>Endpoints: <code>/health</code>, <code>/health/db</code>, <code>/storage-check</code></p>"
        "</body></html>"
    )


@app.route("/storage-check")
def storage_check():
    """Writes a small object to the application S3 bucket to prove the IAM role + bucket work."""
    key = f"data/heartbeat-{socket.gethostname()}.json"
    body = json.dumps({"at": datetime.now(timezone.utc).isoformat()})
    try:
        s3 = boto3.client("s3", region_name=REGION)
        s3.put_object(Bucket=DATA_BUCKET, Key=key, Body=body.encode())
        return jsonify(status="ok", bucket=DATA_BUCKET, key=key), 200
    except Exception as exc:  # noqa: BLE001
        return jsonify(status="error", error=type(exc).__name__), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
