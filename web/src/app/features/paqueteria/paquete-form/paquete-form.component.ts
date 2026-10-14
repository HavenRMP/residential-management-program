import { AfterViewInit, ChangeDetectionStrategy, Component, ElementRef, EventEmitter, HostListener, Input, OnChanges, OnInit, Output, SimpleChanges, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { PaqueteriaService } from '../../../core/services/paqueteria.service';
import { ActualizarPaqueteDto, CrearPaqueteDto, LIMITES_PAQUETE, Paquete, SERVICIO_OTRO, ServicioPaqueteria, empresasSeleccionables } from '../../../core/models/paquete.model';
import { rangoFechasInvalido, rangoFechasIso } from '../../../core/models/visita.model';
import { Vivienda } from '../../../core/models/vivienda.model';
import { mensajeAmigable } from '../../../core/utils/api-errors.util';

interface FormularioPaquete {
  viviendaId: number;
  destinatarioNombre: string;
  /** '' sin elegir, el id de una empresa del catálogo o SERVICIO_OTRO */
  servicio: '' | number | typeof SERVICIO_OTRO;
  servicioOtro: string;
  numeroGuia: string;
  descripcion: string;
  notas: string;
  /** Cómo se avisa la llegada: sin fecha, un día específico o varios días */
  cuando: CuandoLlega;
  /** Valores de inputs type="date" (yyyy-MM-dd, hora local) */
  dia: string;
  desde: string;
  hasta: string;
}

export type CuandoLlega = 'sin' | 'dia' | 'rango';

/** Fecha en formato yyyy-MM-dd de la hora local, el que usan los inputs de fecha */
function aFechaInput(d: Date): string {
  const pad = (n: number) => n.toString().padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function isoAFechaInput(iso: string | null | undefined): string {
  if (!iso) return '';
  const d = new Date(iso);
  return isNaN(d.getTime()) || d.getFullYear() < 2000 ? '' : aFechaInput(d);
}

@Component({
  selector: 'app-paquete-form',
  standalone: true,
  imports: [CommonModule, FormsModule],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="fixed inset-0 z-50 overflow-y-auto bg-black/40 backdrop-blur-xs flex items-center justify-center p-4">
      <div
        class="bg-white rounded-lg max-w-lg w-full p-5 shadow-lg border border-slate-200"
        role="dialog"
        aria-modal="true"
        aria-labelledby="paquete-form-titulo"
        >
        <div class="flex items-center justify-between pb-3 border-b border-slate-100">
          <h3 id="paquete-form-titulo" class="text-sm font-semibold text-slate-900">{{ paquete ? 'Editar paquete' : 'Avisar un paquete' }}</h3>
          <button type="button" (click)="cerrar()" aria-label="Cerrar" class="text-slate-400 hover:text-slate-600 p-1 rounded cursor-pointer">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="mt-3.5 space-y-3">
          @if (viviendas.length > 1 && !paquete) {
            <div>
              <label for="paq-vivienda" class="block text-xs font-semibold text-slate-800 mb-1">Vivienda *</label>
              <select id="paq-vivienda" [(ngModel)]="form.viviendaId"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
                @for (viv of viviendas; track viv.id) {
                  <option [ngValue]="viv.id">{{ viv.numeroCasa }}</option>
                }
              </select>
            </div>
          }

          <div>
            <label for="paq-destinatario" class="block text-xs font-semibold text-slate-800 mb-1">Nombre del destinatario *</label>
            <input id="paq-destinatario" type="text" [(ngModel)]="form.destinatarioNombre" [attr.maxlength]="limites.destinatario" placeholder="Como aparece en el paquete"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            <p class="mt-1 text-[11px] text-slate-500">Caseta lo busca con este nombre.</p>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label for="paq-servicio" class="block text-xs font-semibold text-slate-800 mb-1">Empresa de paquetería *</label>
              <select id="paq-servicio" [(ngModel)]="form.servicio"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]">
                <option [ngValue]="''">Selecciona una empresa</option>
                @for (s of empresas(); track s.id) {
                  <option [ngValue]="s.id">{{ s.nombre }}</option>
                }
                <option [ngValue]="otro">Otra empresa</option>
              </select>
            </div>
            <div>
              <label for="paq-guia" class="block text-xs font-semibold text-slate-800 mb-1">Número de guía</label>
              <input id="paq-guia" type="text" [(ngModel)]="form.numeroGuia" [attr.maxlength]="limites.guia" placeholder="Opcional"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
          </div>

          @if (usaOtraEmpresa()) {
            <div>
              <label for="paq-otra" class="block text-xs font-semibold text-slate-800 mb-1">Nombre de la empresa *</label>
              <input id="paq-otra" type="text" [(ngModel)]="form.servicioOtro" [attr.maxlength]="limites.servicio" placeholder="Escribe el nombre de la empresa"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
          }

          <div>
            <label for="paq-descripcion" class="block text-xs font-semibold text-slate-800 mb-1">Descripción</label>
            <input id="paq-descripcion" type="text" [(ngModel)]="form.descripcion" [attr.maxlength]="limites.descripcion" placeholder="Ej. Caja mediana con zapatos"
              class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
          </div>

          <fieldset>
            <legend class="block text-xs font-semibold text-slate-800 mb-1">¿Cuándo llega?</legend>
            <div class="grid grid-cols-3 gap-1.5" role="radiogroup">
              @for (op of opcionesCuando; track op.valor) {
                <button type="button" role="radio" [attr.aria-checked]="form.cuando === op.valor" (click)="elegirCuando(op.valor)"
                  class="h-9 px-2 text-xs font-medium rounded-lg border transition-colors cursor-pointer focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-[#111C99]"
                  [ngClass]="form.cuando === op.valor ? 'border-[#111C99] bg-[#111C99] text-white' : 'border-slate-300 bg-white text-slate-700 hover:bg-slate-50'">
                  {{ op.texto }}
                </button>
              }
            </div>
          </fieldset>

          @if (form.cuando === 'dia') {
            <div>
              <label for="paq-dia" class="block text-xs font-semibold text-slate-800 mb-1">Día en que llega *</label>
              <input id="paq-dia" type="date" [(ngModel)]="form.dia" [min]="hoy"
                class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
            </div>
          } @else if (form.cuando === 'rango') {
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label for="paq-desde" class="block text-xs font-semibold text-slate-800 mb-1">Llega a partir del *</label>
                <input id="paq-desde" type="date" [(ngModel)]="form.desde" [min]="hoy"
                  class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
              </div>
              <div>
                <label for="paq-hasta" class="block text-xs font-semibold text-slate-800 mb-1">A más tardar el *</label>
                <input id="paq-hasta" type="date" [(ngModel)]="form.hasta" [min]="hoy"
                  class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]" />
              </div>
            </div>
          }
          @if (fechasInvertidas()) {
            <p class="text-[11px] text-red-600 font-medium" role="alert">La fecha de inicio no puede ser posterior a la última.</p>
          } @else if (hastaPasada()) {
            <p class="text-[11px] text-red-600 font-medium" role="alert">La fecha ya pasó. Elige hoy o un día posterior.</p>
          } @else if (form.cuando === 'sin') {
            <p class="text-[11px] text-slate-500">Si no sabes cuándo llega, puedes avisar igual. Caseta lo registra cuando llegue.</p>
          } @else {
            <p class="text-[11px] text-slate-500">Después de {{ form.cuando === 'dia' ? 'ese día' : 'la última fecha' }} el aviso se marca como vencido.</p>
          }

          <div>
            <label for="paq-notas" class="block text-xs font-semibold text-slate-800 mb-1">Notas para caseta</label>
            <textarea id="paq-notas" [(ngModel)]="form.notas" rows="2" placeholder="Ej. Si llega después de las 7 pm, favor de resguardarlo"
              class="w-full text-xs rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"></textarea>
          </div>

          <div class="pt-3 border-t border-slate-100 flex items-center justify-end gap-2">
            <button type="button" (click)="cerrar()"
              class="h-8 px-3 text-xs font-medium text-slate-600 hover:bg-slate-100 rounded-md transition-colors cursor-pointer">
              Cancelar
            </button>
            <button type="button" (click)="guardar()" [disabled]="isSaving() || !esFormularioValido() || (paquete && !hayCambios())"
              class="h-8 px-3.5 bg-[#111C99] hover:bg-[#0d1577] text-white rounded-md text-xs font-medium shadow-2xs transition-colors cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">
              {{ isSaving() ? 'Guardando...' : (paquete ? 'Guardar cambios' : 'Avisar a caseta') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  `
})
export class PaqueteFormComponent implements OnInit, OnChanges, AfterViewInit {
  private readonly paqueteriaService = inject(PaqueteriaService);
  private readonly elemento = inject(ElementRef<HTMLElement>);

  @Input() viviendas: Vivienda[] = [];
  @Input() servicios: ServicioPaqueteria[] = [];
  /** Nombre que se propone como destinatario (el de la persona que avisa) */
  @Input() set nombreSugerido(nombre: string) {
    if (!this.form.destinatarioNombre) this.form.destinatarioNombre = nombre;
  }
  @Input() set viviendaInicial(id: number | null) {
    if (id) this.form.viviendaId = id;
  }
  /** Paquete esperado que se corrige; sin él el formulario da de alta un aviso nuevo */
  @Input() paquete: Paquete | null = null;

  @Output() cerrado = new EventEmitter<void>();
  @Output() guardado = new EventEmitter<Paquete>();
  /** El paquete ya cambió en caseta (o no existe): quien abrió el formulario debe refrescar su lista */
  @Output() obsoleto = new EventEmitter<void>();

  readonly limites = LIMITES_PAQUETE;
  readonly otro = SERVICIO_OTRO;
  readonly hoy = aFechaInput(new Date());
  readonly opcionesCuando: { valor: CuandoLlega; texto: string }[] = [
    { valor: 'sin', texto: 'No sé cuándo' },
    { valor: 'dia', texto: 'Un día' },
    { valor: 'rango', texto: 'Varios días' }
  ];
  readonly isSaving = signal<boolean>(false);

  form: FormularioPaquete = {
    viviendaId: 0,
    destinatarioNombre: '',
    servicio: '',
    servicioOtro: '',
    numeroGuia: '',
    descripcion: '',
    notas: '',
    cuando: 'sin',
    dia: '',
    desde: '',
    hasta: ''
  };

  /** Selección de empresa que se puso sola al abrir; si la persona la cambia ya no se vuelve a tocar */
  private servicioAutomatico: FormularioPaquete['servicio'] = '';

  ngOnInit(): void {
    const p = this.paquete;
    if (!p) return;
    this.form.destinatarioNombre = p.destinatarioNombre;
    this.form.servicioOtro = p.servicioNombre ?? '';
    this.form.numeroGuia = p.numeroGuia ?? '';
    this.form.descripcion = p.descripcion ?? '';
    this.form.notas = p.notas ?? '';
    const desde = isoAFechaInput(p.fechaEsperadaDesde);
    const hasta = isoAFechaInput(p.fechaEsperadaHasta);
    this.form.desde = desde;
    this.form.hasta = hasta;
    // Un aviso cuyo inicio y fin caen el mismo día se muestra como "un día"
    if (desde && desde === hasta) {
      this.form.cuando = 'dia';
      this.form.dia = desde;
    } else if (desde || hasta) {
      this.form.cuando = 'rango';
    }
    this.resolverServicio();
  }

  ngOnChanges(cambios: SimpleChanges): void {
    // El catálogo puede llegar después de abrir el formulario
    if (cambios['servicios'] && this.paquete) this.resolverServicio();
  }

  /** Marca en el selector la empresa del paquete: la del catálogo si coincide, o "otra" con su nombre */
  private resolverServicio(): void {
    const p = this.paquete;
    if (!p || this.form.servicio !== this.servicioAutomatico) return;
    const nombre = (p.servicioNombre ?? '').trim().toLowerCase();
    const delCatalogo = this.empresas().find(s => s.id === p.servicioId) ?? this.empresas().find(s => !!nombre && s.nombre.toLowerCase() === nombre);
    const seleccion: FormularioPaquete['servicio'] = delCatalogo ? delCatalogo.id : p.servicioNombre ? SERVICIO_OTRO : '';
    this.form.servicio = seleccion;
    this.servicioAutomatico = seleccion;
  }

  ngAfterViewInit(): void {
    (this.elemento.nativeElement as HTMLElement).querySelector<HTMLInputElement>('#paq-destinatario')?.focus();
  }

  @HostListener('document:keydown.escape')
  alPresionarEscape(): void {
    if (!this.isSaving()) this.cerrar();
  }

  /** Empresas del catálogo que se ofrecen; "Otro" del catálogo se reemplaza por "Otra empresa" */
  empresas(): ServicioPaqueteria[] {
    return empresasSeleccionables(this.servicios);
  }

  /** Si el catálogo no cargó solo se puede escribir la empresa */
  usaOtraEmpresa(): boolean {
    return this.form.servicio === SERVICIO_OTRO || this.empresas().length === 0;
  }

  elegirCuando(cuando: CuandoLlega): void {
    this.form.cuando = cuando;
  }

  /** Inicio de la ventana según lo elegido: con "un día" el inicio y el fin son el mismo día */
  desdeElegido(): string {
    return this.form.cuando === 'dia' ? this.form.dia : this.form.cuando === 'rango' ? this.form.desde : '';
  }

  hastaElegido(): string {
    return this.form.cuando === 'dia' ? this.form.dia : this.form.cuando === 'rango' ? this.form.hasta : '';
  }

  fechasInvertidas(): boolean {
    return rangoFechasInvalido(this.desdeElegido(), this.hastaElegido());
  }

  /** El backend rechaza una fecha límite que ya pasó */
  hastaPasada(): boolean {
    const hasta = this.hastaElegido();
    return !!hasta && hasta < this.hoy;
  }

  /** "Un día" exige el día; "varios días" exige el inicio y el fin */
  fechasCompletas(): boolean {
    if (this.form.cuando === 'dia') return !!this.form.dia;
    if (this.form.cuando === 'rango') return !!this.form.desde && !!this.form.hasta;
    return true;
  }

  esFormularioValido(): boolean {
    const f = this.form;
    const destinatario = f.destinatarioNombre.trim();
    const empresaValida = this.usaOtraEmpresa() ? !!f.servicioOtro.trim() : f.servicio !== '';
    return (
      (!!this.paquete || this.viviendas.length <= 1 || f.viviendaId > 0) &&
      destinatario.length > 0 &&
      destinatario.length <= LIMITES_PAQUETE.destinatario &&
      empresaValida &&
      this.fechasCompletas() &&
      !this.fechasInvertidas() &&
      !this.hastaPasada()
    );
  }

  cerrar(): void {
    this.cerrado.emit();
  }

  /** Cuerpo del aviso: solo lleva los campos que la persona llenó */
  armarDto(): CrearPaqueteDto {
    const f = this.form;
    const dto: CrearPaqueteDto = {
      viviendaId: f.viviendaId || this.viviendas[0]?.id || 0,
      destinatarioNombre: f.destinatarioNombre.trim()
    };
    if (this.usaOtraEmpresa()) dto.servicioNombre = f.servicioOtro.trim();
    else dto.servicioId = Number(f.servicio);
    if (f.numeroGuia.trim()) dto.numeroGuia = f.numeroGuia.trim();
    if (f.descripcion.trim()) dto.descripcion = f.descripcion.trim();
    if (f.notas.trim()) dto.notas = f.notas.trim();
    const rango = rangoFechasIso(this.desdeElegido(), this.hastaElegido());
    if (rango.desde) dto.fechaEsperadaDesde = rango.desde;
    if (rango.hasta) dto.fechaEsperadaHasta = rango.hasta;
    return dto;
  }

  /** Solo los campos que la persona cambió respecto al paquete que abrió */
  armarCambios(): ActualizarPaqueteDto {
    const o = this.paquete;
    if (!o) return {};
    const f = this.form;
    const cambios: ActualizarPaqueteDto = {};
    if (f.destinatarioNombre.trim() !== o.destinatarioNombre) cambios.destinatarioNombre = f.destinatarioNombre.trim();
    if (this.usaOtraEmpresa()) {
      if (f.servicioOtro.trim() !== (o.servicioNombre ?? '')) cambios.servicioNombre = f.servicioOtro.trim();
    } else if (f.servicio !== '' && Number(f.servicio) !== o.servicioId) {
      cambios.servicioId = Number(f.servicio);
    }
    if (f.numeroGuia.trim() !== (o.numeroGuia ?? '')) cambios.numeroGuia = f.numeroGuia.trim();
    if (f.descripcion.trim() !== (o.descripcion ?? '')) cambios.descripcion = f.descripcion.trim();
    if (f.notas.trim() !== (o.notas ?? '')) cambios.notas = f.notas.trim();
    // Una fecha vacía no se envía: el backend entiende "sin dato" como "no cambiar"
    const desde = this.desdeElegido();
    const hasta = this.hastaElegido();
    const rango = rangoFechasIso(desde, hasta);
    if (desde && desde !== isoAFechaInput(o.fechaEsperadaDesde)) cambios.fechaEsperadaDesde = rango.desde;
    if (hasta && hasta !== isoAFechaInput(o.fechaEsperadaHasta)) cambios.fechaEsperadaHasta = rango.hasta;
    return cambios;
  }

  hayCambios(): boolean {
    return Object.keys(this.armarCambios()).length > 0;
  }

  async guardar(): Promise<void> {
    if (!this.esFormularioValido() || this.isSaving()) return;
    this.isSaving.set(true);
    try {
      if (this.paquete) {
        const actualizado = await this.paqueteriaService.actualizar(this.paquete.id, this.armarCambios());
        this.guardado.emit(actualizado);
        Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Paquete actualizado', showConfirmButton: false, timer: 2500 });
      } else {
        const creado = await this.paqueteriaService.crear(this.armarDto());
        this.guardado.emit(creado);
        Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Aviso enviado a caseta', showConfirmButton: false, timer: 2500 });
      }
    } catch (err: any) {
      console.error('[PaqueteFormComponent] Error al guardar el paquete:', err);
      const yaNoSePuede = !!this.paquete && (err?.status === 404 || err?.status === 409);
      Swal.fire({
        icon: yaNoSePuede ? 'info' : 'error',
        title: yaNoSePuede ? 'Este paquete ya cambió' : this.paquete ? 'No se pudo guardar el paquete' : 'No se pudo avisar el paquete',
        text: yaNoSePuede
          ? 'Ya no se puede modificar, por ejemplo porque llegó a caseta. Actualizamos tu lista.'
          : this.mensajeError(err),
        confirmButtonColor: '#111C99'
      });
      if (yaNoSePuede) this.obsoleto.emit();
    } finally {
      this.isSaving.set(false);
    }
  }

  /** Mensaje del backend: su { error } o el primer error de validación de ModelState */
  private mensajeError(err: any): string {
    const errores = err?.error?.errors;
    if (!err?.error?.error && errores && typeof errores === 'object') {
      const primero = Object.values(errores)[0] as string[] | undefined;
      if (primero?.[0]) return primero[0];
    }
    return mensajeAmigable(err, 'No fue posible enviar el aviso. Intenta de nuevo en unos segundos.');
  }
}
