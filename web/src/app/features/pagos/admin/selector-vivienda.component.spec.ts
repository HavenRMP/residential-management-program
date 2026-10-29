import { ComponentFixture, TestBed } from '@angular/core/testing';
import { SelectorViviendaComponent } from './selector-vivienda.component';
import { ViviendaConResidentes } from '../../../core/models/vivienda.model';

const casas: ViviendaConResidentes[] = [
  {
    id: 1, numeroCasa: 'A-12', tipo: 'Casa', totalResidentes: 2, estaOcupada: true,
    residentes: [
      { id: 'r1', nombre: 'José', apellidos: 'Pérez', telefono: null },
      { id: 'r2', nombre: 'Ana', apellidos: 'López', telefono: null }
    ]
  },
  { id: 2, numeroCasa: 'B-07', tipo: 'Casa', totalResidentes: 0, estaOcupada: false, residentes: [] }
];

describe('SelectorViviendaComponent', () => {
  let fixture: ComponentFixture<SelectorViviendaComponent>;
  let component: SelectorViviendaComponent;

  const filas = () => Array.from(fixture.nativeElement.querySelectorAll('[data-test="vivienda"]') as NodeListOf<HTMLButtonElement>);
  const texto = (el: Element) => (el.textContent ?? '').replace(/\s+/g, ' ').trim();

  async function buscar(valor: string): Promise<void> {
    const entrada = fixture.nativeElement.querySelector('#selector-vivienda-buscar') as HTMLInputElement;
    entrada.value = valor;
    entrada.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  }

  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [SelectorViviendaComponent] });
    fixture = TestBed.createComponent(SelectorViviendaComponent);
    component = fixture.componentInstance;
    component.casas = casas;
    fixture.detectChanges();
  });

  it('lista cada casa con sus residentes, o avisa que no tiene', () => {
    expect(filas().map(texto)).toEqual([
      'Casa A-12 José Pérez · Ana López',
      'Casa B-07 Sin residentes registrados'
    ]);
  });

  it('marca la vivienda elegida', () => {
    component.seleccionada = 2;
    fixture.detectChanges();

    expect(filas().map(f => f.getAttribute('aria-pressed'))).toEqual(['false', 'true']);
  });

  it('avisa con el id de la casa que se toca', () => {
    const elegida = jasmine.createSpy('elegida');
    component.elegida.subscribe(elegida);

    filas()[1].click();

    expect(elegida).toHaveBeenCalledOnceWith(2);
  });

  it('busca por el nombre de un residente sin importar acentos y dice cuando no hay resultados', async () => {
    await buscar('perez');
    expect(filas().map(texto)).toEqual(['Casa A-12 José Pérez · Ana López']);

    await buscar('zzz');
    expect(filas().length).toBe(0);
    expect(texto(fixture.nativeElement.querySelector('[data-test="sin-resultados"]'))).toBe('Ninguna vivienda coincide con la búsqueda.');
  });
});
