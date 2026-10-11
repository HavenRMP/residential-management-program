import { ComponentFixture, TestBed } from '@angular/core/testing';
import { AdminDashboardComponent } from './admin-dashboard.component';
import { AuthService } from '../../../core/services/auth.service';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { ResidentesService } from '../../../core/services/residentes.service';
import { CondominiosService } from '../../../core/services/condominios.service';
import { DirectorioCasasService } from '../../../core/services/directorio-casas.service';
import { signal } from '@angular/core';
import { provideRouter } from '@angular/router';
import { Vivienda } from '../../../core/models/vivienda.model';
import { Residente } from '../../../core/models/residente.model';
import { ViviendaConResidentes } from '../../../core/models/vivienda.model';

const casa = (id: number, numeroCasa: string, totalResidentes: number): ViviendaConResidentes => ({
  id, numeroCasa, tipo: 'Casa', totalResidentes, estaOcupada: totalResidentes > 0, residentes: []
});

describe('AdminDashboardComponent', () => {
  let component: AdminDashboardComponent;
  let fixture: ComponentFixture<AdminDashboardComponent>;
  let mockAuthService: any;
  let mockViviendasService: any;
  let mockResidentesService: any;
  let mockCondominiosService: any;
  let mockDirectorio: { cargar: jasmine.Spy; errorMessage: ReturnType<typeof signal<string | null>>; casas: ReturnType<typeof signal<ViviendaConResidentes[]>> };

  const mockViviendas: Vivienda[] = [
    { id: 1, numeroCasa: '101', tipo: 'Casa', condominioId: 'cond-1' },
    { id: 2, numeroCasa: '102', tipo: 'Departamento', condominioId: 'cond-1' }
  ];

  const mockResidentes: Residente[] = [
    { id: 'res-1', nombre: 'Juan', apellidos: 'Pérez', email: 'juan@test.com', telefono: '5551234567', rol: 'residente' }
  ];

  beforeEach(async () => {
    mockAuthService = {
      currentUser: signal({
        id: 'admin-1',
        email: 'admin@haven.com',
        nombre: 'Admin General',
        rol: 'administrador',
        condominioId: 'cond-1'
      })
    };

    mockViviendasService = {
      listar: jasmine.createSpy('listar').and.returnValue(Promise.resolve(mockViviendas)),
      obtenerResidentesVivienda: jasmine.createSpy('obtenerResidentesVivienda').and.resolveTo([])
    };

    mockDirectorio = {
      cargar: jasmine.createSpy('cargar').and.resolveTo(),
      errorMessage: signal<string | null>(null),
      casas: signal<ViviendaConResidentes[]>([casa(1, '101', 1), casa(2, '102', 0)])
    };

    mockResidentesService = {
      listar: jasmine.createSpy('listar').and.returnValue(Promise.resolve(mockResidentes))
    };

    mockCondominiosService = {
      condominioActual: signal({ id: 'cond-1', nombre: 'Haven Las Palmas' }),
      cargarCondominioUsuario: jasmine.createSpy('cargarCondominioUsuario').and.returnValue(Promise.resolve()),
      generarCodigo: jasmine.createSpy('generarCodigo').and.returnValue(Promise.resolve({ codigo: 'TEST-123' }))
    };

    await TestBed.configureTestingModule({
      imports: [AdminDashboardComponent],
      providers: [
        { provide: AuthService, useValue: mockAuthService },
        { provide: ViviendasService, useValue: mockViviendasService },
        { provide: ResidentesService, useValue: mockResidentesService },
        { provide: CondominiosService, useValue: mockCondominiosService },
        { provide: DirectorioCasasService, useValue: mockDirectorio },
        provideRouter([])
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(AdminDashboardComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('debe inicializar el componente de dashboard administrativo', () => {
    expect(component).toBeTruthy();
  });

  it('debe cargar las métricas y calcular ocupación correctamente al iniciar', async () => {
    await component.cargarMetricas();
    fixture.detectChanges();

    expect(mockViviendasService.listar).toHaveBeenCalled();
    expect(mockResidentesService.listar).toHaveBeenCalled();
    expect(component.totalViviendas()).toBe(2);
    expect(component.totalResidentes()).toBe(1);
    expect(component.viviendasDisponibles()).toBe(1);
    expect(component.porcentajeOcupacion()).toBe(50);
    expect(component.errorMessage()).toBeNull();
  });

  it('calcula la ocupación con una sola consulta del directorio, sin pedir los residentes de cada vivienda', async () => {
    await component.cargarMetricas();

    expect(mockDirectorio.cargar).toHaveBeenCalledWith(false);
    expect(mockViviendasService.obtenerResidentesVivienda).not.toHaveBeenCalled();
  });

  it('la ocupación coincide con la del directorio de viviendas aunque haya muchas casas', async () => {
    const muchas: Vivienda[] = Array.from({ length: 40 }, (_, i) => ({ id: i + 1, numeroCasa: `C-${i + 1}`, tipo: 'Casa', condominioId: 'cond-1' }));
    mockViviendasService.listar.and.resolveTo(muchas);
    mockDirectorio.casas.set(muchas.map((v, i) => casa(v.id, v.numeroCasa, i % 4 === 0 ? 1 : 0)));

    await component.cargarMetricas();

    expect(component.totalViviendas()).toBe(40);
    expect(component.viviendasAsignadas()).toBe(10);
    expect(component.viviendasDisponibles()).toBe(30);
    expect(component.porcentajeOcupacion()).toBe(25);
    expect(mockViviendasService.obtenerResidentesVivienda).not.toHaveBeenCalled();
    expect(component.viviendasResumen().length).toBe(5);
    expect(component.viviendasResumen()[0].asignada).toBeTrue();
    expect(component.viviendasResumen()[1].asignada).toBeFalse();
  });

  it('una vivienda que el directorio no trae cuenta como disponible', async () => {
    mockDirectorio.casas.set([casa(1, '101', 1)]);

    await component.cargarMetricas();

    expect(component.viviendasAsignadas()).toBe(1);
    expect(component.viviendasDisponibles()).toBe(1);
  });

  it('si el directorio falla muestra el error en vez de un 0% engañoso', async () => {
    mockDirectorio.errorMessage.set('No se pudo cargar el directorio de casas.');

    await component.cargarMetricas();

    expect(component.errorMessage()).toContain('No se pudo establecer conexión');
    expect(component.viviendasAsignadas()).toBe(0);
    expect(component.totalViviendas()).toBe(0);
  });

  it('actualizar vuelve a consultar el directorio con datos frescos', async () => {
    await component.cargarMetricas(true);

    expect(mockDirectorio.cargar).toHaveBeenCalledWith(true);
  });

  it('debe formatear nombres y badges de vivienda adecuadamente', () => {
    expect(component.formatearNombre('101')).toBe('Casa #101');
    expect(component.formatearNombre('Casa 205')).toBe('Casa 205');
    expect(component.formatearBadge('Casa 101')).toBe('101');
    expect(component.formatearBadge('A-12')).toBe('A-12');
  });

  it('no debe arrojar NaN% cuando no hay viviendas registradas', () => {
    component.totalViviendas.set(0);
    component.viviendasAsignadas.set(0);
    expect(component.porcentajeOcupacion()).toBe(0);
    expect(component.viviendasDisponibles()).toBe(0);
  });

  it('debe activar el estado de error y banner cuando falla la conexión con el servidor', async () => {
    mockViviendasService.listar.and.returnValue(Promise.reject(new Error('Network error')));

    await component.cargarMetricas();
    fixture.detectChanges();

    expect(component.errorMessage()).toBeTruthy();
    expect(component.errorMessage()).toContain('No se pudo establecer conexión');
    expect(component.totalViviendas()).toBe(0);
    expect(component.loading()).toBeFalse();

    const compiled = fixture.nativeElement as HTMLElement;
    const banner = compiled.querySelector('.bg-rose-50');
    expect(banner).toBeTruthy();
    expect(banner?.textContent).toContain('Error de conexión con el servidor');
  });

  it('debe permitir reintentar con forceRefresh cuando se pulsa el botón de reintento', async () => {
    mockViviendasService.listar.and.returnValue(Promise.reject(new Error('500 Server Error')));
    await component.cargarMetricas();
    expect(component.errorMessage()).toBeTruthy();

    // Simular que el servidor ya responde
    mockViviendasService.listar.and.returnValue(Promise.resolve(mockViviendas));
    mockResidentesService.listar.and.returnValue(Promise.resolve(mockResidentes));

    await component.cargarMetricas(true);
    fixture.detectChanges();

    expect(mockViviendasService.listar).toHaveBeenCalledWith(undefined, undefined, true);
    expect(component.errorMessage()).toBeNull();
    expect(component.totalViviendas()).toBe(2);
  });

  it('debe mostrar el estado legítimo de catálogo vacío cuando no hay viviendas y no hay error', async () => {
    mockViviendasService.listar.and.returnValue(Promise.resolve([]));
    mockResidentesService.listar.and.returnValue(Promise.resolve([]));

    await component.cargarMetricas();
    fixture.detectChanges();

    expect(component.errorMessage()).toBeNull();
    expect(component.viviendasResumen().length).toBe(0);
    expect(component.loading()).toBeFalse();
    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.textContent).toContain('No hay viviendas registradas aún.');
  });
});

describe('AdminDashboardComponent (estado de viviendas)', () => {
  let fixture: ComponentFixture<AdminDashboardComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AdminDashboardComponent],
      providers: [
        { provide: AuthService, useValue: { currentUser: signal({ id: 'a', nombre: 'Admin', rol: 'administrador', condominioId: 'c1' }) } },
        {
          provide: ViviendasService,
          useValue: {
            listar: () => Promise.resolve([{ id: 7, numeroCasa: 'A-12', tipo: 'Casa' }, { id: 8, numeroCasa: 'B-07', tipo: 'Casa' }])
          }
        },
        {
          provide: DirectorioCasasService,
          useValue: { cargar: () => Promise.resolve(), errorMessage: signal<string | null>(null), casas: signal([casa(7, 'A-12', 1), casa(8, 'B-07', 0)]) }
        },
        { provide: ResidentesService, useValue: { listar: () => Promise.resolve([]) } },
        {
          provide: CondominiosService,
          useValue: { condominioActual: signal({ id: 'c1', nombre: 'Haven' }), cargarCondominioUsuario: () => Promise.resolve() }
        },
        provideRouter([])
      ]
    }).compileComponents();
    fixture = TestBed.createComponent(AdminDashboardComponent);
    fixture.detectChanges();
    await fixture.componentInstance.cargarMetricas();
    fixture.detectChanges();
  });

  it('cada vivienda enlaza a su detalle en el directorio y se marca ocupada o disponible', () => {
    const filas = Array.from(fixture.nativeElement.querySelectorAll('a[aria-label^="Ver el detalle"]') as NodeListOf<HTMLAnchorElement>);

    expect(filas.length).toBe(2);
    expect(filas[0].getAttribute('href')).toContain('/dashboard/admin/viviendas?vivienda=7');
    expect(filas[0].textContent).toContain('Ocupada');
    expect(filas[1].getAttribute('href')).toContain('vivienda=8');
    expect(filas[1].textContent).toContain('Disponible');
  });
});
