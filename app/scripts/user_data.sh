#!/bin/bash
set -xe


# Redirect standard output and error to both log file and system console for debugging via AWS Systems Manager
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "==> [Step 1/5] Updating OS packages and installing system runtimes..."
dnf update -y
dnf install -y nodejs npm git

echo "==> [Step 2/5] Creating application directory structure..."
mkdir -p /opt/app
cd /opt/app

echo "==> [Step 3/5] Generating application manifest and source files..."

# Define Node.js project manifest
cat <<'EOF' > /opt/app/package.json
{
  "name": "cloud-diagnostic-app",
  "version": "1.0.0",
  "description": "Cloud-native diagnostic application for 3-tier AWS architecture",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.19.2",
    "pg": "^8.11.5"
  }
}
EOF

# Define core Express backend server
cat <<'EOF' > /opt/app/server.js
const express = require('express');
const http = require('http');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 8080;

// Database connection pool configured via environment variables
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT, 10) || 5432,
  user: process.env.DB_USER || 'cloudadmin',
  password: process.env.DB_PASSWORD || 'password',
  database: process.env.DB_NAME || 'enterprisedb',
  connectionTimeoutMillis: 3000,
  ssl: {
    rejectUnauthorized: false,
  },
});

/**
 * Fetches instance metadata securely using AWS IMDSv2 session tokens.
 * Complies with AWS Security Best Practices and CIS Benchmark standards.
 */
async function getIMDSv2Metadata(path) {
  return new Promise((resolve) => {
    // Step 1: Request IMDSv2 token with a 60-second Time-To-Live (TTL)
    const tokenReq = http.request(
      {
        host: '169.254.169.254',
        path: '/latest/api/token',
        method: 'PUT',
        headers: { 'X-aws-ec2-metadata-token-ttl-seconds': '60' },
        timeout: 1000,
      },
      (res) => {
        let token = '';
        res.on('data', (chunk) => (token += chunk));
        res.on('end', () => {
          if (res.statusCode !== 200) {
            return resolve('Local-Development-Mode');
          }

          // Step 2: Query metadata using the authorized token
          const metaReq = http.request(
            {
              host: '169.254.169.254',
              path: `/latest/meta-data/$${path}`,
              method: 'GET',
              headers: { 'X-aws-ec2-metadata-token': token },
              timeout: 1000,
            },
            (metaRes) => {
              let data = '';
              metaRes.on('data', (chunk) => (data += chunk));
              metaRes.on('end', () => resolve(data.trim()));
            }
          );
          metaReq.on('error', () => resolve('Unavailable'));
          metaReq.end();
        });
      }
    );
    tokenReq.on('error', () => resolve('Local-Development-Mode'));
    tokenReq.end();
  });
}


// Endpoint 1: Health Probe Endpoint (Application Load Balancer & Synthetics Canary)
app.get('/healthz', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime_seconds: process.uptime(),
  });
});


