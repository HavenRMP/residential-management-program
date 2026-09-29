export type AvisoPrioridad = 'informativo' | 'urgente' | 'mantenimiento' | 'evento';

/**
 * Estructura exacta devuelta por el microservicio Avisos.Api (snake_case)
 */
export interface AvisoApi {
  id: string;
  condominio_id?: string;
  condominio_nombre?: string;
  titulo: string;
  contenido: string;
  duracion_dias?: number | null;
  fecha_expiracion_manual?: string | null;
  fecha_publicacion?: string;
  fecha_expiracion: string;
  activo: boolean;
  creado_por?: string;
  creado_por_nombre?: string;
  creado_en: string;
  estado?: string;
  prioridad?: AvisoPrioridad;
}

/**
 * Modelo interno utilizado en los componentes frontend de Haven
 */
export interface Aviso {
  id: string;
  condominioId: string;
  condominioNombre?: string;
  titulo: string;
  contenido: string;
  duracionDias?: number | null;
  fechaPublicacion?: string;
  fechaExpiracion: string;
  activo: boolean;
  creadoPor?: string;
  creadoPorNombre?: string;
  creadoEn: string;
  estado?: string;
  prioridad: AvisoPrioridad;
}

export interface CrearAvisoDto {
  titulo: string;
  contenido: string;
  prioridad?: AvisoPrioridad;
  diasVigencia?: number;
  duracion_dias?: number;
  fechaExpiracion?: string;
  fecha_expiracion?: string;
}

export interface ActualizarAvisoDto {
  titulo?: string;
  contenido?: string;
  prioridad?: AvisoPrioridad;
  diasVigencia?: number;
  duracion_dias?: number;
  fechaExpiracion?: string;
  fecha_expiracion?: string;
}

/**
 * Infiere visualmente una categoría/prioridad a partir del título y contenido
 * para mantener las etiquetas Spartan UI consistentes
 */
export function inferirPrioridad(titulo: string = '', contenido: string = ''): AvisoPrioridad {
  const texto = `${titulo} ${contenido}`.toLowerCase();
  if (texto.includes('urgent') || texto.includes('corte') || texto.includes('emergencia') || texto.includes('alerta') || texto.includes('suspensi')) {
    return 'urgente';
  }
  if (texto.includes('mantenimiento') || texto.includes('reparaci') || texto.includes('revisi') || texto.includes('bomba') || texto.includes('cisterna') || texto.includes('fumiga') || texto.includes('elevador') || texto.includes('ascensor') || texto.includes('trabajos') || texto.includes('limpieza')) {
    return 'mantenimiento';
  }
  if (texto.includes('asamblea') || texto.includes('reuni') || texto.includes('junta') || texto.includes('evento') || texto.includes('festejo') || texto.includes('convocatoria')) {
    return 'evento';
  }
  return 'informativo';
}

/**
 * Mapea la respuesta snake_case de Avisos.Api al modelo de frontend
 */
export function mapAvisoApiToAviso(api: any): Aviso {
  const titulo = api.titulo || '';
  const contenido = api.contenido || '';
  return {
    id: api.id,
    condominioId: api.condominio_id || api.condominioId || '',
    condominioNombre: api.condominio_nombre || api.condominioNombre,
    titulo,
    contenido,
    duracionDias: api.duracion_dias ?? api.duracionDias ?? null,
    fechaPublicacion: api.fecha_publicacion || api.fechaPublicacion,
    fechaExpiracion: api.fecha_expiracion || api.fechaExpiracion || new Date().toISOString(),
    activo: api.activo !== false,
    creadoPor: api.creado_por || api.creadoPor,
    creadoPorNombre: api.creado_por_nombre || api.creadoPorNombre || 'Administración',
    creadoEn: api.creado_en || api.creadoEn || new Date().toISOString(),
    estado: api.estado,
    prioridad: api.prioridad || inferirPrioridad(titulo, contenido)
  };
}
