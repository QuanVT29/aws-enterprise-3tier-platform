const express = require('express');
const http = require('http');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 8080;

// Cấu hình Database Pool (lấy động từ Environment Variables)
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'password',
  database: process.env.DB_NAME || 'testdb',
  connectionTimeoutMillis: 3000,
  ssl: {
    rejectUnauthorized: false,
  },
});

// Hàm hỗ trợ đọc AWS EC2 Metadata qua chuẩn an toàn IMDSv2
async function getIMDSv2Metadata(path) {
  return new Promise((resolve) => {
    // B1: Xin Token IMDSv2
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
          if (res.statusCode !== 200) return resolve('Local-Development-Mode');

          // B2: Dùng Token để đọc Metadata
          const metaReq = http.request(
            {
              host: '169.254.169.254',
              path: `/latest/meta-data/${path}`,
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
          metaReq.on('error', () => resolve('N/A'));
          metaReq.end();
        });
      }
    );
    tokenReq.on('error', () => resolve('Local-Development-Mode'));
    tokenReq.end();
  });
}

// 1. HEALTH CHECK ENDPOINT (ALB và Synthetics Canary)
app.get('/healthz', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime_seconds: process.uptime(),
  });
});

// 2. DASHBOARD VIEW (Hiển thị Instance ID, AZ, IP và DB Status)
app.get('/', async (req, res) => {
  const instanceId = await getIMDSv2Metadata('instance-id');
  const availabilityZone = await getIMDSv2Metadata('placement/availability-zone');
  const privateIp = await getIMDSv2Metadata('local-ipv4');

  let dbStatus = 'Disconnected / Standby';
  try {
    const dbRes = await pool.query('SELECT NOW() as current_time, current_database() as db_name;');
    dbStatus = `Connected to [${dbRes.rows[0].db_name}] at ${dbRes.rows[0].current_time}`;
  } catch (err) {
    dbStatus = `Unavailable (${err.message})`;
  }

  const html = `
  <!DOCTYPE html>
  <html>
  <head>
    <title>Enterprise Cloud Infrastructure Hub</title>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 40px; }
      .container { max-width: 800px; margin: 0 auto; background: #1e293b; border-radius: 12px; padding: 32px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; }
      h1 { margin-top: 0; color: #38bdf8; font-size: 24px; border-bottom: 1px solid #334155; padding-bottom: 16px; }
      .grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 16px; margin-top: 24px; }
      .card { background: #0f172a; padding: 16px; border-radius: 8px; border: 1px solid #334155; }
      .label { font-size: 12px; text-transform: uppercase; color: #94a3b8; letter-spacing: 0.05em; margin-bottom: 6px; }
      .value { font-size: 16px; font-weight: 600; color: #f1f5f9; font-family: monospace; }
      .badge-az { color: #34d399; }
      .status-box { margin-top: 24px; padding: 16px; border-radius: 8px; background: #0f172a; border-left: 4px solid #38bdf8; }
      .actions { margin-top: 24px; display: flex; gap: 12px; }
      button { background: #2563eb; color: white; border: none; padding: 10px 18px; border-radius: 6px; font-weight: 600; cursor: pointer; transition: 0.2s; }
      button:hover { background: #1d4ed8; }
      .btn-danger { background: #dc2626; }
      .btn-danger:hover { background: #b91c1c; }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>🚀 AWS Enterprise 3-Tier Diagnostic Hub</h1>
      <div class="grid">
        <div class="card">
          <div class="label">Instance ID</div>
          <div class="value">${instanceId}</div>
        </div>
        <div class="card">
          <div class="label">Availability Zone</div>
          <div class="value badge-az">${availabilityZone}</div>
        </div>
        <div class="card">
          <div class="label">Private IPv4 Address</div>
          <div class="value">${privateIp}</div>
        </div>
        <div class="card">
          <div class="label">Application Environment</div>
          <div class="value">${process.env.NODE_ENV || 'Production'}</div>
        </div>
      </div>

      <div class="status-box">
        <div class="label">Database Connection Status (RDS Multi-AZ)</div>
        <div class="value" style="font-size: 14px; margin-top: 4px;">${dbStatus}</div>
      </div>

      <div class="actions">
        <button onclick="fetch('/api/stress-cpu').then(() => alert('Triggered CPU Stress! Watch CloudWatch Alarm & ASG Scale-out.'))">🔥 Test CPU Stress (Phase 3)</button>
        <button class="btn-danger" onclick="fetch('/api/simulate-500').then(r => alert('Simulated HTTP ' + r.status + ' Error!'))">⚠️ Simulate HTTP 500 (Phase 3)</button>
      </div>
    </div>
  </body>
  </html>
  `;
  res.send(html);
});

// 3. ENDPOINT TẠO TẢI CPU (test Phase 3 CloudWatch Alarms & ASG Scale-Out)
app.get('/api/stress-cpu', (req, res) => {
  res.json({ message: 'Generating CPU load for 60 seconds...' });

  const endTime = Date.now() + 60000;
  // Vòng lặp tính toán nặng đẩy CPU lên 80-100%
  while (Date.now() < endTime) {
    Math.sqrt(Math.random() * Math.random());
  }
});

// 4. ENDPOINT GIẢ LẬP LỖI 500 (test Log Metric Filter & Alerting)
app.get('/api/simulate-500', (req, res) => {
  console.error('[ERROR] Simulated Fatal Exception: Database transaction timeout at ' + new Date().toISOString());
  res.status(500).json({ error: 'InternalServerError', message: 'Simulated failure for metric filter validation' });
});

app.listen(PORT, () => {
  console.log(`[Diagnostic App] Listening on port ${PORT}`);
});