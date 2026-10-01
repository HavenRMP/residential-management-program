/**
 * Traduce los mensajes en inglés que devuelve Supabase Auth al iniciar sesión.
 * Los mensajes que no se reconocen se devuelven tal cual.
 */
export function traducirErrorLogin(mensaje: string | null | undefined): string {
  const texto = mensaje ?? '';
  if (!texto) return 'Ocurrió un error al iniciar sesión.';
  if (texto.includes('Invalid login credentials')) return 'Correo o contraseña incorrectos.';
  // Cuenta dada de baja por el administrador (por ejemplo, un vigilante)
  if (texto.toLowerCase().includes('banned')) return 'Tu cuenta fue dada de baja. Comunícate con la administración.';
  if (texto.includes('Email not confirmed')) return 'Confirma tu correo antes de iniciar sesión.';
  return texto;
}
