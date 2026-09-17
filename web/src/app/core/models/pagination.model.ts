/**
 * Modelo estándar para respuestas paginadas PagedResult<T> de los microservicios HavenApi.
 */
export interface PagedResult<T> {
  items: T[];
  page?: number;
  pageSize?: number;
  totalCount?: number;
  totalPages?: number;
}

/**
 * Extrae con seguridad la lista de elementos ya sea que el backend retorne
 * un arreglo nativo T[], un objeto PagedResult<T> ({ items: T[] }), o { data: T[] }.
 */
export function extractPagedItems<T>(response: any): T[] {
  if (!response) return [];
  if (Array.isArray(response)) return response;
  if (Array.isArray(response.items)) return response.items;
  if (Array.isArray(response.data)) return response.data;
  return [];
}
