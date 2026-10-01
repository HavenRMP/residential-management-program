import { esRecursoYaNoDisponible, mensajeAmigable } from './api-errors.util';

describe('api-errors.util', () => {
  describe('esRecursoYaNoDisponible', () => {
    it('reconoce los estados que indican que el recurso ya cambió', () => {
      for (const status of [400, 404, 409, 410]) {
        expect(esRecursoYaNoDisponible({ status })).withContext(`${status}`).toBeTrue();
      }
    });

    it('no lo confunde con fallos de red, de permisos o del servidor', () => {
      for (const status of [0, 401, 403, 500, 502, undefined]) {
        expect(esRecursoYaNoDisponible({ status })).withContext(`${status}`).toBeFalse();
      }
      expect(esRecursoYaNoDisponible(null)).toBeFalse();
    });
  });

  describe('mensajeAmigable', () => {
    const respaldo = 'Intenta de nuevo en unos segundos.';

    it('usa el mensaje claro del backend', () => {
      expect(mensajeAmigable({ error: { error: 'La invitación ya no está pendiente.' } }, respaldo)).toBe('La invitación ya no está pendiente.');
    });

    it('descarta el JSON crudo de Supabase y usa el mensaje de respaldo', () => {
      const crudo = 'Error desde Supabase: {"code":"SU004","details":null,"hint":null,"message":"La invitación no se encuentra pendiente"}';

      expect(mensajeAmigable({ error: { error: crudo } }, respaldo)).toBe(respaldo);
      expect(mensajeAmigable({ error: { error: '{"code":"P0002"}' } }, respaldo)).toBe(respaldo);
    });

    it('usa el respaldo cuando no hay mensaje', () => {
      expect(mensajeAmigable({}, respaldo)).toBe(respaldo);
      expect(mensajeAmigable(undefined, respaldo)).toBe(respaldo);
      expect(mensajeAmigable({ error: { error: '   ' } }, respaldo)).toBe(respaldo);
    });
  });
});
