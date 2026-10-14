import { ComponentFixture, TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { Subject, of, throwError } from 'rxjs';
import { ReservasCasetaComponent } from './reservas-caseta.component';
import { ApiService } from '../../../core/services/api.service';
import { ReservaCalendario } from '../../../core/models/reserva.model';
import { fechaEnZona, instanteEnZona } from '../../../core/utils/reservas.util';

const MEXICO = 'America/Mexico_City';
const DIA = 86_400_000;
const salon = { id: 'a1', nombre: 'Salón de usos múltiples', horaApertura: '08:00:00', horaCierre: '22:00:00', zonaHoraria: MEXICO, activo: true };
const alberca = { id: 'a2', nombre: 'Alberca', horaApertura: '09:00:00', horaCierre: '20:00:00', zonaHoraria: MEXICO, activo: true };

const dia = (n: number) => fechaEnZona(Date.now() + n * DIA, MEXICO);
const a = (n: number, hora: string) => instanteEnZona(dia(n), hora, MEXICO);

const evento = (id: string, inicio: string, fin: string, extra: Partial<ReservaCalendario> = {}): ReservaCalendario => ({
  id, areaId: 'a1', areaNombre: 'Salón de usos múltiples', tipo: 'RESERVA', estado: 'APROBADA', inicio, fin,
  titularNombre: 'Residente', titularApellidos: 'Prueba', numeroCasa: 'A-12', ...extra
});

describe('ReservasCasetaComponent', () => {
  let fixture: ComponentFixture<ReservasCasetaComponent>;
  let component: ReservasCasetaComponent;
  let api: jasmine.SpyObj<ApiService>;
  let areas: any[];
  let calendario: ReservaCalendario[];

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const filas = () => Array.from(fixture.nativeElement.querySelectorAll('li') as NodeListOf<HTMLElement>);
  const boton = (nombre: string) =>
    Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.trim() === nombre);
  const consultas = () => api.get.calls.allArgs().filter(c => c[0] === '/api/reservas/calendario').map(c => c[1] as HttpParams);
  const ultima = () => consultas()[consultas().length - 1];

  async function abrir(): Promise<void> {
    fixture = TestBed.createComponent(ReservasCasetaComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    await fixture.whenStable();
    await new Promise(r => setTimeout(r));
    fixture.detectChanges();
  }

  beforeEach(() => {
    areas = [salon, alberca];
    calendario = [];
    api = jasmine.createSpyObj('ApiService', ['get']);
    api.get.and.callFake(((url: string) => {
      if (url.startsWith('/api/areas')) return of({ items: areas, totalCount: areas.length });
      return of({ items: calendario, totalCount: calendario.length });
    }) as any);
    TestBed.configureTestingModule({ imports: [ReservasCasetaComponent], providers: [{ provide: ApiService, useValue: api }] });
  });

  describe('consulta', () => {
    it('abre en "Hoy": pide el día completo de todas las áreas en la zona del condominio', async () => {
      await abrir();

      const p = ultima();
      expect(p.get('from')).toBe(instanteEnZona(dia(0), '00:00', MEXICO));
      expect(p.get('to')).toBe(instanteEnZona(dia(1), '00:00', MEXICO));
      expect(p.has('areaId')).toBeFalse();
      expect(boton('Hoy')!.getAttribute('aria-pressed')).toBe('true');
    });

    it('Mañana, 7 días y 30 días piden su periodo', async () => {
      await abrir();

      boton('Mañana')!.click();
      expect(ultima().get('from')).toBe(instanteEnZona(dia(1), '00:00', MEXICO));
      expect(ultima().get('to')).toBe(instanteEnZona(dia(2), '00:00', MEXICO));

      boton('7 días')!.click();
      expect(ultima().get('from')).toBe(instanteEnZona(dia(0), '00:00', MEXICO));
      expect(ultima().get('to')).toBe(instanteEnZona(dia(7), '00:00', MEXICO));

      boton('30 días')!.click();
      expect(ultima().get('to')).toBe(instanteEnZona(dia(30), '00:00', MEXICO));
    });

    it('elegir un área manda su id', async () => {
      await abrir();

      component.elegirArea('a2');

      expect(ultima().get('areaId')).toBe('a2');
    });

    it('sin áreas lo dice y no consulta el calendario', async () => {
      areas = [];
      await abrir();

      expect(texto()).toContain('El condominio aún no tiene áreas comunes.');
      expect(consultas().length).toBe(0);
    });
  });

  describe('agenda', () => {
    it('muestra horas, área, casa y titular de cada reserva aprobada', async () => {
      calendario = [evento('r1', a(0, '14:00'), a(0, '18:00'))];
      await abrir();

      const fila = filas()[0].textContent!.replace(/\s+/g, ' ');
      expect(fila).toContain('14:00 a 18:00');
      expect(fila).toContain('Salón de usos múltiples');
      expect(fila).toContain('Casa A-12');
      expect(fila).toContain('Residente Prueba');
    });

    it('un bloqueo se muestra como área bloqueada, con su motivo y sin casa', async () => {
      calendario = [evento('b1', a(1, '09:00'), a(1, '10:00'), { tipo: 'BLOQUEO', motivo: 'Mantenimiento de la alberca', numeroCasa: null, titularNombre: null, titularApellidos: null })];
      await abrir();

      const fila = filas()[0].textContent!.replace(/\s+/g, ' ');
      expect(fila).toContain('Área bloqueada: Mantenimiento de la alberca');
      expect(fila).toContain('Bloqueo');
      expect(fila).not.toContain('Casa');
    });

    it('agrupa por día y rotula Hoy y Mañana', async () => {
      calendario = [
        evento('r2', a(1, '10:00'), a(1, '12:00')),
        evento('r1', a(0, '14:00'), a(0, '16:00')),
        evento('r3', a(3, '10:00'), a(3, '12:00'))
      ];
      await abrir();
      boton('7 días')!.click();
      await fixture.whenStable();
      fixture.detectChanges();

      const titulos = Array.from(fixture.nativeElement.querySelectorAll('h3') as NodeListOf<HTMLElement>).map(h => h.textContent!.trim());
      expect(titulos.length).toBe(3);
      expect(titulos[0]).toMatch(/^Hoy · /);
      expect(titulos[1]).toMatch(/^Mañana · /);
      expect(titulos[2]).not.toMatch(/^(Hoy|Mañana)/);
    });

    it('ordena por hora dentro del día', async () => {
      calendario = [evento('tarde', a(0, '18:00'), a(0, '20:00')), evento('mañana', a(0, '09:00'), a(0, '11:00'))];
      await abrir();

      expect(filas()[0].textContent).toContain('09:00 a 11:00');
      expect(filas()[1].textContent).toContain('18:00 a 20:00');
    });

    it('destaca lo que está en curso y atenúa lo que ya terminó', async () => {
      const ahora = Date.now();
      calendario = [
        evento('curso', new Date(ahora - 3_600_000).toISOString(), new Date(ahora + 3_600_000).toISOString()),
        evento('paso', new Date(ahora - 4 * 3_600_000).toISOString(), new Date(ahora - 2 * 3_600_000).toISOString()),
        evento('luego', new Date(ahora + 2 * 3_600_000).toISOString(), new Date(ahora + 4 * 3_600_000).toISOString())
      ];
      await abrir();

      const porId = (texto: string) => filas().find(f => f.textContent!.includes(texto))!;
      expect(component.estado(calendario[0])).toBe('en-curso');
      expect(component.estado(calendario[1])).toBe('terminada');
      expect(component.estado(calendario[2])).toBe('proxima');
      expect(filas().filter(f => f.textContent!.includes('En curso')).length).toBe(1);
      expect(filas().filter(f => f.textContent!.includes('Terminó')).length).toBe(1);
      expect(porId('Terminó').classList.contains('opacity-70')).toBeTrue();
    });

    it('no muestra lo que aún no está aprobado, lo cancelado ni las áreas que ya no están vigentes', async () => {
      calendario = [
        evento('ok', a(0, '10:00'), a(0, '12:00')),
        evento('cancelada', a(0, '13:00'), a(0, '14:00'), { estado: 'CANCELADA' }),
        evento('pendiente', a(0, '15:00'), a(0, '16:00'), { estado: 'PENDIENTE_ADMIN' }),
        evento('de-baja', a(0, '17:00'), a(0, '18:00'), { areaId: 'zzz', areaNombre: 'Área dada de baja' })
      ];
      await abrir();

      expect(filas().length).toBe(1);
      expect(texto()).not.toContain('Área dada de baja');
    });

    it('un horario que cruza la medianoche dice cuándo termina', async () => {
      calendario = [evento('noche', a(0, '21:00'), a(1, '01:00'))];
      await abrir();

      expect(filas()[0].textContent).toMatch(/21:00 a 01:00 \(/);
    });

    it('sin nada reservado dice el periodo que se consultó', async () => {
      await abrir();
      expect(texto()).toContain('Hoy no hay áreas reservadas ni bloqueadas.');

      boton('Mañana')!.click();
      await fixture.whenStable();
      fixture.detectChanges();
      expect(texto()).toContain('Mañana no hay áreas reservadas ni bloqueadas.');
    });
  });

  describe('errores', () => {
    it('si falla la consulta muestra el mensaje y Reintentar la repite', async () => {
      spyOn(console, 'error');
      let falla = true;
      api.get.and.callFake(((url: string) => {
        if (url.startsWith('/api/areas')) return of({ items: areas });
        return falla ? throwError(() => ({ status: 500, error: { error: 'Servicio no disponible' } })) : of({ items: [evento('r1', a(0, '10:00'), a(0, '12:00'))] });
      }) as any);
      await abrir();
      expect(texto()).toContain('Servicio no disponible');

      falla = false;
      boton('Reintentar')!.click();
      await fixture.whenStable();
      fixture.detectChanges();

      expect(texto()).not.toContain('Servicio no disponible');
      expect(filas().length).toBe(1);
    });

    it('oculta el JSON técnico con un mensaje claro', async () => {
      spyOn(console, 'error');
      api.get.and.callFake(((url: string) => (url.startsWith('/api/areas') ? of({ items: areas }) : throwError(() => ({ status: 500, error: { error: 'Error desde Supabase: {"code":"XX000"}' } })))) as any);
      await abrir();

      expect(texto()).toContain('No se pudieron consultar las reservas de las áreas comunes.');
    });

    it('una respuesta lenta de otro periodo no pisa la del periodo elegido después', async () => {
      const lenta = new Subject<any>();
      let llamadas = 0;
      api.get.and.callFake(((url: string) => {
        if (url.startsWith('/api/areas')) return of({ items: areas });
        llamadas++;
        return llamadas === 1 ? of({ items: [] }) : llamadas === 2 ? lenta : of({ items: [evento('nueva', a(1, '10:00'), a(1, '12:00'))] });
      }) as any);
      await abrir();

      component.elegirRango('semana');
      component.elegirRango('manana');
      await fixture.whenStable();
      lenta.next({ items: [evento('vieja', a(0, '10:00'), a(0, '12:00'))] });
      lenta.complete();
      await fixture.whenStable();
      fixture.detectChanges();

      expect(component.items().map(o => o.id)).toEqual(['nueva']);
      expect(component.cargando()).toBeFalse();
    });
  });
});
