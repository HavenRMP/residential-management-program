import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import Swal from 'sweetalert2';
import { PaqueteSinAvisoFormComponent } from './paquete-sin-aviso-form.component';
import { PaqueteriaCasetaService } from '../../../core/services/paqueteria-caseta.service';
import { DirectorioCasasService } from '../../../core/services/directorio-casas.service';
import { Paquete } from '../../../core/models/paquete.model';
import { ViviendaConResidentes } from '../../../core/models/vivienda.model';

const casa = (id: number, numeroCasa: string, residentes: string[] = [], estaOcupada = true): ViviendaConResidentes => ({
  id,
  numeroCasa,
  tipo: null,
  totalResidentes: residentes.length,
  estaOcupada,
  residentes: residentes.map((n, i) => ({ id: `${id}-${i}`, nombre: n, apellidos: 'Pérez', telefono: null }))
});
const catalogo = [
  { id: 1, nombre: 'Amazon', activo: true, esSistema: true },
  { id: 2, nombre: 'DHL', activo: true, esSistema: true },
  { id: 9, nombre: 'Otro', activo: true, esSistema: true }
];
const creado: Paquete = { id: 'nuevo', viviendaId: 33, destinatarioNombre: 'Ana Pérez', estado: 'recibido', esInesperado: true };

