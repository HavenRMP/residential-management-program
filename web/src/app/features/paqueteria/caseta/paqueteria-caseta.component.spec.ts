import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Component, EventEmitter, Input, Output, computed, signal } from '@angular/core';
import Swal from 'sweetalert2';
import { PaqueteriaCasetaComponent } from './paqueteria-caseta.component';
import { PaqueteSinAvisoFormComponent } from './paquete-sin-aviso-form.component';
import { ListaPaquetes, PaqueteriaCasetaService } from '../../../core/services/paqueteria-caseta.service';
import { PaqueteriaService } from '../../../core/services/paqueteria.service';
import { DirectorioCasasService } from '../../../core/services/directorio-casas.service';
import { Paquete, ordenarEsperadosParaCaseta, ordenarPaquetesEnCaseta, ordenarPaquetesRecientesPrimero } from '../../../core/models/paquete.model';

@Component({ selector: 'app-paquete-sin-aviso-form', standalone: true, template: '<p>formulario sin aviso</p>' })
class FormularioStub {
  @Input() servicios: unknown[] = [];
  @Output() cerrado = new EventEmitter<void>();
  @Output() guardado = new EventEmitter<Paquete>();
}

const DIA = 86_400_000;
const paquete = (id: string, extra: Partial<Paquete> = {}): Paquete => ({
  id,
  viviendaId: 33,
  numeroCasa: 'PRUEBA-01',
  servicioNombre: 'Amazon',
  destinatarioNombre: 'Angel Gómez',
  estado: 'esperado',
  creadoEn: '2026-10-10T10:00:00Z',
  ...extra
});

