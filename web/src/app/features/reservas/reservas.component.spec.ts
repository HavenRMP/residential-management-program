import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { By } from '@angular/platform-browser';
import { signal } from '@angular/core';
import { of, throwError } from 'rxjs';
import Swal from 'sweetalert2';
import { fechaEnZona, instanteEnZona } from '../../core/utils/reservas.util';
import { ReservasComponent } from './reservas.component';
import { ReservaFormComponent } from './reserva-form/reserva-form.component';
import { ApiService } from '../../core/services/api.service';
import { AuthService } from '../../core/services/auth.service';
import { ViviendasService } from '../../core/services/viviendas.service';
import { PendienteTitular, Reserva } from '../../core/models/reserva.model';

const DIA = 86_400_000;
/** Mediodía en la zona del área, a tantos días de hoy: así el horario mostrado no depende de la hora a la que corre la prueba */
const mediodia = (enDias: number) => instanteEnZona(fechaEnZona(Date.now() + enDias * DIA, 'America/Mexico_City'), '12:00', 'America/Mexico_City');
const masHoras = (iso: string, horas: number) => new Date(new Date(iso).getTime() + horas * 3_600_000).toISOString();
const area = { id: 'a1', nombre: 'Salón de usos múltiples', horaApertura: '08:00:00', horaCierre: '22:00:00', zonaHoraria: 'America/Mexico_City', activo: true };

const reserva = (id: string, estado: string, inicioEnDias: number, extra: Partial<Reserva> = {}): Reserva => ({
  id, areaId: 'a1', areaNombre: 'Salón de usos múltiples', tipo: 'RESERVA', estado: estado as Reserva['estado'],
  inicio: mediodia(inicioEnDias), fin: masHoras(mediodia(inicioEnDias), 2),
  solicitanteId: 'u1', solicitanteNombre: 'Angel', solicitanteApellidos: 'Gómez', numeroCasa: 'A-12', ...extra
});

const pendiente: PendienteTitular = {
  id: 'p1', areaId: 'a1', areaNombre: 'Salón de usos múltiples', inicio: mediodia(10), fin: masHoras(mediodia(10), 2),
  viviendaId: 1, numeroCasa: 'A-12', solicitanteId: 's1', solicitanteNombre: 'Luis', solicitanteApellidos: 'Prueba', solicitanteEmail: 'luis@example.com', parentesco: 'Familiar'
};

