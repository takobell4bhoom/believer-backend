export async function healthRoutes(app) {
  const healthResponse = async () => ({ status: 'ok' });

  app.get('/', async () => ({
    name: 'Believer Backend API',
    status: 'ok',
    version: '1.0.0',
    docs: {
      openapi: '/docs/openapi.yaml',
      postmanCollection: '/docs/postman_collection.json'
    }
  }));

  app.get('/health', healthResponse);
  app.get('/api/v1/health', healthResponse);
}
