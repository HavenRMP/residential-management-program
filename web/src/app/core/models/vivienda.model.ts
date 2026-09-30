export interface Vivienda {
  id: number;
  numeroCasa: string;
  tipo: string | null;
  condominioId?: string;
  condominioNombre?: string;
  creadoEn?: string;
  ocupada?: boolean;
}

/** Datos de contacto de un residente tal como los devuelve GET /api/viviendas/con-residentes */
export interface ResidenteContacto {
  id: string;
  nombre: string;
  apellidos: string;
  telefono: string | null;
}

/** Vivienda con sus residentes, para el directorio de caseta (Administrador y Vigilancia) */
export interface ViviendaConResidentes {
  id: number;
  numeroCasa: string;
  tipo: string | null;
  totalResidentes: number;
  estaOcupada: boolean;
  residentes: ResidenteContacto[];
}
