import { TestBed } from '@angular/core/testing';
import { Type } from '@angular/core';
import { throwError } from 'rxjs';
import { ApiService } from './api.service';
import { DirectorioCasasService } from './directorio-casas.service';
import { PaqueteriaService } from './paqueteria.service';
import { ReservasService } from './reservas.service';
import { ReservasAdminService } from './reservas-admin.service';
import { SubusuariosService } from './subusuarios.service';
import { VigilantesService } from './vigilantes.service';
import { VisitasService } from './visitas.service';
import { VisitasProgramadasService } from './visitas-programadas.service';
import { VisitasVigilanciaService } from './visitas-vigilancia.service';
import { VisitasHistoricoService } from './visitas-historico.service';

const ERROR_TECNICO = { status: 500, error: { error: 'Error desde Supabase: {"code":"XX000","message":"internal"}' } };
const ERROR_LEGIBLE = { status: 400, error: { error: 'La consulta no es válida para tu condominio.' } };

interface Caso {
  nombre: string;
  servicio: Type<any>;
  /** Pide la lista; el servicio deja el mensaje en su señal de error */
  cargar: (s: any) => Promise<unknown>;
  mensaje: (s: any) => string | null;
}

/**
 * Ninguna pantalla debe mostrar el JSON crudo de Supabase que el backend a veces deja pasar: cada servicio que
 * muestra su error usa `mensajeAmigable`, que lo cambia por el texto de respaldo y conserva los mensajes legibles.
 */
const CASOS: Caso[] = [
  { nombre: 'directorio de casas', servicio: DirectorioCasasService, cargar: s => s.cargar(true), mensaje: s => s.errorMessage() },
  { nombre: 'paquetes del residente', servicio: PaqueteriaService, cargar: s => s.cargar(), mensaje: s => s.errorMessage() },
  { nombre: 'mis reservas', servicio: ReservasService, cargar: s => s.cargarMias(), mensaje: s => s.errorMessage() },
  { nombre: 'áreas comunes', servicio: ReservasService, cargar: s => s.cargarAreas(), mensaje: s => s.errorAreas() },
  { nombre: 'reservas del administrador', servicio: ReservasAdminService, cargar: s => s.cargarReservas(), mensaje: s => s.errorMessage() },
  { nombre: 'áreas del administrador', servicio: ReservasAdminService, cargar: s => s.cargarAreas(), mensaje: s => s.errorAreas() },
  { nombre: 'inasistencias', servicio: ReservasAdminService, cargar: s => s.cargarNoShows(), mensaje: s => s.errorNoShows() },
  { nombre: 'sub-usuarios', servicio: SubusuariosService, cargar: s => s.cargar(33), mensaje: s => s.errorMessage() },
  { nombre: 'vigilantes', servicio: VigilantesService, cargar: s => s.listar().catch(() => undefined), mensaje: s => s.errorMessage() },
  { nombre: 'visitas del residente', servicio: VisitasService, cargar: s => s.cargar(), mensaje: s => s.errorMessage() },
  { nombre: 'visitas programadas', servicio: VisitasProgramadasService, cargar: s => s.cargar(), mensaje: s => s.errorMessage() },
  { nombre: 'visitas próximas de caseta', servicio: VisitasVigilanciaService, cargar: s => s.cargarProximas(), mensaje: s => s.errorMessage() },
  { nombre: 'histórico de visitas', servicio: VisitasHistoricoService, cargar: s => s.cargar(), mensaje: s => s.errorMessage() }
];

describe('errores de los servicios que se muestran en pantalla', () => {
  let api: jasmine.SpyObj<ApiService>;

  beforeEach(() => {
    spyOn(console, 'error');
    api = jasmine.createSpyObj('ApiService', ['get', 'post', 'put', 'patch', 'delete']);
    TestBed.configureTestingModule({ providers: [{ provide: ApiService, useValue: api }] });
  });

  for (const caso of CASOS) {
    describe(caso.nombre, () => {
      it('oculta el JSON técnico del backend', async () => {
        api.get.and.returnValue(throwError(() => ERROR_TECNICO));
        const servicio = TestBed.inject(caso.servicio);

        await caso.cargar(servicio);

        const mensaje = caso.mensaje(servicio);
        expect(mensaje).toBeTruthy();
        expect(mensaje).not.toMatch(/supabase|XX000|[{}]/i);
      });

      it('conserva un mensaje legible del backend', async () => {
        api.get.and.returnValue(throwError(() => ERROR_LEGIBLE));
        const servicio = TestBed.inject(caso.servicio);

        await caso.cargar(servicio);

        expect(caso.mensaje(servicio)).toBe('La consulta no es válida para tu condominio.');
      });
    });
  }
});
