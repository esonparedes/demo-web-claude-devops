const request = require('supertest');
const app = require('../server');

describe('Basic server', () => {
  test('GET / returns 200 and contains Google text', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.text).toMatch(/Google/);
  });

  test('GET /api/search returns JSON with items for query', async () => {
    const res = await request(app).get('/api/search').query({ q: 'test' });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('q', 'test');
    expect(Array.isArray(res.body.items)).toBe(true);
    expect(res.body.items.length).toBeGreaterThanOrEqual(1);
  });

  test('GET /api/search without q returns empty items', async () => {
    const res = await request(app).get('/api/search');
    expect(res.statusCode).toBe(200);
    expect(res.body.q).toBe('');
    expect(Array.isArray(res.body.items)).toBe(true);
    expect(res.body.items.length).toBe(0);
  });
});
