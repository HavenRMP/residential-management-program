import { ComponentFixture, TestBed } from '@angular/core/testing';
import Swal from 'sweetalert2';
import { BloqueoFormComponent } from './bloqueo-form.component';
import { ReservasAdminService } from '../../../core/services/reservas-admin.service';
import { AreaComun, Reserva, ResultadoBloqueo } from '../../../core/models/reserva.model';
import { fechaEnZona, instanteEnZona } from '../../../core/utils/reservas.util';

const MEXICO = 'America/Mexico_City';
const salon: AreaComun = { id: 's1', nombre: 'Salón de usos múltiples', horaApertura: '08:00:00', horaCierre: '22:00:00', zonaHoraria: MEXICO, activo: true };
const enDias = (n: number) => fechaEnZona(Date.now() + n * 86_400_000, MEXICO);

describe('BloqueoFormComponent', () => {
  let fixture: ComponentFixture<BloqueoFormComponent>;
  let component: BloqueoFormComponent;
  let servicio: { crearBloqueo: jasmine.Spy };
  let swal: jasmine.Spy;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const botonBloquear = () =>
    Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => /Bloquear área|Bloqueando/.test(b.textContent!))!;

  const resultado = (reservasAfectadas: number): ResultadoBloqueo => ({ bloqueoId: 'b1', areaId: 's1', inicio: 'i', fin: 'f', motivo: 'Mantenimiento', reservasAfectadas });

  function llenar(extra: Partial<typeof component.form> = {}): void {
    component.form = { fechaInicio: enDias(20), horaInicio: '09:00', fechaFin: enDias(20), horaFin: '13:00', motivo: 'Mantenimiento', ...extra };
    fixture.detectChanges();
  }

  beforeEach(() => {
    servicio = { crearBloqueo: jasmine.createSpy('crearBloqueo').and.resolveTo(resultado(0)) };
    swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true } as any);
    TestBed.configureTestingModule({ imports: [BloqueoFormComponent], providers: [{ provide: ReservasAdminService, useValue: servicio }] });
    fixture = TestBed.createComponent(BloqueoFormComponent);
    component = fixture.componentInstance;
    fixture.componentRef.setInput('area', salon);
    fixture.detectChanges();
  });

  it('advierte que cancela reservas y que el bloqueo se puede editar o quitar después', () => {
    expect(texto()).toContain('Bloquear fechas · Salón de usos múltiples');
    expect(texto()).toContain('Las reservas pendientes o aprobadas que caigan en ese horario se cierran');
    expect(texto()).toContain('se rechazan las pendientes y se cancelan las aprobadas');
    expect(texto()).toContain('Podrás editarlo o quitarlo después desde la lista de reservas.');
    expect(texto()).not.toContain('no se puede quitar');
  });

  it('no deja bloquear hasta llenar fechas, horas y motivo', () => {
    expect(component.esValido()).toBeFalse();
    expect(botonBloquear().disabled).toBeTrue();

    llenar({ motivo: '   ' });
    expect(component.esValido()).toBeFalse();

    llenar();
    expect(component.esValido()).toBeTrue();
    expect(botonBloquear().disabled).toBeFalse();
  });

  it('un fin anterior o igual al inicio se avisa', () => {
    llenar({ horaFin: '09:00' });
    expect(texto()).toContain('El fin del bloqueo debe ser posterior al inicio.');
    expect(component.esValido()).toBeFalse();

    llenar({ fechaFin: enDias(19) });
    expect(component.problema()).toContain('posterior');
  });

  it('un bloqueo que ya terminó se avisa', () => {
    llenar({ fechaInicio: enDias(-3), fechaFin: enDias(-2) });

    expect(texto()).toContain('El bloqueo ya terminó: elige fechas futuras.');
    expect(component.esValido()).toBeFalse();
  });

  it('con un rango válido muestra cuándo quedará bloqueada', () => {
    llenar();

    expect(texto()).toContain('Quedará bloqueada');
    expect(texto()).toContain('09:00 a 13:00');
  });

  it('respeta el largo máximo del motivo', () => {
    llenar({ motivo: 'm'.repeat(501) });
    expect(component.esValido()).toBeFalse();
    llenar({ motivo: 'm'.repeat(500) });
    expect(component.esValido()).toBeTrue();
  });

  it('pide confirmar y, si se confirma, manda los instantes en la zona del área con el motivo', async () => {
    llenar({ motivo: '  Mantenimiento de la alberca ' });
    const creados: ResultadoBloqueo[] = [];
    component.creado.subscribe(r => creados.push(r));

    await component.bloquear();

    const confirmacion = swal.calls.argsFor(0)[0] as any;
    expect(confirmacion.text).toContain('se rechazarán o cancelarán');
    expect(confirmacion.text).not.toContain('no se podrá quitar');
    expect(servicio.crearBloqueo).toHaveBeenCalledOnceWith({
      areaId: 's1',
      inicio: instanteEnZona(enDias(20), '09:00', MEXICO),
      fin: instanteEnZona(enDias(20), '13:00', MEXICO),
      motivo: '  Mantenimiento de la alberca '
    });
    expect(creados.length).toBe(1);
    expect(component.isSaving()).toBeFalse();
  });

  it('si se arrepiente en la confirmación no se crea nada', async () => {
    llenar();
    swal.and.resolveTo({ isConfirmed: false } as any);

    await component.bloquear();

    expect(servicio.crearBloqueo).not.toHaveBeenCalled();
  });

  it('dice cuántas reservas quedaron rechazadas o canceladas, en singular y plural, o que no había ninguna', async () => {
    llenar();

    servicio.crearBloqueo.and.resolveTo(resultado(2));
    await component.bloquear();
    expect((swal.calls.mostRecent().args[0] as any).text).toBe('2 reservas que caían en ese horario quedaron rechazadas o canceladas.');

    servicio.crearBloqueo.and.resolveTo(resultado(1));
    await component.bloquear();
    expect((swal.calls.mostRecent().args[0] as any).text).toBe('Una reserva que caía en ese horario quedó rechazada o cancelada.');

    servicio.crearBloqueo.and.resolveTo(resultado(0));
    await component.bloquear();
    expect((swal.calls.mostRecent().args[0] as any).text).toBe('No había reservas en ese horario.');
  });

  it('si el backend falla muestra su motivo y no avisa que se creó', async () => {
    spyOn(console, 'error');
    servicio.crearBloqueo.and.rejectWith({ status: 400, error: { errors: { Motivo: ['El motivo es obligatorio'] } } });
    llenar();
    const creados: ResultadoBloqueo[] = [];
    component.creado.subscribe(r => creados.push(r));

    await component.bloquear();

    const aviso = swal.calls.mostRecent().args[0] as any;
    expect(aviso.icon).toBe('error');
    expect(aviso.text).toBe('El motivo es obligatorio');
    expect(creados).toEqual([]);
  });

  it('no manda nada si el formulario no es válido; Escape cierra', async () => {
    let cierres = 0;
    component.cerrado.subscribe(() => cierres++);

    await component.bloquear();
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(servicio.crearBloqueo).not.toHaveBeenCalled();
    expect(cierres).toBe(1);
  });
});

