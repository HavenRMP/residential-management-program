import { test as setup, expect } from '@playwright/test';
import { DASHBOARD_DE, ROLES, cuenta, sesionDe, variablesDe } from './support/cuentas';

/**
 * Inicia sesión por la pantalla de login una vez por rol y guarda la sesión para los tests.
 * El primer inicio de sesión tras un rato puede tardar más de un minuto: los servicios de Render arrancan en frío.
 */
for (const rol of ROLES) {
  setup(`iniciar sesión como ${rol}`, async ({ page }) => {
    const datos = cuenta(rol);
    setup.skip(!datos, `Falta ${variablesDe(rol)}`);

    await page.goto('/login');
    await page.locator('input[formControlName="email"]').fill(datos!.email);
    await page.locator('input[formControlName="password"]').fill(datos!.password);
    await page.locator('button[type="submit"]').click();

    await expect(page).not.toHaveURL(/\/login/, { timeout: 4 * 60_000 });
    await expect(page).toHaveURL(new RegExp(DASHBOARD_DE[rol]), { timeout: 60_000 });

    await page.context().storageState({ path: sesionDe(rol) });
  });
}
