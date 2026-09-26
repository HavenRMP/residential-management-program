export type TurnoVigilante = 'matutino' | 'vespertino' | 'nocturno';

export interface Vigilante {
  id: string;
  nombre: string;
  apellidos: string;
  email: string;
  telefono: string;
  turno: TurnoVigilante;
  activo: boolean;
  creadoEn: string;
}

export interface CrearVigilanteDto {
  nombre: string;
  apellidos: string;
  email: string;
  telefono: string;
  turno: TurnoVigilante;
}
