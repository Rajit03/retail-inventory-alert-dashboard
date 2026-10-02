const app = require('./app');
const PORT = process.env.PORT || 3000;

let server;

if (require.main === module) {
  server = app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
  });
}

module.exports = { app, server };
