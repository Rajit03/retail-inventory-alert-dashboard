const express = require('express');
const path = require('path');

const {
  securityHeaders,
  createSessionMiddleware,
  ensureCsrfToken,
  verifyCsrf,
  requireLogin,
  authRouter
} = require('./auth');

const itemsApiRouter = require('./routes/items');
const catalogueRouter = require('./routes/catalogue');
const transactionsRouter = require('./routes/transactions');
const alertsRouter = require('./routes/alerts');

const app = express();

app.set('trust proxy', 1);

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Security headers
app.use(securityHeaders);

// Static assets (public)
app.use(express.static(path.join(__dirname, '../public')));

// Body parsers
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Sessions
app.use(createSessionMiddleware());

// CSRF token generation & view locals
app.use(ensureCsrfToken);

// Public health check route
app.get('/health', (req, res) => {
  res.json({ status: 'UP' });
});

// CSRF verification on state-changing requests (exempts POST /api/login)
app.use(verifyCsrf);

// Authentication routes (/login, /api/login, /logout, /api/me)
app.use(authRouter);

// Require login for all remaining routes
app.use(requireLogin);

// Protected routes
app.use('/api/items', itemsApiRouter);
app.use(catalogueRouter);
app.use(transactionsRouter);
app.use(alertsRouter);

app.get('/', (req, res) => {
  res.redirect('/items');
});

module.exports = app;
