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
  const botonGuardar = () => fixture.nativeElement.querySelector('button.bg-\\[\\#111C99\\]') as HTMLButtonElement;

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

  it('las fechas cubren el día completo de inicio y de fin', () => {
    abrir();
    component.form.servicio = 1;
    component.form.desde = component.hoy;
    component.form.hasta = component.hoy;

    const dto = component.armarDto();

    expect(new Date(dto.fechaEsperadaDesde!).getTime()).toBe(new Date(`${component.hoy}T00:00:00`).getTime());
    expect(new Date(dto.fechaEsperadaHasta!).getTime()).toBe(new Date(`${component.hoy}T23:59:59.999`).getTime());
  });

  it('rechaza fechas invertidas o ya pasadas y lo explica', () => {
    abrir();
    component.form.servicio = 1;

    component.form.desde = '2099-02-10';
    component.form.hasta = '2099-02-01';
    fixture.detectChanges();
    expect(component.esFormularioValido()).toBeFalse();
    expect(texto()).toContain('La fecha de inicio no puede ser posterior');

    component.form.desde = '';
    component.form.hasta = '2020-01-01';
    fixture.detectChanges();
    expect(component.esFormularioValido()).toBeFalse();
    expect(texto()).toContain('La última fecha ya pasó');
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
