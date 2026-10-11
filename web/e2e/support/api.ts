import { Rol, cuenta } from './cuentas';

// Mismos valores públicos que web/src/environments/environment.ts; se pueden sustituir para probar otro entorno.
const SUPABASE_URL = process.env['E2E_SUPABASE_URL'] || 'https://qunkgbmxmxmjponyxzdu.supabase.co';
const SUPABASE_KEY = process.env['E2E_SUPABASE_KEY'] || 'sb_publishable_2an39B-QMQpwkuaCYfg1Bw_EgWoC-SF';

export const SERVICIOS = {
  visitas: process.env['E2E_VISITAS_API_URL'] || 'https://visitas-api-r66s.onrender.com',
  viviendas: process.env['E2E_VIVIENDAS_API_URL'] || 'https://viviendas-api.onrender.com',
  usuarios: process.env['E2E_USUARIOS_API_URL'] || 'https://usuarios-api-n1qi.onrender.com'
} as const;

export type Servicio = keyof typeof SERVICIOS;

/** Un servicio dormido en Render puede tardar más de un minuto en responder la primera vez */
const ESPERA_MAXIMA_MS = 3 * 60_000;

const tokens = new Map<Rol, string>();

/** Token de acceso de la cuenta de prueba del rol (se pide una sola vez por ejecución) */
export async function tokenDe(rol: Rol): Promise<string> {
  const guardado = tokens.get(rol);
  if (guardado) return guardado;

  const datos = cuenta(rol);
  if (!datos) throw new Error(`Falta la cuenta de prueba de ${rol}`);

  const respuesta = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: SUPABASE_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: datos.email, password: datos.password }),
    signal: AbortSignal.timeout(ESPERA_MAXIMA_MS)
  });
  if (!respuesta.ok) throw new Error(`No se pudo iniciar sesión como ${rol} (${respuesta.status})`);
  const token = (await respuesta.json()).access_token as string;
  tokens.set(rol, token);
  return token;
}

export interface Respuesta<T> {
  status: number;
  datos: T | null;
}

/** Llama a un microservicio como el rol indicado. Nunca lanza por un estado HTTP de error: el test decide qué hacer. */
export async function llamar<T = any>(
  servicio: Servicio,
  metodo: 'GET' | 'POST' | 'PUT' | 'DELETE',
  ruta: string,
  rol: Rol,
  cuerpo?: unknown
): Promise<Respuesta<T>> {
  const respuesta = await fetch(`${SERVICIOS[servicio]}${ruta}`, {
    method: metodo,
    headers: { Authorization: `Bearer ${await tokenDe(rol)}`, 'Content-Type': 'application/json' },
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
    signal: AbortSignal.timeout(ESPERA_MAXIMA_MS)
  });
  const texto = await respuesta.text();
  let datos: T | null = null;
  try {
    datos = texto ? (JSON.parse(texto) as T) : null;
  } catch {
    datos = null;
  }
  return { status: respuesta.status, datos };
}

/** Elementos de una respuesta paginada o de un arreglo simple */
export function elementos<T = any>(datos: any): T[] {
  if (!datos) return [];
  if (Array.isArray(datos)) return datos;
  return datos.items ?? datos.data ?? [];
}

/** Todas las páginas de una consulta paginada (con tope de seguridad) */
export async function todasLasPaginas<T = any>(servicio: Servicio, ruta: string, rol: Rol): Promise<T[]> {
  const separador = ruta.includes('?') ? '&' : '?';
  const todos: T[] = [];
  for (let pagina = 1; pagina <= 20; pagina++) {
    const { datos } = await llamar(servicio, 'GET', `${ruta}${separador}page=${pagina}&pageSize=100`, rol);
    const lote = elementos<T>(datos);
    todos.push(...lote);
    if (lote.length < 100) break;
  }
  return todos;
}

/** Id de la primera vivienda del residente de prueba */
export async function viviendaDe(rol: Rol): Promise<number> {
  const { datos } = await llamar('viviendas', 'GET', '/api/viviendas/mis-viviendas?pageSize=100', rol);
  const primera = elementos(datos)[0];
  const id = primera?.viviendaId ?? primera?.id;
  if (!id) throw new Error(`La cuenta de ${rol} no tiene vivienda asignada`);
  return id as number;
}