// Endpoint 2: Diagnostic Dashboard UI
// Displays EC2 instance metadata, active Availability Zone, and RDS connectivity status
app.get('/', async (req, res) => {
  const instanceId = await getIMDSv2Metadata('instance-id');
  const availabilityZone = await getIMDSv2Metadata('placement/availability-zone');
  const privateIp = await getIMDSv2Metadata('local-ipv4');

  let dbStatus = 'Disconnected / Standby';
  try {
    const dbRes = await pool.query('SELECT NOW() as current_time, current_database() as db_name;');
    dbStatus = `Connected to [$${dbRes.rows[0].db_name}] at $${dbRes.rows[0].current_time}`;
  } catch (err) {
    dbStatus = `Unavailable ($${err.message})`;
  }

  const html = `
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Enterprise Cloud Infrastructure Hub</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 40px; }
      .container { max-width: 820px; margin: 0 auto; background: #1e293b; border-radius: 12px; padding: 32px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; }
      h1 { margin-top: 0; color: #38bdf8; font-size: 24px; border-bottom: 1px solid #334155; padding-bottom: 16px; }
      .grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 16px; margin-top: 24px; }
      .card { background: #0f172a; padding: 16px; border-radius: 8px; border: 1px solid #334155; }
      .label { font-size: 12px; text-transform: uppercase; color: #94a3b8; letter-spacing: 0.05em; margin-bottom: 6px; }
      .value { font-size: 16px; font-weight: 600; color: #f1f5f9; font-family: monospace; }
      .badge-az { color: #34d399; }
      .status-box { margin-top: 24px; padding: 16px; border-radius: 8px; background: #0f172a; border-left: 4px solid #38bdf8; }
      .actions { margin-top: 24px; display: flex; gap: 12px; }
      button { background: #2563eb; color: #ffffff; border: none; padding: 10px 18px; border-radius: 6px; font-weight: 600; cursor: pointer; transition: 0.2s; }
      button:hover { background: #1d4ed8; }
      .btn-danger { background: #dc2626; }
      .btn-danger:hover { background: #b91c1c; }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>Enterprise 3-Tier Diagnostic Hub</h1>
      <div class="grid">
        <div class="card">
          <div class="label">Instance ID</div>
          <div class="value">$${instanceId}</div>
        </div>
        <div class="card">
          <div class="label">Availability Zone</div>
          <div class="value badge-az">$${availabilityZone}</div>
        </div>
        <div class="card">
          <div class="label">Private IPv4 Address</div>
          <div class="value">$${privateIp}</div>
        </div>
        <div class="card">
          <div class="label">Deployment Environment</div>
          <div class="value">$${process.env.NODE_ENV || 'production'}</div>
        </div>
      </div>

      <div class="status-box">
        <div class="label">Database Connection Status (RDS Multi-AZ)</div>
        <div class="value" style="font-size: 14px; margin-top: 4px;">$${dbStatus}</div>
      </div>

      <div class="actions">
        <button onclick="fetch('/api/stress-cpu').then(() => alert('Triggered CPU Stress test! Monitor CloudWatch Alarm and ASG Scale-out event.'))">Trigger CPU Stress (Phase 3)</button>
        <button class="btn-danger" onclick="fetch('/api/simulate-500').then(r => alert('Simulated HTTP ' + r.status + ' Error! Verify CloudWatch Metric Filter.'))">Simulate HTTP 500 (Phase 3)</button>
      </div>
    </div>
  </body>
  </html>
  `;
  res.send(html);
});


// Endpoint 3: Synthetic CPU Stress Generator
// Drives CPU utilization to trigger CloudWatch High CPU Alarms and ASG scaling policies
app.get('/api/stress-cpu', (req, res) => {
  res.json({ message: 'Generating sustained CPU workload for 60 seconds...' });

  const endTime = Date.now() + 60000;
  while (Date.now() < endTime) {
    Math.sqrt(Math.random() * Math.random());
  }
});


// Endpoint 4: Simulated Application Fault
// Emits error logs to validate CloudWatch Log Metric Filters and ChatOps notifications
app.get('/api/simulate-500', (req, res) => {
  console.error('[ERROR] Simulated Fatal Exception: Database transaction timeout at ' + new Date().toISOString());
  res.status(500).json({ error: 'InternalServerError', message: 'Simulated failure for metric filter validation' });
});

app.listen(PORT, () => {
  console.log(`[Diagnostic App] Server listening on port $${PORT}`);
});
EOF

echo "==> [Step 4/5] Installing production dependencies and assigning permissions..."
npm install --production
chown -R ec2-user:ec2-user /opt/app

echo "==> [Step 5/5] Provisioning systemd service unit..."
cat <<EOF > /etc/systemd/system/cloud-app.service
[Unit]
Description=Enterprise Cloud Diagnostic Web Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/app
ExecStart=/usr/bin/node /opt/app/server.js
Restart=always
RestartSec=5
Environment=PORT=8080
Environment=NODE_ENV=production
Environment=DB_HOST=${db_host}
Environment=DB_PORT=${db_port}
Environment=DB_NAME=${db_name}
Environment=DB_USER=${db_user}
Environment=DB_PASSWORD=${db_password}

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd manager configuration and enable the service on boot
systemctl daemon-reload
systemctl enable --now cloud-app.service

echo "==> Bootstrap process complete. Service running on port 8080."