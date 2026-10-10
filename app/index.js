const express = require('express');
const path = require('node:path');

const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = process.env.APP_VERSION || '1.0.0';
let requestCount = 0;
const startTime = Date.now();

app.use((req, res, next) => {
	requestCount += 1;
	next();
});
app.use(express.static(path.join(__dirname, 'public')));

app.get('/health', (req, res) => {
	res.json({
		status: 'healthy',
		service: 'shipfast-app',
		version: VERSION,
		uptime: `${Math.floor((Date.now() - startTime) / 1000)}s`,
	});
});

app.get('/api/info', (req, res) => {
	res.json({
		company: 'ShipFast',
		environment: process.env.NODE_ENV || 'development',
		requests_served: requestCount,
	});
});

app.get('/metrics', (req, res) => {
	const uptime = (Date.now() - startTime) / 1000;
	res.set('Content-Type', 'text/plain');
	res.send([
		'# HELP http_requests_total Total number of HTTP requests',
		'# TYPE http_requests_total counter',
		`http_requests_total{service="shipfast-app"} ${requestCount}`,
		'# HELP process_uptime_seconds Process uptime in seconds',
		'# TYPE process_uptime_seconds gauge',
		`process_uptime_seconds{service="shipfast-app"} ${uptime.toFixed(2)}`,
	].join('\n') + '\n');
});

if (require.main === module) {
	const server = app.listen(PORT, () => {
		console.log(`ShipFast app v${VERSION} running on port ${server.address().port}`);
	});
}

module.exports = app;