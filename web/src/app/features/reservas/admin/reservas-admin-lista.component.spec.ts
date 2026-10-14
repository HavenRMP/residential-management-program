import { ComponentFixture, TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import Swal from 'sweetalert2';
import { fechaEnZona, instanteEnZona } from '../../../core/utils/reservas.util';
import { ReservasAdminListaComponent } from './reservas-admin-lista.component';
import { ApiService } from '../../../core/services/api.service';
import { ReservasAdminService } from '../../../core/services/reservas-admin.service';
import { Reserva } from '../../../core/models/reserva.model';

const DIA = 86_400_000;
/** Mediodía en la zona del área, a tantos días de hoy: así el horario mostrado no depende de la hora a la que corre la prueba */
const mediodia = (enDias: number) => instanteEnZona(fechaEnZona(Date.now() + enDias * DIA, 'America/Mexico_City'), '12:00', 'America/Mexico_City');
const masHoras = (iso: string, horas: number) => new Date(new Date(iso).getTime() + horas * 3_600_000).toISOString();
const area = { id: 'a1', nombre: 'Salón de usos múltiples', horaApertura: '08:00:00', horaCierre: '22:00:00', zonaHoraria: 'America/Mexico_City', activo: true };

const reserva = (id: string, estado: string, inicioEnDias: number, extra: Partial<Reserva> = {}): Reserva => ({
  id, areaId: 'a1', areaNombre: 'Salón de usos múltiples', tipo: 'RESERVA', estado: estado as Reserva['estado'],
  inicio: mediodia(inicioEnDias), fin: masHoras(mediodia(inicioEnDias), 2),
  titularId: 't1', titularNombre: 'Residente', titularApellidos: 'Prueba', numeroCasa: 'A-12',
  solicitanteId: 't1', solicitanteNombre: 'Residente', solicitanteApellidos: 'Prueba', ...extra
});

describe('ReservasAdminListaComponent', () => {
  let fixture: ComponentFixture<ReservasAdminListaComponent>;
  let component: ReservasAdminListaComponent;
  let api: jasmine.SpyObj<ApiService>;
  let swal: jasmine.Spy;
  let items: Reserva[];
  let total: number;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const filas = () => Array.from(fixture.nativeElement.querySelectorAll('tbody tr') as NodeListOf<HTMLElement>);
  const boton = (nombre: string, dentro: ParentNode = fixture.nativeElement) =>
    Array.from(dentro.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.trim().startsWith(nombre));
  const ultimaConsulta = () => api.get.calls.allArgs().filter(a => a[0] === '/api/admin/reservas').pop()![1] as HttpParams;

  async function abrir(): Promise<void> {
    fixture = TestBed.createComponent(ReservasAdminListaComponent);
    component = fixture.componentInstance;
    TestBed.inject(ReservasAdminService).areas.set([area]);
    fixture.detectChanges();
    await fixture.whenStable();
    await new Promise(r => setTimeout(r));
    fixture.detectChanges();
  }

  beforeEach(() => {
    items = [];
    total = 0;
    api = jasmine.createSpyObj('ApiService', ['get', 'post']);
    api.get.and.callFake((() => of({ items, totalCount: total || items.length })) as any);
    api.post.and.returnValue(of(null));
    swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true, value: 'Motivo de prueba' } as any);
    TestBed.configureTestingModule({ imports: [ReservasAdminListaComponent], providers: [{ provide: ApiService, useValue: api }] });
  });

  describe('listado', () => {
    it('abre con lo que espera aprobación del administrador', async () => {
      await abrir();

      expect(ultimaConsulta().get('estado')).toBe('PENDIENTE_ADMIN');
      expect(ultimaConsulta().get('page')).toBe('1');
    });

    it('muestra área, horario, vivienda, titular, quien solicitó y estado', async () => {
      items = [reserva('r1', 'PENDIENTE_TITULAR', 10, { solicitanteId: 's1', solicitanteNombre: 'Luis', solicitanteApellidos: 'Prueba' })];
      await abrir();

      const fila = filas()[0].textContent!.replace(/\s+/g, ' ');
      expect(fila).toContain('Salón de usos múltiples');
      expect(fila).toMatch(/\d{1,2}:\d{2} a \d{1,2}:\d{2}/);
      expect(fila).toContain('A-12');
      expect(fila).toContain('Titular: Residente Prueba');
      expect(fila).toContain('Luis Prueba');
      expect(fila).toContain('Espera al titular');
    });

    it('señala las inasistencias previas del titular y de quien solicita', async () => {
      items = [reserva('r1', 'PENDIENTE_ADMIN', 10, { noShowsTitular: 2, solicitanteId: 's1', noShowsSolicitante: 1 })];
      await abrir();

      expect(texto()).toContain('2 inasistencia(s) del titular');
      expect(texto()).toContain('1 inasistencia(s)');
    });

    it('un bloqueo se distingue, muestra su motivo y no ofrece acciones', async () => {
      items = [reserva('b1', 'APROBADA', 10, { tipo: 'BLOQUEO', motivo: 'Mantenimiento de la alberca', titularNombre: null, numeroCasa: null })];
      await abrir();

      expect(filas()[0].textContent).toContain('Bloqueo');
      expect(filas()[0].textContent).toContain('Mantenimiento de la alberca');
      expect(filas()[0].textContent).toContain('Un bloqueo no se puede quitar desde aquí');
      expect(boton('Aprobar', filas()[0])).toBeUndefined();
      expect(boton('Cancelar', filas()[0])).toBeUndefined();
    });

    it('una reserva aprobada y confirmada lo dice', async () => {
      items = [reserva('r1', 'APROBADA', 10, { confirmadaEn: new Date().toISOString() })];
      await abrir();

      expect(filas()[0].textContent).toContain('Confirmada');
      expect(filas()[0].textContent).toContain('Asistencia confirmada');
    });

    it('sin solicitudes por aprobar lo dice con claridad y con otros filtros dice que no hay reservas', async () => {
      await abrir();
      expect(texto()).toContain('No hay solicitudes por aprobar.');

      component.estado = 'CANCELADA';
      await component.buscar();
      fixture.detectChanges();
      expect(texto()).toContain('No hay reservas con estos filtros.');
    });

    it('si falla la carga muestra el error y Reintentar vuelve a pedir la misma página', async () => {
      spyOn(console, 'error');
      api.get.and.returnValue(throwError(() => ({ status: 500, error: { error: 'Servicio no disponible' } })));
      await abrir();
      expect(texto()).toContain('Servicio no disponible');

      api.get.and.callFake((() => of({ items: [reserva('r1', 'PENDIENTE_ADMIN', 10)], totalCount: 1 })) as any);
      boton('Reintentar')!.click();
      await fixture.whenStable();
      fixture.detectChanges();

      expect(texto()).not.toContain('Servicio no disponible');
      expect(filas().length).toBe(1);
    });
  });

  describe('filtros y páginas', () => {
    it('Buscar manda estado, área y el rango de fechas del día completo', async () => {
      await abrir();
      component.estado = 'APROBADA';
      component.areaId = 'a1';
      component.desde = '2026-10-20';
      component.hasta = '2026-10-22';

      await component.buscar();

      const p = ultimaConsulta();
      expect(p.get('estado')).toBe('APROBADA');
      expect(p.get('areaId')).toBe('a1');
      expect(new Date(p.get('from')!).getTime()).toBe(new Date('2026-10-20T00:00:00').getTime());
      expect(new Date(p.get('to')!).getTime()).toBe(new Date('2026-10-22T23:59:59.999').getTime());
    });

    it('"Todas" no manda estado y Limpiar vuelve a lo que espera aprobación', async () => {
      await abrir();
      component.estado = '';
      await component.buscar();
      expect(ultimaConsulta().has('estado')).toBeFalse();

      await component.limpiar();
      expect(ultimaConsulta().get('estado')).toBe('PENDIENTE_ADMIN');
      expect(component.areaId).toBe('');
    });

    it('un rango de fechas invertido avisa y no busca', async () => {
      await abrir();
      api.get.calls.reset();
      component.desde = '2026-10-22';
      component.hasta = '2026-10-20';
      fixture.detectChanges();

      await component.buscar();

      expect(texto()).toContain('no puede ser posterior');
      expect(api.get).not.toHaveBeenCalled();
    });

    it('con varias páginas muestra el total y pagina con los filtros de la última búsqueda, no con lo que se está escribiendo', async () => {
      items = Array.from({ length: 20 }, (_, i) => reserva(`r${i}`, 'PENDIENTE_ADMIN', 10 + i));
      total = 45;
      await abrir();
      expect(texto()).toContain('Página 1 de 3 · 45 en total');

      component.estado = 'CANCELADA'; // escrito pero sin pulsar Buscar
      await component.irAPagina(2);

      expect(ultimaConsulta().get('page')).toBe('2');
      expect(ultimaConsulta().get('estado')).toBe('PENDIENTE_ADMIN');
    });
  });

  describe('acciones', () => {
    it('lo pendiente ofrece Aprobar y Rechazar; lo aprobado por venir, Cancelar; lo aprobado ya terminado, No utilizada', async () => {
      items = [reserva('p', 'PENDIENTE_ADMIN', 10), reserva('f', 'APROBADA', 10), reserva('t', 'APROBADA', -3)];
      await abrir();

      expect(boton('Aprobar', filas()[0])).toBeDefined();
      expect(boton('Rechazar', filas()[0])).toBeDefined();
      expect(boton('Cancelar', filas()[0])).toBeUndefined();
      expect(boton('Cancelar', filas()[1])).toBeDefined();
      expect(boton('Aprobar', filas()[1])).toBeUndefined();
      expect(boton('No utilizada', filas()[2])).toBeDefined();
      expect(boton('Cancelar', filas()[2])).toBeUndefined();
    });

    it('lo que espera al titular solo se puede rechazar', async () => {
      items = [reserva('p', 'PENDIENTE_TITULAR', 10)];
      await abrir();

      expect(boton('Rechazar', filas()[0])).toBeDefined();
      expect(boton('Aprobar', filas()[0])).toBeUndefined();
    });

    it('aprobar pide confirmación, la aprueba y actualiza la lista', async () => {
      items = [reserva('r1', 'PENDIENTE_ADMIN', 10)];
      await abrir();
      api.get.calls.reset();

      await component.aprobar(items[0]);

      expect(api.post).toHaveBeenCalledWith('/api/admin/reservas/r1/aprobar', {}, undefined, 'reservas');
      expect(api.get).toHaveBeenCalled();
      expect((swal.calls.mostRecent().args[0] as any).title).toBe('Reserva aprobada');
    });

    it('si se arrepiente al aprobar no se envía nada', async () => {
      items = [reserva('r1', 'PENDIENTE_ADMIN', 10)];
      await abrir();
      swal.and.resolveTo({ isConfirmed: false } as any);

      await component.aprobar(items[0]);

      expect(api.post).not.toHaveBeenCalled();
    });

    it('rechazar exige un motivo y lo manda', async () => {
      items = [reserva('r1', 'PENDIENTE_ADMIN', 10)];
      await abrir();
      swal.and.resolveTo({ isConfirmed: true, value: '  Evento del condominio ' } as any);

      await component.rechazar(items[0]);

      const dialogo = swal.calls.argsFor(swal.calls.count() - 2)[0] as any;
      expect(dialogo.input).toBe('textarea');
      expect(dialogo.inputValidator('   ')).toBe('Escribe el motivo.');
      expect(dialogo.inputValidator('Un motivo')).toBeUndefined();
      expect(api.post).toHaveBeenCalledWith('/api/admin/reservas/r1/rechazar', { motivo: 'Evento del condominio' }, undefined, 'reservas');
    });

    it('un motivo vacío o cancelar el diálogo no envía nada', async () => {
      items = [reserva('r1', 'PENDIENTE_ADMIN', 10)];
      await abrir();

      swal.and.resolveTo({ isConfirmed: true, value: '   ' } as any);
      await component.rechazar(items[0]);
      swal.and.resolveTo({ isConfirmed: false } as any);
      await component.cancelar(reserva('r2', 'APROBADA', 10));

      expect(api.post).not.toHaveBeenCalled();
    });

    it('cancelar una aprobada manda el motivo', async () => {
      items = [reserva('r2', 'APROBADA', 10)];
      await abrir();
      swal.and.resolveTo({ isConfirmed: true, value: 'Contingencia climática' } as any);

      await component.cancelar(items[0]);

      expect(api.post).toHaveBeenCalledWith('/api/admin/reservas/r2/cancelar', { motivo: 'Contingencia climática' }, undefined, 'reservas');
    });

    it('marcar como no utilizada advierte de las inasistencias y la envía', async () => {
      items = [reserva('r3', 'APROBADA', -3)];
      await abrir();

      await component.marcarNoUtilizada(items[0]);

      expect((swal.calls.argsFor(swal.calls.count() - 2)[0] as any).text).toContain('inasistencia');
      expect(api.post).toHaveBeenCalledWith('/api/admin/reservas/r3/no-utilizada', {}, undefined, 'reservas');
    });

    it('si ya la resolvió otra persona (409) lo explica con el mensaje del backend y actualiza la lista', async () => {
      spyOn(console, 'error');
      items = [reserva('r1', 'PENDIENTE_ADMIN', 10)];
      await abrir();
      api.post.and.returnValue(throwError(() => ({ status: 409, error: { error: 'El estado de la reserva no permite esta operación.' } })));
      api.get.calls.reset();

      await component.aprobar(items[0]);

      const aviso = swal.calls.mostRecent().args[0] as any;
      expect(aviso.icon).toBe('info');
      expect(aviso.text).toBe('El estado de la reserva no permite esta operación.');
      expect(api.get).toHaveBeenCalled();
    });

    it('un error de validación (400) se muestra como error sin dar la reserva por cambiada', async () => {
      spyOn(console, 'error');
      items = [reserva('r1', 'PENDIENTE_ADMIN', 10)];
      await abrir();
      swal.and.resolveTo({ isConfirmed: true, value: 'x' } as any);
      api.post.and.returnValue(throwError(() => ({ status: 400, error: { errors: { Motivo: ['El motivo es obligatorio'] } } })));
      api.get.calls.reset();

      await component.rechazar(items[0]);

      const aviso = swal.calls.mostRecent().args[0] as any;
      expect(aviso.icon).toBe('error');
      expect(aviso.text).toBe('El motivo es obligatorio');
      expect(api.get).not.toHaveBeenCalled();
    });

    it('oculta el JSON técnico con un mensaje claro', async () => {
      spyOn(console, 'error');
      items = [reserva('r1', 'PENDIENTE_ADMIN', 10)];
      await abrir();
      api.post.and.returnValue(throwError(() => ({ status: 500, error: { error: 'Error desde Supabase: {"code":"XX000"}' } })));

      await component.aprobar(items[0]);

      expect((swal.calls.mostRecent().args[0] as any).text).toBe('No fue posible completar la acción. Intenta de nuevo en unos segundos.');
    });
  });
});
