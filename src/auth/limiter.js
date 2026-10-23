const { rateLimit, MemoryStore } = require('express-rate-limit');

const store = new MemoryStore();

const loginLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 5,
  skipSuccessfulRequests: true,
  standardHeaders: true,
  legacyHeaders: false,
  store,
  handler: (req, res) => {
    const isApi = req.originalUrl.startsWith('/api/') || req.path.startsWith('/api/');
    if (isApi) {
      return res.status(429).json({ error: 'Too many failed login attempts. Please try again later.' });
    }
    return res.status(429).render('auth/login', {
      title: 'Login',
      error: 'Too many failed login attempts. Please try again later.',
      next: req.body?.next || req.query?.next || '',
      errors: ['Too many failed login attempts. Please try again later.']
    });
  }
});

function resetLoginLimiter() {
  if (typeof store.resetAll === 'function') {
    store.resetAll();
  }
}

module.exports = {
  loginLimiter,
  resetLoginLimiter,
  limiterStore: store
};
