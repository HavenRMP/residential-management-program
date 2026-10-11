import { test, expect } from '@playwright/test';
import { elementos, llamar, todasLasPaginas } from '../support/api';
import { cuenta, sesionDe, variablesDe } from '../support/cuentas';

test.describe('ocupación de viviendas (administrador)', () => {
  test.skip(!cuenta('administrador'), `Falta ${variablesDe('administrador')}`);
  test.use({ storageState: sesionDe('administrador') });

  /** Cuántas viviendas tienen al menos un residente, preguntando vivienda por vivienda */
  async function ocupacionReal(): Promise<{ total: number; ocupadas: number }> {
    const viviendas = await todasLasPaginas<any>('viviendas', '/api/viviendas', 'administrador');
    let ocupadas = 0;
    for (const v of viviendas) {
      const { datos } = await llamar('viviendas', 'GET', `/api/viviendas/${v.id}/residentes`, 'administrador');
      if (elementos(datos).length > 0) ocupadas++;
    }
    return { total: viviendas.length, ocupadas };
  }

  test('el dashboard calcula la ocupación con una sola consulta y coincide con la real', async ({ page }) => {
    const porVivienda: string[] = [];
    const conResidentes: string[] = [];
    page.on('request', r => {
      if (/\/api\/viviendas\/\d+\/residentes/.test(r.url())) porVivienda.push(r.url());
      if (r.url().includes('/api/viviendas/con-residentes')) conResidentes.push(r.url());
    });
    const real = await ocupacionReal();

    await page.goto('/dashboard/admin');
    const tarjeta = page.locator('a[aria-label="Ver viviendas y su ocupación"]');
    await expect(tarjeta).toContainText('%');
    await expect(tarjeta).not.toContainText('—');

    const porcentaje = real.total ? Math.round((real.ocupadas / real.total) * 100) : 0;
    await expect(tarjeta).toContainText(`${porcentaje}%`);
    expect(porVivienda, 'no debe pedir los residentes de cada vivienda').toHaveLength(0);
    expect(conResidentes.length, 'una sola consulta del directorio').toBeGreaterThanOrEqual(1);
    expect(conResidentes.length).toBeLessThanOrEqual(2);
  });

  test('el directorio de viviendas marca las mismas casas como ocupadas', async ({ page }) => {
    const real = await ocupacionReal();

    await page.goto('/dashboard/admin/viviendas');
    await expect(page.locator('tbody tr').first()).toBeVisible();
    // La ocupación llega después de la lista: el conteo espera a que el directorio con residentes cargue
    await expect(page.locator('tbody tr', { hasText: 'Ocupada' })).toHaveCount(real.ocupadas);
  });
});
