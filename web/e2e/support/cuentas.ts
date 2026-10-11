export type Rol = 'administrador' | 'residente' | 'vigilante' | 'subusuario';

export const ROLES: Rol[] = ['administrador', 'residente', 'vigilante', 'subusuario'];

const PREFIJO: Record<Rol, string> = {
  administrador: 'E2E_ADMIN',
  residente: 'E2E_RESIDENTE',
  vigilante: 'E2E_VIGILANTE',
  subusuario: 'E2E_SUBUSUARIO'
};

export interface Cuenta {
  email: string;
  password: string;
}

/** Cuenta de prueba del rol, tomada de las variables de entorno; null si falta alguna de las dos */
export function cuenta(rol: Rol): Cuenta | null {
  const email = process.env[`${PREFIJO[rol]}_EMAIL`];
  const password = process.env[`${PREFIJO[rol]}_PASSWORD`];
  return email && password ? { email, password } : null;
}

/** Variables que hay que definir para poder probar con ese rol (para el mensaje al omitir un test) */
export function variablesDe(rol: Rol): string {
  return `${PREFIJO[rol]}_EMAIL y ${PREFIJO[rol]}_PASSWORD`;
}

/** Ruta del archivo con la sesión ya iniciada de ese rol */
export function sesionDe(rol: Rol): string {
  return `e2e/.auth/${rol}.json`;
}

/** A dónde llega cada rol al entrar */
export const DASHBOARD_DE: Record<Rol, string> = {
  administrador: '/dashboard/admin',
  residente: '/dashboard/residente',
  vigilante: '/dashboard/vigilante',
  // El sub-usuario tiene rol residente en el sistema
  subusuario: '/dashboard/residente'
};
