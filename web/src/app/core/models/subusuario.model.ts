/**
 * Estructura exacta devuelta por GET /api/subusuarios/mis-subusuarios (Usuarios.Api)
 */
export interface SubusuarioItemApi {
  id: string;
  nombre: string;
  email: string;
  telefono: string;
  parentesco: string;
  estado: 'Activo' | 'Pendiente';
  creado_en?: string | null;
}

/**
 * Modelo interno utilizado en los componentes frontend de Haven
 */
export interface SubUsuarioItem {
  id: string;
  nombre: string;
  email: string;
  telefono: string;
  parentesco: string;
  activo: boolean;
  creadoEn: string | null;
}

export function mapSubusuarioApiToItem(api: SubusuarioItemApi): SubUsuarioItem {
  return {
    id: api.id,
    nombre: api.nombre,
    email: api.email,
    telefono: api.telefono,
    parentesco: api.parentesco,
    activo: api.estado === 'Activo',
    creadoEn: api.creado_en ?? null
  };
}

export interface InvitarSubusuarioDto {
  viviendaId: number;
  email: string;
  parentesco: string;
}

/**
 * Estructura exacta devuelta por GET /api/subusuarios/mis-invitaciones (vw_invitaciones_subusuarios)
 * Ya viene filtrada por el backend a solo invitaciones con estado PENDIENTE.
 */
export interface InvitacionRecibidaApi {
  id: string;
  vivienda_id: number;
  numero_casa?: string | null;
  condominio_nombre?: string | null;
  titular_id: string;
  titular_nombre?: string | null;
  invitado_id: string;
  invitado_email?: string | null;
  parentesco: string;
  estado: string;
  creado_en: string;
}

/**
 * Modelo interno de una invitación recibida por el usuario actual, pendiente de responder.
 */
export interface InvitacionRecibida {
  id: string;
  viviendaId: number;
  numeroCasa: string | null;
  condominioNombre: string | null;
  titularNombre: string | null;
  parentesco: string;
  creadoEn: string;
}

export function mapInvitacionApiToInvitacion(api: InvitacionRecibidaApi): InvitacionRecibida {
  return {
    id: api.id,
    viviendaId: api.vivienda_id,
    numeroCasa: api.numero_casa ?? null,
    condominioNombre: api.condominio_nombre ?? null,
    titularNombre: api.titular_nombre ?? null,
    parentesco: api.parentesco,
    creadoEn: api.creado_en
  };
}

export type RespuestaInvitacion = 'ACEPTADA' | 'RECHAZADA';
