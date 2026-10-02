const express = require('express');
const path = require('path');

const itemsApiRouter = require('./routes/items');
const catalogueRouter = require('./routes/catalogue');
const transactionsRouter = require('./routes/transactions');
const alertsRouter = require('./routes/alerts');

const app = express();

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(express.static(path.join(__dirname, '../public')));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use('/api/items', itemsApiRouter);
app.use(catalogueRouter);
app.use(transactionsRouter);
app.use(alertsRouter);

app.get('/health', (req, res) => {
  res.json({ status: 'UP' });
});

app.get('/', (req, res) => {
  res.redirect('/items');
});

module.exports = app;
