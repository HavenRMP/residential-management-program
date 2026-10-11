import { test, expect } from '@playwright/test';
import { cuenta, sesionDe, variablesDe } from '../support/cuentas';
import { MARCADOR, diaEnMexico, limpiar } from '../support/datos';

test.describe('visitas del residente', () => {
  test.skip(!cuenta('residente'), `Falta ${variablesDe('residente')}`);
  test.use({ storageState: sesionDe('residente') });
  test.afterAll(async () => {
    await limpiar();
  });

  test('programa una visita, recibe su código, la edita y la cancela', async ({ page }) => {
    await page.goto('/dashboard/residente/visitas');
    const apellidos = `${MARCADOR}-RESIDENTE`;
    const tarjeta = page.locator('li', { hasText: apellidos });

    await test.step('programarla con el formulario', async () => {
      await page.getByRole('button', { name: 'Programar visita' }).click();
      await page.getByPlaceholder('Nombre', { exact: true }).fill('E2E Prueba');
      await page.getByPlaceholder('Apellidos', { exact: true }).fill(apellidos);
      await page.locator('input[type="datetime-local"]').fill(`${diaEnMexico(1)}T10:00`);
      await page.getByRole('button', { name: 'Programar', exact: true }).click();
    });

    await test.step('recibe el código de acceso para compartirlo', async () => {
      const aviso = page.locator('.swal2-popup');
      await expect(aviso).toContainText('Visita programada');
      await expect(aviso.locator('strong')).toHaveText(/^[A-Z0-9]{4,}$/);
      await page.locator('.swal2-confirm').click();
      await expect(tarjeta).toContainText('Programada');
      await expect(tarjeta).toContainText('Código de acceso');
    });

    await test.step('editar una nota', async () => {
      await tarjeta.getByRole('button', { name: 'Editar' }).click();
      await page.locator('textarea').fill('Nota de la prueba e2e');
      await page.getByRole('button', { name: 'Guardar cambios' }).click();
      await expect(tarjeta).toContainText('Nota de la prueba e2e');
    });

    await test.step('cancelarla y que deje de tener acciones', async () => {
      await tarjeta.getByRole('button', { name: 'Cancelar' }).click();
      await page.locator('.swal2-confirm').click();
      await expect(tarjeta).toContainText('Cancelada');
      await expect(tarjeta.getByRole('button', { name: 'Editar' })).toHaveCount(0);
      await expect(tarjeta).not.toContainText('Código de acceso');
    });
  });

  test('no deja programar una visita sin los datos obligatorios', async ({ page }) => {
    await page.goto('/dashboard/residente/visitas');
    await page.getByRole('button', { name: 'Programar visita' }).click();

    await expect(page.getByRole('button', { name: 'Programar', exact: true })).toBeDisabled();

    await page.getByPlaceholder('Nombre', { exact: true }).fill('E2E Prueba');
    await page.getByPlaceholder('Apellidos', { exact: true }).fill(MARCADOR);
    await expect(page.getByRole('button', { name: 'Programar', exact: true })).toBeDisabled();

    await page.locator('input[type="datetime-local"]').fill(`${diaEnMexico(1)}T10:00`);
    await expect(page.getByRole('button', { name: 'Programar', exact: true })).toBeEnabled();
  });
});
