const express = require('express');
const cors = require('cors');

const app = express();
const port = process.env.PORT || 3000;
const startTime = new Date();

app.use(cors());

// Logging Middleware
app.use((req, res, next) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ${req.ip} - ${req.method} ${req.url}`);
    next();
});

app.get('/', (req, res) => {
    const uptime = Math.floor((new Date() - startTime) / 1000);
    res.json({
        status: 'Alive',
        uptime_seconds: uptime,
        message: 'Pterodactyl Codespace is running!',
        timestamp: new Date().toISOString()
    });
});

app.get('/ping', (req, res) => {
    res.send('pong');
});

app.get('/health', (req, res) => {
    // Simple health check logic
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.listen(port, () => {
    console.log(`[${new Date().toISOString()}] Keep-Alive Server Started on port ${port}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM signal received: closing HTTP server');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT signal received: closing HTTP server');
    process.exit(0);
});
