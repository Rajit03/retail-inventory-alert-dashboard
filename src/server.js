const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;

const itemsApiRouter = require('./routes/items');

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use('/api/items', itemsApiRouter);

app.get('/health', (req, res) => {
  res.json({ status: 'UP' });
});

app.get('/', (req, res) => {
  res.send('Retail Inventory Alert Dashboard');
});

const server = app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});

module.exports = { app, server };
