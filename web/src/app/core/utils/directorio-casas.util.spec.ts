import { ViviendaConResidentes } from '../models/vivienda.model';
import { filtrarDirectorio, normalizarBusqueda, telefonoParaLlamar } from './directorio-casas.util';

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
});