describe('ReservasComponent', () => {
  let fixture: ComponentFixture<ReservasComponent>;
  let component: ReservasComponent;
  let api: jasmine.SpyObj<ApiService>;
  let viviendas: { obtenerMisViviendas: jasmine.Spy };
  let swal: jasmine.Spy;
  let datos: { areas: any[]; mias: Reserva[]; pendientes: PendienteTitular[] };

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const tarjetas = () => Array.from(fixture.nativeElement.querySelectorAll('ul li') as NodeListOf<HTMLElement>);
  const boton = (nombre: string) =>
    Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.trim().startsWith(nombre));

  async function abrir(): Promise<void> {
    fixture = TestBed.createComponent(ReservasComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    await fixture.whenStable();
    await new Promise(r => setTimeout(r));
    fixture.detectChanges();
  }

  async function irAMias(): Promise<void> {
    boton('Mis reservas')!.click();
    fixture.detectChanges();
  }

  beforeEach(() => {
    datos = { areas: [area], mias: [], pendientes: [] };
    api = jasmine.createSpyObj('ApiService', ['get', 'post']);
    api.get.and.callFake(((url: string) => {
      if (url.startsWith('/api/areas')) return of({ items: datos.areas, totalCount: datos.areas.length });
      if (url.startsWith('/api/reservas/mias')) return of({ items: datos.mias, totalCount: datos.mias.length });
      if (url.startsWith('/api/reservas/por-aprobar-titular')) return of({ items: datos.pendientes, totalCount: datos.pendientes.length });
      return of({ items: [] });
    }) as any);
    api.post.and.returnValue(of(null));
    viviendas = { obtenerMisViviendas: jasmine.createSpy('obtenerMisViviendas').and.resolveTo([{ id: 33, numeroCasa: 'A-12' }]) };
    swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true, value: '' } as any);
    TestBed.configureTestingModule({
      imports: [ReservasComponent],
      providers: [
        provideRouter([]),
        { provide: ApiService, useValue: api },
        { provide: ViviendasService, useValue: viviendas },
        { provide: AuthService, useValue: { currentUser: signal({ id: 'u1', nombre: 'Angel', rol: 'residente' }), logout: () => undefined } }
      ]
    });
  });

  describe('reservar', () => {
    it('abre en "Reservar" con el formulario cuando hay áreas', async () => {
      await abrir();

      expect(fixture.debugElement.query(By.directive(ReservaFormComponent))).not.toBeNull();
      expect(texto()).toContain('1. Elige el área');
    });

    it('sin áreas explica que el administrador debe darlas de alta', async () => {
      datos.areas = [];
      await abrir();

      expect(fixture.debugElement.query(By.directive(ReservaFormComponent))).toBeNull();
      expect(texto()).toContain('Tu condominio aún no tiene áreas comunes para reservar.');
    });

    it('si no cargan las áreas muestra el error y deja reintentar', async () => {
      spyOn(console, 'error');
      api.get.and.callFake(((url: string) => (url.startsWith('/api/areas') ? throwError(() => ({ status: 500, error: { error: 'Servicio no disponible' } })) : of({ items: [] }))) as any);
      await abrir();
      expect(texto()).toContain('Servicio no disponible');

      api.get.and.callFake((() => of({ items: [area], totalCount: 1 })) as any);
      boton('Reintentar')!.click();
      await fixture.whenStable();
      fixture.detectChanges();

      expect(texto()).not.toContain('Servicio no disponible');
      expect(fixture.debugElement.query(By.directive(ReservaFormComponent))).not.toBeNull();
    });

    it('sin vivienda pide una y no consulta nada', async () => {
      viviendas.obtenerMisViviendas.and.resolveTo([]);
      await abrir();

      expect(texto()).toContain('Necesitas una vivienda asignada');
      expect(api.get).not.toHaveBeenCalled();
    });

    it('al solicitar una reserva pasa a "Mis reservas"', async () => {
      await abrir();

      component.alSolicitar();
      fixture.detectChanges();

      expect(component.pestana()).toBe('mias');
      expect(texto()).toContain('Próximas');
    });
  });

  describe('mis reservas', () => {
    it('separa las próximas del historial y muestra estado, día y horas', async () => {
      datos.mias = [
        reserva('r1', 'PENDIENTE_ADMIN', 10),
        reserva('r2', 'CANCELADA', 12),
        reserva('r3', 'APROBADA', -3)
      ];
      await abrir();
      await irAMias();

      expect(texto()).toContain('Próximas (1)');
      expect(texto()).toContain('Historial (2)');
      expect(tarjetas().length).toBe(1);
      expect(tarjetas()[0].textContent).toContain('Espera al administrador');
      expect(tarjetas()[0].textContent).toMatch(/\d{1,2}:\d{2} a \d{1,2}:\d{2}/);

      boton('Historial')!.click();
      fixture.detectChanges();
      expect(tarjetas().length).toBe(2);
      expect(texto()).toContain('Cancelada');
    });

    it('sin reservas próximas invita a reservar', async () => {
      await abrir();
      await irAMias();

      expect(texto()).toContain('No tienes reservas próximas.');
      boton('Reservar un área')!.click();
      fixture.detectChanges();
      expect(component.pestana()).toBe('reservar');
    });

    it('muestra quién la pidió cuando no fue la misma persona y el motivo de un rechazo', async () => {
      datos.mias = [
        reserva('r1', 'PENDIENTE_TITULAR', 10, { solicitanteId: 's1', solicitanteNombre: 'Luis', solicitanteApellidos: 'Prueba' }),
        reserva('r2', 'RECHAZADA_ADMIN', 12, { motivo: 'Evento del condominio' })
      ];
      await abrir();
      await irAMias();
      expect(texto()).toContain('Solicitada por Luis Prueba');
      expect(texto()).toContain('Espera al titular');

      boton('Historial')!.click();
      fixture.detectChanges();
      expect(texto()).toContain('Motivo: Evento del condominio');
    });

    it('una reserva aprobada dentro de la ventana trae "Confirmar asistencia"; antes de tiempo dice cuándo podrá', async () => {
      datos.mias = [reserva('dentro', 'APROBADA', 5), reserva('lejos', 'APROBADA', 20)];
      await abrir();
      await irAMias();

      const dentro = tarjetas().find(t => t.textContent!.includes('Confirmar asistencia'))!;
      expect(dentro).toBeDefined();
      const lejos = tarjetas().find(t => !t.textContent!.includes('Confirmar asistencia'))!;
      expect(lejos.textContent).toContain('Podrás confirmar tu asistencia a partir del');
    });

    it('una reserva aprobada y ya confirmada figura como Confirmada, sin botón de confirmar ni avisos de plazo', async () => {
      datos.mias = [reserva('ok', 'APROBADA', 5, { confirmadaEn: new Date().toISOString() })];
      await abrir();
      await irAMias();

      expect(tarjetas()[0].textContent).toContain('Confirmada');
      expect(texto()).toContain('Asistencia confirmada.');
      expect(boton('Confirmar asistencia')).toBeUndefined();
      expect(boton('Cancelar')).toBeDefined();
      expect(texto()).not.toContain('Podrás confirmar');
    });

    it('pasado el plazo de confirmación avisa que ya no se puede', async () => {
      datos.mias = [reserva('tarde', 'APROBADA', 1)];
      await abrir();
      await irAMias();

      expect(texto()).toContain('Ya pasó el plazo para confirmar la asistencia.');
      expect(boton('Confirmar asistencia')).toBeUndefined();
    });

    it('lo que ya terminó o se cerró no trae acciones', async () => {
      datos.mias = [reserva('a', 'CANCELADA', 10), reserva('b', 'APROBADA', -3), reserva('c', 'NO_UTILIZADA', -5)];
      await abrir();
      await irAMias();
      boton('Historial')!.click();
      fixture.detectChanges();

      expect(boton('Cancelar')).toBeUndefined();
      expect(boton('Confirmar asistencia')).toBeUndefined();
    });
  });

  describe('acciones', () => {
    beforeEach(() => {
      datos.mias = [reserva('r1', 'APROBADA', 5)];
    });

    it('confirmar pide confirmación, avisa que cuenta como inasistencia y confirma', async () => {
      await abrir();
      await irAMias();

      boton('Confirmar asistencia')!.click();
      await fixture.whenStable();
      await new Promise(r => setTimeout(r));

      expect((swal.calls.argsFor(0)[0] as any).text).toContain('contará como inasistencia');
      expect(api.post).toHaveBeenCalledWith('/api/reservas/r1/confirmar', {}, undefined, 'reservas');
    });

    it('si se arrepiente al confirmar no se envía nada', async () => {
      swal.and.resolveTo({ isConfirmed: false } as any);
      await abrir();
      await irAMias();

      await component.confirmarAsistencia(datos.mias[0]);

      expect(api.post).not.toHaveBeenCalled();
    });

    it('cancelar manda el motivo escrito', async () => {
      swal.and.resolveTo({ isConfirmed: true, value: 'Cambio de planes' } as any);
      await abrir();
      await irAMias();

      await component.cancelarReserva(datos.mias[0]);

      expect(api.post).toHaveBeenCalledWith('/api/reservas/r1/cancelar', { motivo: 'Cambio de planes' }, undefined, 'reservas');
    });

    it('si la reserva ya cambió (409) lo explica con el mensaje del backend y actualiza la lista', async () => {
      spyOn(console, 'error');
      api.post.and.returnValue(throwError(() => ({ status: 409, error: { error: 'El estado de la reserva no permite esta operación.' } })));
      await abrir();
      await irAMias();
      api.get.calls.reset();

      await component.cancelarReserva(datos.mias[0]);

      const aviso = swal.calls.mostRecent().args[0] as any;
      expect(aviso.icon).toBe('info');
      expect(aviso.text).toBe('El estado de la reserva no permite esta operación.');
      expect(api.get).toHaveBeenCalled();
    });

    it('un error de validación (400) se muestra como error, sin dar la reserva por cambiada', async () => {
      spyOn(console, 'error');
      api.post.and.returnValue(throwError(() => ({ status: 400, error: { error: 'No se pudo completar la operación' } })));
      await abrir();
      await irAMias();
      api.get.calls.reset();

      await component.cancelarReserva(datos.mias[0]);

      expect((swal.calls.mostRecent().args[0] as any).icon).toBe('error');
      expect(api.get).not.toHaveBeenCalled();
    });

    it('oculta el JSON técnico con un mensaje claro', async () => {
      spyOn(console, 'error');
      api.post.and.returnValue(throwError(() => ({ status: 500, error: { error: 'Error desde Supabase: {"code":"XX000"}' } })));
      await abrir();
      await irAMias();

      await component.cancelarReserva(datos.mias[0]);

      expect((swal.calls.mostRecent().args[0] as any).text).toBe('No fue posible completar la acción. Intenta de nuevo en unos segundos.');
    });
  });

  describe('solicitudes de sub-usuarios (titular)', () => {
    beforeEach(() => {
      datos.pendientes = [pendiente];
    });

    it('avisa arriba con quién la pide, su parentesco y su correo', async () => {
      await abrir();

      expect(texto()).toContain('Una solicitud espera tu aprobación');
      expect(texto()).toContain('Luis Prueba');
      expect(texto()).toContain('Familiar');
      expect(texto()).toContain('luis@example.com');
    });

    it('sin solicitudes no muestra la sección', async () => {
      datos.pendientes = [];
      await abrir();

      expect(texto()).not.toContain('espera tu aprobación');
    });

    it('aprobar la envía y la quita de la lista', async () => {
      await abrir();

      boton('Aprobar')!.click();
      await fixture.whenStable();
      await new Promise(r => setTimeout(r));
      fixture.detectChanges();

      expect(api.post).toHaveBeenCalledWith('/api/reservas/p1/aprobar-titular', {}, undefined, 'reservas');
      expect(texto()).not.toContain('espera tu aprobación');
    });

    it('rechazar manda el motivo opcional', async () => {
      swal.and.resolveTo({ isConfirmed: true, value: 'No estaré en casa' } as any);
      await abrir();

      await component.rechazarSolicitud(pendiente);

      expect(api.post).toHaveBeenCalledWith('/api/reservas/p1/rechazar-titular', { motivo: 'No estaré en casa' }, undefined, 'reservas');
    });
  });
});
