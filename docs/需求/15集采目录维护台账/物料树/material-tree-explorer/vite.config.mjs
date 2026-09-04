import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';
import { createApiHandler } from './server/scm-api.mjs';

export default defineConfig({
  plugins: [
    react(),
    {
      name: 'scm-local-api',
      configureServer(server) {
        const handleApi = createApiHandler();
        server.middlewares.use((request, response, next) => {
          if (!request.url?.startsWith('/api/')) {
            next();
            return;
          }
          void handleApi(request, response);
        });
      },
    },
  ],
  server: {
    host: '127.0.0.1',
    port: 4317,
    strictPort: true,
  },
  preview: {
    host: '127.0.0.1',
    port: 4317,
    strictPort: true,
  },
});
