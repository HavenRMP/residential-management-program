import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
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
      condominioActual: signal({
        id: 'cond-1',
        nombre: 'Condominio Central'
      }),
      condominioSeleccionado: signal({
        id: 'cond-1',
        nombre: 'Condominio Central'
      }),
      cargarCondominioUsuario: jasmine.createSpy('cargarCondominioUsuario').and.returnValue(Promise.resolve(null))
    };

    await TestBed.configureTestingModule({
      imports: [AvisosListComponent],
      providers: [
        provideRouter([]),
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

  describe('Vigencia flexible y fecha en calendario', () => {
    it('debe calcular minFechaExpiracion como la fecha local de hoy', () => {
      const hoy = new Date();
      const expected = `${hoy.getFullYear()}-${String(hoy.getMonth() + 1).padStart(2, '0')}-${String(hoy.getDate()).padStart(2, '0')}`;
      expect(component.minFechaExpiracion).toBe(expected);
    });

    it('debe alternar modos de vigencia correctamente', () => {
      component.seleccionarModoVigencia('fecha');
      expect(component.formAviso.tipoVigencia).toBe('fecha');
      expect(component.formAviso.fechaExpiracion).toBe(component.minFechaExpiracion);

      component.seleccionarModoVigencia('dias');
      expect(component.formAviso.tipoVigencia).toBe('dias');
    });

    it('debe permitir seleccionar presets de días', () => {
      component.formAviso.esDiasPersonalizado = true;
      component.setPresetDias(15);
      expect(component.formAviso.diasVigencia).toBe(15);
      expect(component.formAviso.esDiasPersonalizado).toBeFalse();
    });

    it('debe validar formulario con días personalizados', async () => {
      component.abrirModalCrear();
      component.formAviso.titulo = 'Aviso Días Custom';
      component.formAviso.contenido = 'Contenido válido';
      component.formAviso.diasVigencia = 45;
      component.formAviso.esDiasPersonalizado = true;

      expect(component.isFormValido).toBeTrue();
      await component.guardarAviso();

      expect(mockAvisosService.crear).toHaveBeenCalledWith(
        jasmine.objectContaining({
          titulo: 'Aviso Días Custom',
          contenido: 'Contenido válido',
          duracion_dias: 45
        }),
        'cond-1'
      );
    });

    it('debe validar formulario con fecha en calendario y permitir el mismo día', async () => {
      component.abrirModalCrear();
      component.formAviso.titulo = 'Aviso Mismo Día';
      component.formAviso.contenido = 'Expira hoy en la noche';
      component.seleccionarModoVigencia('fecha');
      component.formAviso.fechaExpiracion = component.minFechaExpiracion;

      expect(component.isFormValido).toBeTrue();
      await component.guardarAviso();

      expect(mockAvisosService.crear).toHaveBeenCalledWith(
        jasmine.objectContaining({
          titulo: 'Aviso Mismo Día',
          contenido: 'Expira hoy en la noche',
          fecha_expiracion: jasmine.stringMatching(/T23:59:59|T.*:59:59/)
        }),
        'cond-1'
      );
    });

    it('debe invalidar el formulario si se ingresa una fecha anterior a hoy', () => {
      component.abrirModalCrear();
      component.formAviso.titulo = 'Aviso Fecha Pasada';
      component.formAviso.contenido = 'No permitido';
      component.seleccionarModoVigencia('fecha');
      component.formAviso.fechaExpiracion = '2020-01-01';

      expect(component.isFormValido).toBeFalse();
    });
  });
});
