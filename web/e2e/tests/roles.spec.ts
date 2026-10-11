import { test, expect } from '@playwright/test';
import { DASHBOARD_DE, ROLES, Rol, cuenta, sesionDe, variablesDe } from '../support/cuentas';

/** Rutas que un rol no debe poder abrir, con el panel al que lo devuelve la app */
const PROHIBIDAS: Partial<Record<Rol, string[]>> = {
  residente: ['/dashboard/admin', '/dashboard/vigilante'],
  subusuario: ['/dashboard/admin', '/dashboard/vigilante'],
  vigilante: ['/dashboard/admin', '/dashboard/residente'],
  administrador: ['/dashboard/residente', '/dashboard/vigilante']
};

for (const rol of ROLES) {
  test.describe(`acceso como ${rol}`, () => {
    test.skip(!cuenta(rol), `Falta ${variablesDe(rol)}`);
    test.use({ storageState: sesionDe(rol) });

    test('entra directo a su panel', async ({ page }) => {
      await page.goto('/');

      await expect(page).toHaveURL(new RegExp(DASHBOARD_DE[rol]));
    });

    for (const ruta of PROHIBIDAS[rol] ?? []) {
      test(`no puede abrir ${ruta}`, async ({ page }) => {
        await page.goto(ruta);

        // La app lo devuelve a su propio panel
        await expect(page).toHaveURL(new RegExp(DASHBOARD_DE[rol]));
        await expect(page).not.toHaveURL(new RegExp(`${ruta}(/|$|\\?)`));
      });
    }
  });
}

test.describe('sin sesión', () => {
  test.use({ storageState: { cookies: [], origins: [] } });

  for (const ruta of ['/dashboard/admin', '/dashboard/residente', '/dashboard/vigilante', '/dashboard/residente/paquetes']) {
    test(`${ruta} manda al inicio de sesión`, async ({ page }) => {
      await page.goto(ruta);

      await expect(page).toHaveURL(/\/login/);
    });
  }
});
