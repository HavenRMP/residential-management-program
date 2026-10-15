import { DestroyRef } from '@angular/core';
import { fakeAsync, tick } from '@angular/core/testing';
import { autoActualizar } from './auto-actualizar.util';

describe('autoActualizar', () => {
  let destruir: () => void;
  let destroyRef: DestroyRef;
  let visibilidad: 'visible' | 'hidden';

  beforeEach(() => {
    destruir = () => {};
    destroyRef = { onDestroy: (fn: () => void) => { destruir = fn; return () => {}; } } as unknown as DestroyRef;
    visibilidad = 'visible';
    spyOnProperty(document, 'visibilityState', 'get').and.callFake(() => visibilidad);
  });

  it('pide los datos cada intervalo mientras la pestaña está a la vista', fakeAsync(() => {
    const accion = jasmine.createSpy('accion');
    autoActualizar(destroyRef, accion, 1000);
    tick(3000);
    expect(accion).toHaveBeenCalledTimes(3);
    destruir();
  }));

  it('no pide nada con la pestaña en segundo plano', fakeAsync(() => {
    const accion = jasmine.createSpy('accion');
    autoActualizar(destroyRef, accion, 1000);
    visibilidad = 'hidden';
    tick(5000);
    expect(accion).not.toHaveBeenCalled();
    destruir();
  }));

  it('al volver a la pestaña actualiza de inmediato si ya pasó el intervalo', fakeAsync(() => {
    const accion = jasmine.createSpy('accion');
    autoActualizar(destroyRef, accion, 1000);
    visibilidad = 'hidden';
    tick(2500);
    visibilidad = 'visible';
    document.dispatchEvent(new Event('visibilitychange'));
    expect(accion).toHaveBeenCalledTimes(1);
    destruir();
  }));

  it('al volver a la pestaña no repite si acaba de actualizar', fakeAsync(() => {
    const accion = jasmine.createSpy('accion');
    autoActualizar(destroyRef, accion, 1000);
    tick(1000);
    expect(accion).toHaveBeenCalledTimes(1);
    document.dispatchEvent(new Event('visibilitychange'));
    expect(accion).toHaveBeenCalledTimes(1);
    destruir();
  }));

  it('se detiene al destruirse el componente', fakeAsync(() => {
    const accion = jasmine.createSpy('accion');
    autoActualizar(destroyRef, accion, 1000);
    tick(1000);
    destruir();
    tick(5000);
    expect(accion).toHaveBeenCalledTimes(1);
  }));
});
