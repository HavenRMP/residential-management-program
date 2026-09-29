export interface Vigilante {
  id: string;
  nombre: string;
  apellidos: string;
  email: string;
  telefono: string;
  activo: boolean;
  creadoEn: string;
}

export interface CrearVigilanteDto {
  nombre: string;
  apellidos: string;
  email: string;
  telefono: string;
  password: string;
}

/** Respuesta de POST /api/auth/register-vigilante */
export interface VigilanteRegistradoApi {
  id: string;
  email: string;
  nombre: string;
  apellidos: string;
  telefono: string;
  condominioId?: string;
  creadoEn: string;
}
