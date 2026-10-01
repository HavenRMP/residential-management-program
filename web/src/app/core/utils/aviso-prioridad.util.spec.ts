import { AvisoPrioridad } from '../models/aviso.model';
import { claseBadgePrioridad, etiquetaPrioridad, ordenarAvisosPorPrioridad, tiempoRestanteAviso } from './aviso-prioridad.util';

describe('aviso-prioridad.util', () => {
  it('asigna etiqueta y color a cada prioridad, con informativo como valor por defecto', () => {
    const prioridades: AvisoPrioridad[] = ['urgente', 'mantenimiento', 'evento', 'informativo'];
    expect(prioridades.map(etiquetaPrioridad)).toEqual(['Urgente', 'Mantenimiento', 'Evento', 'Informativo']);
    expect(claseBadgePrioridad('urgente')).toContain('rose');
    expect(claseBadgePrioridad('mantenimiento')).toContain('amber');
    expect(claseBadgePrioridad('evento')).toContain('indigo');
    expect(etiquetaPrioridad(undefined)).toBe('Informativo');
    expect(claseBadgePrioridad(undefined)).toBe(claseBadgePrioridad('informativo'));
  });

  it('calcula el tiempo restante en días, en singular y plural, o expirado', () => {
    const ahora = new Date('2026-10-01T12:00:00Z').getTime();

    expect(tiempoRestanteAviso({ fechaExpiracion: '2026-10-01T20:00:00Z' }, ahora)).toBe('1 día restante');
    expect(tiempoRestanteAviso({ fechaExpiracion: '2026-10-04T12:00:00Z' }, ahora)).toBe('3 días restantes');
    expect(tiempoRestanteAviso({ fechaExpiracion: '2026-10-01T11:00:00Z' }, ahora)).toBe('Expirado');
  });

  it('ordena con los urgentes primero y, a igual prioridad, el que vence antes; sin mutar la lista original', () => {
    const lista = [
      { id: 'info', prioridad: 'informativo' as AvisoPrioridad, fechaExpiracion: '2026-10-02T00:00:00Z' },
      { id: 'urg-tarde', prioridad: 'urgente' as AvisoPrioridad, fechaExpiracion: '2026-10-09T00:00:00Z' },
      { id: 'evt', prioridad: 'evento' as AvisoPrioridad, fechaExpiracion: '2026-10-05T00:00:00Z' },
      { id: 'urg-pronto', prioridad: 'urgente' as AvisoPrioridad, fechaExpiracion: '2026-10-03T00:00:00Z' },
      { id: 'mant', prioridad: 'mantenimiento' as AvisoPrioridad, fechaExpiracion: '2026-10-04T00:00:00Z' }
    ];

    expect(ordenarAvisosPorPrioridad(lista).map(a => a.id)).toEqual(['urg-pronto', 'urg-tarde', 'mant', 'evt', 'info']);
    expect(lista[0].id).toBe('info');
  });

  it('un aviso sin prioridad se trata como informativo', () => {
    const lista: { id: string; prioridad?: AvisoPrioridad; fechaExpiracion: string }[] = [
      { id: 'sin', fechaExpiracion: '2026-10-02T00:00:00Z' },
      { id: 'evt', prioridad: 'evento', fechaExpiracion: '2026-10-09T00:00:00Z' }
    ];

    expect(ordenarAvisosPorPrioridad(lista).map(a => a.id)).toEqual(['evt', 'sin']);
  });
});
