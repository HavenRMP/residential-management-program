/**
 * Estructura exacta devuelta por vw_notificaciones (Usuarios.Api)
 */
export interface NotificacionApi {
  id: string;
  usuario_id?: string;
  usuario_nombre?: string;
  usuario_email?: string;
  tipo_evento: string;
  titulo: string;
  mensaje: string;
  url_redireccion?: string | null;
  leida: boolean;
  creado_en: string;
}

/**
 * Modelo interno utilizado en los componentes frontend de Haven
 */
export interface Notificacion {
  id: string;
  tipoEvento: string;
  titulo: string;
  mensaje: string;
  urlRedireccion: string | null;
  leida: boolean;
  creadoEn: string;
}

export function mapNotificacionApiToNotificacion(api: NotificacionApi): Notificacion {
  return {
    id: api.id,
    tipoEvento: api.tipo_evento,
    titulo: api.titulo,
    mensaje: api.mensaje,
    urlRedireccion: api.url_redireccion ?? null,
    leida: api.leida,
    creadoEn: api.creado_en
  };
}
