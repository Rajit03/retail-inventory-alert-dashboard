const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;

const path = require('path');

const itemsApiRouter = require('./routes/items');
const catalogueRouter = require('./routes/catalogue');
const alertsRouter = require('./routes/alerts');

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(express.static(path.join(__dirname, '../public')));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use('/api/items', itemsApiRouter);
app.use(catalogueRouter);
app.use(alertsRouter);

app.get('/health', (req, res) => {
  res.json({ status: 'UP' });
});

app.get('/', (req, res) => {
  res.redirect('/items');
});

const server = app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});

module.exports = { app, server };
