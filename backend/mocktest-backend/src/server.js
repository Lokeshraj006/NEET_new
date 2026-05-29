require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { testConnection } = require('./db');
const mocktestRouter = require('./routes/mocktest');

const app = express();
const port = Number(process.env.PORT || 3000);

app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.get('/health', async (_req, res) => {
  res.json({ ok: true });
});

app.use('/mocktest', mocktestRouter);

app.use((error, _req, res, _next) => {
  console.error(error);
  res.status(500).json({
    detail: 'Internal server error.',
  });
});

async function start() {
  await testConnection();
  app.listen(port, () => {
    console.log(`Mock test backend running on port ${port}`);
  });
}

start().catch((error) => {
  console.error('Failed to start mock test backend:', error);
  process.exit(1);
});
