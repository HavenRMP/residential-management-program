import { routes } from './app.routes';

/** Las notificaciones del backend traen una url_redireccion corta; debe llevar a la pantalla del residente */
describe('rutas de redirección de notificaciones', () => {
  const destino = (path: string) => routes.find(r => r.path === path)?.redirectTo;

  it('una notificación de visita lleva a las visitas del residente', () => {
    expect(destino('visitas/:id')).toBe('dashboard/residente/visitas');
  });

  it('una notificación de llegada de paquete lleva a la paquetería del residente', () => {
    expect(destino('paquetes/:id')).toBe('dashboard/residente/paquetes');
  });

  it('una notificación de reserva pasa por el puente que la lleva a la pantalla de su rol', () => {
    const ruta = routes.find(r => r.path === 'reservas/:id');

    expect(ruta?.canActivate?.length).toBe(1);
    expect(ruta?.loadComponent).toBeDefined();
  });

  it('la administración de reservas es una pantalla hija del panel del administrador', () => {
    const panel = routes.find(r => r.path === 'dashboard/admin');
    const reservas = panel?.children?.find(r => r.path === 'reservas');

    expect(panel?.canActivate?.length).toBe(2);
    expect(reservas?.loadComponent).toBeDefined();
  });

  it('la pantalla de reservas del residente exige sesión y rol', () => {
    const ruta = routes.find(r => r.path === 'dashboard/residente/reservas');

    expect(ruta?.canActivate?.length).toBe(2);
    expect(ruta?.loadComponent).toBeDefined();
  });

  it('la pantalla de paquetería es solo para residentes', () => {
    const ruta = routes.find(r => r.path === 'dashboard/residente/paquetes');

    expect(ruta?.canActivate?.length).toBe(2);
    expect(ruta?.loadComponent).toBeDefined();
  });
});
