import { llamar, todasLasPaginas, viviendaDe } from './api';

const ZONA = 'America/Mexico_City';

/**
 * Texto único de esta ejecución. Todo lo que crea un test lleva este texto en un nombre o una guía,
 * así se reconoce y se limpia sin tocar los datos de nadie más.
 */
export const MARCADOR = `E2E${Date.now().toString(36).toUpperCase()}`;

/** Reconoce el marcador de cualquier ejecución, también de una anterior que haya terminado a medias */
const ES_DE_PRUEBA = /E2E[0-9A-Z]{6,}/;

/** Fecha (yyyy-MM-dd) en la zona de la app, a tantos días de hoy */
export function diaEnMexico(diasDespues = 0): string {
  const fecha = new Date(Date.now() + diasDespues * 86_400_000);
  return new Intl.DateTimeFormat('en-CA', { timeZone: ZONA, year: 'numeric', month: '2-digit', day: '2-digit' }).format(fecha);
}

/** Visita de prueba que llega en unos minutos, para que caseta la atienda dentro de la ventana de 24 horas */
export async function crearVisitaDeResidente(nombre: string, minutosParaLlegar = 10): Promise<{ id: string; codigo: string }> {
  const viviendaId = await viviendaDe('residente');
  const { status, datos } = await llamar('visitas', 'POST', '/api/visitas', 'residente', {
    viviendaId,
    nombreVisitante: nombre,
    apellidosVisitante: MARCADOR,
    motivo: 'personal',
    numAcompanantes: 0,
    fechaLlegadaEsperada: new Date(Date.now() + minutosParaLlegar * 60_000).toISOString(),
    horasVigencia: 2
  });
  if (status !== 201 && status !== 200) throw new Error(`No se pudo crear la visita de prueba (${status})`);
  return { id: datos.id, codigo: datos.codigo };
}

/**
 * Cancela lo que las pruebas dejaron vigente. Las visitas ya finalizadas y los paquetes entregados no se pueden borrar:
 * por eso los tests procuran dejar todo cancelado y solo los recorridos de caseta dejan historial.
 */
export async function limpiar(): Promise<void> {
  const visitas = await todasLasPaginas<any>('visitas', '/api/visitas/mis-visitas', 'residente');
  for (const v of visitas) {
    const mio = ES_DE_PRUEBA.test(`${v.nombreVisitante} ${v.apellidosVisitante}`);
    if (mio && v.estado === 'programada') {
      await llamar('visitas', 'POST', `/api/visitas/${v.id}/cancelar`, 'residente', {});
    }
  }

  const paquetes = await todasLasPaginas<any>('visitas', '/api/paqueteria/mis-paquetes?estado=esperado', 'residente');
  for (const p of paquetes) {
    if (ES_DE_PRUEBA.test(`${p.numeroGuia ?? ''} ${p.descripcion ?? ''}`)) {
      await llamar('visitas', 'POST', `/api/paqueteria/${p.id}/cancelar`, 'residente', { motivo: 'limpieza de pruebas e2e' });
    }
  }
}