describe('PaqueteriaCasetaComponent', () => {
  let fixture: ComponentFixture<PaqueteriaCasetaComponent>;
  let component: PaqueteriaCasetaComponent;
  let servicio: any;
  let swal: jasmine.Spy;
  let directorio: any;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const botones = () => Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>);
  const boton = (t: string) => botones().find(b => b.textContent!.trim() === t);
  const pestana = (nombre: string) =>
    Array.from(fixture.nativeElement.querySelectorAll('[role=tab]') as NodeListOf<HTMLElement>).find(t => t.textContent!.includes(nombre))!;
  const tarjetas = () => Array.from(fixture.nativeElement.querySelectorAll('li') as NodeListOf<HTMLElement>);

  async function abrir(soloLectura = false): Promise<void> {
    fixture = TestBed.createComponent(PaqueteriaCasetaComponent);
    component = fixture.componentInstance;
    component.soloLectura = soloLectura;
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  async function pulsar(el: HTMLElement | undefined): Promise<void> {
    el!.click();
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  function cargar(lista: ListaPaquetes, items: Paquete[]): void {
    lista.items.set(items);
  }

  beforeEach(() => {
    const esperados = new ListaPaquetes();
    const enCaseta = new ListaPaquetes();
    const historial = new ListaPaquetes();
    servicio = {
      esperados,
      enCaseta,
      historial,
      esperadosOrdenados: computed(() => ordenarEsperadosParaCaseta(esperados.items())),
      enCasetaOrdenados: computed(() => ordenarPaquetesEnCaseta(enCaseta.items())),
      historialOrdenado: computed(() => ordenarPaquetesRecientesPrimero(historial.items())),
      cargarEsperados: jasmine.createSpy('cargarEsperados').and.resolveTo(),
      cargarEnCaseta: jasmine.createSpy('cargarEnCaseta').and.resolveTo(),
      cargarHistorial: jasmine.createSpy('cargarHistorial').and.resolveTo(),
      recibir: jasmine.createSpy('recibir').and.resolveTo(paquete('p1', { estado: 'recibido' })),
      entregar: jasmine.createSpy('entregar').and.resolveTo(paquete('p1', { estado: 'entregado' })),
      quitarDeListas: jasmine.createSpy('quitarDeListas')
    };
    directorio = {
      cargar: jasmine.createSpy('cargar').and.resolveTo(),
      residentesDeCasa: jasmine.createSpy('residentesDeCasa').and.returnValue([])
    };
    swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true, value: '' } as any);
    TestBed.configureTestingModule({
      imports: [PaqueteriaCasetaComponent],
      providers: [
        { provide: PaqueteriaCasetaService, useValue: servicio },
        { provide: PaqueteriaService, useValue: { servicios: signal([]), cargarServicios: jasmine.createSpy('cargarServicios') } },
        { provide: DirectorioCasasService, useValue: directorio }
      ]
    });
    TestBed.overrideComponent(PaqueteriaCasetaComponent, {
      remove: { imports: [PaqueteSinAvisoFormComponent] },
      add: { imports: [FormularioStub] }
    });
  });

  describe('al abrir', () => {
    it('pide los esperados y los que están en caseta, y el directorio para los teléfonos', async () => {
      await abrir();

      expect(servicio.cargarEsperados).toHaveBeenCalled();
      expect(servicio.cargarEnCaseta).toHaveBeenCalled();
      expect(servicio.cargarHistorial).not.toHaveBeenCalled();
      expect(directorio.cargar).toHaveBeenCalled();
    });

    it('muestra tres pestañas con la cantidad de esperados y de paquetes en caseta', async () => {
      cargar(servicio.esperados, [paquete('a'), paquete('b')]);
      cargar(servicio.enCaseta, [paquete('c', { estado: 'recibido' })]);
      await abrir();

      expect(pestana('Esperados').textContent).toContain('2');
      expect(pestana('En caseta').textContent).toContain('1');
      expect(pestana('Ya resueltos')).toBeDefined();
      expect(pestana('Esperados').getAttribute('aria-selected')).toBe('true');
    });

    it('sin nada esperado lo dice con palabras sencillas', async () => {
      await abrir();
      expect(texto()).toContain('No hay paquetes esperados por ahora.');
    });
  });

  describe('esperados', () => {
    it('cada tarjeta dice empresa, casa, para quién y si lo esperan hoy', async () => {
      cargar(servicio.esperados, [paquete('a', { numeroGuia: 'G-1', notas: 'Tocar el timbre' })]);
      await abrir();

      const t = tarjetas()[0].textContent!.replace(/\s+/g, ' ');
      expect(t).toContain('Amazon');
      expect(t).toContain('Casa PRUEBA-01');
      expect(t).toContain('Para: Angel Gómez');
      expect(t).toContain('Guía: G-1');
      expect(t).toContain('Nota del residente: Tocar el timbre');
      expect(t).toContain('Lo esperan hoy');
    });

    it('un paquete esperado para otro día lo dice y va después de los de hoy', async () => {
      const luego = new Date(Date.now() + 5 * DIA).toISOString();
      cargar(servicio.esperados, [paquete('luego', { servicioNombre: 'DHL', fechaEsperadaDesde: luego, fechaEsperadaHasta: luego }), paquete('hoy')]);
      await abrir();

      expect(tarjetas()[0].textContent).toContain('Amazon');
      expect(tarjetas()[1].textContent).toContain('Aún no es su día');
    });

    it('recibir pregunta dónde guardarlo y manda la ubicación', async () => {
      cargar(servicio.esperados, [paquete('a')]);
      await abrir();
      swal.and.resolveTo({ isConfirmed: true, value: '  Estante 2 ' } as any);

      await pulsar(boton('Recibir paquete'));

      const cuadro = swal.calls.argsFor(0)[0] as any;
      expect(cuadro.title).toBe('Recibir paquete');
      expect(cuadro.html).toContain('Amazon');
      expect(cuadro.html).toContain('Angel Gómez');
      expect(cuadro.html).toContain('PRUEBA-01');
      expect(servicio.recibir).toHaveBeenCalledWith({ paqueteId: 'a', ubicacionAlmacen: 'Estante 2' });
      expect((swal.calls.mostRecent().args[0] as any).toast).toBeTrue();
    });

    it('recibir sin escribir ubicación no la manda', async () => {
      cargar(servicio.esperados, [paquete('a')]);
      await abrir();

      await pulsar(boton('Recibir paquete'));

      expect(servicio.recibir).toHaveBeenCalledWith({ paqueteId: 'a' });
    });

    it('si dice "No" no recibe nada', async () => {
      cargar(servicio.esperados, [paquete('a')]);
      await abrir();
      swal.and.resolveTo({ isConfirmed: false } as any);

      await pulsar(boton('Recibir paquete'));

      expect(servicio.recibir).not.toHaveBeenCalled();
    });

    it('los nombres con símbolos no rompen el cuadro de confirmación', async () => {
      cargar(servicio.esperados, [paquete('a', { destinatarioNombre: '<img src=x onerror=alert(1)>' })]);
      await abrir();

      await pulsar(boton('Recibir paquete'));

      expect((swal.calls.argsFor(0)[0] as any).html).not.toContain('<img');
    });

    it('si el paquete ya cambió avisa, lo quita y actualiza las listas', async () => {
      spyOn(console, 'error');
      cargar(servicio.esperados, [paquete('a')]);
      await abrir();
      servicio.recibir.and.rejectWith({ status: 409, error: { error: 'El paquete ya fue recibido.' } });

      await pulsar(boton('Recibir paquete'));

      const aviso = swal.calls.mostRecent().args[0] as any;
      expect(aviso.title).toBe('Este paquete ya cambió');
      expect(servicio.quitarDeListas).toHaveBeenCalledWith('a');
      expect(servicio.cargarEsperados).toHaveBeenCalledTimes(2);
    });

    it('si falla por otra razón muestra el mensaje y deja el paquete', async () => {
      spyOn(console, 'error');
      cargar(servicio.esperados, [paquete('a')]);
      await abrir();
      servicio.recibir.and.rejectWith({ status: 500, error: { error: 'Error desde Supabase: {"code":"XX000"}' } });

      await pulsar(boton('Recibir paquete'));

      const aviso = swal.calls.mostRecent().args[0] as any;
      expect(aviso.icon).toBe('error');
      expect(aviso.title).toBe('No se pudo recibir el paquete');
      expect(aviso.text).toBe('Intenta de nuevo en unos segundos.');
      expect(servicio.quitarDeListas).not.toHaveBeenCalled();
    });
  });

  describe('en caseta', () => {
    const enCaseta = (extra: Partial<Paquete> = {}) =>
      paquete('c', { estado: 'recibido', ubicacionAlmacen: 'Estante 2', recibidoEn: new Date(Date.now() - 2 * 3_600_000).toISOString(), ...extra });

    it('dice dónde está guardado, desde cuándo y la etiqueta de los que nadie avisó', async () => {
      cargar(servicio.enCaseta, [enCaseta({ esInesperado: true })]);
      await abrir();
      await pulsar(pestana('En caseta'));

      const t = tarjetas()[0].textContent!.replace(/\s+/g, ' ');
      expect(t).toContain('Guardado en: Estante 2');
      expect(t).toContain('Llegó hace 2 h');
      expect(t).toContain('Nadie lo avisó');
    });

    it('resalta los que llevan una semana o más sin recogerse', async () => {
      cargar(servicio.enCaseta, [enCaseta({ recibidoEn: new Date(Date.now() - 9 * DIA).toISOString() })]);
      await abrir();
      await pulsar(pestana('En caseta'));

      expect(tarjetas()[0].className).toContain('border-amber-300');
      expect(tarjetas()[0].textContent).toContain('Llegó hace 1 sem');
    });

    it('muestra a quién llamar, con enlace de teléfono', async () => {
      directorio.residentesDeCasa.and.returnValue([
        { id: '1', nombre: 'Ana', apellidos: 'Pérez', telefono: '55 1234 5678' },
        { id: '2', nombre: 'Luis', apellidos: 'Sin teléfono', telefono: null }
      ]);
      cargar(servicio.enCaseta, [enCaseta()]);
      await abrir();
      await pulsar(pestana('En caseta'));

      const enlace = tarjetas()[0].querySelector('a')!;
      expect(directorio.residentesDeCasa).toHaveBeenCalledWith('PRUEBA-01');
      expect(enlace.getAttribute('href')).toBe('tel:5512345678');
      expect(enlace.textContent).toContain('55 1234 5678');
      expect(tarjetas()[0].textContent).toContain('Avisar a Ana Pérez');
      expect(tarjetas()[0].textContent).not.toContain('Luis');
    });

    it('entregar propone el nombre del destinatario y manda quien lo recoge', async () => {
      cargar(servicio.enCaseta, [enCaseta()]);
      await abrir();
      await pulsar(pestana('En caseta'));
      swal.and.resolveTo({ isConfirmed: true, value: ' Rosa Pérez ' } as any);

      await pulsar(boton('Entregar paquete'));

      const cuadro = swal.calls.argsFor(0)[0] as any;
      expect(cuadro.title).toBe('Entregar paquete');
      expect(cuadro.inputValue).toBe('Angel Gómez');
      expect(cuadro.inputValidator('   ')).toBe('Escribe el nombre de quien lo recoge');
      expect(cuadro.inputValidator('Rosa')).toBeNull();
      expect(servicio.entregar).toHaveBeenCalledWith('c', ' Rosa Pérez ');
    });

    it('si dice "No" no entrega', async () => {
      cargar(servicio.enCaseta, [enCaseta()]);
      await abrir();
      await pulsar(pestana('En caseta'));
      swal.and.resolveTo({ isConfirmed: false } as any);

      await pulsar(boton('Entregar paquete'));

      expect(servicio.entregar).not.toHaveBeenCalled();
    });

    it('si falla al entregar muestra el error', async () => {
      spyOn(console, 'error');
      cargar(servicio.enCaseta, [enCaseta()]);
      await abrir();
      await pulsar(pestana('En caseta'));
      servicio.entregar.and.rejectWith({ status: 500, error: { error: 'Sin conexión con el servicio.' } });

      await pulsar(boton('Entregar paquete'));

      const aviso = swal.calls.mostRecent().args[0] as any;
      expect(aviso.title).toBe('No se pudo entregar el paquete');
      expect(aviso.text).toBe('Sin conexión con el servicio.');
    });

    it('sin paquetes en caseta lo dice', async () => {
      await abrir();
      await pulsar(pestana('En caseta'));
      expect(texto()).toContain('No hay paquetes en caseta.');
    });
  });

  describe('historial', () => {
    it('abrirlo pide los entregados de los últimos 30 días', async () => {
      await abrir();
      await pulsar(pestana('Ya resueltos'));

      const filtros = servicio.cargarHistorial.calls.mostRecent().args[0];
      expect(filtros.estado).toBe('entregado');
      const desde = new Date(filtros.desde);
      const esperado = new Date();
      esperado.setHours(0, 0, 0, 0);
      esperado.setDate(esperado.getDate() - 30);
      expect(desde.getTime()).toBe(esperado.getTime());
    });

    it('cambiar el tipo o el periodo vuelve a pedir; "Todos" no manda fecha', async () => {
      await abrir();
      await pulsar(pestana('Ya resueltos'));

      await pulsar(boton('Cancelados'));
      expect(servicio.cargarHistorial.calls.mostRecent().args[0].estado).toBe('cancelado');

      await pulsar(boton('Todos'));
      expect(servicio.cargarHistorial.calls.mostRecent().args[0]).toEqual({ estado: 'cancelado' });

      await pulsar(boton('Últimos 7 días'));
      expect(servicio.cargarHistorial.calls.mostRecent().args[0].desde).toBeDefined();
    });

    it('cuenta quién recogió el paquete y cuándo', async () => {
      cargar(servicio.historial, [paquete('h', { estado: 'entregado', entregadoANombre: 'Rosa Pérez', entregadoEn: '2026-10-10T18:00:00Z' })]);
      await abrir();
      await pulsar(pestana('Ya resueltos'));

      expect(tarjetas()[0].textContent).toContain('Se entregó a Rosa Pérez el');
    });

    it('un historial vacío dice qué tipo de paquetes no hay', async () => {
      await abrir();
      await pulsar(pestana('Ya resueltos'));
      expect(texto()).toContain('No hay paquetes entregados en este periodo.');

      await pulsar(boton('Vencidos'));
      expect(texto()).toContain('No hay paquetes vencidos en este periodo.');
    });

    it('no ofrece acciones sobre lo ya resuelto', async () => {
      cargar(servicio.historial, [paquete('h', { estado: 'entregado', entregadoANombre: 'Rosa' })]);
      await abrir();
      await pulsar(pestana('Ya resueltos'));

      expect(boton('Recibir paquete')).toBeUndefined();
      expect(boton('Entregar paquete')).toBeUndefined();
    });
  });

  describe('búsqueda y actualización', () => {
    it('busca por nombre, casa o empresa y avisa si no encuentra', async () => {
      cargar(servicio.esperados, [paquete('a'), paquete('b', { servicioNombre: 'DHL', destinatarioNombre: 'Rosa Luna', numeroCasa: 'A-12' })]);
      await abrir();

      component.busqueda.set('a-12');
      fixture.detectChanges();
      expect(tarjetas().length).toBe(1);
      expect(tarjetas()[0].textContent).toContain('Rosa Luna');

      component.busqueda.set('zzz');
      fixture.detectChanges();
      expect(texto()).toContain('No se encontró ningún paquete.');
    });

    it('cambiar de pestaña limpia la búsqueda', async () => {
      await abrir();
      component.busqueda.set('algo');

      await pulsar(pestana('En caseta'));

      expect(component.busqueda()).toBe('');
    });

    it('Actualizar vuelve a pedir la lista de la pestaña abierta', async () => {
      await abrir();
      await pulsar(boton('Actualizar'));
      expect(servicio.cargarEsperados).toHaveBeenCalledTimes(2);

      await pulsar(pestana('En caseta'));
      await pulsar(boton('Actualizar'));
      expect(servicio.cargarEnCaseta).toHaveBeenCalledTimes(2);
    });

    it('si falla la carga muestra el mensaje y "Intentar de nuevo" la repite', async () => {
      servicio.esperados.error.set('No se pudieron cargar los paquetes esperados.');
      await abrir();

      expect(texto()).toContain('No se pudieron cargar los paquetes esperados.');
      await pulsar(boton('Intentar de nuevo'));

      expect(servicio.cargarEsperados).toHaveBeenCalledTimes(2);
    });

    it('mientras carga por primera vez muestra marcadores y no el mensaje de vacío', async () => {
      servicio.esperados.cargando.set(true);
      await abrir();

      expect(fixture.nativeElement.querySelector('[aria-busy=true]')).not.toBeNull();
      expect(texto()).not.toContain('No hay paquetes esperados');
    });
  });

  describe('paquete que nadie avisó', () => {
    it('el botón grande abre el formulario y al guardar lo cierra, avisa y abre "En caseta"', async () => {
      await abrir();
      expect(fixture.nativeElement.querySelector('app-paquete-sin-aviso-form')).toBeNull();

      await pulsar(boton('Llegó un paquete que nadie avisó'));
      expect(fixture.nativeElement.querySelector('app-paquete-sin-aviso-form')).not.toBeNull();

      component.alRegistrarSinAviso();
      fixture.detectChanges();

      expect(fixture.nativeElement.querySelector('app-paquete-sin-aviso-form')).toBeNull();
      expect(component.pestana()).toBe('caseta');
      expect((swal.calls.mostRecent().args[0] as any).title).toContain('Paquete guardado');
    });
  });

  describe('solo lectura (administración)', () => {
    it('no ofrece recibir, entregar ni registrar paquetes sin aviso', async () => {
      cargar(servicio.esperados, [paquete('a')]);
      cargar(servicio.enCaseta, [paquete('c', { estado: 'recibido' })]);
      await abrir(true);

      expect(boton('Recibir paquete')).toBeUndefined();
      expect(boton('Llegó un paquete que nadie avisó')).toBeUndefined();
      await pulsar(pestana('En caseta'));
      expect(boton('Entregar paquete')).toBeUndefined();
      expect(texto()).toContain('Consulta los paquetes de las casas.');
    });

    it('no pide el catálogo de empresas, que solo sirve para registrar', async () => {
      await abrir(true);
      expect(TestBed.inject(PaqueteriaService).cargarServicios).not.toHaveBeenCalled();
    });
  });
});
