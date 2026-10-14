import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import Swal from 'sweetalert2';
import { ReservaFormComponent } from './reserva-form.component';
import { ReservasService } from '../../../core/services/reservas.service';
import { AreaComun, Reserva, ReservaCalendario } from '../../../core/models/reserva.model';
import { diasReservables, fechaEnZona, instanteEnZona } from '../../../core/utils/reservas.util';

const MEXICO = 'America/Mexico_City';
const salon: AreaComun = { id: 's1', nombre: 'Salón de usos múltiples', descripcion: 'Para fiestas', horaApertura: '08:00:00', horaCierre: '22:00:00', zonaHoraria: MEXICO, activo: true };
const alberca: AreaComun = { id: 'a1', nombre: 'Alberca', horaApertura: '09:00:00', horaCierre: '20:00:00', zonaHoraria: MEXICO, activo: true };
/** Un día cómodamente dentro de la ventana de 7 a 30 días */
const dia = fechaEnZona(Date.now() + 15 * 86_400_000, MEXICO);

const creada = (estado = 'PENDIENTE_ADMIN'): Reserva => ({
  id: 'nueva', areaId: 's1', areaNombre: 'Salón', tipo: 'RESERVA', estado: estado as Reserva['estado'],
  inicio: instanteEnZona(dia, '10:00', MEXICO), fin: instanteEnZona(dia, '12:00', MEXICO)
});

