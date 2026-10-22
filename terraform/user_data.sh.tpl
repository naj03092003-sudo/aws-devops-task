#!/bin/bash
# App bundle hash: ${app_hash}   (changes here => new launch template version => rolling instance refresh)
set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

dnf install -y python3-pip unzip

mkdir -p /opt/app
aws s3 cp "s3://${app_bucket}/${bundle_key}" /tmp/app.zip --region ${region}
unzip -o /tmp/app.zip -d /opt/app

python3 -m venv /opt/app/venv
/opt/app/venv/bin/pip install --no-cache-dir -r /opt/app/requirements.txt

# RDS CA bundle so the app can verify the database TLS certificate.
curl -fsSL https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -o /opt/app/rds-ca-bundle.pem

useradd --system --no-create-home --shell /sbin/nologin appsvc || true
chown -R appsvc:appsvc /opt/app

cat > /etc/systemd/system/app.service <<UNIT
[Unit]
Description=Demo Flask application
After=network-online.target
Wants=network-online.target

[Service]
User=appsvc
WorkingDirectory=/opt/app
Environment=AWS_REGION=${region}
Environment=AWS_DEFAULT_REGION=${region}
Environment=DB_SECRET_ARN=${secret_arn}
Environment=DATA_BUCKET=${app_bucket}
Environment=DB_SSL_CA=/opt/app/rds-ca-bundle.pem
ExecStart=/opt/app/venv/bin/gunicorn --workers 2 --bind 0.0.0.0:8080 --access-logfile - app:app
Restart=always
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now app.service
