// Review Service — Online Boutique
// Autenticación de compradores (email + contraseña) y reseñas verificadas por compra.
// Solo un usuario que compró el producto puede comentarlo y calificarlo (1-5).
const http = require('http');
const crypto = require('crypto');
const { Pool } = require('pg');

const PORT = process.env.PORT || 8080;
const SESSION_TTL_HOURS = 24;

const pool = new Pool({
  host: process.env.DB_HOST || 'postgres-review-db',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'reviewdb',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || '',
  max: 5,
});

// ---------- utilidades ----------

function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(password, salt, 64).toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(password, stored) {
  const [salt, hash] = stored.split(':');
  const candidate = crypto.scryptSync(password, salt, 64).toString('hex');
  return crypto.timingSafeEqual(Buffer.from(hash, 'hex'), Buffer.from(candidate, 'hex'));
}

function newToken() {
  return crypto.randomBytes(32).toString('hex');
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
      if (data.length > 1e6) reject(new Error('payload too large'));
    });
    req.on('end', () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch (e) {
        reject(new Error('invalid json'));
      }
    });
    req.on('error', reject);
  });
}

function json(res, code, obj) {
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(obj));
}

function bearerToken(req) {
  const h = req.headers['authorization'] || '';
  return h.startsWith('Bearer ') ? h.slice(7) : null;
}

async function userFromToken(req) {
  const token = bearerToken(req);
  if (!token) return null;
  const q = await pool.query(
    `SELECT u.id, u.email, u.name FROM sessions s
     JOIN users u ON u.id = s.user_id
     WHERE s.token = $1 AND s.expires_at > NOW()`,
    [token]
  );
  return q.rows[0] || null;
}

async function hasPurchased(userId, productId) {
  const q = await pool.query(
    'SELECT 1 FROM purchases WHERE user_id = $1 AND product_id = $2 LIMIT 1',
    [userId, productId]
  );
  return q.rowCount > 0;
}

// ---------- esquema ----------

