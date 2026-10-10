const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');
const app = require('../index');

let baseUrl;
let server;

before(async () => {
    server = app.listen(0, '127.0.0.1');
    await new Promise((resolve, reject) => {
        server.once('error', reject);
        server.once('listening', resolve);
    });
    baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
    if (!server) {
        return;
    }

    await new Promise((resolve, reject) => {
        server.close((error) => error ? reject(error) : resolve());
    });
});

test('health endpoint reports a healthy service', async () => {
    const response = await fetch(`${baseUrl}/health`);
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.status, 'healthy');
    assert.equal(body.service, 'shipfast-app');
    assert.match(body.uptime, /^\d+s$/);
});

test('API info reports the service and request count', async () => {
    const response = await fetch(`${baseUrl}/api/info`);
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.company, 'ShipFast');
    assert.ok(body.requests_served >= 2);
});

test('metrics endpoint exposes request and uptime metrics', async () => {
    const response = await fetch(`${baseUrl}/metrics`);
    const body = await response.text();

    assert.equal(response.status, 200);
    assert.match(body, /http_requests_total\{service="shipfast-app"\}/);
    assert.match(body, /process_uptime_seconds\{service="shipfast-app"\}/);
});

test('root route serves the ShipFast page', async () => {
    const response = await fetch(`${baseUrl}/`);
    const body = await response.text();

    assert.equal(response.status, 200);
    assert.match(body, /<title>ShipFast<\/title>/);
});