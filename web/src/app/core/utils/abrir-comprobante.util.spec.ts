import { abrirEnPestana } from './abrir-comprobante.util';

describe('abrirEnPestana', () => {
  const pestanaFalsa = () => ({ opener: 'ventana-original', location: { href: '' }, close: jasmine.createSpy('close') });

  it('abre la pestaña de inmediato y le pone la dirección cuando llega', async () => {
    const pestana = pestanaFalsa();
    const abrir = spyOn(window, 'open').and.returnValue(pestana as unknown as Window);
    let resolver!: (url: string) => void;
    const pendiente = abrirEnPestana(() => new Promise<string>(r => (resolver = r)));

    expect(abrir).toHaveBeenCalledOnceWith('', '_blank');
    expect(pestana.opener).toBeNull();

    resolver('https://storage/firmada');
    await pendiente;

    expect(pestana.location.href).toBe('https://storage/firmada');
    expect(pestana.close).not.toHaveBeenCalled();
  });

  it('si pedir el enlace falla cierra la pestaña y propaga el error', async () => {
    const pestana = pestanaFalsa();
    spyOn(window, 'open').and.returnValue(pestana as unknown as Window);

    await expectAsync(abrirEnPestana(() => Promise.reject(new Error('sin comprobante')))).toBeRejectedWithError('sin comprobante');

    expect(pestana.close).toHaveBeenCalled();
  });

  it('un enlace vacío cuenta como error', async () => {
    const pestana = pestanaFalsa();
    spyOn(window, 'open').and.returnValue(pestana as unknown as Window);

    await expectAsync(abrirEnPestana(() => Promise.resolve(''))).toBeRejected();

    expect(pestana.close).toHaveBeenCalled();
  });

  it('si el navegador bloquea la pestaña, abre el enlace en una nueva con noopener', async () => {
    const abrir = spyOn(window, 'open').and.returnValue(null);

    await abrirEnPestana(() => Promise.resolve('https://storage/firmada'));

    expect(abrir).toHaveBeenCalledTimes(2);
    expect(abrir.calls.mostRecent().args).toEqual(['https://storage/firmada', '_blank', 'noopener']);
  });
});
