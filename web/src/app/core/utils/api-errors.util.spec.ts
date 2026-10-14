import { esRecursoYaNoDisponible, mensajeAmigable, mensajeConValidacion } from './api-errors.util';

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

  describe('mensajeConValidacion', () => {
    const respaldo = 'No se pudo completar la acción.';

    it('usa el { error } del backend cuando lo trae', () => {
      expect(mensajeConValidacion({ error: { error: 'Ya tienes una reserva para ese día.' } }, respaldo)).toBe('Ya tienes una reserva para ese día.');
    });

    it('si solo hay errores de validación usa el primero', () => {
      const err = { error: { errors: { Motivo: ['El motivo es obligatorio'], Otro: ['x'] } } };

      expect(mensajeConValidacion(err, respaldo)).toBe('El motivo es obligatorio');
    });

    it('el { error } tiene prioridad sobre los errores de validación', () => {
      expect(mensajeConValidacion({ error: { error: 'Choca con un bloqueo', errors: { Motivo: ['x'] } } }, respaldo)).toBe('Choca con un bloqueo');
    });

    it('oculta el JSON técnico y usa el respaldo si no hay nada utilizable', () => {
      expect(mensajeConValidacion({ error: { error: 'Error desde Supabase: {"code":"XX000"}' } }, respaldo)).toBe(respaldo);
      expect(mensajeConValidacion({ error: { errors: {} } }, respaldo)).toBe(respaldo);
      expect(mensajeConValidacion({ error: { errors: { Motivo: [''] } } }, respaldo)).toBe(respaldo);
      expect(mensajeConValidacion(undefined, respaldo)).toBe(respaldo);
    });
  });
});
