#!/bin/bash

# Bootstraps the EC2 application instance for the AWS Web Platform.
# Installs Apache, creates a basic application landing page, and exposes a health endpoint.

set -euo pipefail

LOG_FILE="/var/log/user-data.log"

exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "===== User Data Execution Started ====="
date

get_metadata_token() {
  curl -sS -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true
}

get_metadata() {
  local path="$1"
  local token="$2"

  if [[ -n "$token" ]]; then
    curl -sS \
      -H "X-aws-ec2-metadata-token: $token" \
      "http://169.254.169.254/latest/meta-data/${path}" || echo "unknown"
  else
    curl -sS "http://169.254.169.254/latest/meta-data/${path}" || echo "unknown"
  fi
}

echo "[INFO] Updating system packages..."
dnf update -y

echo "[INFO] Installing required packages..."
dnf install -y httpd jq

echo "[INFO] Enabling and starting Apache..."
systemctl enable httpd
systemctl start httpd

TOKEN="$(get_metadata_token)"
INSTANCE_ID="$(get_metadata "instance-id" "$TOKEN")"
AZ="$(get_metadata "placement/availability-zone" "$TOKEN")"
HOSTNAME="$(hostname)"
GENERATED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

echo "[INFO] Creating application index page..."

cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>AWS Web Platform</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            background: #f8fafc;
            color: #1f2937;
        }
        .container {
            max-width: 900px;
            padding: 24px;
            background: #ffffff;
            border: 1px solid #e5e7eb;
            border-radius: 8px;
        }
        .status {
            color: #047857;
            font-weight: bold;
        }
        code {
            background: #f3f4f6;
            padding: 2px 6px;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <main class="container">
        <h1>AWS Web Platform</h1>

        <p class="status">Application server launched successfully.</p>

        <p>
            This instance is running as part of a production-style AWS web platform
            deployed behind an Application Load Balancer and managed by an Auto Scaling Group.
        </p>

        <h2>Instance Information</h2>

        <ul>
            <li><strong>Hostname:</strong> ${HOSTNAME}</li>
            <li><strong>Instance ID:</strong> ${INSTANCE_ID}</li>
            <li><strong>Availability Zone:</strong> ${AZ}</li>
            <li><strong>Generated At:</strong> ${GENERATED_AT}</li>
        </ul>

        <h2>Health Check</h2>

        <p>
            Health endpoint:
            <code>/health.html</code>
        </p>
    </main>
</body>
</html>
EOF

echo "[INFO] Creating health check endpoint..."

cat > /var/www/html/health.html <<EOF
OK
EOF

echo "[INFO] Setting file permissions..."
chmod 644 /var/www/html/index.html /var/www/html/health.html

echo "[INFO] Validating Apache configuration..."
httpd -t

echo "[INFO] Restarting Apache..."
systemctl restart httpd

echo "[INFO] Verifying Apache status..."
systemctl is-active --quiet httpd

echo "===== User Data Execution Complete ====="
date