import { ComponentFixture, TestBed } from '@angular/core/testing';
import Swal from 'sweetalert2';
import { PaqueteFormComponent } from './paquete-form.component';
import { PaqueteriaService } from '../../../core/services/paqueteria.service';
import { Paquete } from '../../../core/models/paquete.model';

const catalogo = [
  { id: 1, nombre: 'Amazon', activo: true, esSistema: true },
  { id: 2, nombre: 'DHL', activo: true, esSistema: true }
];
const casa = { id: 33, numeroCasa: 'PRUEBA-01' };
const creado: Paquete = { id: 'nuevo', viviendaId: 33, destinatarioNombre: 'Angel Gómez', estado: 'esperado' };

describe('PaqueteFormComponent', () => {
  let fixture: ComponentFixture<PaqueteFormComponent>;
  let component: PaqueteFormComponent;
  let servicio: { crear: jasmine.Spy };
  let swal: jasmine.Spy;

  const campo = (id: string) => fixture.nativeElement.querySelector('#' + id) as HTMLInputElement | HTMLSelectElement | null;
  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const botonPorTexto = (t: string) =>
    Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.trim() === t);
  // Es el último botón con el color de marca: antes van las opciones de "¿Cuándo llega?", que también lo usan al estar elegidas
  const botonGuardar = () => Array.from(fixture.nativeElement.querySelectorAll('button.bg-\\[\\#111C99\\]') as NodeListOf<HTMLButtonElement>).pop()!;

  function abrir(opciones: { viviendas?: any[]; servicios?: any[]; nombre?: string } = {}): void {
    fixture = TestBed.createComponent(PaqueteFormComponent);
    component = fixture.componentInstance;
    component.viviendas = opciones.viviendas ?? [casa];
    component.servicios = opciones.servicios ?? catalogo;
    component.nombreSugerido = opciones.nombre ?? 'Angel Gómez';
    component.viviendaInicial = (opciones.viviendas ?? [casa])[0].id;
    fixture.detectChanges();
  }

  beforeEach(() => {
    servicio = { crear: jasmine.createSpy('crear').and.resolveTo(creado) };
    swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true } as any);
    TestBed.configureTestingModule({
      imports: [PaqueteFormComponent],
      providers: [{ provide: PaqueteriaService, useValue: servicio }]
    });
  });

  it('propone el nombre de quien avisa y no deja guardar sin elegir empresa', async () => {
    abrir();
    await fixture.whenStable();

    expect((campo('paq-destinatario') as HTMLInputElement).value).toBe('Angel Gómez');
    expect(component.esFormularioValido()).toBeFalse();
  });

  it('con una empresa del catálogo manda su id, sin nombre de empresa', () => {
    abrir();
    component.form.servicio = 2;

    expect(component.esFormularioValido()).toBeTrue();
    expect(component.armarDto()).toEqual({ viviendaId: 33, destinatarioNombre: 'Angel Gómez', servicioId: 2 });
  });

  it('con otra empresa pide el nombre y manda solo servicioNombre', () => {
    abrir();
    component.form.servicio = 'otro';
    fixture.detectChanges();
    expect(campo('paq-otra')).not.toBeNull();
    expect(component.esFormularioValido()).toBeFalse();

    component.form.servicioOtro = '  Paquetexpress ';

    expect(component.esFormularioValido()).toBeTrue();
    const dto = component.armarDto();
    expect(dto.servicioNombre).toBe('Paquetexpress');
    expect(dto.servicioId).toBeUndefined();
  });

  it('si el catálogo no cargó deja escribir la empresa', () => {
    abrir({ servicios: [] });

    expect(campo('paq-otra')).not.toBeNull();
    component.form.servicioOtro = 'Estafeta';
    expect(component.esFormularioValido()).toBeTrue();
    expect(component.armarDto().servicioNombre).toBe('Estafeta');
  });

  it('solo manda los campos opcionales que se llenaron y recorta espacios', () => {
    abrir();
    component.form.servicio = 1;
    component.form.numeroGuia = ' ML-9845 ';
    component.form.descripcion = '   ';
    component.form.notas = 'Dejar en caseta';

    const dto = component.armarDto();

    expect(dto.numeroGuia).toBe('ML-9845');
    expect(dto.descripcion).toBeUndefined();
    expect(dto.notas).toBe('Dejar en caseta');
    expect(dto.fechaEsperadaDesde).toBeUndefined();
    expect(dto.fechaEsperadaHasta).toBeUndefined();
  });

  it('"varios días" cubre el día completo de inicio y de fin', () => {
    abrir();
    component.form.servicio = 1;
    component.elegirCuando('rango');
    component.form.desde = component.hoy;
    component.form.hasta = component.hoy;

    const dto = component.armarDto();

    expect(new Date(dto.fechaEsperadaDesde!).getTime()).toBe(new Date(`${component.hoy}T00:00:00`).getTime());
    expect(new Date(dto.fechaEsperadaHasta!).getTime()).toBe(new Date(`${component.hoy}T23:59:59.999`).getTime());
  });

  it('"un día" manda ese día completo como inicio y fin', () => {
    abrir();
    component.form.servicio = 1;
    component.elegirCuando('dia');
    component.form.dia = '2099-03-05';

    const dto = component.armarDto();

    expect(new Date(dto.fechaEsperadaDesde!).getTime()).toBe(new Date('2099-03-05T00:00:00').getTime());
    expect(new Date(dto.fechaEsperadaHasta!).getTime()).toBe(new Date('2099-03-05T23:59:59.999').getTime());
  });

  it('"no sé cuándo" no manda fechas aunque haya algo escrito en los otros campos', () => {
    abrir();
    component.form.servicio = 1;
    component.form.dia = '2099-03-05';
    component.form.desde = '2099-03-01';
    component.form.hasta = '2099-03-09';

    const dto = component.armarDto();

    expect(dto.fechaEsperadaDesde).toBeUndefined();
    expect(dto.fechaEsperadaHasta).toBeUndefined();
  });

  it('el selector "¿Cuándo llega?" muestra solo los campos de la opción elegida', () => {
    abrir();
    expect(campo('paq-dia')).toBeNull();
    expect(campo('paq-desde')).toBeNull();

    botonPorTexto('Un día')!.click();
    fixture.detectChanges();
    expect(campo('paq-dia')).not.toBeNull();
    expect(campo('paq-desde')).toBeNull();

    botonPorTexto('Varios días')!.click();
    fixture.detectChanges();
    expect(campo('paq-dia')).toBeNull();
    expect(campo('paq-desde')).not.toBeNull();
    expect(campo('paq-hasta')).not.toBeNull();
    expect(botonPorTexto('Varios días')!.getAttribute('aria-checked')).toBe('true');
  });

  it('con "un día" o "varios días" pide las fechas antes de dejar avisar', () => {
    abrir();
    component.form.servicio = 1;
    component.form.destinatarioNombre = 'Angel Gómez';
    expect(component.esFormularioValido()).toBeTrue();

    component.elegirCuando('dia');
    expect(component.esFormularioValido()).toBeFalse();
    component.form.dia = component.hoy;
    expect(component.esFormularioValido()).toBeTrue();

    component.elegirCuando('rango');
    component.form.desde = component.hoy;
    expect(component.esFormularioValido()).toBeFalse();
    component.form.hasta = component.hoy;
    expect(component.esFormularioValido()).toBeTrue();
  });

  it('un día que ya pasó no se acepta y lo explica', () => {
    abrir();
    component.form.servicio = 1;
    component.elegirCuando('dia');
    component.form.dia = '2020-01-01';
    fixture.detectChanges();

    expect(component.esFormularioValido()).toBeFalse();
    expect(texto()).toContain('La fecha ya pasó');
  });

  it('rechaza fechas invertidas o ya pasadas y lo explica', () => {
    abrir();
    component.form.servicio = 1;
    component.elegirCuando('rango');

    component.form.desde = '2099-02-10';
    component.form.hasta = '2099-02-01';
    fixture.detectChanges();
    expect(component.esFormularioValido()).toBeFalse();
    expect(texto()).toContain('La fecha de inicio no puede ser posterior');

    component.form.desde = '';
    component.form.hasta = '2020-01-01';
    fixture.detectChanges();
    expect(component.esFormularioValido()).toBeFalse();
    expect(texto()).toContain('La fecha ya pasó');
  });

  it('exige el nombre del destinatario y respeta su largo máximo', () => {
    abrir();
    component.form.servicio = 1;

    component.form.destinatarioNombre = '   ';
    expect(component.esFormularioValido()).toBeFalse();
    component.form.destinatarioNombre = 'x'.repeat(101);
    expect(component.esFormularioValido()).toBeFalse();
    component.form.destinatarioNombre = 'x'.repeat(100);
    expect(component.esFormularioValido()).toBeTrue();
  });

  it('con varias viviendas pide elegir cuál y la incluye en el aviso', () => {
    abrir({ viviendas: [casa, { id: 34, numeroCasa: 'PRUEBA-02' }] });
    component.form.servicio = 1;
    component.form.viviendaId = 34;
    fixture.detectChanges();

    expect(campo('paq-vivienda')).not.toBeNull();
    expect(component.armarDto().viviendaId).toBe(34);
  });

  it('con una sola vivienda no muestra el selector', () => {
    abrir();

    expect(campo('paq-vivienda')).toBeNull();
  });

  it('al guardar envía el aviso, avisa al padre y confirma con un aviso breve', async () => {
    abrir();
    component.form.servicio = 1;
    const guardados: Paquete[] = [];
    component.guardado.subscribe(p => guardados.push(p));

    await component.guardar();

    expect(servicio.crear).toHaveBeenCalledOnceWith({ viviendaId: 33, destinatarioNombre: 'Angel Gómez', servicioId: 1 });
    expect(guardados).toEqual([creado]);
    expect((swal.calls.mostRecent().args[0] as any).toast).toBeTrue();
    expect(component.isSaving()).toBeFalse();
  });

  it('si el backend rechaza el aviso muestra su motivo y no cierra', async () => {
    spyOn(console, 'error');
    abrir();
    component.form.servicio = 1;
    servicio.crear.and.rejectWith({ status: 400, error: { error: 'La fecha límite esperada ya ha pasado respecto a la fecha actual.' } });
    const guardados: Paquete[] = [];
    component.guardado.subscribe(p => guardados.push(p));

    await component.guardar();

    expect(guardados).toEqual([]);
    const error = swal.calls.mostRecent().args[0] as any;
    expect(error.icon).toBe('error');
    expect(error.text).toBe('La fecha límite esperada ya ha pasado respecto a la fecha actual.');
    expect(component.isSaving()).toBeFalse();
  });

  it('muestra el primer error de validación cuando el backend no manda { error }', async () => {
    spyOn(console, 'error');
    abrir();
    component.form.servicio = 1;
    servicio.crear.and.rejectWith({ status: 400, error: { errors: { Descripcion: ['La descripción no puede exceder 250 caracteres.'] } } });

    await component.guardar();

    expect((swal.calls.mostRecent().args[0] as any).text).toBe('La descripción no puede exceder 250 caracteres.');
  });

  it('oculta el JSON técnico con un mensaje genérico', async () => {
    spyOn(console, 'error');
    abrir();
    component.form.servicio = 1;
    servicio.crear.and.rejectWith({ status: 500, error: { error: 'Error desde Supabase: {"code":"XX000"}' } });

    await component.guardar();

    expect((swal.calls.mostRecent().args[0] as any).text).toBe('No fue posible enviar el aviso. Intenta de nuevo en unos segundos.');
  });

  it('no envía nada si el formulario no es válido', async () => {
    abrir();

    await component.guardar();

    expect(servicio.crear).not.toHaveBeenCalled();
    expect(botonGuardar().disabled).toBeTrue();
  });

  describe('editar un paquete esperado', () => {
    const original: Paquete = {
      id: 'p1',
      viviendaId: 33,
      destinatarioNombre: 'Angel Gómez',
      servicioId: 1,
      servicioNombre: 'Amazon',
      numeroGuia: 'ML-9845',
      descripcion: 'Caja de zapatos',
      notas: 'Dejar en caseta',
      fechaEsperadaDesde: new Date(2099, 1, 1, 12).toISOString(),
      fechaEsperadaHasta: new Date(2099, 1, 3, 12).toISOString(),
      estado: 'esperado'
    };

    function abrirEdicion(paquete: Paquete, servicios: any[] = catalogo): void {
      fixture = TestBed.createComponent(PaqueteFormComponent);
      component = fixture.componentInstance;
      fixture.componentRef.setInput('viviendas', [casa, { id: 34, numeroCasa: 'PRUEBA-02' }]);
      fixture.componentRef.setInput('servicios', servicios);
      fixture.componentRef.setInput('paquete', paquete);
      fixture.detectChanges();
    }

    it('rellena los datos del paquete, no pide vivienda y no deja guardar sin cambios', async () => {
      abrirEdicion(original);
      await fixture.whenStable();
      fixture.detectChanges();

      expect(texto()).toContain('Editar paquete');
      expect((campo('paq-destinatario') as HTMLInputElement).value).toBe('Angel Gómez');
      expect((campo('paq-guia') as HTMLInputElement).value).toBe('ML-9845');
      expect(component.form.cuando).toBe('rango');
      expect((campo('paq-desde') as HTMLInputElement).value).toBe('2099-02-01');
      expect((campo('paq-hasta') as HTMLInputElement).value).toBe('2099-02-03');
      expect(campo('paq-vivienda')).toBeNull();
      expect(component.form.servicio).toBe(1);
      expect(component.hayCambios()).toBeFalse();
      expect(botonGuardar().textContent).toContain('Guardar cambios');
      expect(botonGuardar().disabled).toBeTrue();
    });

    it('un aviso de un solo día se abre como "un día" y cambiar el día manda ambas fechas', () => {
      abrirEdicion({ ...original, fechaEsperadaDesde: new Date(2099, 1, 1, 0, 0, 0).toISOString(), fechaEsperadaHasta: new Date(2099, 1, 1, 23, 59, 59, 999).toISOString() });
      expect(component.form.cuando).toBe('dia');
      expect(component.form.dia).toBe('2099-02-01');
      expect(component.armarCambios()).toEqual({});

      component.form.dia = '2099-02-04';
      const cambios = component.armarCambios();

      expect(Object.keys(cambios).sort()).toEqual(['fechaEsperadaDesde', 'fechaEsperadaHasta']);
      expect(new Date(cambios.fechaEsperadaDesde!).getTime()).toBe(new Date('2099-02-04T00:00:00').getTime());
      expect(new Date(cambios.fechaEsperadaHasta!).getTime()).toBe(new Date('2099-02-04T23:59:59.999').getTime());
    });

    it('sin cambios no arma ningún campo', () => {
      abrirEdicion(original);

      expect(component.armarCambios()).toEqual({});
    });

    it('envía solo lo que cambió', () => {
      abrirEdicion(original);
      component.form.numeroGuia = ' ML-0001 ';
      component.form.notas = '';
      component.form.hasta = '2099-02-10';

      const cambios = component.armarCambios();

      expect(Object.keys(cambios).sort()).toEqual(['fechaEsperadaHasta', 'notas', 'numeroGuia']);
      expect(cambios.numeroGuia).toBe('ML-0001');
      expect(cambios.notas).toBe('');
      expect(new Date(cambios.fechaEsperadaHasta!).getTime()).toBe(new Date('2099-02-10T23:59:59.999').getTime());
      expect(component.hayCambios()).toBeTrue();
    });

    it('cambiar a otra empresa del catálogo manda su id', () => {
      abrirEdicion(original);
      component.form.servicio = 2;

      expect(component.armarCambios()).toEqual({ servicioId: 2 });
    });

    it('una empresa que no está en el catálogo se muestra como "otra" con su nombre', () => {
      abrirEdicion({ ...original, servicioId: null, servicioNombre: 'Paquetexpress' });

      expect(component.form.servicio).toBe('otro');
      expect(component.form.servicioOtro).toBe('Paquetexpress');
      expect(component.armarCambios()).toEqual({});
      component.form.servicioOtro = 'Redpack';
      expect(component.armarCambios()).toEqual({ servicioNombre: 'Redpack' });
    });

    it('reconoce la empresa por nombre si el paquete no trae su id', () => {
      abrirEdicion({ ...original, servicioId: null, servicioNombre: 'dhl' });

      expect(component.form.servicio).toBe(2);
    });

    it('si el catálogo llega después de abrir, selecciona la empresa del paquete', () => {
      abrirEdicion(original, []);
      expect(component.usaOtraEmpresa()).toBeTrue();

      fixture.componentRef.setInput('servicios', catalogo);
      fixture.detectChanges();

      expect(component.form.servicio).toBe(1);
      expect(component.hayCambios()).toBeFalse();
    });

    it('si la persona ya eligió otra empresa, una recarga del catálogo no se la cambia', () => {
      abrirEdicion(original);
      component.form.servicio = 2;

      fixture.componentRef.setInput('servicios', [...catalogo]);
      fixture.detectChanges();

      expect(component.form.servicio).toBe(2);
    });

    it('al guardar envía los cambios, actualiza y avisa al padre', async () => {
      const actualizado = { ...original, numeroGuia: 'ML-0001' };
      const actualizar = jasmine.createSpy('actualizar').and.resolveTo(actualizado);
      (servicio as any).actualizar = actualizar;
      abrirEdicion(original);
      component.form.numeroGuia = 'ML-0001';
      const guardados: Paquete[] = [];
      component.guardado.subscribe(p => guardados.push(p));

      await component.guardar();

      expect(actualizar).toHaveBeenCalledOnceWith('p1', { numeroGuia: 'ML-0001' });
      expect(servicio.crear).not.toHaveBeenCalled();
      expect(guardados).toEqual([actualizado]);
      expect((swal.calls.mostRecent().args[0] as any).title).toBe('Paquete actualizado');
    });

    it('si ya lo recibieron en caseta (409) avisa con claridad y pide refrescar la lista', async () => {
      spyOn(console, 'error');
      (servicio as any).actualizar = jasmine.createSpy('actualizar').and.rejectWith({ status: 409 });
      abrirEdicion(original);
      component.form.numeroGuia = 'ML-0001';
      let obsoletos = 0;
      component.obsoleto.subscribe(() => obsoletos++);

      await component.guardar();

      const aviso = swal.calls.mostRecent().args[0] as any;
      expect(aviso.icon).toBe('info');
      expect(aviso.text).toContain('Ya no se puede modificar');
      expect(obsoletos).toBe(1);
    });

    it('un error de validación muestra su motivo sin pedir refrescar', async () => {
      spyOn(console, 'error');
      (servicio as any).actualizar = jasmine.createSpy('actualizar').and.rejectWith({ status: 400, error: { error: 'La fecha límite esperada debe ser posterior a la fecha inicial.' } });
      abrirEdicion(original);
      component.form.numeroGuia = 'ML-0001';
      let obsoletos = 0;
      component.obsoleto.subscribe(() => obsoletos++);

      await component.guardar();

      const aviso = swal.calls.mostRecent().args[0] as any;
      expect(aviso.icon).toBe('error');
      expect(aviso.text).toBe('La fecha límite esperada debe ser posterior a la fecha inicial.');
      expect(obsoletos).toBe(0);
    });
  });

  it('Escape y Cancelar cierran sin guardar', () => {
    abrir();
    let cierres = 0;
    component.cerrado.subscribe(() => cierres++);

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    component.cerrar();

    expect(cierres).toBe(2);
    expect(servicio.crear).not.toHaveBeenCalled();
  });
});