async function initSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      pass_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS sessions (
      token TEXT PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      expires_at TIMESTAMPTZ NOT NULL
    );
    CREATE TABLE IF NOT EXISTS purchases (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      product_id TEXT NOT NULL,
      order_id TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE (user_id, product_id, order_id)
    );
    CREATE TABLE IF NOT EXISTS reviews (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      product_id TEXT NOT NULL,
      rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
      comment TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE (user_id, product_id)
    );
  `);
  console.log('esquema listo');
}

// ---------- handlers ----------

async function handleRegister(req, res) {
  const { email, password, name } = await readBody(req);
  if (!email || !password || !name) return json(res, 400, { error: 'email, password y name son obligatorios' });
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return json(res, 400, { error: 'email invalido' });
  if (password.length < 6) return json(res, 400, { error: 'password minimo 6 caracteres' });

  const exists = await pool.query('SELECT 1 FROM users WHERE email = $1', [email.toLowerCase()]);
  if (exists.rowCount > 0) return json(res, 409, { error: 'ese correo ya esta registrado' });

  const ins = await pool.query(
    'INSERT INTO users (email, name, pass_hash) VALUES ($1, $2, $3) RETURNING id, email, name',
    [email.toLowerCase(), name, hashPassword(password)]
  );
  const user = ins.rows[0];
  const token = await createSession(user.id);
  json(res, 201, { user, token });
}

async function createSession(userId) {
  const token = newToken();
  await pool.query(
    'INSERT INTO sessions (token, user_id, expires_at) VALUES ($1, $2, NOW() + $3::interval)',
    [token, userId, `${SESSION_TTL_HOURS} hours`]
  );
  return token;
}

async function handleLogin(req, res) {
  const { email, password } = await readBody(req);
  if (!email || !password) return json(res, 400, { error: 'email y password son obligatorios' });

  const q = await pool.query('SELECT id, email, name, pass_hash FROM users WHERE email = $1', [email.toLowerCase()]);
  const user = q.rows[0];
  if (!user || !verifyPassword(password, user.pass_hash)) {
    return json(res, 401, { error: 'credenciales invalidas' });
  }
  const token = await createSession(user.id);
  json(res, 200, { user: { id: user.id, email: user.email, name: user.name }, token });
}

async function handleLogout(req, res) {
  const token = bearerToken(req);
  if (token) await pool.query('DELETE FROM sessions WHERE token = $1', [token]);
  json(res, 200, { ok: true });
}

async function handleMe(req, res) {
  const user = await userFromToken(req);
  if (!user) return json(res, 401, { error: 'sesion no valida' });
  json(res, 200, { user });
}

// Lista de reseñas públicas de un producto
async function handleGetReviews(req, res, url) {
  const productId = url.searchParams.get('product_id');
  if (!productId) return json(res, 400, { error: 'falta product_id' });

  const q = await pool.query(
    `SELECT r.id, r.rating, r.comment, r.created_at, u.name AS author
     FROM reviews r JOIN users u ON u.id = r.user_id
     WHERE r.product_id = $1 ORDER BY r.created_at DESC`,
    [productId]
  );
  const avg = q.rowCount
    ? q.rows.reduce((s, r) => s + r.rating, 0) / q.rowCount
    : 0;
  json(res, 200, { reviews: q.rows, count: q.rowCount, avg_rating: Math.round(avg * 10) / 10 });
}

// ¿Este usuario puede reseñar este producto? Solo si lo compró.
async function handleCanReview(req, res, url) {
  const user = await userFromToken(req);
  if (!user) return json(res, 200, { allowed: false, reason: 'not_logged_in' });

  const productId = url.searchParams.get('product_id');
  if (!productId) return json(res, 400, { error: 'falta product_id' });

  const bought = await hasPurchased(user.id, productId);
  const already = await pool.query(
    'SELECT 1 FROM reviews WHERE user_id = $1 AND product_id = $2', [user.id, productId]
  );
  json(res, 200, {
    allowed: bought,
    already_reviewed: already.rowCount > 0,
    reason: bought ? 'purchased' : 'not_purchased',
  });
}

// Crear/actualizar reseña — exige sesion + compra verificada
async function handleCreateReview(req, res) {
  const user = await userFromToken(req);
  if (!user) return json(res, 401, { error: 'inicia sesion para comentar' });

  const { product_id, rating, comment } = await readBody(req);
  if (!product_id || !rating || !comment) return json(res, 400, { error: 'product_id, rating y comment son obligatorios' });
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) return json(res, 400, { error: 'rating debe ser entero de 1 a 5' });

  // REGLA DE NEGOCIO: solo compradores verificados
  if (!(await hasPurchased(user.id, product_id))) {
    return json(res, 403, { error: 'solo puedes calificar productos que compraste' });
  }

  const q = await pool.query(
    `INSERT INTO reviews (user_id, product_id, rating, comment)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (user_id, product_id)
     DO UPDATE SET rating = EXCLUDED.rating, comment = EXCLUDED.comment, updated_at = NOW()
     RETURNING id, rating, comment, created_at`,
    [user.id, product_id, rating, comment]
  );
  json(res, 201, { review: q.rows[0] });
}

// Registrar compra al terminar checkout (llamado por el frontend)
async function handleRecordPurchase(req, res) {
  const user = await userFromToken(req);
  if (!user) return json(res, 401, { error: 'sesion requerida' });

  const { order_id, product_ids } = await readBody(req);
  if (!Array.isArray(product_ids) || product_ids.length === 0) {
    return json(res, 400, { error: 'product_ids requerido' });
  }
  for (const pid of product_ids) {
    await pool.query(
      'INSERT INTO purchases (user_id, product_id, order_id) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING',
      [user.id, String(pid), order_id || null]
    );
  }
  json(res, 201, { recorded: product_ids.length });
}

// ---------- router ----------

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const path = url.pathname.replace(/\/+$/, '') || '/';
  try {
    if (req.method === 'GET' && (path === '/health' || path === '/liveness')) {
      return json(res, 200, { status: 'ok' });
    }
    if (req.method === 'POST' && path === '/api/register') return await handleRegister(req, res);
    if (req.method === 'POST' && path === '/api/login') return await handleLogin(req, res);
    if (req.method === 'POST' && path === '/api/logout') return await handleLogout(req, res);
    if (req.method === 'GET' && path === '/api/me') return await handleMe(req, res);
    if (req.method === 'GET' && path === '/api/reviews') return await handleGetReviews(req, res, url);
    if (req.method === 'GET' && path === '/api/can-review') return await handleCanReview(req, res, url);
    if (req.method === 'POST' && path === '/api/reviews') return await handleCreateReview(req, res);
    if (req.method === 'POST' && path === '/api/purchases') return await handleRecordPurchase(req, res);
    if (req.method === 'GET' && path === '/') return json(res, 200, { message: 'Review Service Active' });
    json(res, 404, { error: 'not found' });
  } catch (e) {
    console.error('error:', e.message);
    json(res, e.message === 'invalid json' ? 400 : 500, { error: 'error interno' });
  }
});

initSchema()
  .then(() => server.listen(PORT, () => console.log(`Review service listening on port ${PORT}`)))
  .catch((e) => {
    console.error('no se pudo inicializar la base de datos:', e.message);
    process.exit(1);
  });
