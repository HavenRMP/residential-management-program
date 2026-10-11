import { defineConfig, devices } from '@playwright/test';

// Variables locales opcionales (cuentas de prueba, URL a probar). Nunca se versiona: ver .env.e2e.example
try {
  process.loadEnvFile('.env.e2e');
} catch {
  // Sin archivo: las variables pueden venir del entorno (CI)
}

const baseURL = process.env['E2E_BASE_URL'] || undefined;
const puertoLocal = 4300;

/**
 * Recorridos de punta a punta contra el entorno real (Render + Supabase), con las cuentas de prueba del condominio Maderas.
 * - Los servicios en Render se duermen: la primera petición tras un rato puede tardar más de un minuto, por eso los tiempos son largos.
 * - Un solo worker: todas las cuentas comparten la misma vivienda de prueba y los pasos se apoyan en datos que otro test podría tocar.
 */
export default defineConfig({
  testDir: './e2e',
  timeout: 5 * 60_000,
  expect: { timeout: 60_000 },
  fullyParallel: false,
  workers: 1,
  forbidOnly: !!process.env['CI'],
  retries: process.env['CI'] ? 1 : 0,
  reporter: process.env['CI'] ? [['github'], ['html', { open: 'never' }]] : [['list'], ['html', { open: 'never' }]],
  outputDir: 'test-results',
  use: {
    baseURL: baseURL ?? `http://localhost:${puertoLocal}`,
    // Fecha y hora fijas para que "mañana a las 10:00" sea el mismo instante en cualquier máquina
    locale: 'es-MX',
    timezoneId: 'America/Mexico_City',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    // "chrome" usa el Chrome instalado en vez de descargar Chromium
    channel: process.env['E2E_BROWSER_CHANNEL'] || undefined
  },
  projects: [
    { name: 'setup', testMatch: /auth\.setup\.ts/ },
    {
      name: 'e2e',
      dependencies: ['setup'],
      testMatch: /tests\/.*\.spec\.ts/,
      use: { ...devices['Desktop Chrome'], viewport: { width: 1920, height: 1080 } }
    }
  ],
  // Sin E2E_BASE_URL se levanta la app local; con ella se prueba ese despliegue tal cual
  webServer: baseURL
    ? undefined
    : {
        command: `npm run start -- --port ${puertoLocal}`,
        url: `http://localhost:${puertoLocal}`,
        reuseExistingServer: !process.env['CI'],
        timeout: 4 * 60_000
      }
});
