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

  it('la pantalla de paquetería es solo para residentes', () => {
    const ruta = routes.find(r => r.path === 'dashboard/residente/paquetes');

    expect(ruta?.canActivate?.length).toBe(2);
    expect(ruta?.loadComponent).toBeDefined();
  });
});
