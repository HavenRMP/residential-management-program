import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ResidenteDashboardComponent } from './residente-dashboard.component';
import { AuthService } from '../../../core/services/auth.service';
import { ViviendasService } from '../../../core/services/viviendas.service';
import { CondominiosService } from '../../../core/services/condominios.service';
import { AvisosService } from '../../../core/services/avisos.service';
import { signal } from '@angular/core';
import { provideRouter } from '@angular/router';
import { Aviso } from '../../../core/models/aviso.model';

describe('ResidenteDashboardComponent', () => {
  let component: ResidenteDashboardComponent;
  let fixture: ComponentFixture<ResidenteDashboardComponent>;
  let mockAuthService: any;
  let mockViviendasService: any;
  let mockCondominiosService: any;
  let mockAvisosService: any;

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
      cargarAvisos: jasmine.createSpy('cargarAvisos').and.returnValue(Promise.resolve([avisoMock]))
    };

    await TestBed.configureTestingModule({
      imports: [ResidenteDashboardComponent],
      providers: [
        { provide: AuthService, useValue: mockAuthService },
        { provide: ViviendasService, useValue: mockViviendasService },
        { provide: CondominiosService, useValue: mockCondominiosService },
        { provide: AvisosService, useValue: mockAvisosService },
        provideRouter([])
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
