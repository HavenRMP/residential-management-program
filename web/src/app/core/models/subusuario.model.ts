export interface SubUsuarioInvitacion {
  id: string;
  nombreInvitado: string;
  emailInvitado?: string;
  telefonoInvitado?: string;
  codigoInvitacion: string;
  creadoEn: string;
  expiraEn: string;
  estado: 'pendiente' | 'activa' | 'expirada';
}

export interface CrearInvitacionSubUsuarioDto {
  nombreInvitado: string;
  emailInvitado?: string;
  telefonoInvitado?: string;
}
