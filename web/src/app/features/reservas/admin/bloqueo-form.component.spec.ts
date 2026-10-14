import { ComponentFixture, TestBed } from '@angular/core/testing';
import Swal from 'sweetalert2';
import { BloqueoFormComponent } from './bloqueo-form.component';
import { ReservasAdminService } from '../../../core/services/reservas-admin.service';
import { AreaComun, ResultadoBloqueo } from '../../../core/models/reserva.model';
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

  it('advierte que cancela reservas y que el bloqueo no se puede quitar', () => {
    expect(texto()).toContain('Bloquear fechas · Salón de usos múltiples');
    expect(texto()).toContain('Las reservas pendientes o aprobadas que caigan en ese horario se cancelan');
    expect(texto()).toContain('Un bloqueo no se puede quitar después.');
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
    expect(confirmacion.text).toContain('el bloqueo no se podrá quitar');
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

  it('dice cuántas reservas se cancelaron, en singular y plural, o que no había ninguna', async () => {
    llenar();

    servicio.crearBloqueo.and.resolveTo(resultado(2));
    await component.bloquear();
    expect((swal.calls.mostRecent().args[0] as any).text).toBe('Se cancelaron 2 reservas que caían en ese horario.');

    servicio.crearBloqueo.and.resolveTo(resultado(1));
    await component.bloquear();
    expect((swal.calls.mostRecent().args[0] as any).text).toBe('Se cancelaron 1 reserva que caían en ese horario.');

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
