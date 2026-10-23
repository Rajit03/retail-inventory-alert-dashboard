const cookieSession = require('cookie-session');
const crypto = require('crypto');
const { can } = require('./permissions');

function securityHeaders(req, res, next) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'same-origin');
  next();
}

function createSessionMiddleware() {
  if (process.env.NODE_ENV === 'production' && !process.env.SESSION_SECRET) {
    throw new Error('SESSION_SECRET environment variable is required in production.');
  }

  const secret = process.env.SESSION_SECRET || 'dev-session-secret-retail-inventory-alert-dashboard';

  return cookieSession({
    name: 'session',
    keys: [secret],
    maxAge: 8 * 60 * 60 * 1000, // 8 hours
    httpOnly: true,
    sameSite: 'lax',
    secure: false
  });
}

function ensureCsrfToken(req, res, next) {
  if (req.session) {
    if (!req.session.csrfToken) {
      req.session.csrfToken = crypto.randomBytes(24).toString('hex');
    }
    res.locals.csrfToken = req.session.csrfToken;
    res.locals.user = req.session.user || null;
    res.locals.can = (action) => can(req.session.user?.role, action);
  } else {
    res.locals.csrfToken = '';
    res.locals.user = null;
    res.locals.can = () => false;
  }
  next();
}

function verifyCsrf(req, res, next) {
  if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
    return next();
  }

  // Exempt only POST /api/login
  const normalizedPath = (req.baseUrl || '') + req.path;
  if (req.method === 'POST' && (normalizedPath === '/api/login' || req.originalUrl.split('?')[0] === '/api/login')) {
    return next();
  }

  const token = (req.body && req.body._csrf) || req.headers['x-csrf-token'];
  const sessionToken = req.session && req.session.csrfToken;

  if (!token || !sessionToken || token !== sessionToken) {
    const isApi = req.originalUrl.startsWith('/api/') || req.path.startsWith('/api/');
    if (isApi) {
      return res.status(403).json({ error: 'Invalid or missing CSRF token' });
    }
    return res.status(403).render('auth/403', {
      title: '403 Forbidden',
      message: 'Invalid or missing CSRF token'
    });
  }

  next();
}

function sanitizeNext(nextPath) {
  if (typeof nextPath !== 'string') return null;
  const trimmed = nextPath.trim();
  if (trimmed.startsWith('/') && !trimmed.startsWith('//') && !trimmed.startsWith('/\\')) {
    try {
      const dummy = new URL(trimmed, 'http://localhost');
      if (dummy.pathname.startsWith('//') || dummy.pathname.startsWith('/\\')) return null;
      return dummy.pathname + dummy.search + dummy.hash;
    } catch (_) {
      return null;
    }
  }
  return null;
}

function getLandingPage(role, next) {
  const defaultPage = role === 'purchasing' ? '/alerts' : '/items';
  const cleanNext = sanitizeNext(next);
  if (!cleanNext || cleanNext === '/login' || cleanNext === '/logout') {
    return defaultPage;
  }
  return cleanNext;
}

function requireLogin(req, res, next) {
  if (req.session && req.session.user) {
    return next();
  }

  const isApi = req.originalUrl.startsWith('/api/') || req.path.startsWith('/api/');
  if (isApi) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  const nextParam = sanitizeNext(req.originalUrl);
  const nextQuery = nextParam ? `?next=${encodeURIComponent(nextParam)}` : '';
  return res.redirect(`/login${nextQuery}`);
}

function requirePermission(action) {
  return (req, res, next) => {
    const role = req.session?.user?.role;
    if (can(role, action)) {
      return next();
    }

    const isApi = req.originalUrl.startsWith('/api/') || req.path.startsWith('/api/');
    if (isApi) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    return res.status(403).render('auth/403', {
      title: '403 Forbidden',
      message: 'You do not have permission to access this resource.'
    });
  };
}

module.exports = {
  securityHeaders,
  createSessionMiddleware,
  ensureCsrfToken,
  verifyCsrf,
  sanitizeNext,
  getLandingPage,
  requireLogin,
  requirePermission
};
