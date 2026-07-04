// HS256 JWT 발급기(의존 0). 사용: node mint-jwt.js <userId> [role] [ttlSec]
const crypto = require('crypto');
const SECRET = process.env.JWT_SECRET
  || 'test-secret-please-change-min-32-bytes-long-0123456789';
const userId = process.argv[2] || '1';
const role = process.argv[3] || 'LEARNER';
const ttl = parseInt(process.argv[4] || '3600', 10);
const b64u = (buf) => Buffer.from(buf).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const header = b64u(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
const payload = b64u(JSON.stringify({ sub: String(userId), role, iat: now, exp: now + ttl }));
const data = `${header}.${payload}`;
const sig = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
process.stdout.write(`${data}.${sig}`);
