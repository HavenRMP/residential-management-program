import { test, expect } from '@playwright/test';
import { cuenta, sesionDe, variablesDe } from '../support/cuentas';

test.describe('sub-usuarios', () => {
  test.skip(!cuenta('residente') || !cuenta('subusuario'), `Faltan ${variablesDe('residente')} y ${variablesDe('subusuario')}`);

  test.describe('el titular', () => {
    test.use({ storageState: sesionDe('residente') });

    test('ve a su sub-usuario activo y puede invitar o revocar', async ({ page }) => {
      await page.goto('/dashboard/residente/subusuarios');

      await expect(page.getByText('Sub-usuarios autorizados')).toBeVisible();
      await expect(page.getByText(cuenta('subusuario')!.email)).toBeVisible();
      await expect(page.getByRole('button', { name: 'Invitar', exact: true })).toBeVisible();
      await expect(page.locator('button[title="Revocar"]').first()).toBeVisible();
    });

    test('el formulario de invitación valida el correo antes de enviar', async ({ page }) => {
      await page.goto('/dashboard/residente/subusuarios');
      await page.getByRole('button', { name: 'Invitar', exact: true }).click();

      await expect(page.getByRole('heading', { name: 'Invitar sub-usuario' })).toBeVisible();
      await page.getByPlaceholder(/correo|email/i).first().fill('esto-no-es-un-correo');
      await expect(page.getByRole('button', { name: /Enviar invitación|Invitar/ }).last()).toBeDisabled();
    });
  });

  test.describe('el sub-usuario', () => {
    test.use({ storageState: sesionDe('subusuario') });

    test('ve los accesos de su vivienda pero no puede invitar ni revocar', async ({ page }) => {
      await page.goto('/dashboard/residente/subusuarios');

      await expect(page.getByText('Eres sub-usuario de esta vivienda')).toBeVisible();
      await expect(page.getByText('Solo el titular puede invitar o revocar accesos.')).toBeVisible();
      await expect(page.getByRole('button', { name: 'Invitar', exact: true })).toHaveCount(0);
      await expect(page.locator('button[title="Revocar"]')).toHaveCount(0);
    });

    test('también ve la paquetería de su vivienda', async ({ page }) => {
      await page.goto('/dashboard/residente/paquetes');
      await expect(page.getByText('Mis paquetes')).toBeVisible();
      await expect(page.getByRole('tab', { name: /Pendientes/ })).toBeVisible();
    });
  });
});