describe('PaqueteSinAvisoFormComponent', () => {
  let fixture: ComponentFixture<PaqueteSinAvisoFormComponent>;
  let component: PaqueteSinAvisoFormComponent;
  let servicio: { recibir: jasmine.Spy };
  let directorio: { casas: ReturnType<typeof signal<ViviendaConResidentes[]>>; isLoading: ReturnType<typeof signal<boolean>>; errorMessage: ReturnType<typeof signal<string | null>>; cargar: jasmine.Spy };
  let swal: jasmine.Spy;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const botones = () => Array.from(fixture.nativeElement.querySelectorAll('button') as NodeListOf<HTMLButtonElement>);
  const boton = (t: string) => botones().find(b => b.textContent!.trim() === t);
  const campo = (id: string) => fixture.nativeElement.querySelector('#' + id) as HTMLInputElement | null;

  function abrir(servicios: any[] = catalogo): void {
    fixture = TestBed.createComponent(PaqueteSinAvisoFormComponent);
    component = fixture.componentInstance;
    component.servicios = servicios;
    fixture.detectChanges();
  }

  beforeEach(() => {
    servicio = { recibir: jasmine.createSpy('recibir').and.resolveTo(creado) };
    directorio = {
      casas: signal([casa(33, 'PRUEBA-01', ['Ana']), casa(12, 'A-12', ['Luis', 'Rosa']), casa(120, 'A-120', ['Eva']), casa(7, 'B-7', [], false)]),
      isLoading: signal(false),
      errorMessage: signal<string | null>(null),
      cargar: jasmine.createSpy('cargar').and.resolveTo()
    };
    swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true } as any);
    TestBed.configureTestingModule({
      imports: [PaqueteSinAvisoFormComponent],
      providers: [
        { provide: PaqueteriaCasetaService, useValue: servicio },
        { provide: DirectorioCasasService, useValue: directorio }
      ]
    });
  });

  describe('casa', () => {
    it('al abrir pide la casa, carga el directorio y no deja guardar', () => {
      abrir();

      expect(texto()).toContain('¿Para qué casa es?');
      expect(directorio.cargar).toHaveBeenCalled();
      expect(component.faltante()).toBe('Elige la casa para continuar.');
      expect(boton('Guardar paquete')!.disabled).toBeTrue();
      expect(campo('sin-destinatario')).toBeNull();
    });

    it('sugiere casas que coinciden, las que empiezan igual primero, y no sugiere casas vacías', () => {
      abrir();

      component.consulta.set('a-12');
      fixture.detectChanges();
      expect(component.sugerencias().map(c => c.numeroCasa)).toEqual(['A-12', 'A-120']);

      // B-7 existe pero no tiene residentes: no se le deja dejar paquetes
      component.consulta.set('b-7');
      fixture.detectChanges();
      expect(component.sugerencias().length).toBe(0);
      expect(texto()).toContain('No hay ninguna casa con ese número.');
    });

    it('sin escribir nada no sugiere casas', () => {
      abrir();
      expect(component.sugerencias()).toEqual([]);
    });

    it('elegir una casa con una sola persona propone su nombre', async () => {
      abrir();
      component.consulta.set('prueba');
      fixture.detectChanges();

      boton('Casa PRUEBA-01')!.click();
      fixture.detectChanges();
      await fixture.whenStable();

      expect(texto()).toContain('Casa PRUEBA-01');
      expect((campo('sin-destinatario') as HTMLInputElement).value).toBe('Ana Pérez');
    });

    it('con varias personas ofrece sus nombres para tocar y no propone ninguno', async () => {
      abrir();
      component.elegirCasa(directorio.casas()[1]);
      fixture.detectChanges();
      await fixture.whenStable();

      expect(component.destinatario).toBe('');
      expect(boton('Luis Pérez')).toBeDefined();
      expect(boton('Rosa Pérez')).toBeDefined();

      boton('Rosa Pérez')!.click();
      fixture.detectChanges();
      expect(component.destinatario).toBe('Rosa Pérez');
    });

    it('Cambiar vuelve a pedir la casa y limpia el nombre', () => {
      abrir();
      component.elegirCasa(directorio.casas()[0]);
      fixture.detectChanges();

      boton('Cambiar')!.click();
      fixture.detectChanges();

      expect(component.casa()).toBeNull();
      expect(component.destinatario).toBe('');
      expect(campo('sin-casa')).not.toBeNull();
    });

    it('si el directorio no cargó lo dice y Intentar de nuevo lo pide otra vez', () => {
      directorio.casas.set([]);
      directorio.errorMessage.set('No se pudo cargar el directorio de casas.');
      abrir();

      expect(texto()).toContain('No se pudo cargar la lista de casas.');
      boton('Intentar de nuevo')!.click();

      expect(directorio.cargar).toHaveBeenCalledWith(true);
    });
  });

  describe('qué falta', () => {
    it('pide el nombre del paquete y, si eligió otra empresa, su nombre', () => {
      abrir();
      component.elegirCasa(directorio.casas()[1]);
      expect(component.faltante()).toBe('Escribe el nombre que trae el paquete.');

      component.destinatario = 'Rosa Pérez';
      expect(component.faltante()).toBeNull();

      component.elegirEmpresa('otro');
      expect(component.faltante()).toBe('Escribe el nombre de la empresa.');
      component.empresaOtra = 'Paquetexpress';
      expect(component.faltante()).toBeNull();
    });

    it('la empresa es opcional: tocar la elegida la quita', () => {
      abrir();
      component.elegirEmpresa(1);
      expect(component.empresa).toBe(1);

      component.elegirEmpresa(1);

      expect(component.empresa).toBe('');
    });

    it('ofrece las empresas del catálogo sin su "Otro" y agrega "Otra empresa"', () => {
      abrir();
      component.elegirCasa(directorio.casas()[0]);
      fixture.detectChanges();

      expect(botones().map(b => b.textContent!.trim())).toEqual(jasmine.arrayContaining(['Amazon', 'DHL', 'Otra empresa']));
      expect(boton('Otro')).toBeUndefined();
    });

    it('si el catálogo no cargó solo ofrece "Otra empresa"', () => {
      abrir([]);
      component.elegirCasa(directorio.casas()[0]);
      fixture.detectChanges();

      expect(boton('Otra empresa')).toBeDefined();
      expect(boton('Amazon')).toBeUndefined();
    });
  });

  describe('guardar', () => {
    it('con empresa del catálogo manda su id y solo los datos escritos', async () => {
      abrir();
      component.elegirCasa(directorio.casas()[0]);
      component.elegirEmpresa(2);
      component.ubicacion = ' Estante 2 ';
      component.descripcion = '   ';
      component.guia = ' G-1 ';
      const guardado = jasmine.createSpy('guardado');
      component.guardado.subscribe(guardado);

      await component.guardar();

      expect(servicio.recibir).toHaveBeenCalledWith({
        viviendaId: 33,
        destinatarioNombre: 'Ana Pérez',
        servicioId: 2,
        numeroGuia: 'G-1',
        ubicacionAlmacen: 'Estante 2'
      });
      expect(guardado).toHaveBeenCalledWith(creado);
    });

    it('con otra empresa manda solo su nombre', async () => {
      abrir();
      component.elegirCasa(directorio.casas()[0]);
      component.elegirEmpresa('otro');
      component.empresaOtra = ' Paquetexpress ';

      await component.guardar();

      const dto = servicio.recibir.calls.mostRecent().args[0];
      expect(dto.servicioNombre).toBe('Paquetexpress');
      expect(dto.servicioId).toBeUndefined();
    });

    it('sin empresa no manda ninguna', async () => {
      abrir();
      component.elegirCasa(directorio.casas()[0]);

      await component.guardar();

      const dto = servicio.recibir.calls.mostRecent().args[0];
      expect(dto.servicioId).toBeUndefined();
      expect(dto.servicioNombre).toBeUndefined();
    });

    it('no guarda si falta algo', async () => {
      abrir();

      await component.guardar();

      expect(servicio.recibir).not.toHaveBeenCalled();
    });

    it('si falla muestra el error, no cierra y deja volver a intentar', async () => {
      spyOn(console, 'error');
      servicio.recibir.and.rejectWith({ status: 400, error: { error: 'La vivienda no pertenece al condominio.' } });
      abrir();
      component.elegirCasa(directorio.casas()[0]);
      const guardado = jasmine.createSpy('guardado');
      component.guardado.subscribe(guardado);

      await component.guardar();

      const aviso = swal.calls.mostRecent().args[0] as any;
      expect(aviso.icon).toBe('error');
      expect(aviso.text).toBe('La vivienda no pertenece al condominio.');
      expect(guardado).not.toHaveBeenCalled();
      expect(component.isSaving()).toBeFalse();
    });

    it('oculta el JSON técnico con un mensaje claro', async () => {
      spyOn(console, 'error');
      servicio.recibir.and.rejectWith({ status: 500, error: { error: 'Error desde Supabase: {"code":"XX000"}' } });
      abrir();
      component.elegirCasa(directorio.casas()[0]);

      await component.guardar();

      expect((swal.calls.mostRecent().args[0] as any).text).toBe('Intenta de nuevo en unos segundos.');
    });
  });

  it('Cancelar y Escape cierran', () => {
    abrir();
    const cerrado = jasmine.createSpy('cerrado');
    component.cerrado.subscribe(cerrado);

    boton('Cancelar')!.click();
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(cerrado).toHaveBeenCalledTimes(2);
  });
});
