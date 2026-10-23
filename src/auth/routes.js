const express = require('express');
const crypto = require('crypto');
const db = require('../db/database');
const { comparePassword } = require('./hash');
const { getUserByUsername } = require('./db');
const { loginLimiter } = require('./limiter');
const { sanitizeNext, getLandingPage, requireLogin } = require('./middleware');

const router = express.Router();

// GET /login - render login page
router.get('/login', (req, res) => {
  if (req.session && req.session.user) {
    return res.redirect(getLandingPage(req.session.user.role, req.query.next));
  }
  res.render('auth/login', {
    title: 'Login',
    error: null,
    next: sanitizeNext(req.query.next) || '',
    csrfToken: req.session?.csrfToken || ''
  });
});

// POST /login - web form login
router.post('/login', loginLimiter, async (req, res) => {
  const { username, password, next } = req.body || {};

  if (!username || !password) {
    return res.status(401).render('auth/login', {
      title: 'Login',
      error: 'Invalid username or password',
      next: sanitizeNext(next) || '',
      csrfToken: req.session?.csrfToken || ''
    });
  }

  try {
    const user = getUserByUsername(db, String(username).trim());
    if (user) {
      const match = await comparePassword(String(password), user.password_hash);
      if (match) {
        req.session.user = {
          id: user.id,
          username: user.username,
          role: user.role
        };
        req.session.csrfToken = crypto.randomBytes(24).toString('hex');
        return res.redirect(getLandingPage(user.role, next));
      }
    }

    return res.status(401).render('auth/login', {
      title: 'Login',
      error: 'Invalid username or password',
      next: sanitizeNext(next) || '',
      csrfToken: req.session?.csrfToken || ''
    });
  } catch (err) {
    return res.status(500).render('auth/login', {
      title: 'Login',
      error: 'An internal error occurred. Please try again.',
      next: sanitizeNext(next) || '',
      csrfToken: req.session?.csrfToken || ''
    });
  }
});

// POST /api/login - API login endpoint (CSRF exempt)
router.post('/api/login', loginLimiter, async (req, res) => {
  const { username, password } = req.body || {};

  if (!username || !password) {
    return res.status(401).json({ error: 'Invalid username or password' });
  }

  try {
    const user = getUserByUsername(db, String(username).trim());
    if (user) {
      const match = await comparePassword(String(password), user.password_hash);
      if (match) {
        req.session.user = {
          id: user.id,
          username: user.username,
          role: user.role
        };
        if (!req.session.csrfToken) {
          req.session.csrfToken = crypto.randomBytes(24).toString('hex');
        }
        return res.status(200).json({
          username: user.username,
          role: user.role,
          csrfToken: req.session.csrfToken
        });
      }
    }

    return res.status(401).json({ error: 'Invalid username or password' });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to process login request' });
  }
});

// POST /logout - web logout (CSRF protected)
router.post('/logout', requireLogin, (req, res) => {
  req.session = null;
  res.redirect('/login');
});

// GET /api/me - get current authenticated user and csrfToken
router.get('/api/me', requireLogin, (req, res) => {
  return res.json({
    user: req.session.user,
    username: req.session.user.username,
    role: req.session.user.role,
    csrfToken: req.session.csrfToken
  });
});

module.exports = router;
