import { ComponentFixture, TestBed, fakeAsync, tick } from '@angular/core/testing';
import { signal } from '@angular/core';
import Swal from 'sweetalert2';
import { CasetaVisitasComponent } from './caseta-visitas.component';
import { VisitasVigilanciaService } from '../../../core/services/visitas-vigilancia.service';
import { DirectorioCasasService } from '../../../core/services/directorio-casas.service';
import { VisitasHistoricoService } from '../../../core/services/visitas-historico.service';
import { VisitasProgramadasService } from '../../../core/services/visitas-programadas.service';
import { VisitaVigilancia } from '../../../core/models/visita.model';

const visita: VisitaVigilancia = {
  id: 'v-1',
  viviendaId: 33,
  numeroCasa: 'PRUEBA-01',
  nombreVisitante: 'Juan',
  apellidosVisitante: 'Pérez',
  motivo: 'personal',
  numAcompanantes: 0,
  fechaLlegadaEsperada: '2026-10-01T15:00:00Z',
  vigenciaHasta: '2026-10-02T15:00:00Z',
  estado: 'programada'
};

describe('CasetaVisitasComponent', () => {
  let fixture: ComponentFixture<CasetaVisitasComponent>;
  let component: CasetaVisitasComponent;
  let servicio: {
    PAGE_SIZE: number;
    items: ReturnType<typeof signal<VisitaVigilancia[]>>;
    totalCount: ReturnType<typeof signal<number>>;
    page: ReturnType<typeof signal<number>>;
    isLoading: ReturnType<typeof signal<boolean>>;
    errorMessage: ReturnType<typeof signal<string | null>>;
    cargarHoy: jasmine.Spy;
    registrarEntrada: jasmine.Spy;
    validarCodigo: jasmine.Spy;
  };
  let directorio: {
    isLoading: ReturnType<typeof signal<boolean>>;
    cargar: jasmine.Spy;
    residentesDeCasa: jasmine.Spy;
  };
  let programadas: {
    items: ReturnType<typeof signal<VisitaVigilancia[]>>;
    isLoading: ReturnType<typeof signal<boolean>>;
    errorMessage: ReturnType<typeof signal<string | null>>;
    cargar: jasmine.Spy;
  };
  let historico: {
    PAGE_SIZE: number;
    items: ReturnType<typeof signal<VisitaVigilancia[]>>;
    totalCount: ReturnType<typeof signal<number>>;
    page: ReturnType<typeof signal<number>>;
    isLoading: ReturnType<typeof signal<boolean>>;
    errorMessage: ReturnType<typeof signal<string | null>>;
    cargar: jasmine.Spy;
  };

  beforeEach(() => {
    servicio = {
      PAGE_SIZE: 20,
      items: signal<VisitaVigilancia[]>([visita]),
      totalCount: signal(1),
      page: signal(1),
      isLoading: signal(false),
      errorMessage: signal<string | null>(null),
      cargarHoy: jasmine.createSpy('cargarHoy'),
      registrarEntrada: jasmine.createSpy('registrarEntrada').and.callFake(async () => ({ ...visita, estado: 'en_curso' })),
      validarCodigo: jasmine.createSpy('validarCodigo').and.callFake(async () => visita)
    };

    directorio = {
      isLoading: signal(false),
      cargar: jasmine.createSpy('cargar').and.returnValue(Promise.resolve()),
      residentesDeCasa: jasmine.createSpy('residentesDeCasa').and.callFake((casa: string) =>
        casa === 'PRUEBA-01'
          ? [
              { id: 'r1', nombre: 'Ana', apellidos: 'López', telefono: '55 1234 5678' },
              { id: 'r2', nombre: 'Luis', apellidos: 'Ruiz', telefono: null }
            ]
          : []
      )
    };

    programadas = {
      items: signal<VisitaVigilancia[]>([]),
      isLoading: signal(false),
      errorMessage: signal<string | null>(null),
      cargar: jasmine.createSpy('cargarProgramadas')
    };

    historico = {
      PAGE_SIZE: 20,
      items: signal<VisitaVigilancia[]>([]),
      totalCount: signal(0),
      page: signal(1),
      isLoading: signal(false),
      errorMessage: signal<string | null>(null),
      cargar: jasmine.createSpy('cargarHistorico')
    };

    TestBed.configureTestingModule({
      imports: [CasetaVisitasComponent],
      providers: [
        { provide: VisitasVigilanciaService, useValue: servicio },
        { provide: DirectorioCasasService, useValue: directorio },
        { provide: VisitasHistoricoService, useValue: historico },
        { provide: VisitasProgramadasService, useValue: programadas }
      ]
    });

    fixture = TestBed.createComponent(CasetaVisitasComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    servicio.cargarHoy.calls.reset();
  });

  it('espera a que el guardia deje de teclear y hace una sola búsqueda', fakeAsync(() => {
    component.busqueda = 'Pe';
    component.onBusquedaCambio();
    tick(200);
    component.busqueda = 'Perez';
    component.onBusquedaCambio();
    tick(349);
    expect(servicio.cargarHoy).not.toHaveBeenCalled();

    tick(1);
    expect(servicio.cargarHoy).toHaveBeenCalledOnceWith('Perez', 1);
  }));

  it('abre y cierra el modal de detalle mostrando los datos de la visita', () => {
    component.abrirDetalle(visita);
    fixture.detectChanges();
    expect(component.visitaDetalle()?.id).toBe('v-1');
    expect(fixture.nativeElement.textContent).toContain('Llegada esperada');

    component.cerrarDetalle();
    fixture.detectChanges();
    expect(component.visitaDetalle()).toBeNull();
    expect(fixture.nativeElement.textContent).not.toContain('Llegada esperada');
  });

  it('el detalle refleja los cambios de la lista sin cerrarse', () => {
    component.abrirDetalle(visita);
    servicio.items.set([{ ...visita, estado: 'en_curso' }]);
    fixture.detectChanges();

    expect(component.visitaDetalle()?.estado).toBe('en_curso');
  });

  it('muestra registrar entrada solo para visitas programadas', () => {
    const textoInicial = fixture.nativeElement.textContent as string;
    expect(textoInicial).toContain('Registrar entrada');

    servicio.items.set([{ ...visita, estado: 'en_curso' }]);
    fixture.detectChanges();
    const textoEnCurso = fixture.nativeElement.textContent as string;
    expect(textoEnCurso).toContain('Registrar salida');
    expect(textoEnCurso).not.toContain('Registrar entrada');
  });

  describe('pestañas Hoy, Programadas e Historial', () => {
    const pestanas = () => Array.from(fixture.nativeElement.querySelectorAll('[role="tab"]') as NodeListOf<HTMLButtonElement>);
    const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
    const visitaVieja: VisitaVigilancia = { ...visita, id: 'v-vieja', nombreVisitante: 'Rosa', estado: 'finalizada', horaEntrada: '2026-09-20T10:00:00Z', horaSalida: '2026-09-20T11:00:00Z' };

    it('abre en "Hoy" con su conteo y sin pedir el historial hasta que se abra su pestaña', () => {
      expect(pestanas().map(p => p.getAttribute('aria-selected'))).toEqual(['true', 'false', 'false']);
      expect(pestanas()[0].textContent).toContain('1');
      expect(historico.cargar).not.toHaveBeenCalled();
      expect(programadas.cargar).not.toHaveBeenCalled();
    });

    it('al abrir "Historial" lo pide una sola vez y lo muestra con las visitas más recientes primero', () => {
      historico.items.set([{ ...visita, id: 'v-nueva', nombreVisitante: 'Marta' }, visitaVieja]);
      historico.totalCount.set(2);

      pestanas()[2].click();
      fixture.detectChanges();
      pestanas()[0].click();
      pestanas()[2].click();
      fixture.detectChanges();

      expect(historico.cargar).toHaveBeenCalledOnceWith({ estado: 'finalizada' }, 1);
      const nombres = Array.from(fixture.nativeElement.querySelectorAll('li p.font-semibold') as NodeListOf<HTMLElement>).map(p => p.textContent!.trim());
      expect(nombres).toEqual(['Marta Pérez', 'Rosa Pérez']);
      expect(texto()).toContain('Salió');
      expect(texto()).toContain('Visitas que ya pasaron, la más reciente primero.');
    });

    it('filtra el historial por estado y vuelve a la primera página', () => {
      component.cambiarPestana('historial');
      historico.cargar.calls.reset();

      component.cambiarEstadoHistorial('finalizada');

      expect(historico.cargar).toHaveBeenCalledOnceWith({ estado: 'finalizada' }, 1);
    });

    it('pagina el historial', () => {
      historico.totalCount.set(45);
      historico.page.set(2);
      component.cambiarPestana('historial');
      fixture.detectChanges();
      historico.cargar.calls.reset();

      expect(texto()).toContain('Página 2 de 3');
      component.irAPaginaHistorial(3);
      component.irAPaginaHistorial(4);

      expect(historico.cargar).toHaveBeenCalledOnceWith({ estado: 'finalizada' }, 3);
    });

    it('si el backend no permite el historial muestra su mensaje en vez de una lista vacía', () => {
      historico.errorMessage.set('Tu cuenta no tiene permiso para consultar el historial de visitas.');
      pestanas()[2].click();
      fixture.detectChanges();

      expect(texto()).toContain('Tu cuenta no tiene permiso para consultar el historial de visitas.');
      expect(texto()).not.toContain('No hay visitas con este estado.');
    });

    it('el historial solo ofrece estados de visitas que ya pasaron', () => {
      pestanas()[2].click();
      fixture.detectChanges();

      const opciones = Array.from(fixture.nativeElement.querySelectorAll('#estado-historial option') as NodeListOf<HTMLOptionElement>)
        .map(o => o.textContent!.trim());
      expect(opciones).toEqual(['Finalizada', 'Cancelada', 'Expirada']);
    });

    it('"Programadas" pide las visitas a futuro una sola vez y las lista sin acciones de entrada', () => {
      const futura: VisitaVigilancia = { ...visita, id: 'v-futura', nombreVisitante: 'Lucía', fechaLlegadaEsperada: '2026-10-05T15:00:00Z' };
      programadas.items.set([futura]);

      pestanas()[1].click();
      fixture.detectChanges();
      pestanas()[0].click();
      pestanas()[1].click();
      fixture.detectChanges();

      expect(programadas.cargar).toHaveBeenCalledTimes(1);
      expect(texto()).toContain('Lucía Pérez');
      expect(texto()).toContain('Llega');
      expect(texto()).toContain('Visitas que todavía no llegan, la más próxima primero.');
      expect(texto()).not.toContain('Registrar entrada');
    });

    it('el detalle de una programada a futuro es de consulta', () => {
      const futura: VisitaVigilancia = { ...visita, id: 'v-futura', nombreVisitante: 'Lucía' };
      programadas.items.set([futura]);
      servicio.items.set([]);
      component.abrirDetalle(futura);
      fixture.detectChanges();

      expect(component.detalleEsDeHoy()).toBeFalse();
      expect(texto()).toContain('Lucía Pérez');
      expect(fixture.nativeElement.querySelector('#placas-entrada')).toBeNull();
    });

    it('indica cuando no hay visitas programadas a futuro', () => {
      pestanas()[1].click();
      fixture.detectChanges();

      expect(texto()).toContain('No hay visitas programadas para los próximos días.');
    });

    it('el detalle de una visita del historial es de consulta: sin placas ni entrada o salida', () => {
      historico.items.set([{ ...visitaVieja, estado: 'programada' }]);
      pestanas()[2].click();
      fixture.detectChanges();

      component.abrirDetalle({ ...visitaVieja, estado: 'programada' });
      fixture.detectChanges();

      expect(component.detalleEsDeHoy()).toBeFalse();
      expect(texto()).toContain('Rosa Pérez');
      expect(fixture.nativeElement.querySelector('#placas-entrada')).toBeNull();
      expect(texto()).not.toContain('Registrar entrada');
    });

    it('el detalle de una visita de hoy sí permite registrar la entrada', () => {
      component.abrirDetalle(visita);
      fixture.detectChanges();

      expect(component.detalleEsDeHoy()).toBeTrue();
      expect(fixture.nativeElement.querySelector('#placas-entrada')).not.toBeNull();
    });
  });

  describe('a quién avisar en la casa', () => {
    it('carga el directorio al iniciar', () => {
      expect(directorio.cargar).toHaveBeenCalled();
    });

    it('el detalle lista los residentes de la casa con su teléfono como enlace para llamar', () => {
      component.abrirDetalle(visita);
      fixture.detectChanges();

      const texto = (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
      expect(texto).toContain('A quién avisar en la casa PRUEBA-01');
      expect(texto).toContain('Ana López');
      expect(texto).toContain('Luis Ruiz');
      expect(texto).toContain('Sin teléfono');
      const enlace = fixture.nativeElement.querySelector('a[href^="tel:"]') as HTMLAnchorElement;
      expect(enlace.getAttribute('href')).toBe('tel:5512345678');
      expect(enlace.textContent!.trim()).toBe('55 1234 5678');
    });

    it('si la casa no tiene residentes lo dice, y si el directorio aún carga lo indica', () => {
      component.abrirDetalle({ ...visita, id: 'v-2', numeroCasa: 'B-07' });
      servicio.items.set([{ ...visita, id: 'v-2', numeroCasa: 'B-07' }]);
      fixture.detectChanges();
      expect(fixture.nativeElement.textContent).toContain('No hay residentes registrados en esta casa.');

      directorio.isLoading.set(true);
      fixture.detectChanges();
      expect(fixture.nativeElement.textContent).toContain('Cargando residentes');
    });
  });

  describe('captura de placas', () => {
    it('precarga las placas que indicó el residente y las muestra solo en visitas programadas', () => {
      component.abrirDetalle({ ...visita, vehiculoPlacas: 'ABC-123' });
      fixture.detectChanges();

      expect(component.placasEntrada).toBe('ABC-123');
      expect(fixture.nativeElement.querySelector('#placas-entrada')).not.toBeNull();

      servicio.items.set([{ ...visita, estado: 'en_curso' }]);
      fixture.detectChanges();
      expect(fixture.nativeElement.querySelector('#placas-entrada')).toBeNull();
    });

    it('registra la entrada desde el detalle con las placas capturadas', async () => {
      component.abrirDetalle(visita);
      component.placasEntrada = 'XYZ-789';

      await component.registrarEntrada(visita, component.placasEntrada);

      expect(servicio.registrarEntrada).toHaveBeenCalledOnceWith('v-1', 'XYZ-789');
    });

    it('la entrada rápida desde la lista no manda placas aunque el detalle haya guardado otras', async () => {
      component.abrirDetalle(visita);
      component.placasEntrada = 'VIEJAS-1';
      component.cerrarDetalle();
      fixture.detectChanges();

      const botones = Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>);
      botones.find(b => b.textContent?.includes('Registrar entrada'))!.click();

      expect(servicio.registrarEntrada).toHaveBeenCalledOnceWith('v-1', undefined);
    });
  });

  describe('validar código', () => {
    beforeEach(() => spyOn(Swal, 'fire').and.returnValue(Promise.resolve({} as any)));

    it('al validar una visita programada registra la entrada con las placas que ya tenía', async () => {
      servicio.validarCodigo.and.callFake(async () => ({ ...visita, vehiculoPlacas: 'ABC-123' }));
      component.codigo = ' ab12cd ';

      await component.validarCodigo();

      expect(servicio.validarCodigo).toHaveBeenCalledOnceWith('ab12cd');
      expect(servicio.registrarEntrada).toHaveBeenCalledOnceWith('v-1', 'ABC-123');
      expect(component.visitaValidada()?.estado).toBe('en_curso');
      expect(component.codigo).toBe('');
    });

    it('no registra nada si la visita ya está en curso: se queda para dar la salida', async () => {
      servicio.validarCodigo.and.callFake(async () => ({ ...visita, estado: 'en_curso' }));
      component.codigo = 'ab12cd';

      await component.validarCodigo();

      expect(servicio.registrarEntrada).not.toHaveBeenCalled();
      expect(component.visitaValidada()?.estado).toBe('en_curso');
    });

    it('con un código inválido muestra el error y no registra entrada', async () => {
      servicio.validarCodigo.and.returnValue(Promise.reject({ error: { error: 'Código no encontrado.' } }));
      component.codigo = 'nope';

      await component.validarCodigo();

      expect(servicio.registrarEntrada).not.toHaveBeenCalled();
      expect(component.errorCodigo()).toBe('Código no encontrado.');
    });

    it('si la entrada falla conserva la visita validada para reintentar con el botón', async () => {
      servicio.registrarEntrada.and.returnValue(Promise.reject({ error: { error: 'Fuera de vigencia.' } }));
      component.codigo = 'ab12cd';

      await component.validarCodigo();

      expect(component.visitaValidada()?.estado).toBe('programada');
    });
  });
});
