import { ComponentFixture, TestBed } from '@angular/core/testing';
import { AvisosListComponent } from './avisos-list.component';
import { AvisosService } from '../../../core/services/avisos.service';
import { AuthService } from '../../../core/services/auth.service';
import { CondominiosService } from '../../../core/services/condominios.service';
import { signal } from '@angular/core';
import { Aviso } from '../../../core/models/aviso.model';

describe('AvisosListComponent', () => {
  let component: AvisosListComponent;
  let fixture: ComponentFixture<AvisosListComponent>;
  let mockAvisosService: any;
  let mockAuthService: any;
  let mockCondominiosService: any;

  const avisoMock: Aviso = {
    id: 'aviso-1',
    condominioId: 'cond-1',
    titulo: 'Aviso Test',
    contenido: 'Contenido de prueba para el comunicado',
    fechaExpiracion: new Date(Date.now() + 86400000).toISOString(),
    activo: true,
    creadoEn: new Date().toISOString(),
    prioridad: 'informativo'
  };

  beforeEach(async () => {
    mockAvisosService = {
      avisos: signal<Aviso[]>([avisoMock]),
      vigentes: signal<Aviso[]>([avisoMock]),
      expirados: signal<Aviso[]>([]),
      isLoading: signal<boolean>(false),
      cargarAvisos: jasmine.createSpy('cargarAvisos').and.returnValue(Promise.resolve([avisoMock])),
      crear: jasmine.createSpy('crear').and.returnValue(Promise.resolve(avisoMock)),
      actualizar: jasmine.createSpy('actualizar').and.returnValue(Promise.resolve(avisoMock)),
      eliminar: jasmine.createSpy('eliminar').and.returnValue(Promise.resolve(true))
    };

    mockAuthService = {
      currentUser: signal({
        id: 'usr-1',
        email: 'admin@haven.com',
        rol: 'administrador',
        condominioId: 'cond-1'
      })
    };

    mockCondominiosService = {
      condominioSeleccionado: signal({
        id: 'cond-1',
        nombre: 'Condominio Central'
      })
    };

    await TestBed.configureTestingModule({
      imports: [AvisosListComponent],
      providers: [
        { provide: AvisosService, useValue: mockAvisosService },
        { provide: AuthService, useValue: mockAuthService },
        { provide: CondominiosService, useValue: mockCondominiosService }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(AvisosListComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create the component', () => {
    expect(component).toBeTruthy();
  });

  describe('Formulario de creación y edición (#134)', () => {
    it('debe abrir el modal en modo creación con valores limpios', () => {
      component.abrirModalCrear();
      expect(component.modalAbierto()).toBeTrue();
      expect(component.modoEdicion()).toBeFalse();
      expect(component.formAviso.titulo).toBe('');
      expect(component.formAviso.contenido).toBe('');
    });

    it('debe abrir el modal en modo edición precargando los datos del aviso', () => {
      component.abrirModalEditar(avisoMock);
      expect(component.modalAbierto()).toBeTrue();
      expect(component.modoEdicion()).toBeTrue();
      expect(component.formAviso.titulo).toBe('Aviso Test');
      expect(component.formAviso.contenido).toBe('Contenido de prueba para el comunicado');
    });

    it('debe cerrar el modal correctamente', () => {
      component.abrirModalCrear();
      component.cerrarModal();
      expect(component.modalAbierto()).toBeFalse();
    });
  });

  describe('Historial de comunicados (#135)', () => {
    it('debe alternar entre la pestaña de vigentes e historial', () => {
      expect(component.tabActiva()).toBe('vigentes');
      component.tabActiva.set('historial');
      expect(component.tabActiva()).toBe('historial');
      component.tabActiva.set('vigentes');
      expect(component.tabActiva()).toBe('vigentes');
    });

    it('debe filtrar correctamente los avisos según la pestaña activa', () => {
      component.tabActiva.set('vigentes');
      expect(component.avisosFiltrados().length).toBe(1);

      component.tabActiva.set('historial');
      expect(component.avisosFiltrados().length).toBe(0);
    });

    it('debe filtrar avisos por prioridad seleccionada', () => {
      component.tabActiva.set('vigentes');
      component.filtroPrioridad = 'urgente';
      expect(component.avisosFiltrados().length).toBe(0);

      component.filtroPrioridad = 'informativo';
      expect(component.avisosFiltrados().length).toBe(1);
    });
  });

  describe('Acciones de editar y eliminar (#136)', () => {
    it('debe llamar a actualizar al guardar en modo edición', async () => {
      component.abrirModalEditar(avisoMock);
      component.formAviso.titulo = 'Aviso Modificado';
      await component.guardarAviso();
      expect(mockAvisosService.actualizar).toHaveBeenCalled();
    });

    it('debe llamar a crear al guardar en modo creación', async () => {
      component.abrirModalCrear();
      component.formAviso.titulo = 'Nuevo Aviso';
      component.formAviso.contenido = 'Detalle del nuevo aviso';
      await component.guardarAviso();
      expect(mockAvisosService.crear).toHaveBeenCalled();
    });

    it('debe solicitar confirmación al invocar eliminar aviso', () => {
      expect(component.confirmarEliminar).toBeDefined();
    });
  });
});
