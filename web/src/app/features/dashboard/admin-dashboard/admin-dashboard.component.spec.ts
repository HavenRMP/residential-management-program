import { ComponentFixture, TestBed } from '@angular/core/testing';
import { AdminDashboardComponent } from './admin-dashboard.component';
import { AuthService } from '../../../core/services/auth.service';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { ResidentesService } from '../../../core/services/residentes.service';
import { CondominiosService } from '../../../core/services/condominios.service';
import { signal } from '@angular/core';
import { provideRouter } from '@angular/router';
import { Vivienda } from '../../../core/models/vivienda.model';
import { Residente } from '../../../core/models/residente.model';

describe('AdminDashboardComponent', () => {
  let component: AdminDashboardComponent;
  let fixture: ComponentFixture<AdminDashboardComponent>;
  let mockAuthService: any;
  let mockViviendasService: any;
  let mockResidentesService: any;
  let mockCondominiosService: any;

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
      obtenerResidentesVivienda: jasmine.createSpy('obtenerResidentesVivienda').and.callFake((id: number) => {
        return Promise.resolve(id === 1 ? mockResidentes : []);
      })
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
        provideRouter([])
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(AdminDashboardComponent);
    component = fixture.componentInstance;
  });

  it('debe inicializar el componente de dashboard administrativo', () => {
    fixture.detectChanges();
    expect(component).toBeTruthy();
  });

  it('debe cargar las métricas y calcular ocupación correctamente al iniciar', async () => {
    fixture.detectChanges();
    await fixture.whenStable();

    expect(mockViviendasService.listar).toHaveBeenCalled();
    expect(mockResidentesService.listar).toHaveBeenCalled();
    expect(component.totalViviendas()).toBe(2);
    expect(component.totalResidentes()).toBe(1);
    expect(component.viviendasDisponibles()).toBe(1);
    expect(component.porcentajeOcupacion()).toBe(50);
    expect(component.errorMessage()).toBeNull();
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
    fixture.detectChanges();
    await fixture.whenStable();

    expect(component.errorMessage()).toBeTruthy();
    expect(component.errorMessage()).toContain('No se pudo establecer conexión');
    expect(component.totalViviendas()).toBe(0);
    expect(component.loading()).toBeFalse();

    fixture.detectChanges();
    const compiled = fixture.nativeElement as HTMLElement;
    const banner = compiled.querySelector('.bg-rose-50');
    expect(banner).toBeTruthy();
    expect(banner?.textContent).toContain('Error de conexión con el servidor');
  });

  it('debe permitir reintentar con forceRefresh cuando se pulsa el botón de reintento', async () => {
    mockViviendasService.listar.and.returnValue(Promise.reject(new Error('500 Server Error')));
    fixture.detectChanges();
    await fixture.whenStable();
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

    fixture.detectChanges();
    await fixture.whenStable();

    expect(component.errorMessage()).toBeNull();
    expect(component.viviendasResumen().length).toBe(0);
    expect(component.loading()).toBeFalse();
    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.textContent).toContain('No hay viviendas registradas aún.');
  });
});
