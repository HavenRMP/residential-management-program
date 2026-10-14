import { ChangeDetectionStrategy, Component, Input, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { FiltrosHistorialPaquetes, ListaPaquetes, PaqueteriaCasetaService } from '../../../core/services/paqueteria-caseta.service';
import { PaqueteriaService } from '../../../core/services/paqueteria.service';
import { DirectorioCasasService } from '../../../core/services/directorio-casas.service';
import {
  EstadoPaquete,
  LIMITES_PAQUETE,
  Paquete,
  llegaHoy,
  paqueteCoincideConBusqueda,
  textoVentanaPaquete
} from '../../../core/models/paquete.model';
import { formatearFechaVisita } from '../../../core/models/visita.model';
import { esRecursoYaNoDisponible, mensajeAmigable } from '../../../core/utils/api-errors.util';
import { telefonoParaLlamar } from '../../../core/utils/directorio-casas.util';
import { tiempoRelativo } from '../../../core/utils/tiempo-relativo.util';
import { PaqueteSinAvisoFormComponent } from './paquete-sin-aviso-form.component';

type Pestana = 'esperados' | 'caseta' | 'historial';
type Periodo = '7' | '30' | 'todo';

/** A partir de estos días en caseta se avisa que el paquete lleva mucho tiempo sin recogerse */
const DIAS_PARA_AVISAR = 7;

/** Botones grandes y de texto claro en los cuadros de confirmación: caseta los usa de pie y con prisa */
const BOTONES_GRANDES = {
  confirmButton: 'h-12 px-6 mx-1 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-base font-semibold cursor-pointer',
  cancelButton: 'h-12 px-6 mx-1 rounded-lg bg-slate-200 hover:bg-slate-300 text-slate-800 text-base font-semibold cursor-pointer',
  input: 'text-base'
};

@Component({
  selector: 'app-paqueteria-caseta',
  standalone: true,
  imports: [CommonModule, FormsModule, PaqueteSinAvisoFormComponent],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <section class="rounded-xl border border-slate-200 bg-white p-5 shadow-xs space-y-5">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h2 class="text-lg font-bold text-slate-900">Paquetes</h2>
          <p class="text-sm text-slate-600 mt-0.5">
            {{ soloLectura ? 'Consulta los paquetes de las casas. La caseta los recibe y los entrega.' : 'Recibe los paquetes que llegan y entrégalos a quien los recoge.' }}
          </p>
        </div>
        @if (!soloLectura) {
          <button
            type="button"
            (click)="mostrarSinAviso.set(true)"
            class="h-12 px-5 inline-flex items-center justify-center gap-2 rounded-lg bg-[#111C99] hover:bg-[#0d1577] text-white text-base font-semibold shadow-2xs transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#111C99]"
            >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4" />
            </svg>
            Llegó un paquete que nadie avisó
          </button>
        }
      </div>

      <!-- Tres pestañas grandes con la cantidad de cada una -->
      <div class="grid grid-cols-3 gap-2" role="tablist" aria-label="Paquetes">
        @for (p of pestanas; track p.id) {
          <button
            type="button"
            role="tab"
            [attr.aria-selected]="pestana() === p.id"
            (click)="cambiarPestana(p.id)"
            class="min-h-14 px-2 py-2 rounded-lg border text-center transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
            [ngClass]="pestana() === p.id ? 'bg-slate-900 border-slate-900 text-white' : 'bg-white border-slate-300 text-slate-800 hover:bg-slate-50'"
            >
            <span class="block text-sm sm:text-base font-semibold leading-tight">{{ p.texto }}</span>
            @if (p.id !== 'historial') {
              <span class="block text-xs mt-0.5" [ngClass]="pestana() === p.id ? 'text-slate-300' : 'text-slate-600'">
                {{ cantidad(p.id) }}
              </span>
            }
          </button>
        }
      </div>

      <div class="flex flex-col sm:flex-row gap-2">
        <input
          type="search"
          [ngModel]="busqueda()"
          (ngModelChange)="busqueda.set($event)"
          aria-label="Buscar paquetes"
          placeholder="Buscar por nombre, casa o empresa"
          autocomplete="off"
          class="h-12 sm:flex-1 text-base rounded-lg border border-slate-300 bg-white px-4 text-slate-900 placeholder-slate-500 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
          />
        <button
          type="button"
          (click)="actualizar()"
          [disabled]="listaActual().cargando()"
          class="h-12 px-5 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-800 text-base font-medium transition-colors cursor-pointer disabled:opacity-50"
          >
          Actualizar
        </button>
      </div>

      <!-- Filtros del historial -->
      @if (pestana() === 'historial') {
        <div class="flex flex-col sm:flex-row sm:items-center gap-3">
          <div class="flex flex-wrap gap-2" role="group" aria-label="Qué paquetes ver">
            @for (e of estadosHistorial; track e.estado) {
              <button
                type="button"
                [attr.aria-pressed]="estadoHistorial() === e.estado"
                (click)="elegirEstadoHistorial(e.estado)"
                class="h-10 px-4 rounded-lg border text-sm font-medium transition-colors cursor-pointer"
                [ngClass]="estadoHistorial() === e.estado ? 'bg-[#111C99] border-[#111C99] text-white' : 'bg-white border-slate-300 text-slate-800 hover:bg-slate-50'"
                >
                {{ e.texto }}
              </button>
            }
          </div>
          <div class="flex flex-wrap gap-2 sm:ml-auto" role="group" aria-label="De cuándo">
            @for (p of periodos; track p.valor) {
              <button
                type="button"
                [attr.aria-pressed]="periodo() === p.valor"
                (click)="elegirPeriodo(p.valor)"
                class="h-10 px-4 rounded-lg border text-sm font-medium transition-colors cursor-pointer"
                [ngClass]="periodo() === p.valor ? 'bg-slate-900 border-slate-900 text-white' : 'bg-white border-slate-300 text-slate-800 hover:bg-slate-50'"
                >
                {{ p.texto }}
              </button>
            }
          </div>
        </div>
      }

      <!-- Cargando -->
      @if (listaActual().cargando() && listaActual().items().length === 0) {
        <div class="space-y-3" aria-busy="true">
          @for (s of [1, 2, 3]; track s) {
            <div class="h-28 rounded-xl bg-slate-100 animate-pulse"></div>
          }
        </div>
      }

      <!-- Error -->
      @if (listaActual().error(); as mensaje) {
        <div class="rounded-lg border border-rose-200 bg-rose-50 p-4 space-y-3" role="alert">
          <p class="text-base font-medium text-rose-800">{{ mensaje }}</p>
          <button
            type="button"
            (click)="actualizar()"
            class="h-11 px-5 rounded-lg bg-rose-700 hover:bg-rose-800 text-white text-base font-semibold cursor-pointer"
            >
            Intentar de nuevo
          </button>
        </div>
      }

      <!-- Vacío -->
      @if (!listaActual().cargando() && !listaActual().error() && visibles().length === 0) {
        <div class="py-10 text-center space-y-1">
          <p class="text-base font-semibold text-slate-800">{{ mensajeVacio() }}</p>
          @if (busqueda().trim()) {
            <p class="text-sm text-slate-600">Prueba con otro nombre, otra casa u otra empresa.</p>
          }
        </div>
      }

      <!-- Lista -->
      @if (visibles().length > 0) {
        <ul class="space-y-3">
          @for (p of visibles(); track p.id) {
            <li class="rounded-xl border-2 p-4 flex flex-col lg:flex-row lg:items-center justify-between gap-4" [ngClass]="claseTarjeta(p)">
              <div class="min-w-0 space-y-1.5">
                <div class="flex flex-wrap items-center gap-2">
                  <p class="text-lg font-bold text-slate-900">{{ p.servicioNombre || 'Paquete' }}</p>
                  <span class="inline-flex items-center px-2.5 py-1 rounded-md text-sm font-bold bg-slate-900 text-white">Casa {{ p.numeroCasa || '—' }}</span>
                  @if (etiqueta(p); as e) {
                    <span class="inline-flex items-center px-2.5 py-1 rounded-md text-sm font-semibold border" [ngClass]="e.clase">{{ e.texto }}</span>
                  }
                </div>
                <p class="text-base text-slate-900">Para: <span class="font-semibold">{{ p.destinatarioNombre }}</span></p>
                @if (p.numeroGuia) {
                  <p class="text-sm text-slate-700">Guía: <span class="font-mono">{{ p.numeroGuia }}</span></p>
                }
                @if (p.descripcion) {
                  <p class="text-sm text-slate-700">{{ p.descripcion }}</p>
                }
                @if (p.notas && pestana() !== 'historial') {
                  <p class="text-sm text-amber-900 bg-amber-50 border border-amber-200 rounded-md px-2.5 py-1.5">Nota del residente: {{ p.notas }}</p>
                }

                @switch (pestana()) {
                  @case ('esperados') {
                    @if (ventana(p)) {
                      <p class="text-sm text-slate-700">Lo esperan: {{ ventana(p) }}</p>
                    }
                  }
                  @case ('caseta') {
                    @if (p.ubicacionAlmacen) {
                      <p class="text-sm font-medium text-slate-900">Guardado en: {{ p.ubicacionAlmacen }}</p>
                    }
                    @if (p.recibidoEn) {
                      <p class="text-sm" [ngClass]="llevaMuchoTiempo(p) ? 'font-semibold text-amber-800' : 'text-slate-700'">
                        Llegó {{ tiempoDesde(p.recibidoEn) }}
                      </p>
                    }
                    @for (t of telefonos(p); track t.numero) {
                      <p class="text-sm text-slate-700">
                        Avisar a {{ t.nombre }}:
                        <a [href]="'tel:' + t.numero" class="font-semibold text-[#111C99] underline">{{ t.texto }}</a>
                      </p>
                    }
                  }
                  @case ('historial') {
                    <p class="text-sm text-slate-700">{{ resumenHistorial(p) }}</p>
                  }
                }
              </div>

              @if (!soloLectura && pestana() === 'esperados') {
                <button
                  type="button"
                  (click)="recibir(p)"
                  [disabled]="ocupado() === p.id"
                  [attr.aria-label]="'Recibir paquete de ' + (p.servicioNombre || 'paquetería') + ' para ' + p.destinatarioNombre"
                  class="h-14 lg:w-56 px-6 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-lg font-bold shadow-2xs transition-colors cursor-pointer disabled:opacity-50 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-emerald-600"
                  >
                  {{ ocupado() === p.id ? 'Guardando...' : 'Recibir paquete' }}
                </button>
              }
              @if (!soloLectura && pestana() === 'caseta') {
                <button
                  type="button"
                  (click)="entregar(p)"
                  [disabled]="ocupado() === p.id"
                  [attr.aria-label]="'Entregar paquete de ' + (p.servicioNombre || 'paquetería') + ' para ' + p.destinatarioNombre"
                  class="h-14 lg:w-56 px-6 rounded-lg bg-[#111C99] hover:bg-[#0d1577] text-white text-lg font-bold shadow-2xs transition-colors cursor-pointer disabled:opacity-50 focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-[#111C99]"
                  >
                  {{ ocupado() === p.id ? 'Guardando...' : 'Entregar paquete' }}
                </button>
              }
            </li>
          }
        </ul>
      }
    </section>

    @if (mostrarSinAviso()) {
      <app-paquete-sin-aviso-form
        [servicios]="paqueteria.servicios()"
        (cerrado)="mostrarSinAviso.set(false)"
        (guardado)="alRegistrarSinAviso()"
      />
    }
  `
})
export class PaqueteriaCasetaComponent implements OnInit {
  readonly servicio = inject(PaqueteriaCasetaService);
  readonly paqueteria = inject(PaqueteriaService);
  private readonly directorio = inject(DirectorioCasasService);

  /** Administración solo consulta: recibir y entregar es trabajo de la caseta */
  @Input() soloLectura = false;

  readonly pestanas: { id: Pestana; texto: string }[] = [
    { id: 'esperados', texto: 'Esperados' },
    { id: 'caseta', texto: 'En caseta' },
    { id: 'historial', texto: 'Ya resueltos' }
  ];
  readonly estadosHistorial: { estado: EstadoPaquete; texto: string }[] = [
    { estado: 'entregado', texto: 'Entregados' },
    { estado: 'cancelado', texto: 'Cancelados' },
    { estado: 'vencido', texto: 'Vencidos' }
  ];
  readonly periodos: { valor: Periodo; texto: string }[] = [
    { valor: '7', texto: 'Últimos 7 días' },
    { valor: '30', texto: 'Últimos 30 días' },
    { valor: 'todo', texto: 'Todos' }
  ];

  readonly pestana = signal<Pestana>('esperados');
  readonly busqueda = signal<string>('');
  readonly estadoHistorial = signal<EstadoPaquete>('entregado');
  readonly periodo = signal<Periodo>('30');
  /** Id del paquete que se está guardando, para no repetir el toque */
  readonly ocupado = signal<string | null>(null);
  readonly mostrarSinAviso = signal<boolean>(false);

  readonly listaActual = computed<ListaPaquetes>(() => {
    switch (this.pestana()) {
      case 'esperados': return this.servicio.esperados;
      case 'caseta': return this.servicio.enCaseta;
      default: return this.servicio.historial;
    }
  });

  readonly visibles = computed<Paquete[]>(() => {
    const lista =
      this.pestana() === 'esperados' ? this.servicio.esperadosOrdenados()
      : this.pestana() === 'caseta' ? this.servicio.enCasetaOrdenados()
      : this.servicio.historialOrdenado();
    return lista.filter(p => paqueteCoincideConBusqueda(p, this.busqueda()));
  });

  ngOnInit(): void {
    this.servicio.cargarEsperados();
    this.servicio.cargarEnCaseta();
    // Los teléfonos de cada casa salen del directorio; si no llega, la tarjeta solo omite esa línea
    this.directorio.cargar();
    if (!this.soloLectura) this.paqueteria.cargarServicios();
  }

  cantidad(pestana: Pestana): number {
    return pestana === 'esperados' ? this.servicio.esperados.items().length : this.servicio.enCaseta.items().length;
  }

  cambiarPestana(pestana: Pestana): void {
    this.pestana.set(pestana);
    this.busqueda.set('');
    // El historial no se pide hasta que se abre, y se vuelve a pedir cada vez para que esté al día
    if (pestana === 'historial') this.cargarHistorial();
  }

  actualizar(): void {
    switch (this.pestana()) {
      case 'esperados': this.servicio.cargarEsperados(); break;
      case 'caseta': this.servicio.cargarEnCaseta(); break;
      default: this.cargarHistorial();
    }
  }

  elegirEstadoHistorial(estado: EstadoPaquete): void {
    this.estadoHistorial.set(estado);
    this.cargarHistorial();
  }

  elegirPeriodo(periodo: Periodo): void {
    this.periodo.set(periodo);
    this.cargarHistorial();
  }

  private cargarHistorial(): void {
    const filtros: FiltrosHistorialPaquetes = { estado: this.estadoHistorial() };
    if (this.periodo() !== 'todo') {
      const desde = new Date();
      desde.setHours(0, 0, 0, 0);
      desde.setDate(desde.getDate() - Number(this.periodo()));
      filtros.desde = desde.toISOString();
    }
    this.servicio.cargarHistorial(filtros);
  }

  mensajeVacio(): string {
    if (this.busqueda().trim()) return 'No se encontró ningún paquete.';
    switch (this.pestana()) {
      case 'esperados': return 'No hay paquetes esperados por ahora.';
      case 'caseta': return 'No hay paquetes en caseta.';
      default: return `No hay paquetes ${this.estadoHistorial() === 'entregado' ? 'entregados' : this.estadoHistorial() === 'cancelado' ? 'cancelados' : 'vencidos'} en este periodo.`;
    }
  }

  claseTarjeta(p: Paquete): string {
    if (this.pestana() === 'caseta' && this.llevaMuchoTiempo(p)) return 'border-amber-300 bg-amber-50/40';
    if (this.pestana() === 'esperados' && llegaHoy(p)) return 'border-emerald-300 bg-emerald-50/40';
    return 'border-slate-200 bg-white';
  }

  /** Etiqueta de la tarjeta: lo primero que debe notar quien atiende */
  etiqueta(p: Paquete): { texto: string; clase: string } | null {
    if (this.pestana() === 'esperados') {
      return llegaHoy(p)
        ? { texto: 'Lo esperan hoy', clase: 'bg-emerald-100 text-emerald-900 border-emerald-300' }
        : { texto: 'Aún no es su día', clase: 'bg-slate-100 text-slate-800 border-slate-300' };
    }
    if (this.pestana() === 'caseta' && p.esInesperado) {
      return { texto: 'Nadie lo avisó', clase: 'bg-amber-100 text-amber-900 border-amber-300' };
    }
    return null;
  }

  ventana(p: Paquete): string {
    return textoVentanaPaquete(p);
  }

  tiempoDesde(iso: string): string {
    return tiempoRelativo(iso);
  }

  llevaMuchoTiempo(p: Paquete): boolean {
    const recibido = p.recibidoEn ? new Date(p.recibidoEn).getTime() : NaN;
    return !isNaN(recibido) && Date.now() - recibido >= DIAS_PARA_AVISAR * 86_400_000;
  }

  /** Quién y cómo se le avisa: hasta dos personas de la casa con teléfono */
  telefonos(p: Paquete): { nombre: string; numero: string; texto: string }[] {
    if (!p.numeroCasa) return [];
    return this.directorio
      .residentesDeCasa(p.numeroCasa)
      .filter(r => !!telefonoParaLlamar(r.telefono))
      .slice(0, 2)
      .map(r => ({ nombre: `${r.nombre} ${r.apellidos}`.trim(), numero: telefonoParaLlamar(r.telefono), texto: r.telefono! }));
  }

  resumenHistorial(p: Paquete): string {
    switch (p.estado) {
      case 'entregado':
        return `Se entregó a ${p.entregadoANombre || 'quien lo recogió'}${p.entregadoEn ? ' el ' + formatearFechaVisita(p.entregadoEn) : ''}.`;
      case 'cancelado': return 'El residente canceló el aviso antes de que llegara.';
      case 'vencido': return 'Pasó la fecha en que lo esperaban y no llegó.';
      case 'devuelto': return 'Se devolvió a la empresa.';
      default: return '';
    }
  }

  async recibir(p: Paquete): Promise<void> {
    const respuesta = await Swal.fire({
      title: 'Recibir paquete',
      html: `<p class="text-base">${this.resumen(p)}</p>`,
      input: 'text',
      inputLabel: '¿Dónde lo vas a guardar? (si quieres)',
      inputPlaceholder: 'Ejemplo: Estante 2',
      inputAttributes: { maxlength: String(LIMITES_PAQUETE.ubicacion), autocomplete: 'off' },
      showCancelButton: true,
      confirmButtonText: 'Sí, recibir',
      cancelButtonText: 'No',
      buttonsStyling: false,
      customClass: BOTONES_GRANDES
    });
    if (!respuesta.isConfirmed) return;

    this.ocupado.set(p.id);
    try {
      const ubicacion = String(respuesta.value ?? '').trim();
      await this.servicio.recibir({ paqueteId: p.id, ...(ubicacion ? { ubicacionAlmacen: ubicacion } : {}) });
      this.aviso('Paquete recibido. Ya aparece en "En caseta".');
    } catch (err: any) {
      this.alFallar(err, p, 'No se pudo recibir el paquete');
    } finally {
      this.ocupado.set(null);
    }
  }

  async entregar(p: Paquete): Promise<void> {
    const respuesta = await Swal.fire({
      title: 'Entregar paquete',
      html: `<p class="text-base">${this.resumen(p)}</p>`,
      input: 'text',
      inputLabel: '¿Quién lo recoge? Escribe su nombre.',
      inputValue: p.destinatarioNombre,
      inputAttributes: { maxlength: String(LIMITES_PAQUETE.recoge), autocomplete: 'off' },
      inputValidator: valor => (String(valor ?? '').trim() ? null : 'Escribe el nombre de quien lo recoge'),
      showCancelButton: true,
      confirmButtonText: 'Sí, entregar',
      cancelButtonText: 'No',
      buttonsStyling: false,
      customClass: BOTONES_GRANDES
    });
    if (!respuesta.isConfirmed) return;

    this.ocupado.set(p.id);
    try {
      await this.servicio.entregar(p.id, String(respuesta.value));
      this.aviso('Paquete entregado');
    } catch (err: any) {
      this.alFallar(err, p, 'No se pudo entregar el paquete');
    } finally {
      this.ocupado.set(null);
    }
  }

  alRegistrarSinAviso(): void {
    this.mostrarSinAviso.set(false);
    this.aviso('Paquete guardado. Ya aparece en "En caseta" y se avisó a la casa.');
    this.pestana.set('caseta');
    this.busqueda.set('');
  }

  /** Texto del cuadro de confirmación; los nombres vienen de la base de datos, así que se escapan */
  private resumen(p: Paquete): string {
    const escapar = (t: string) => t.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
    return `<b>${escapar(p.servicioNombre || 'Paquete')}</b> para <b>${escapar(p.destinatarioNombre)}</b>, casa <b>${escapar(p.numeroCasa || '—')}</b>`;
  }

  private aviso(titulo: string): void {
    Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: titulo, showConfirmButton: false, timer: 4000 });
  }

  private alFallar(err: any, p: Paquete, titulo: string): void {
    console.error('[PaqueteriaCasetaComponent]', titulo, err);
    const cambio = esRecursoYaNoDisponible(err);
    Swal.fire({
      icon: cambio ? 'info' : 'error',
      title: cambio ? 'Este paquete ya cambió' : titulo,
      text: cambio
        ? 'Alguien más ya lo atendió o el residente lo canceló. Actualizamos la lista.'
        : mensajeAmigable(err, 'Intenta de nuevo en unos segundos.'),
      confirmButtonColor: '#111C99'
    });
    if (cambio) {
      this.servicio.quitarDeListas(p.id);
      this.servicio.cargarEsperados();
      this.servicio.cargarEnCaseta();
    }
  }
}
