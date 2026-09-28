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
  codigo?: string | null;
  expira_en?: string | null;
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
  codigo: string | null;
  expiraEn: string | null;
}

export function mapSubusuarioApiToItem(api: SubusuarioItemApi): SubUsuarioItem {
  return {
    id: api.id,
    nombre: api.nombre,
    email: api.email,
    telefono: api.telefono,
    parentesco: api.parentesco,
    activo: api.estado === 'Activo',
    codigo: api.codigo ?? null,
    expiraEn: api.expira_en ?? null
  };
}

export interface InvitarSubusuarioDto {
  viviendaId: number;
  nombre: string;
  apellidos: string;
  email: string;
  telefono: string;
  parentesco: string;
}