describe('BloqueoFormComponent: editar un bloqueo', () => {
  let fixture: ComponentFixture<BloqueoFormComponent>;
  let component: BloqueoFormComponent;
  let servicio: { actualizarBloqueo: jasmine.Spy };
  let swal: jasmine.Spy;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const botonGuardar = () =>
    Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => /Guardar cambios|Guardando/.test(b.textContent!))!;
  const campo = (id: string) => fixture.nativeElement.querySelector('#' + id) as HTMLInputElement | HTMLTextAreaElement;

  const bloqueo = (extra: Partial<Reserva> = {}): Reserva => ({
    id: 'b1', areaId: 's1', areaNombre: salon.nombre, tipo: 'BLOQUEO', estado: 'APROBADA',
    inicio: instanteEnZona(enDias(20), '09:00', MEXICO), fin: instanteEnZona(enDias(20), '13:00', MEXICO), motivo: 'Mantenimiento', ...extra
  });
  const resultado = (reservasAfectadas: number): ResultadoBloqueo => ({ bloqueoId: 'b1', areaId: 's1', inicio: 'i', fin: 'f', motivo: 'M', reservasAfectadas });

  function abrir(b: Reserva = bloqueo()): void {
    fixture = TestBed.createComponent(BloqueoFormComponent);
    component = fixture.componentInstance;
    fixture.componentRef.setInput('area', salon);
    fixture.componentRef.setInput('bloqueo', b);
    fixture.detectChanges();
  }

  beforeEach(() => {
    servicio = { actualizarBloqueo: jasmine.createSpy('actualizarBloqueo').and.resolveTo(resultado(0)) };
    swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true } as any);
    TestBed.configureTestingModule({ imports: [BloqueoFormComponent], providers: [{ provide: ReservasAdminService, useValue: servicio }] });
  });

  it('abre con los datos del bloqueo en la zona del área y no deja guardar sin cambios', async () => {
    abrir();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(texto()).toContain('Editar bloqueo · Salón de usos múltiples');
    expect(campo('blq-fecha-inicio').value).toBe(enDias(20));
    expect(campo('blq-hora-inicio').value).toBe('09:00');
    expect(campo('blq-hora-fin').value).toBe('13:00');
    expect(campo('blq-motivo').value).toBe('Mantenimiento');
    expect(botonGuardar().textContent).toContain('Guardar cambios');
    expect(botonGuardar().disabled).toBeTrue();
    expect(component.cambios()).toBeNull();
  });

  it('explica que cambiar el horario puede cerrar otras reservas', () => {
    abrir();
    expect(texto()).toContain('Esto también aplica si cambias el horario');
    expect(texto()).not.toContain('Podrás editarlo o quitarlo después');
  });

  it('un bloqueo en curso (ya empezó, aún no termina) se puede editar: el inicio pasado no es un problema', () => {
    abrir(bloqueo({ inicio: instanteEnZona(enDias(-1), '09:00', MEXICO), fin: instanteEnZona(enDias(2), '13:00', MEXICO) }));

    component.form.motivo = 'Mantenimiento extendido';

    expect(component.problema()).toBeNull();
    expect(component.esValido()).toBeTrue();
  });

  it('cambiar solo el motivo manda solo el motivo y no pide confirmar', async () => {
    abrir();
    component.form.motivo = '  Mantenimiento de la alberca ';
    const guardados: ResultadoBloqueo[] = [];
    component.actualizado.subscribe(r => guardados.push(r));

    await component.actualizar();

    expect(servicio.actualizarBloqueo).toHaveBeenCalledOnceWith('b1', { motivo: 'Mantenimiento de la alberca' });
    expect(swal.calls.count()).toBe(1);
    expect((swal.calls.mostRecent().args[0] as any).title).toBe('Bloqueo actualizado');
    expect(guardados.length).toBe(1);
    expect(component.isSaving()).toBeFalse();
  });

  it('cambiar el horario pide confirmar, manda solo lo que cambió y dice cuántas reservas se cerraron', async () => {
    abrir();
    component.form.horaFin = '15:00';
    servicio.actualizarBloqueo.and.resolveTo(resultado(2));

    await component.actualizar();

    const confirmacion = swal.calls.argsFor(0)[0] as any;
    expect(confirmacion.title).toBe('¿Cambiar el horario del bloqueo?');
    expect(servicio.actualizarBloqueo).toHaveBeenCalledOnceWith('b1', { fin: instanteEnZona(enDias(20), '15:00', MEXICO) });
    expect((swal.calls.mostRecent().args[0] as any).text).toBe('2 reservas que caen en el nuevo horario quedaron rechazadas o canceladas.');
  });

  it('si se arrepiente al confirmar el horario no se guarda nada', async () => {
    abrir();
    component.form.horaFin = '15:00';
    swal.and.resolveTo({ isConfirmed: false } as any);

    await component.actualizar();

    expect(servicio.actualizarBloqueo).not.toHaveBeenCalled();
  });

  it('un fin anterior al inicio o un bloqueo que ya terminó no se pueden guardar', () => {
    abrir();
    component.form.horaFin = '08:00';
    expect(component.esValido()).toBeFalse();
    expect(component.problema()).toContain('posterior');

    component.form = { fechaInicio: enDias(-3), horaInicio: '09:00', fechaFin: enDias(-2), horaFin: '13:00', motivo: 'Mantenimiento' };
    expect(component.problema()).toContain('ya terminó');
    expect(component.esValido()).toBeFalse();
  });

  it('si el bloqueo ya no existe avisa con claridad y pide refrescar la lista', async () => {
    spyOn(console, 'error');
    abrir();
    component.form.motivo = 'Otro motivo';
    servicio.actualizarBloqueo.and.rejectWith({ status: 404, error: { error: 'Bloqueo no encontrado' } });
    const obsoletos = jasmine.createSpy('obsoleto');
    component.obsoleto.subscribe(obsoletos);

    await component.actualizar();

    expect((swal.calls.mostRecent().args[0] as any).title).toBe('Este bloqueo ya cambió');
    expect(obsoletos).toHaveBeenCalledTimes(1);
  });

  it('si el backend rechaza el cambio muestra su mensaje y no lo da por guardado', async () => {
    spyOn(console, 'error');
    abrir();
    component.form.motivo = 'Otro motivo';
    servicio.actualizarBloqueo.and.rejectWith({ status: 400, error: { error: 'No se pudo actualizar el bloqueo' } });
    const guardados = jasmine.createSpy('actualizado');
    component.actualizado.subscribe(guardados);

    await component.actualizar();

    const aviso = swal.calls.mostRecent().args[0] as any;
    expect(aviso.icon).toBe('error');
    expect(aviso.text).toBe('No se pudo actualizar el bloqueo');
    expect(guardados).not.toHaveBeenCalled();
    expect(component.isSaving()).toBeFalse();
  });

  it('un error técnico de Supabase se reemplaza por un mensaje claro', async () => {
    spyOn(console, 'error');
    abrir();
    component.form.motivo = 'Otro motivo';
    servicio.actualizarBloqueo.and.rejectWith({ status: 500, error: { error: 'Error desde Supabase: {"code":"XX000"}' } });

    await component.actualizar();

    expect((swal.calls.mostRecent().args[0] as any).text).toBe('No fue posible guardar los cambios. Intenta de nuevo en unos segundos.');
  });
});

