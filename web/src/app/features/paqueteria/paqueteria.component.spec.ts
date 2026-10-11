import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { signal } from '@angular/core';
import { of, throwError } from 'rxjs';
import { By } from '@angular/platform-browser';
import Swal from 'sweetalert2';
import { PaqueteriaComponent } from './paqueteria.component';
import { PaqueteFormComponent } from './paquete-form/paquete-form.component';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { ViviendasService } from '../../core/services/viviendas.service';
import { Paquete } from '../../core/models/paquete.model';

const paquete = (id: string, extra: Partial<Paquete> = {}): Paquete => ({
  id,
  viviendaId: 33,
  numeroCasa: 'PRUEBA-01',
  destinatarioNombre: 'Angel Gómez',
  servicioNombre: 'Amazon',
  estado: 'esperado',
  creadoEn: '2026-10-10T10:00:00Z',
  ...extra
});

describe('PaqueteriaComponent', () => {
  let fixture: ComponentFixture<PaqueteriaComponent>;
  let api: jasmine.SpyObj<ApiService>;
  let viviendas: { obtenerMisViviendas: jasmine.Spy };

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const tarjetas = () => Array.from(fixture.nativeElement.querySelectorAll('li') as NodeListOf<HTMLElement>);
  const boton = (nombre: string) =>
    Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.includes(nombre));

  async function abrir(items: Paquete[]): Promise<void> {
    api.get.and.returnValue(of({ items, totalCount: items.length }));
    fixture = TestBed.createComponent(PaqueteriaComponent);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(() => {
    api = jasmine.createSpyObj('ApiService', ['get', 'post', 'put']);
    viviendas = { obtenerMisViviendas: jasmine.createSpy('obtenerMisViviendas').and.resolveTo([{ id: 33, numeroCasa: 'PRUEBA-01' }]) };
    TestBed.configureTestingModule({
      imports: [PaqueteriaComponent],
      providers: [
        provideRouter([]),
        { provide: ApiService, useValue: api },
        { provide: ViviendasService, useValue: viviendas },
        { provide: AuthService, useValue: { currentUser: signal({ id: 'u1', nombre: 'Angel', rol: 'residente' }), logout: () => undefined } }
      ]
    });
  });

  it('muestra los pendientes con su empresa, guía y destinatario', async () => {
    await abrir([paquete('p1', { numeroGuia: 'ML-9845', descripcion: 'Caja de zapatos' })]);

    expect(tarjetas().length).toBe(1);
    expect(texto()).toContain('Amazon');
    expect(texto()).toContain('Esperado');
    expect(texto()).toContain('Para Angel Gómez');
    expect(texto()).toContain('Guía ML-9845');
    expect(texto()).toContain('Pendientes (1)');
    expect(texto()).toContain('Historial (0)');
  });

  it('avisa cuando hay paquetes en caseta y los pone primero con su ubicación', async () => {
    await abrir([
      paquete('e1', { servicioNombre: 'DHL', creadoEn: '2026-10-12T10:00:00Z' }),
      paquete('r1', { servicioNombre: 'FedEx', estado: 'recibido', recibidoEn: '2026-10-11T08:00:00Z', ubicacionAlmacen: 'Estante 3' })
    ]);

    expect(texto()).toContain('Tienes 1 paquete en caseta');
    expect(tarjetas()[0].textContent).toContain('FedEx');
    expect(tarjetas()[0].textContent).toContain('En caseta');
    expect(tarjetas()[0].textContent).toContain('Ubicación: Estante 3');
  });

  it('usa el plural cuando son varios', async () => {
    await abrir([paquete('r1', { estado: 'recibido' }), paquete('r2', { estado: 'recibido' })]);

    expect(texto()).toContain('Tienes 2 paquetes en caseta');
  });

  it('marca los paquetes que llegaron sin avisar', async () => {
    await abrir([paquete('r1', { estado: 'recibido', esInesperado: true })]);

    expect(texto()).toContain('Llegó sin avisar');
  });

  it('el historial muestra lo entregado y cancelado, sin acciones', async () => {
    await abrir([
      paquete('h1', { estado: 'entregado', entregadoEn: '2026-10-11T09:00:00Z', entregadoANombre: 'Angel Gómez' }),
      paquete('c1', { estado: 'cancelado', servicioNombre: 'DHL' })
    ]);

    boton('Historial')!.click();
    fixture.detectChanges();

    expect(tarjetas().length).toBe(2);
    expect(texto()).toContain('Entregado a Angel Gómez');
    expect(texto()).toContain('Cancelado');
  });

  it('un esperado cuya fecha ya pasó figura como vencido en el historial', async () => {
    await abrir([paquete('v1', { fechaEsperadaHasta: '2020-01-01T00:00:00Z' })]);

    expect(texto()).toContain('Pendientes (0)');
    boton('Historial')!.click();
    fixture.detectChanges();

    expect(tarjetas().length).toBe(1);
    expect(texto()).toContain('Vencido');
    expect(texto()).toContain('La fecha en que lo esperabas ya pasó.');
  });

  it('la búsqueda filtra por empresa o guía y avisa si nada coincide', async () => {
    await abrir([paquete('p1', { servicioNombre: 'Amazon' }), paquete('p2', { servicioNombre: 'DHL', numeroGuia: 'GUIA-77' })]);

    const caja = fixture.nativeElement.querySelector('#busqueda-paquetes') as HTMLInputElement;
    caja.value = 'guia-77';
    caja.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(tarjetas().length).toBe(1);
    expect(tarjetas()[0].textContent).toContain('DHL');

    caja.value = 'fedex';
    caja.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(tarjetas().length).toBe(0);
    expect(texto()).toContain('Ningún paquete coincide con «fedex».');
  });

  it('sin paquetes pendientes lo dice con claridad', async () => {
    await abrir([]);

    expect(texto()).toContain('No tienes paquetes pendientes.');
  });

  it('si la carga falla muestra el error y Reintentar vuelve a pedir los paquetes', async () => {
    spyOn(console, 'error');
    api.get.and.returnValue(throwError(() => ({ status: 500, error: { error: 'Servicio no disponible' } })));
    fixture = TestBed.createComponent(PaqueteriaComponent);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(texto()).toContain('Servicio no disponible');

    api.get.and.returnValue(of({ items: [paquete('p1')], totalCount: 1 }));
    boton('Reintentar')!.click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(texto()).not.toContain('Servicio no disponible');
    expect(tarjetas().length).toBe(1);
  });

  it('sin vivienda pide una y no consulta paquetes', async () => {
    viviendas.obtenerMisViviendas.and.resolveTo([]);
    await abrir([]);

    expect(texto()).toContain('Necesitas una vivienda asignada');
    expect(api.get).not.toHaveBeenCalled();
  });

  describe('avisar un paquete', () => {
    const formulario = () => fixture.debugElement.query(By.directive(PaqueteFormComponent));

    beforeEach(() => {
      spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true } as any);
    });

    it('el botón abre el formulario y pide el catálogo de empresas', async () => {
      await abrir([]);
      api.get.calls.reset();
      api.get.and.returnValue(of([{ id: 1, nombre: 'Amazon', activo: true, esSistema: true }]));

      boton('Avisar un paquete')!.click();
      fixture.detectChanges();
      await fixture.whenStable();
      fixture.detectChanges();

      expect(formulario()).not.toBeNull();
      expect(api.get.calls.mostRecent().args[0]).toBe('/api/paqueteria/servicios');
      expect(texto()).toContain('Amazon');
    });

    it('el estado vacío ofrece avisar un paquete', async () => {
      await abrir([]);

      const botones = Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>)
        .filter(b => b.textContent!.includes('Avisar un paquete'));

      expect(botones.length).toBe(2);
    });

    it('al guardar cierra el formulario y el paquete aparece en Pendientes', async () => {
      await abrir([]);
      api.get.and.returnValue(of([{ id: 1, nombre: 'Amazon', activo: true, esSistema: true }]));
      api.post.and.returnValue(of(paquete('nuevo', { servicioNombre: 'Amazon' })));
      boton('Avisar un paquete')!.click();
      fixture.detectChanges();
      await fixture.whenStable();
      fixture.detectChanges();
      const form = formulario().componentInstance as PaqueteFormComponent;
      form.form.servicio = 1;

      await form.guardar();
      fixture.detectChanges();

      expect(formulario()).toBeNull();
      expect(tarjetas().length).toBe(1);
      expect(texto()).toContain('Pendientes (1)');
    });

    it('cancelar cierra el formulario sin enviar nada', async () => {
      await abrir([]);
      boton('Avisar un paquete')!.click();
      fixture.detectChanges();

      (formulario().componentInstance as PaqueteFormComponent).cerrar();
      fixture.detectChanges();

      expect(formulario()).toBeNull();
      expect(api.post).not.toHaveBeenCalled();
    });
  });

  describe('corregir y cancelar un aviso', () => {
    let swal: jasmine.Spy;
    const botonDe = (nombre: string, tarjeta = 0) =>
      Array.from(tarjetas()[tarjeta].querySelectorAll('button')).find(b => b.textContent!.trim() === nombre);

    beforeEach(() => {
      swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true, value: '' } as any);
    });

    it('solo un esperado vigente trae Editar y Cancelar', async () => {
      await abrir([
        paquete('e1'),
        paquete('r1', { estado: 'recibido', recibidoEn: '2026-10-11T08:00:00Z' }),
        paquete('v1', { fechaEsperadaHasta: '2020-01-01T00:00:00Z' })
      ]);

      // Pendientes: primero el recibido (sin acciones) y luego el esperado
      expect(botonDe('Editar', 0)).toBeUndefined();
      expect(botonDe('Cancelar', 0)).toBeUndefined();
      expect(botonDe('Editar', 1)).toBeDefined();
      expect(botonDe('Cancelar', 1)).toBeDefined();

      boton('Historial')!.click();
      fixture.detectChanges();
      expect(botonDe('Editar', 0)).toBeUndefined();
      expect(botonDe('Cancelar', 0)).toBeUndefined();
    });

    it('Editar abre el formulario con los datos del paquete', async () => {
      await abrir([paquete('e1', { numeroGuia: 'ML-9845' })]);

      botonDe('Editar')!.click();
      fixture.detectChanges();
      await fixture.whenStable();
      fixture.detectChanges();

      const form = fixture.debugElement.query(By.directive(PaqueteFormComponent));
      expect(form).not.toBeNull();
      expect(texto()).toContain('Editar paquete');
      expect((fixture.nativeElement.querySelector('#paq-guia') as HTMLInputElement).value).toBe('ML-9845');
    });

    it('cancelar con motivo lo envía y pasa el aviso al historial', async () => {
      await abrir([paquete('e1')]);
      swal.and.resolveTo({ isConfirmed: true, value: 'Cancelé la compra' } as any);
      api.post.and.returnValue(of(undefined));

      await fixture.componentInstance.confirmarCancelar(paquete('e1'));
      fixture.detectChanges();

      expect(api.post).toHaveBeenCalledWith('/api/paqueteria/e1/cancelar', { motivo: 'Cancelé la compra' }, undefined, 'visitas');
      expect(texto()).toContain('Pendientes (0)');
      expect(texto()).toContain('Historial (1)');
      expect((swal.calls.mostRecent().args[0] as any).title).toBe('Aviso cancelado');
    });

    it('si se arrepiente no cancela nada', async () => {
      await abrir([paquete('e1')]);
      swal.and.resolveTo({ isConfirmed: false } as any);

      await fixture.componentInstance.confirmarCancelar(paquete('e1'));

      expect(api.post).not.toHaveBeenCalled();
    });

    it('si ya llegó a caseta (409) lo explica y actualiza la lista', async () => {
      spyOn(console, 'error');
      await abrir([paquete('e1')]);
      api.post.and.returnValue(throwError(() => ({ status: 409 })));
      api.get.calls.reset();
      api.get.and.returnValue(of({ items: [paquete('e1', { estado: 'recibido' })], totalCount: 1 }));

      await fixture.componentInstance.confirmarCancelar(paquete('e1'));
      fixture.detectChanges();

      const aviso = swal.calls.mostRecent().args[0] as any;
      expect(aviso.icon).toBe('info');
      expect(aviso.text).toContain('Ya no se puede cancelar');
      expect(api.get).toHaveBeenCalled();
      expect(texto()).toContain('Tienes 1 paquete en caseta');
    });

    it('un fallo del servidor oculta el JSON técnico y no cambia la lista', async () => {
      spyOn(console, 'error');
      await abrir([paquete('e1')]);
      api.post.and.returnValue(throwError(() => ({ status: 500, error: { error: 'Error desde Supabase: {"code":"XX000"}' } })));

      await fixture.componentInstance.confirmarCancelar(paquete('e1'));
      fixture.detectChanges();

      const aviso = swal.calls.mostRecent().args[0] as any;
      expect(aviso.icon).toBe('error');
      expect(aviso.text).toBe('No fue posible cancelar el aviso. Intenta de nuevo en unos segundos.');
      expect(texto()).toContain('Pendientes (1)');
    });

    it('si el formulario avisa que el paquete cambió, se cierra y se refresca la lista', async () => {
      await abrir([paquete('e1')]);
      botonDe('Editar')!.click();
      fixture.detectChanges();
      api.get.calls.reset();
      api.get.and.returnValue(of({ items: [paquete('e1', { estado: 'recibido' })], totalCount: 1 }));

      (fixture.debugElement.query(By.directive(PaqueteFormComponent)).componentInstance as PaqueteFormComponent).obsoleto.emit();
      await fixture.whenStable();
      fixture.detectChanges();

      expect(fixture.debugElement.query(By.directive(PaqueteFormComponent))).toBeNull();
      expect(api.get).toHaveBeenCalled();
      expect(texto()).toContain('Tienes 1 paquete en caseta');
    });
  });

  it('con varias viviendas indica a qué casa pertenece cada paquete', async () => {
    viviendas.obtenerMisViviendas.and.resolveTo([{ id: 33, numeroCasa: 'PRUEBA-01' }, { id: 34, numeroCasa: 'PRUEBA-02' }]);
    await abrir([paquete('p1', { numeroCasa: 'PRUEBA-02' })]);

    expect(tarjetas()[0].textContent).toContain('Casa PRUEBA-02');
  });
});
