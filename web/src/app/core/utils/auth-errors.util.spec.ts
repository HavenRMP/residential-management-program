import { traducirErrorLogin } from './auth-errors.util';

describe('traducirErrorLogin', () => {
  it('traduce las credenciales inválidas', () => {
    expect(traducirErrorLogin('Invalid login credentials')).toBe('Correo o contraseña incorrectos.');
  });

  it('avisa que la cuenta fue dada de baja cuando Supabase responde "User is banned"', () => {
    expect(traducirErrorLogin('User is banned')).toBe('Tu cuenta fue dada de baja. Comunícate con la administración.');
  });

  it('traduce el correo sin confirmar', () => {
    expect(traducirErrorLogin('Email not confirmed')).toBe('Confirma tu correo antes de iniciar sesión.');
  });

  it('deja intactos los mensajes desconocidos y usa uno genérico si no hay mensaje', () => {
    expect(traducirErrorLogin('Algo raro')).toBe('Algo raro');
    expect(traducirErrorLogin(undefined)).toBe('Ocurrió un error al iniciar sesión.');
    expect(traducirErrorLogin('')).toBe('Ocurrió un error al iniciar sesión.');
  });
});
