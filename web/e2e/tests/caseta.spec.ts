import { test, expect } from '@playwright/test';
import { cuenta, sesionDe, variablesDe } from '../support/cuentas';
import { MARCADOR, crearVisitaDeResidente, limpiar } from '../support/datos';

test.describe('caseta: códigos de acceso', () => {
  test.skip(!cuenta('vigilante') || !cuenta('residente'), `Faltan ${variablesDe('vigilante')} y ${variablesDe('residente')}`);
  test.use({ storageState: sesionDe('vigilante') });
  test.afterAll(async () => {
    await limpiar();
  });

  test('un código válido registra la entrada solo, luego la salida y la visita queda en el historial', async ({ page }) => {
    // Esta visita termina "finalizada": el backend no permite borrarla, por eso lleva el marcador de pruebas
    const visita = await crearVisitaDeResidente('E2E Entrada', 10, 'ENTRADA');
    await page.goto('/dashboard/vigilante');

    await test.step('validar el código registra la entrada sin otro clic', async () => {
      await page.getByPlaceholder('Código de la visita').fill(visita.codigo);
      await page.getByRole('button', { name: 'Validar' }).click();
      await expect(page.locator('.swal2-popup')).toContainText('Entrada registrada');
      await expect(page.getByText(`${MARCADOR}-ENTRADA`).first()).toBeVisible();
    });

    await test.step('registrar la salida', async () => {
      await page.getByRole('button', { name: 'Registrar salida' }).first().click();
      await expect(page.locator('.swal2-popup')).toContainText('Salida registrada');
    });

    await test.step('aparece en el historial como finalizada', async () => {
      await page.getByRole('tab', { name: 'Historial' }).click();
      const fila = page.locator('tr, li').filter({ hasText: `${MARCADOR}-ENTRADA` }).first();
      await expect(fila).toBeVisible();
      await expect(fila).toContainText('Finalizada');
    });
  });

  test('un código que no existe muestra un error y no registra nada', async ({ page }) => {
    await page.goto('/dashboard/vigilante');

    await page.getByPlaceholder('Código de la visita').fill('ZZZZZZZZ');
    await page.getByRole('button', { name: 'Validar' }).click();

    await expect(page.locator('.bg-rose-50').first()).toBeVisible();
    await expect(page.getByRole('button', { name: 'Registrar entrada' })).toHaveCount(0);
  });

  test('una visita que llega en más de 24 horas no se atiende todavía', async ({ page }) => {
    const lejana = await crearVisitaDeResidente('E2E Lejana', 3 * 24 * 60, 'LEJANA');
    await page.goto('/dashboard/vigilante');

    await page.getByPlaceholder('Código de la visita').fill(lejana.codigo);
    await page.getByRole('button', { name: 'Validar' }).click();

    await expect(page.getByText('la visita no está por atender')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Registrar entrada' })).toHaveCount(0);
  });
});
