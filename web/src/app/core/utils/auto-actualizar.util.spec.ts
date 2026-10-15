import { DestroyRef, Injector, NgZone } from '@angular/core';
import { fakeAsync, tick } from '@angular/core/testing';
import { autoActualizar } from './auto-actualizar.util';

describe('autoActualizar', () => {
  let destruir: () => void;
  let injector: Injector;
  let visibilidad: 'visible' | 'hidden';

  beforeEach(() => {
    destruir = () => {};
    const destroyRef = { onDestroy: (fn: () => void) => { destruir = fn; return () => {}; } } as unknown as DestroyRef;
    const zona = { run: (fn: () => void) => fn(), runOutsideAngular: (fn: () => void) => fn() } as unknown as NgZone;
    injector = { get: (token: unknown) => (token === DestroyRef ? destroyRef : zona) } as unknown as Injector;
    visibilidad = 'visible';
    spyOnProperty(document, 'visibilityState', 'get').and.callFake(() => visibilidad);
  });

  it('pide los datos cada intervalo mientras la pestaña está a la vista', fakeAsync(() => {
    const accion = jasmine.createSpy('accion');
    autoActualizar(injector, accion, 1000);
    tick(3000);
    expect(accion).toHaveBeenCalledTimes(3);
    destruir();
  }));

  it('no pide nada con la pestaña en segundo plano', fakeAsync(() => {
    const accion = jasmine.createSpy('accion');
    autoActualizar(injector, accion, 1000);
    visibilidad = 'hidden';
    tick(5000);
    expect(accion).not.toHaveBeenCalled();
    destruir();
  }));

  it('al volver a la pestaña actualiza de inmediato si ya pasó el intervalo', fakeAsync(() => {
    const accion = jasmine.createSpy('accion');
    autoActualizar(injector, accion, 1000);
    visibilidad = 'hidden';
    tick(2500);
    visibilidad = 'visible';
    document.dispatchEvent(new Event('visibilitychange'));
    expect(accion).toHaveBeenCalledTimes(1);
    destruir();
  }));

  it('al volver a la pestaña no repite si acaba de actualizar', fakeAsync(() => {
    const accion = jasmine.createSpy('accion');
    autoActualizar(injector, accion, 1000);
    tick(1000);
    expect(accion).toHaveBeenCalledTimes(1);
    document.dispatchEvent(new Event('visibilitychange'));
    expect(accion).toHaveBeenCalledTimes(1);
    destruir();
  }));

  it('se detiene al destruirse el componente', fakeAsync(() => {
    const accion = jasmine.createSpy('accion');
    autoActualizar(injector, accion, 1000);
    tick(1000);
    destruir();
    tick(5000);
    expect(accion).toHaveBeenCalledTimes(1);
  }));

  it('al volver a la pestaña no espera el intervalo completo: basta con unos segundos', fakeAsync(() => {
    const accion = jasmine.createSpy('accion');
    autoActualizar(injector, accion, 30_000);
    tick(6_000);
    document.dispatchEvent(new Event('visibilitychange'));
    expect(accion).toHaveBeenCalledTimes(1);
    destruir();
  }));

  it('al volver a la pestaña no repite si apenas pasaron un par de segundos', fakeAsync(() => {
    const accion = jasmine.createSpy('accion');
    autoActualizar(injector, accion, 30_000);
    tick(2_000);
    document.dispatchEvent(new Event('visibilitychange'));
    expect(accion).not.toHaveBeenCalled();
    destruir();
  }));

  it('al enfocar de nuevo la ventana también actualiza', fakeAsync(() => {
    const accion = jasmine.createSpy('accion');
    autoActualizar(injector, accion, 30_000);
    tick(6_000);
    window.dispatchEvent(new Event('focus'));
    expect(accion).toHaveBeenCalledTimes(1);
    destruir();
  }));
});
