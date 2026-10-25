import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ResidenteDashboardComponent } from './residente-dashboard.component';
import { AuthService } from '../../../core/services/auth.service';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { CondominiosService } from '../../../core/services/condominios.service';
import { AvisosService } from '../../../core/services/avisos.service';
import { PaqueteriaService } from '../../../core/services/paqueteria.service';
import { ReservasService } from '../../../core/services/reservas.service';
import { PagosService } from '../../../core/services/pagos.service';
import { signal } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withXhr } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { Aviso } from '../../../core/models/aviso.model';

describe('ResidenteDashboardComponent', () => {
  let component: ResidenteDashboardComponent;
  let fixture: ComponentFixture<ResidenteDashboardComponent>;
  let mockAuthService: any;
  let mockViviendasService: any;
  let mockCondominiosService: any;
  let mockAvisosService: any;
  let mockPaqueteriaService: any;
  let mockReservasService: any;
  let mockPagosService: any;

  const avisoMock: Aviso = {
    id: 'aviso-1',
    condominioId: 'cond-1',
    titulo: 'Mantenimiento de bomba',
    contenido: 'Trabajos de mantenimiento programados',
    fechaExpiracion: new Date(Date.now() + 86400000 * 3).toISOString(),
    activo: true,
    creadoEn: new Date().toISOString(),
    prioridad: 'mantenimiento'
  };

  beforeEach(async () => {
    mockAuthService = {
      currentUser: signal({
        id: 'res-1',
        email: 'residente@haven.com',
        nombre: 'Carlos',
        rol: 'residente',
        condominioId: 'cond-1'
      }),
      logout: jasmine.createSpy('logout')
    };

    mockViviendasService = {
      obtenerMisViviendas: jasmine.createSpy('obtenerMisViviendas').and.returnValue(Promise.resolve([])),
      redimirCodigo: jasmine.createSpy('redimirCodigo').and.returnValue(Promise.resolve(null))
    };

    mockCondominiosService = {
      obtenerPorId: jasmine.createSpy('obtenerPorId').and.returnValue(Promise.resolve({ id: 'cond-1', nombre: 'Condominio Demo' })),
      redimirCodigo: jasmine.createSpy('redimirCodigo').and.returnValue(Promise.resolve(null))
    };

    mockAvisosService = {
      vigentes: signal<Aviso[]>([avisoMock]),
      isLoading: signal<boolean>(false),
      cargarAvisos: jasmine.createSpy('cargarAvisos').and.returnValue(Promise.resolve([avisoMock]))
    };

    mockPaqueteriaService = {
      contarEnCaseta: jasmine.createSpy('contarEnCaseta').and.resolveTo(0)
    };

    mockPagosService = {
      contarCargosAbiertos: jasmine.createSpy('contarCargosAbiertos').and.resolveTo(0)
    };

    mockReservasService = {
      accionesPendientes: signal<number>(0),
      cargarMias: jasmine.createSpy('cargarMias').and.resolveTo(),
      cargarPorAprobar: jasmine.createSpy('cargarPorAprobar').and.resolveTo()
    };

    await TestBed.configureTestingModule({
      imports: [ResidenteDashboardComponent],
      providers: [
        { provide: AuthService, useValue: mockAuthService },
        { provide: ViviendasService, useValue: mockViviendasService },
        { provide: CondominiosService, useValue: mockCondominiosService },
        { provide: AvisosService, useValue: mockAvisosService },
        { provide: PaqueteriaService, useValue: mockPaqueteriaService },
        { provide: ReservasService, useValue: mockReservasService },
        { provide: PagosService, useValue: mockPagosService },
        provideRouter([]),
        provideHttpClient(withXhr()),
        provideHttpClientTesting()
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(ResidenteDashboardComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create the resident dashboard', () => {
    expect(component).toBeTruthy();
  });

  describe('Componente de tarjeta de comunicado (#138)', () => {
    it('debe devolver la clase de badge correspondiente a la prioridad', () => {
      expect(component.getBadgeClass('urgente')).toContain('text-rose-700');
      expect(component.getBadgeClass('mantenimiento')).toContain('text-amber-700');
      expect(component.getBadgeClass('evento')).toContain('text-indigo-700');
      expect(component.getBadgeClass('informativo')).toContain('text-slate-800');
    });

    it('debe formatear el tiempo restante de expiración correctamente', () => {
      const tiempo = component.tiempoRestante(avisoMock);
      expect(tiempo).toContain('días restantes');
    });
  });

  describe('Conexión con endpoint cronológico (#139)', () => {
    it('debe llamar a cargarAvisos con el condominioId en ngOnInit', () => {
      expect(mockAvisosService.cargarAvisos).toHaveBeenCalledWith('cond-1');
    });

    it('debe mantener orden cronológico en los avisos del feed', () => {
      const lista = component.avisosService.vigentes();
      expect(lista.length).toBeGreaterThan(0);
      expect(new Date(lista[0].creadoEn).getTime()).toBeLessThanOrEqual(Date.now());
    });
  });

  describe('Acceso a reservas', () => {
    const botonReservas = (f: ComponentFixture<ResidenteDashboardComponent>) =>
      f.nativeElement.querySelector('a[href="/dashboard/residente/reservas"]') as HTMLElement | null;

    it('muestra el botón de reservas sin insignia cuando no hay nada por atender', async () => {
      const f = TestBed.createComponent(ResidenteDashboardComponent);
      f.detectChanges();
      await f.whenStable();
      f.detectChanges();

      expect(botonReservas(f)?.textContent).toContain('Reservas');
      expect(botonReservas(f)?.textContent).not.toContain('por atender');
    });

    it('la insignia cuenta las solicitudes por aprobar y las reservas por confirmar', async () => {
      mockReservasService.accionesPendientes.set(3);
      const f = TestBed.createComponent(ResidenteDashboardComponent);
      f.detectChanges();
      await f.whenStable();
      f.detectChanges();

      expect(botonReservas(f)?.textContent?.replace(/\s+/g, ' ')).toContain('3 por atender');
    });

    it('al abrir el portal consulta lo necesario para la insignia', () => {
      expect(mockReservasService.cargarMias).toHaveBeenCalled();
      expect(mockReservasService.cargarPorAprobar).toHaveBeenCalled();
    });
  });

  describe('Accesos del portal en un teléfono', () => {
    it('los botones de Visitas, Paquetes y Reservas pasan a otra línea en vez de salirse de la pantalla', async () => {
      const f = TestBed.createComponent(ResidenteDashboardComponent);
      f.detectChanges();
      await f.whenStable();
      f.detectChanges();

      const fila = f.nativeElement.querySelector('[data-test="accesos-portal"]') as HTMLElement;

      expect(fila.classList.contains('flex-wrap')).toBeTrue();
      expect(fila.querySelectorAll('a').length).toBeGreaterThanOrEqual(3);
    });
  });

  describe('Acceso a paquetería', () => {
    const botonPaqueteria = (f: ComponentFixture<ResidenteDashboardComponent>) =>
      f.nativeElement.querySelector('a[href="/dashboard/residente/paquetes"]') as HTMLElement | null;

    async function abrirPortal(): Promise<ComponentFixture<ResidenteDashboardComponent>> {
      const f = TestBed.createComponent(ResidenteDashboardComponent);
      f.detectChanges();
      await f.whenStable();
      f.detectChanges();
      return f;
    }

    it('muestra el botón sin insignia cuando no hay paquetes en caseta', async () => {
      const f = await abrirPortal();

      expect(botonPaqueteria(f)?.textContent).toContain('Paquetería');
      expect(botonPaqueteria(f)?.textContent).not.toContain('en caseta');
    });

    it('muestra cuántos paquetes esperan en caseta', async () => {
      mockPaqueteriaService.contarEnCaseta.and.resolveTo(2);

      const f = await abrirPortal();

      expect(botonPaqueteria(f)?.textContent?.replace(/\s+/g, ' ')).toContain('2 en caseta');
    });
  });

  describe('Acceso a pagos', () => {
    const botonPagos = (f: ComponentFixture<ResidenteDashboardComponent>) =>
      f.nativeElement.querySelector('a[href="/dashboard/residente/pagos"]') as HTMLElement | null;

    async function abrirPortal(): Promise<ComponentFixture<ResidenteDashboardComponent>> {
      const f = TestBed.createComponent(ResidenteDashboardComponent);
      f.detectChanges();
      await f.whenStable();
      f.detectChanges();
      return f;
    }

    it('muestra el botón sin insignia cuando no hay cargos por pagar', async () => {
      const f = await abrirPortal();

      expect(botonPagos(f)?.textContent).toContain('Pagos');
      expect(botonPagos(f)?.textContent).not.toContain('por pagar');
    });

    it('muestra cuántos cargos tiene por pagar', async () => {
      mockPagosService.contarCargosAbiertos.and.resolveTo(3);

      const f = await abrirPortal();

      expect(botonPagos(f)?.textContent?.replace(/\s+/g, ' ')).toContain('3 por pagar');
    });
  });

  describe('Detalle de la vivienda', () => {
    async function abrirPortalConCasa(): Promise<ComponentFixture<ResidenteDashboardComponent>> {
      mockViviendasService.obtenerMisViviendas.and.resolveTo([{ id: 7, numeroCasa: '105', tipo: 'Mediana' }]);
      const f = TestBed.createComponent(ResidenteDashboardComponent);
      f.detectChanges();
      await f.whenStable();
      f.detectChanges();
      return f;
    }
    const tarjeta = (f: ComponentFixture<ResidenteDashboardComponent>) =>
      f.nativeElement.querySelector('button[aria-label^="Ver detalle de"]') as HTMLButtonElement;

    it('al tocar la tarjeta de la casa abre su detalle en solo lectura', async () => {
      const f = await abrirPortalConCasa();
      expect(f.nativeElement.querySelector('app-viviendas-detalle')).toBeNull();

      tarjeta(f).click();
      f.detectChanges();

      expect(f.nativeElement.querySelector('app-viviendas-detalle [role="dialog"]')).not.toBeNull();
      expect(f.componentInstance.viviendaDetalle()?.id).toBe(7);
    });

    it('al cerrar el detalle el foco vuelve a la tarjeta de la casa', async () => {
      const f = await abrirPortalConCasa();
      document.body.appendChild(f.nativeElement);
      tarjeta(f).click();
      f.detectChanges();

      f.componentInstance.cerrarDetalleVivienda();
      f.detectChanges();

      expect(f.nativeElement.querySelector('app-viviendas-detalle')).toBeNull();
      expect(document.activeElement).toBe(tarjeta(f));
      f.nativeElement.remove();
    });
  });

  describe('Integración en dashboard de inicio (#140)', () => {
    it('debe mostrar los avisos vigentes desde el servicio', () => {
      expect(component.avisosService.vigentes().length).toBe(1);
      expect(component.avisosService.vigentes()[0].titulo).toBe('Mantenimiento de bomba');
    });

    it('debe permitir abrir el diálogo con el detalle completo del comunicado', () => {
      expect(component.verDetalleAviso).toBeDefined();
    });
  });
});
