import { AfterViewInit, ChangeDetectionStrategy, Component, ElementRef, EventEmitter, HostListener, Input, Output, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { PaqueteriaCasetaService } from '../../../core/services/paqueteria-caseta.service';
import { DirectorioCasasService } from '../../../core/services/directorio-casas.service';
import { LIMITES_PAQUETE, Paquete, RecibirPaqueteDto, SERVICIO_OTRO, ServicioPaqueteria, empresasSeleccionables } from '../../../core/models/paquete.model';
import { ViviendaConResidentes } from '../../../core/models/vivienda.model';
import { normalizarBusqueda } from '../../../core/utils/directorio-casas.util';
import { mensajeConValidacion } from '../../../core/utils/api-errors.util';

/** Cuántas casas se sugieren a la vez: más que eso ya no se lee de un vistazo */
const MAX_SUGERENCIAS = 8;

/**
 * Registra un paquete que llegó a caseta sin que el residente lo avisara. Pensado para quien atiende de pie y con
 * prisa: se elige la casa tocando, la empresa tocando, y solo se escribe el nombre que trae el paquete.
 */
@Component({
  selector: 'app-paquete-sin-aviso-form',
  standalone: true,
  imports: [CommonModule, FormsModule],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="fixed inset-0 z-50 overflow-y-auto bg-black/40 backdrop-blur-xs flex items-start sm:items-center justify-center p-4">
      <div
        class="bg-white rounded-xl max-w-xl w-full p-5 shadow-lg border border-slate-200"
        role="dialog"
        aria-modal="true"
        aria-labelledby="sin-aviso-titulo"
        >
        <div class="flex items-center justify-between pb-3 border-b border-slate-100">
          <h3 id="sin-aviso-titulo" class="text-lg font-bold text-slate-900">Llegó un paquete que nadie avisó</h3>
          <button type="button" (click)="cerrar()" aria-label="Cerrar" class="h-10 w-10 inline-flex items-center justify-center text-slate-500 hover:bg-slate-100 rounded-lg cursor-pointer">
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="mt-4 space-y-5">
          <!-- 1. Casa -->
          <div class="space-y-2">
            <p class="text-base font-semibold text-slate-900">¿Para qué casa es?</p>
            @if (casa(); as c) {
              <div class="flex items-center justify-between gap-3 rounded-lg border-2 border-emerald-300 bg-emerald-50 px-4 py-3">
                <p class="text-lg font-bold text-emerald-900">Casa {{ c.numeroCasa }}</p>
                <button type="button" (click)="cambiarCasa()" class="h-10 px-4 rounded-lg border border-slate-300 bg-white text-sm font-medium text-slate-800 hover:bg-slate-50 cursor-pointer">
                  Cambiar
                </button>
              </div>
            } @else {
              <input
                id="sin-casa"
                type="search"
                [ngModel]="consulta()"
                (ngModelChange)="consulta.set($event)"
                aria-label="Número de la casa"
                placeholder="Escribe el número de la casa"
                autocomplete="off"
                class="h-12 w-full text-base rounded-lg border border-slate-300 bg-white px-4 text-slate-900 placeholder-slate-500 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
                />
              @if (directorio.isLoading() && directorio.casas().length === 0) {
                <p class="text-sm text-slate-600">Cargando las casas...</p>
              } @else if (directorio.errorMessage() && directorio.casas().length === 0) {
                <div class="rounded-lg border border-rose-200 bg-rose-50 p-3 space-y-2" role="alert">
                  <p class="text-sm font-medium text-rose-800">No se pudo cargar la lista de casas.</p>
                  <button type="button" (click)="reintentarCasas()" class="h-10 px-4 rounded-lg bg-rose-700 text-white text-sm font-semibold cursor-pointer">Intentar de nuevo</button>
                </div>
              } @else if (consulta().trim() && sugerencias().length === 0) {
                <p class="text-sm text-slate-700">No hay ninguna casa con ese número.</p>
              } @else if (sugerencias().length > 0) {
                <ul class="grid grid-cols-2 sm:grid-cols-3 gap-2">
                  @for (s of sugerencias(); track s.id) {
                    <li>
                      <button type="button" (click)="elegirCasa(s)" class="w-full h-12 px-3 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-base font-semibold text-slate-900 cursor-pointer">
                        Casa {{ s.numeroCasa }}
                      </button>
                    </li>
                  }
                </ul>
              }
            }
          </div>

          @if (casa(); as c) {
            <!-- 2. Para quién -->
            <div class="space-y-2">
              <label for="sin-destinatario" class="block text-base font-semibold text-slate-900">¿Qué nombre trae el paquete?</label>
              @if (c.residentes.length > 0) {
                <div class="flex flex-wrap gap-2">
                  @for (r of c.residentes; track r.id) {
                    <button
                      type="button"
                      (click)="destinatario = nombreDe(r)"
                      class="h-11 px-4 rounded-lg border text-sm font-medium cursor-pointer"
                      [ngClass]="destinatario === nombreDe(r) ? 'bg-[#111C99] border-[#111C99] text-white' : 'bg-white border-slate-300 text-slate-800 hover:bg-slate-50'"
                      >
                      {{ nombreDe(r) }}
                    </button>
                  }
                </div>
              }
              <input
                id="sin-destinatario"
                type="text"
                [(ngModel)]="destinatario"
                [attr.maxlength]="limites.destinatario"
                placeholder="Escribe el nombre como aparece en el paquete"
                autocomplete="off"
                class="h-12 w-full text-base rounded-lg border border-slate-300 bg-white px-4 text-slate-900 placeholder-slate-500 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
                />
            </div>

            <!-- 3. Empresa -->
            <div class="space-y-2">
              <p class="text-base font-semibold text-slate-900">¿De qué empresa es? <span class="text-sm font-normal text-slate-600">(si lo sabes)</span></p>
              <div class="grid grid-cols-2 sm:grid-cols-3 gap-2">
                @for (s of empresas(); track s.id) {
                  <button
                    type="button"
                    [attr.aria-pressed]="empresa === s.id"
                    (click)="elegirEmpresa(s.id)"
                    class="h-12 px-3 rounded-lg border text-sm font-semibold cursor-pointer"
                    [ngClass]="empresa === s.id ? 'bg-[#111C99] border-[#111C99] text-white' : 'bg-white border-slate-300 text-slate-800 hover:bg-slate-50'"
                    >
                    {{ s.nombre }}
                  </button>
                }
                <button
                  type="button"
                  [attr.aria-pressed]="empresa === otro"
                  (click)="elegirEmpresa(otro)"
                  class="h-12 px-3 rounded-lg border text-sm font-semibold cursor-pointer"
                  [ngClass]="empresa === otro ? 'bg-[#111C99] border-[#111C99] text-white' : 'bg-white border-slate-300 text-slate-800 hover:bg-slate-50'"
                  >
                  Otra empresa
                </button>
              </div>
              @if (empresa === otro) {
                <input
                  id="sin-otra-empresa"
                  type="text"
                  [(ngModel)]="empresaOtra"
                  [attr.maxlength]="limites.servicio"
                  aria-label="Nombre de la empresa"
                  placeholder="Escribe el nombre de la empresa"
                  autocomplete="off"
                  class="h-12 w-full text-base rounded-lg border border-slate-300 bg-white px-4 text-slate-900 placeholder-slate-500 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
                  />
              }
            </div>

            <!-- 4. Datos opcionales -->
            <div class="space-y-3">
              <div>
                <label for="sin-ubicacion" class="block text-base font-semibold text-slate-900">¿Dónde lo vas a guardar? <span class="text-sm font-normal text-slate-600">(si quieres)</span></label>
                <input id="sin-ubicacion" type="text" [(ngModel)]="ubicacion" [attr.maxlength]="limites.ubicacion" placeholder="Ejemplo: Estante 2" autocomplete="off"
                  class="mt-1 h-12 w-full text-base rounded-lg border border-slate-300 bg-white px-4 text-slate-900 placeholder-slate-500 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
              </div>
              <div>
                <label for="sin-descripcion" class="block text-base font-semibold text-slate-900">¿Cómo es el paquete? <span class="text-sm font-normal text-slate-600">(si quieres)</span></label>
                <input id="sin-descripcion" type="text" [(ngModel)]="descripcion" [attr.maxlength]="limites.descripcion" placeholder="Ejemplo: Caja mediana café" autocomplete="off"
                  class="mt-1 h-12 w-full text-base rounded-lg border border-slate-300 bg-white px-4 text-slate-900 placeholder-slate-500 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
              </div>
              <div>
                <label for="sin-guia" class="block text-base font-semibold text-slate-900">Número de guía <span class="text-sm font-normal text-slate-600">(si quieres)</span></label>
                <input id="sin-guia" type="text" [(ngModel)]="guia" [attr.maxlength]="limites.guia" autocomplete="off"
                  class="mt-1 h-12 w-full text-base rounded-lg border border-slate-300 bg-white px-4 text-slate-900 placeholder-slate-500 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
              </div>
            </div>
          }

          <div class="pt-4 border-t border-slate-100 space-y-2">
            @if (faltante(); as falta) {
              <p class="text-sm text-slate-700" role="status">{{ falta }}</p>
            }
            <div class="flex flex-col-reverse sm:flex-row sm:justify-end gap-2">
              <button type="button" (click)="cerrar()" class="h-14 px-6 rounded-lg bg-slate-200 hover:bg-slate-300 text-slate-800 text-base font-semibold cursor-pointer">
                Cancelar
              </button>
              <button
                type="button"
                (click)="guardar()"
                [disabled]="isSaving() || !!faltante()"
                class="h-14 px-6 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-lg font-bold shadow-2xs cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                >
                {{ isSaving() ? 'Guardando...' : 'Guardar paquete' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  `
})
export class PaqueteSinAvisoFormComponent implements AfterViewInit {
  private readonly servicio = inject(PaqueteriaCasetaService);
  readonly directorio = inject(DirectorioCasasService);
  private readonly elemento = inject(ElementRef<HTMLElement>);

  /** Empresas del catálogo; si no cargó, solo queda "Otra empresa" */
  @Input() servicios: ServicioPaqueteria[] = [];

  @Output() cerrado = new EventEmitter<void>();
  @Output() guardado = new EventEmitter<Paquete>();

  readonly limites = LIMITES_PAQUETE;
  readonly otro = SERVICIO_OTRO;
  readonly isSaving = signal<boolean>(false);
  readonly consulta = signal<string>('');
  readonly casa = signal<ViviendaConResidentes | null>(null);

  destinatario = '';
  /** Id de una empresa del catálogo, SERVICIO_OTRO o '' si no se eligió */
  empresa: number | typeof SERVICIO_OTRO | '' = '';
  empresaOtra = '';
  ubicacion = '';
  descripcion = '';
  guia = '';

  /** Casas ocupadas que coinciden con lo escrito: las que empiezan igual primero */
  readonly sugerencias = computed<ViviendaConResidentes[]>(() => {
    const q = normalizarBusqueda(this.consulta());
    if (!q) return [];
    const coincide = this.directorio.casas().filter(c => c.estaOcupada && normalizarBusqueda(c.numeroCasa).includes(q));
    const peso = (c: ViviendaConResidentes) => {
      const n = normalizarBusqueda(c.numeroCasa);
      return n === q ? 0 : n.startsWith(q) ? 1 : 2;
    };
    return coincide.sort((a, b) => peso(a) - peso(b)).slice(0, MAX_SUGERENCIAS);
  });

  /** "Otro" del catálogo se reemplaza por "Otra empresa", que sí pide el nombre */
  empresas(): ServicioPaqueteria[] {
    return empresasSeleccionables(this.servicios);
  }

  ngAfterViewInit(): void {
    this.directorio.cargar();
    (this.elemento.nativeElement as HTMLElement).querySelector<HTMLInputElement>('#sin-casa')?.focus();
  }

  @HostListener('document:keydown.escape')
  alPresionarEscape(): void {
    if (!this.isSaving()) this.cerrar();
  }

  nombreDe(r: { nombre: string; apellidos: string }): string {
    return `${r.nombre} ${r.apellidos}`.trim();
  }

  elegirCasa(c: ViviendaConResidentes): void {
    this.casa.set(c);
    // Con una sola persona en la casa se propone su nombre; con varias, quien atiende elige
    this.destinatario = c.residentes.length === 1 ? this.nombreDe(c.residentes[0]) : '';
  }

  cambiarCasa(): void {
    this.casa.set(null);
    this.destinatario = '';
    this.consulta.set('');
    queueMicrotask(() => (this.elemento.nativeElement as HTMLElement).querySelector<HTMLInputElement>('#sin-casa')?.focus());
  }

  reintentarCasas(): void {
    this.directorio.cargar(true);
  }

  elegirEmpresa(valor: number | typeof SERVICIO_OTRO): void {
    // Tocar la empresa ya elegida la quita: la empresa es opcional
    this.empresa = this.empresa === valor ? '' : valor;
  }

  /** Lo que falta para poder guardar, dicho en una frase; null si ya se puede */
  faltante(): string | null {
    if (!this.casa()) return 'Elige la casa para continuar.';
    if (!this.destinatario.trim()) return 'Escribe el nombre que trae el paquete.';
    if (this.empresa === SERVICIO_OTRO && !this.empresaOtra.trim()) return 'Escribe el nombre de la empresa.';
    return null;
  }

  cerrar(): void {
    this.cerrado.emit();
  }

  armarDto(): RecibirPaqueteDto {
    const dto: RecibirPaqueteDto = {
      viviendaId: this.casa()!.id,
      destinatarioNombre: this.destinatario.trim()
    };
    if (this.empresa === SERVICIO_OTRO) dto.servicioNombre = this.empresaOtra.trim();
    else if (this.empresa !== '') dto.servicioId = Number(this.empresa);
    if (this.guia.trim()) dto.numeroGuia = this.guia.trim();
    if (this.descripcion.trim()) dto.descripcion = this.descripcion.trim();
    if (this.ubicacion.trim()) dto.ubicacionAlmacen = this.ubicacion.trim();
    return dto;
  }

  async guardar(): Promise<void> {
    if (this.faltante() || this.isSaving()) return;
    this.isSaving.set(true);
    try {
      const creado = await this.servicio.recibir(this.armarDto());
      this.guardado.emit(creado);
    } catch (err: any) {
      console.error('[PaqueteSinAvisoFormComponent] Error al registrar el paquete:', err);
      Swal.fire({
        icon: 'error',
        title: 'No se pudo guardar el paquete',
        text: mensajeConValidacion(err, 'Intenta de nuevo en unos segundos.'),
        confirmButtonColor: '#111C99'
      });
    } finally {
      this.isSaving.set(false);
    }
  }
}
