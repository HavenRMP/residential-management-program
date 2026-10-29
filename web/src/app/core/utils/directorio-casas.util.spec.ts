import { ViviendaConResidentes } from '../models/vivienda.model';
import { filasDelDirectorio, filtrarCasas, filtrarDirectorio, normalizarBusqueda, ocupacionPorVivienda, telefonoParaLlamar, todasLasPersonas } from './directorio-casas.util';

const casas: ViviendaConResidentes[] = [
  {
    id: 1, numeroCasa: 'A-12', tipo: 'Casa', totalResidentes: 2, estaOcupada: true,
    residentes: [
      { id: 'r1', nombre: 'José', apellidos: 'Pérez Ruiz', telefono: '55 1234 5678' },
      { id: 'r2', nombre: 'Ana', apellidos: 'López', telefono: null }
    ]
  },
  { id: 2, numeroCasa: 'B-07', tipo: 'Casa', totalResidentes: 0, estaOcupada: false, residentes: [] },
  {
    id: 3, numeroCasa: 'PRUEBA-01', tipo: 'Casa', totalResidentes: 1, estaOcupada: true,
    residentes: [{ id: 'r3', nombre: 'Residente', apellidos: 'Prueba', telefono: '5512345678' }]
  }
];

describe('directorio-casas.util', () => {
  it('normaliza acentos y mayúsculas', () => {
    expect(normalizarBusqueda('  PÉREZ ')).toBe('perez');
  });

  it('deja solo dígitos y el + inicial para marcar', () => {
    expect(telefonoParaLlamar('+52 (55) 1234-5678')).toBe('+525512345678');
    expect(telefonoParaLlamar(null)).toBe('');
  });

  it('sin consulta no lista nada', () => {
    expect(filtrarDirectorio(casas, '')).toEqual([]);
    expect(filtrarDirectorio(casas, '   ')).toEqual([]);
  });

  it('busca por nombre sin importar acentos y devuelve casa, nombre y teléfono en la misma fila', () => {
    const filas = filtrarDirectorio(casas, 'jose perez');

    expect(filas).toEqual([
      { casaId: 1, numeroCasa: 'A-12', nombreCompleto: 'José Pérez Ruiz', telefono: '55 1234 5678' }
    ]);
  });

  it('al buscar por casa devuelve todos los residentes de esa casa, incluso sin teléfono', () => {
    const filas = filtrarDirectorio(casas, 'a-12');

    expect(filas.map(f => f.nombreCompleto)).toEqual(['José Pérez Ruiz', 'Ana López']);
    expect(filas[1].telefono).toBeNull();
  });

  it('una casa sin residentes aparece sin nombre solo si coincide por su número', () => {
    expect(filtrarDirectorio(casas, 'b-07')).toEqual([
      { casaId: 2, numeroCasa: 'B-07', nombreCompleto: null, telefono: null }
    ]);
    expect(filtrarDirectorio(casas, 'lopez').some(f => f.casaId === 2)).toBeFalse();
  });

  it('busca por teléfono ignorando espacios y guiones, con al menos 3 dígitos', () => {
    expect(filtrarDirectorio(casas, '1234 5678').map(f => f.casaId)).toEqual([1, 3]);
    expect(filtrarDirectorio(casas, '55').some(f => f.casaId === 1 && f.nombreCompleto === 'José Pérez Ruiz')).toBeFalse();
  });

  it('lista a todas las personas con su casa y teléfono, sin las casas vacías', () => {
    const personas = todasLasPersonas(casas);

    expect(personas.map(p => `${p.numeroCasa}|${p.nombreCompleto}|${p.telefono}`)).toEqual([
      'A-12|José Pérez Ruiz|55 1234 5678',
      'A-12|Ana López|null',
      'PRUEBA-01|Residente Prueba|5512345678'
    ]);
  });

  describe('ocupacionPorVivienda', () => {
    it('indexa por id y marca ocupadas las casas con residentes', () => {
      const mapa = ocupacionPorVivienda(casas);

      expect(mapa.get(1)).toEqual({ ocupada: true, total: 2 });
      expect(mapa.get(2)).toEqual({ ocupada: false, total: 0 });
      expect(mapa.get(3)).toEqual({ ocupada: true, total: 1 });
      expect(mapa.size).toBe(3);
    });

    it('una casa con residentes cuenta como ocupada aunque el backend no la marque', () => {
      const mapa = ocupacionPorVivienda([{ ...casas[0], estaOcupada: false }]);

      expect(mapa.get(1)?.ocupada).toBeTrue();
    });

    it('una casa marcada ocupada por el backend lo es aunque no traiga residentes', () => {
      const mapa = ocupacionPorVivienda([{ ...casas[1], estaOcupada: true }]);

      expect(mapa.get(2)?.ocupada).toBeTrue();
    });

    it('sin casas devuelve un mapa vacío', () => {
      expect(ocupacionPorVivienda([]).size).toBe(0);
    });
  });

  it('sin consulta lista todo y con consulta filtra', () => {
    expect(filasDelDirectorio(casas, '  ').length).toBe(3);
    expect(filasDelDirectorio(casas, 'ana').map(f => f.nombreCompleto)).toEqual(['Ana López']);
    expect(filasDelDirectorio(casas, 'b-07').length).toBe(1);
  });

  describe('filtrarCasas', () => {
    it('sin consulta devuelve todas las casas', () => {
      expect(filtrarCasas(casas, '  ')).toBe(casas);
    });

    it('encuentra la casa por su número o por el nombre de un residente, sin acentos', () => {
      expect(filtrarCasas(casas, 'b-07').map(c => c.id)).toEqual([2]);
      expect(filtrarCasas(casas, 'perez').map(c => c.id)).toEqual([1]);
    });

    it('conserva todos los residentes de la casa que coincide', () => {
      expect(filtrarCasas(casas, 'ana')[0].residentes.length).toBe(2);
    });

    it('encuentra por teléfono desde tres dígitos', () => {
      expect(filtrarCasas(casas, '1234 56').map(c => c.id)).toEqual([1, 3]);
      expect(filtrarCasas(casas, '55')).toEqual([]);
    });
  });
});
