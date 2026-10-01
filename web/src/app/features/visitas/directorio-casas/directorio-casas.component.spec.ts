import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import Swal from 'sweetalert2';
import { DirectorioCasasComponent } from './directorio-casas.component';
import { DirectorioCasasService } from '../../../core/services/directorio-casas.service';
import { ViviendaConResidentes } from '../../../core/models/vivienda.model';

const casas: ViviendaConResidentes[] = [
  {
    id: 1, numeroCasa: 'A-12', tipo: 'Casa', totalResidentes: 2, estaOcupada: true,
    residentes: [
      { id: 'r1', nombre: 'José', apellidos: 'Pérez Ruiz', telefono: '55 1234 5678' },
      { id: 'r2', nombre: 'Ana', apellidos: 'López', telefono: null }
    ]
  },
  { id: 2, numeroCasa: 'B-07', tipo: 'Casa', totalResidentes: 0, estaOcupada: false, residentes: [] }
];

describe('DirectorioCasasComponent', () => {
  let fixture: ComponentFixture<DirectorioCasasComponent>;
  let servicio: {
    casas: ReturnType<typeof signal<ViviendaConResidentes[]>>;
    isLoading: ReturnType<typeof signal<boolean>>;
    errorMessage: ReturnType<typeof signal<string | null>>;
    cargar: jasmine.Spy;
  };
  let clipboard: jasmine.Spy;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const escribir = (valor: string) => {
    const input = fixture.nativeElement.querySelector('input[type="search"]') as HTMLInputElement;
    input.value = valor;
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
  };

  beforeEach(() => {
    spyOn(Swal, 'fire').and.returnValue(Promise.resolve({} as any));
    clipboard = jasmine.createSpy('writeText').and.returnValue(Promise.resolve());
    spyOnProperty(navigator, 'clipboard', 'get').and.returnValue({ writeText: clipboard } as unknown as Clipboard);

    servicio = {
      casas: signal(casas),
      isLoading: signal(false),
      errorMessage: signal<string | null>(null),
      cargar: jasmine.createSpy('cargar').and.returnValue(Promise.resolve())
    };
    TestBed.configureTestingModule({
      imports: [DirectorioCasasComponent],
      providers: [{ provide: DirectorioCasasService, useValue: servicio }]
    });
    fixture = TestBed.createComponent(DirectorioCasasComponent);
    fixture.detectChanges();
  });

  it('carga el directorio al iniciar y no lista teléfonos hasta que se busca', () => {
    expect(servicio.cargar).toHaveBeenCalled();
    expect(texto()).toContain('Escribe un número de casa o un nombre');
    expect(fixture.nativeElement.querySelectorAll('li').length).toBe(0);
    expect(texto()).not.toContain('5678');
  });

  it('al buscar muestra casa, nombre y teléfono en una misma fila', () => {
    escribir('jose');

    const filas = fixture.nativeElement.querySelectorAll('li') as NodeListOf<HTMLElement>;
    expect(filas.length).toBe(1);
    const fila = filas[0].textContent!.replace(/\s+/g, ' ');
    expect(fila).toContain('A-12');
    expect(fila).toContain('José Pérez Ruiz');
    expect(fila).toContain('55 1234 5678');
  });

  it('el botón Llamar usa un enlace tel: solo con dígitos', () => {
    escribir('a-12');

    const enlace = fixture.nativeElement.querySelector('a[aria-label^="Llamar a"]') as HTMLAnchorElement;
    expect(enlace.getAttribute('href')).toBe('tel:5512345678');
    expect(enlace.getAttribute('aria-label')).toBe('Llamar a José Pérez Ruiz');
  });

  it('un residente sin teléfono muestra el aviso y no ofrece llamar', () => {
    escribir('lopez');

    expect(texto()).toContain('Ana López');
    expect(texto()).toContain('Sin teléfono registrado');
    expect(fixture.nativeElement.querySelector('a[aria-label^="Llamar a"]')).toBeNull();
  });

  it('una casa sin residentes lo dice claramente', () => {
    escribir('b-07');

    expect(texto()).toContain('B-07');
    expect(texto()).toContain('Sin residentes registrados');
  });

  it('copia el teléfono y avisa', async () => {
    escribir('jose');

    (fixture.nativeElement.querySelector('button[aria-label^="Copiar el teléfono"]') as HTMLButtonElement).click();
    await fixture.whenStable();

    expect(clipboard).toHaveBeenCalledOnceWith('55 1234 5678');
    expect((Swal.fire as unknown as jasmine.Spy).calls.mostRecent().args[0].title).toBe('Teléfono copiado');
  });

  it('indica cuando no hay coincidencias y permite borrar la búsqueda', () => {
    escribir('zzz');
    expect(texto()).toContain('No hay casas ni residentes que coincidan con "zzz".');

    (fixture.nativeElement.querySelector('button[aria-label="Borrar búsqueda"]') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(texto()).toContain('Escribe un número de casa o un nombre');
  });

  it('limita los resultados a 20 e invita a afinar la búsqueda', () => {
    servicio.casas.set(Array.from({ length: 35 }, (_, i) => ({
      id: i, numeroCasa: `Calle-${i}`, tipo: 'Casa', totalResidentes: 1, estaOcupada: true,
      residentes: [{ id: `r${i}`, nombre: 'Vecino', apellidos: `${i}`, telefono: '5500000000' }]
    })));
    fixture.detectChanges();
    escribir('calle');

    expect(fixture.nativeElement.querySelectorAll('li').length).toBe(20);
    expect(texto()).toContain('Mostrando 20 de 35');
  });

  it('muestra el esqueleto mientras carga y el error con reintento si falla', () => {
    servicio.isLoading.set(true);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelectorAll('.animate-pulse').length).toBeGreaterThan(0);

    servicio.isLoading.set(false);
    servicio.errorMessage.set('No se pudo cargar el directorio de casas.');
    fixture.detectChanges();
    expect(texto()).toContain('No se pudo cargar el directorio de casas.');

    servicio.cargar.calls.reset();
    ([...fixture.nativeElement.querySelectorAll('button')] as HTMLButtonElement[]).find(b => b.textContent!.includes('Reintentar'))!.click();
    expect(servicio.cargar).toHaveBeenCalledOnceWith(true);
  });
});
