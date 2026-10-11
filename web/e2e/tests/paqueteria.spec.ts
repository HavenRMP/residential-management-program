import { test, expect } from '@playwright/test';
import { llamar } from '../support/api';
import { cuenta, sesionDe, variablesDe } from '../support/cuentas';
import { MARCADOR, diaEnMexico, limpiar } from '../support/datos';

test.describe('paquetería del residente', () => {
  test.skip(!cuenta('residente'), `Falta ${variablesDe('residente')}`);
  test.use({ storageState: sesionDe('residente') });
  test.afterAll(async () => {
    await limpiar();
  });

  test('avisa un paquete, lo corrige y lo cancela', async ({ page }) => {
    await page.goto('/dashboard/residente/paquetes');
    const guia = `${MARCADOR}-A`;
    const tarjeta = page.locator('li', { hasText: guia });

    await test.step('avisar con una empresa del catálogo', async () => {
      await page.getByRole('button', { name: 'Avisar un paquete' }).first().click();
      await expect(page.locator('#paq-destinatario')).not.toHaveValue('');
      await expect(page.getByRole('button', { name: 'Avisar a caseta' })).toBeDisabled();
      await page.locator('#paq-servicio').selectOption({ label: 'Amazon' });
      await page.locator('#paq-guia').fill(guia);
      await page.locator('#paq-hasta').fill(diaEnMexico(2));
      await page.getByRole('button', { name: 'Avisar a caseta' }).click();

      await expect(tarjeta).toContainText('Amazon');
      await expect(tarjeta).toContainText('Esperado');
      await expect(page.getByRole('tab', { name: /Pendientes/ })).toContainText(/\(\d+\)/);
    });

    await test.step('corregir la descripción', async () => {
      await tarjeta.getByRole('button', { name: 'Editar' }).click();
      await expect(page.getByRole('button', { name: 'Guardar cambios' })).toBeDisabled();
      await page.locator('#paq-descripcion').fill(`Caja de prueba ${MARCADOR}`);
      await page.getByRole('button', { name: 'Guardar cambios' }).click();
      await expect(tarjeta).toContainText('Caja de prueba');
    });

    await test.step('cancelar con motivo y verlo en el historial', async () => {
      await tarjeta.getByRole('button', { name: 'Cancelar' }).click();
      await page.locator('.swal2-input').fill('Prueba e2e');
      await page.locator('.swal2-confirm').click();
      await expect(tarjeta).toHaveCount(0);

      await page.getByRole('tab', { name: /Historial/ }).click();
      await expect(tarjeta).toContainText('Cancelado');
      await expect(tarjeta.getByRole('button', { name: 'Editar' })).toHaveCount(0);
    });
  });

  test('otra empresa pide su nombre', async ({ page }) => {
    await page.goto('/dashboard/residente/paquetes');
    await page.getByRole('button', { name: 'Avisar un paquete' }).first().click();

    await page.locator('#paq-servicio').selectOption({ label: 'Otra empresa' });

    await expect(page.locator('#paq-otra')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Avisar a caseta' })).toBeDisabled();
    await page.locator('#paq-otra').fill('Paquetexpress');
    await expect(page.getByRole('button', { name: 'Avisar a caseta' })).toBeEnabled();
  });

  test('rechaza una fecha límite que ya pasó', async ({ page }) => {
    await page.goto('/dashboard/residente/paquetes');
    await page.getByRole('button', { name: 'Avisar un paquete' }).first().click();

    await page.locator('#paq-servicio').selectOption({ label: 'DHL' });
    await page.locator('#paq-hasta').fill(diaEnMexico(-3));

    await expect(page.getByText('La última fecha ya pasó')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Avisar a caseta' })).toBeDisabled();
  });

  /**
   * Un paquete recibido o entregado ya no se puede borrar ni cancelar, y cada ejecución dejaría uno más en el historial.
   * Por eso este recorrido solo corre si se pide con E2E_DATOS_PERMANENTES=1.
   */
  test('caseta recibe el paquete y se ve en caseta; al entregarlo pasa al historial', async ({ page }) => {
    test.skip(!process.env['E2E_DATOS_PERMANENTES'] || !cuenta('vigilante'), 'Define E2E_DATOS_PERMANENTES=1 y la cuenta de vigilante');
    await page.goto('/dashboard/residente/paquetes');

    const guia = `${MARCADOR}-C`;
    await page.getByRole('button', { name: 'Avisar un paquete' }).first().click();
    await page.locator('#paq-servicio').selectOption({ label: 'FedEx' });
    await page.locator('#paq-guia').fill(guia);
    await page.getByRole('button', { name: 'Avisar a caseta' }).click();
    const tarjeta = page.locator('li', { hasText: guia });
    await expect(tarjeta).toContainText('Esperado');

    const { datos: lista } = await llamar('visitas', 'GET', '/api/paqueteria/mis-paquetes?estado=esperado&pageSize=100', 'residente');
    const paquete = (lista?.items ?? []).find((p: any) => p.numeroGuia === guia);
    const recepcion = await llamar('visitas', 'POST', '/api/paqueteria/recepcion', 'vigilante', { paqueteId: paquete.id, ubicacionAlmacen: 'Estante e2e' });
    expect(recepcion.status).toBe(201);

    await page.getByRole('button', { name: 'Actualizar' }).click();
    await expect(page.getByText(/Tienes \d+ paquetes? en caseta/)).toBeVisible();
    await expect(tarjeta).toContainText('En caseta');
    await expect(tarjeta).toContainText('Estante e2e');
    await expect(tarjeta.getByRole('button', { name: 'Editar' })).toHaveCount(0);

    const entrega = await llamar('visitas', 'POST', `/api/paqueteria/${paquete.id}/entrega`, 'vigilante', { entregadoANombre: 'Residente e2e' });
    expect(entrega.status).toBe(200);
    await page.getByRole('button', { name: 'Actualizar' }).click();
    await page.getByRole('tab', { name: /Historial/ }).click();
    await expect(tarjeta).toContainText('Entregado a Residente e2e');
  });
});
