export interface Vivienda {
  id: number;
  numeroCasa: string;
  tipo: string | null;
  condominioId?: string;
  condominioNombre?: string;
  creadoEn?: string;
  ocupada?: boolean;
}