describe('ReservaFormComponent', () => {
  let fixture: ComponentFixture<ReservaFormComponent>;
  let component: ReservaFormComponent;
  let servicio: { areas: ReturnType<typeof signal<AreaComun[]>>; mias: ReturnType<typeof signal<Reserva[]>>; calendario: jasmine.Spy; solicitar: jasmine.Spy };
  let swal: jasmine.Spy;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const campo = (id: string) => fixture.nativeElement.querySelector('#' + id) as HTMLInputElement | null;
  const boton = (nombre: string) =>
    Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.includes(nombre));

  async function abrir(areas: AreaComun[] = [salon, alberca]): Promise<void> {
    servicio.areas.set(areas);
    fixture = TestBed.createComponent(ReservaFormComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    await fixture.whenStable();
  }

  async function elegirDia(): Promise<void> {
    component.cambiarFecha(dia);
    await fixture.whenStable();
    await new Promise(r => setTimeout(r));
    fixture.detectChanges();
  }

  function poner(inicio: string, fin: string): void {
    component.horaInicio.set(inicio);
    component.horaFin.set(fin);
    fixture.detectChanges();
  }

  beforeEach(() => {
    servicio = {
      areas: signal<AreaComun[]>([]),
      mias: signal<Reserva[]>([]),
      calendario: jasmine.createSpy('calendario').and.resolveTo([]),
      solicitar: jasmine.createSpy('solicitar').and.callFake(async () => creada())
    };
    swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true } as any);
    TestBed.configureTestingModule({ imports: [ReservaFormComponent], providers: [{ provide: ReservasService, useValue: servicio }] });
  });

  it('muestra las áreas con su horario y no pide el día hasta elegir una', async () => {
    await abrir();

    expect(texto()).toContain('Salón de usos múltiples');
    expect(texto()).toContain('Abierta de 08:00 a 22:00');
    expect(texto()).toContain('Alberca');
    expect(campo('res-fecha')).toBeNull();
  });

  it('elegir un área abre el paso del día con los límites de 7 a 30 días', async () => {
    await abrir();

    component.seleccionarArea(salon);
    fixture.detectChanges();

    const limites = diasReservables(Date.now(), MEXICO);
    expect(campo('res-fecha')!.min).toBe(limites.min);
    expect(campo('res-fecha')!.max).toBe(limites.max);
    expect(texto()).toContain('2. Elige el día');
  });

  it('con una sola área la usa sin pedir elegirla', async () => {
    await abrir([salon]);

    expect(component.area()?.id).toBe('s1');
    expect(campo('res-fecha')).not.toBeNull();
  });

  it('al elegir el día consulta el calendario del área para ese día completo en su zona horaria', async () => {
    await abrir();
    component.seleccionarArea(salon);

    await elegirDia();

    const [areaId, desde, hasta] = servicio.calendario.calls.mostRecent().args;
    expect(areaId).toBe('s1');
    expect(desde).toBe(instanteEnZona(dia, '00:00', MEXICO));
    expect(new Date(hasta).getTime() - new Date(desde).getTime()).toBe(86_400_000);
  });

  it('sin nada ocupado avisa que el día está libre', async () => {
    await abrir([salon]);

    await elegirDia();

    expect(texto()).toContain('Ese día el área está libre en todo su horario.');
  });

  it('dibuja lo ocupado y lo lista con sus horas, casa y motivo del bloqueo', async () => {
    const ocupados: ReservaCalendario[] = [
      { id: 'o1', areaId: 's1', areaNombre: 'Salón', tipo: 'RESERVA', estado: 'APROBADA', inicio: instanteEnZona(dia, '10:00', MEXICO), fin: instanteEnZona(dia, '12:00', MEXICO), numeroCasa: 'A-12' },
      { id: 'o2', areaId: 's1', areaNombre: 'Salón', tipo: 'BLOQUEO', estado: 'APROBADA', inicio: instanteEnZona(dia, '15:00', MEXICO), fin: instanteEnZona(dia, '16:00', MEXICO), motivo: 'Mantenimiento' },
      { id: 'o3', areaId: 's1', areaNombre: 'Salón', tipo: 'RESERVA', estado: 'PENDIENTE_ADMIN', inicio: instanteEnZona(dia, '18:00', MEXICO), fin: instanteEnZona(dia, '19:00', MEXICO), numeroCasa: 'B-3' }
    ];
    servicio.calendario.and.resolveTo(ocupados);
    await abrir([salon]);

    await elegirDia();

    expect(component.segmentos().length).toBe(3);
    expect(texto()).toContain('10:00 a 12:00 · Casa A-12');
    expect(texto()).toContain('15:00 a 16:00 · Bloqueado: Mantenimiento');
    expect(texto()).toContain('18:00 a 19:00 · Casa B-3 (por aprobar)');
  });

  it('si no se puede consultar el día lo dice y deja reintentar', async () => {
    spyOn(console, 'error');
    servicio.calendario.and.rejectWith({ status: 500 });
    await abrir([salon]);

    await elegirDia();

    expect(texto()).toContain('No se pudo consultar la disponibilidad de ese día.');
    servicio.calendario.and.resolveTo([]);
    boton('Reintentar')!.click();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(texto()).not.toContain('No se pudo consultar');
  });

  it('una respuesta lenta de otro día no pisa la del día elegido después', async () => {
    let soltarLenta!: (v: ReservaCalendario[]) => void;
    const lenta = new Promise<ReservaCalendario[]>(r => (soltarLenta = r));
    servicio.calendario.and.returnValues(lenta, Promise.resolve([]));
    await abrir([salon]);

    component.cambiarFecha(dia);
    component.cambiarFecha(fechaEnZona(Date.now() + 16 * 86_400_000, MEXICO));
    await new Promise(r => setTimeout(r));
    soltarLenta([{ id: 'x', areaId: 's1', areaNombre: 'S', tipo: 'RESERVA', estado: 'APROBADA', inicio: instanteEnZona(dia, '10:00', MEXICO), fin: instanteEnZona(dia, '12:00', MEXICO) }]);
    await new Promise(r => setTimeout(r));

    expect(component.ocupados()).toEqual([]);
  });

  describe('horario', () => {
    beforeEach(async () => {
      await abrir([salon]);
      await elegirDia();
    });

    it('sin horario completo no marca problema ni deja solicitar', () => {
      poner('10:00', '');

      expect(component.problema()).toBeNull();
      expect(boton('Solicitar reserva')!.disabled).toBeTrue();
    });

    it('un horario válido muestra el resumen y habilita Solicitar', () => {
      poner('10:00', '12:30');

      expect(texto()).toContain('Salón de usos múltiples:');
      expect(texto()).toContain('10:00 a 12:30');
      expect(texto()).toContain('(2 h 30 min)');
      expect(boton('Solicitar reserva')!.disabled).toBeFalse();
    });

    it('explica el problema y bloquea el botón: fuera de horario, muy corta o muy larga', () => {
      poner('06:00', '09:00');
      expect(texto()).toContain('El área opera de 08:00 a 22:00.');
      expect(boton('Solicitar reserva')!.disabled).toBeTrue();

      poner('10:00', '10:15');
      expect(texto()).toContain('al menos 30 minutos');

      poner('08:00', '21:00');
      expect(texto()).toContain('hasta 12 horas');
    });

    it('avisa de un traslape con lo ya ocupado', async () => {
      servicio.calendario.and.resolveTo([{ id: 'o1', areaId: 's1', areaNombre: 'S', tipo: 'RESERVA', estado: 'APROBADA', inicio: instanteEnZona(dia, '11:00', MEXICO), fin: instanteEnZona(dia, '13:00', MEXICO) }]);
      await component.cargarDia();

      poner('10:00', '12:00');

      expect(texto()).toContain('Ese horario ya está ocupado.');
      expect(boton('Solicitar reserva')!.disabled).toBeTrue();
    });

    it('avisa antes de enviar si la vivienda ya tiene una reserva ese día, aunque sea en otra área', () => {
      servicio.mias.set([{ ...creada('PENDIENTE_ADMIN'), id: 'previa', areaId: 'a1', areaNombre: 'Alberca', inicio: instanteEnZona(dia, '16:00', MEXICO), fin: instanteEnZona(dia, '18:00', MEXICO) }]);

      poner('10:00', '12:00');

      expect(texto()).toContain('Tu vivienda ya tiene una reserva ese día (Alberca, 16:00 a 18:00). Solo se permite una por día.');
      expect(boton('Solicitar reserva')!.disabled).toBeTrue();
    });

    it('una reserva cancelada o de otro día no impide reservar', () => {
      servicio.mias.set([
        { ...creada('CANCELADA'), id: 'c', inicio: instanteEnZona(dia, '16:00', MEXICO), fin: instanteEnZona(dia, '18:00', MEXICO) },
        { ...creada('APROBADA'), id: 'o', inicio: instanteEnZona(fechaEnZona(Date.now() + 16 * 86_400_000, MEXICO), '16:00', MEXICO), fin: instanteEnZona(fechaEnZona(Date.now() + 16 * 86_400_000, MEXICO), '18:00', MEXICO) }
      ]);

      poner('10:00', '12:00');

      expect(component.problema()).toBeNull();
      expect(boton('Solicitar reserva')!.disabled).toBeFalse();
    });

    it('dibuja el horario elegido sobre la línea de tiempo', () => {
      poner('08:00', '15:00');

      expect(component.seleccion()!.izquierda).toBeCloseTo(0, 5);
      expect(component.seleccion()!.ancho).toBeCloseTo((7 / 14) * 100, 5);
    });

    it('al solicitar manda los instantes en la zona del área, avisa y se limpia', async () => {
      const emitidas: Reserva[] = [];
      component.solicitada.subscribe(r => emitidas.push(r));
      poner('10:00', '12:00');

      await component.solicitar();

      expect(servicio.solicitar).toHaveBeenCalledOnceWith({ areaId: 's1', inicio: instanteEnZona(dia, '10:00', MEXICO), fin: instanteEnZona(dia, '12:00', MEXICO) });
      expect((swal.calls.mostRecent().args[0] as any).title).toBe('Solicitud enviada al administrador');
      expect(emitidas.map(r => r.id)).toEqual(['nueva']);
      expect(component.horaInicio()).toBe('');
      expect(component.horaFin()).toBe('');
      expect(component.enviando()).toBeFalse();
    });

    it('si la pide un sub-usuario el aviso dice que va primero al titular', async () => {
      servicio.solicitar.and.resolveTo(creada('PENDIENTE_TITULAR'));
      poner('10:00', '12:00');

      await component.solicitar();

      expect((swal.calls.mostRecent().args[0] as any).title).toBe('Solicitud enviada al titular de tu vivienda');
    });

    it('si el backend la rechaza muestra su motivo, no limpia el horario y actualiza el día en un choque', async () => {
      spyOn(console, 'error');
      servicio.solicitar.and.rejectWith({ status: 409, error: { error: 'Ya tienes una reserva para ese día.' } });
      poner('10:00', '12:00');
      servicio.calendario.calls.reset();

      await component.solicitar();

      const aviso = swal.calls.mostRecent().args[0] as any;
      expect(aviso.icon).toBe('error');
      expect(aviso.text).toBe('Ya tienes una reserva para ese día.');
      expect(component.horaInicio()).toBe('10:00');
      expect(servicio.calendario).toHaveBeenCalled();
    });

    it('oculta el JSON técnico del backend con un mensaje claro', async () => {
      spyOn(console, 'error');
      servicio.solicitar.and.rejectWith({ status: 500, error: { error: 'Error desde Supabase: {"code":"XX000"}' } });
      poner('10:00', '12:00');

      await component.solicitar();

      expect((swal.calls.mostRecent().args[0] as any).text).toBe('No fue posible enviar la solicitud. Intenta de nuevo en unos segundos.');
    });

    it('no envía nada si el horario no es válido', async () => {
      poner('06:00', '09:00');

      await component.solicitar();

      expect(servicio.solicitar).not.toHaveBeenCalled();
    });
  });
});
