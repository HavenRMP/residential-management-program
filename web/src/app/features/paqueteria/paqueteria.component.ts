import { Component, ChangeDetectionStrategy, Injector, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import Swal from 'sweetalert2';
import { AuthService } from '../../core/services/auth.service';
import { ViviendasService } from '../../core/services/viviendas.service';
import { PaqueteriaService } from '../../core/services/paqueteria.service';
import {
  CLASES_ESTADO_PAQUETE,
  ETIQUETAS_ESTADO_PAQUETE,
  Paquete,
  estadoEfectivoPaquete,
  paqueteCoincideConBusqueda,
  puedeModificarPaquete,
  textoVentanaPaquete
} from '../../core/models/paquete.model';
import { formatearFechaVisita } from '../../core/models/visita.model';
import { mensajeAmigable } from '../../core/utils/api-errors.util';
import { autoActualizar } from '../../core/utils/auto-actualizar.util';
import { Vivienda } from '../../core/models/vivienda.model';
import { UserMenuComponent } from '../../core/components/user-menu/user-menu.component';
import { PaqueteFormComponent } from './paquete-form/paquete-form.component';

type Pestana = 'pendientes' | 'historial';

@Component({
  selector: 'app-paqueteria',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, UserMenuComponent, PaqueteFormComponent],
  changeDetection: ChangeDetectionStrategy.Eager,
  template: `
    <div class="min-h-screen bg-[#F8FAFC] text-slate-900 font-sans antialiased">

      <header class="bg-white border-b border-slate-200 sticky top-0 z-30 shadow-2xs">
        <div class="w-full px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <a
              routerLink="/dashboard/residente"
              class="h-8 w-8 inline-flex items-center justify-center text-slate-500 hover:text-slate-900 hover:bg-slate-100 rounded-md transition-colors cursor-pointer"
              title="Volver"
              aria-label="Volver al portal"
              >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
            </a>
            <div class="flex items-center gap-2">
              <span class="font-bold text-base tracking-tight text-slate-900">Paquetería</span>
              <span class="text-[11px] font-medium px-2 py-0.5 rounded-md bg-slate-100 text-slate-700 border border-slate-200">
                Gestión
              </span>
            </div>
          </div>

          <app-user-menu [user]="currentUser()" (logout)="onLogout()" />
        </div>
      </header>

      <main class="w-full px-4 sm:px-6 lg:px-8 py-6 space-y-6">

        <nav aria-label="Ruta de navegación" class="flex items-center gap-2 text-xs text-slate-600 font-medium">
          <a routerLink="/dashboard/residente" class="hover:text-slate-900 transition-colors">Portal</a>
          <span>/</span>
          <span class="text-slate-900">Paquetería</span>
        </nav>
        <h1 class="sr-only">Paquetería</h1>

        <!-- Sin vivienda asignada -->
        @if (!isLoadingVivienda() && viviendas().length === 0) {
          <div class="rounded-lg border border-slate-200 bg-white p-8 text-center shadow-2xs space-y-2">
            <h2 class="text-base font-semibold text-slate-900">Necesitas una vivienda asignada</h2>
            <p class="text-xs text-slate-500 max-w-md mx-auto">
              Vincula tu cuenta a una vivienda desde el portal para poder avisar de tus paquetes.
            </p>
            <a routerLink="/dashboard/residente" class="h-8 px-4 inline-flex items-center justify-center rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs mt-2">
              Volver al portal
            </a>
          </div>
        }

        @if (viviendas().length > 0) {
          <!-- Paquetes que ya esperan en caseta -->
          @if (paqueteriaService.enCaseta().length > 0) {
            <div class="rounded-lg border border-emerald-200 bg-emerald-50 p-4 flex items-start gap-3" role="status">
              <svg class="w-5 h-5 text-emerald-600 shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4" />
              </svg>
              <div>
                <p class="text-sm font-semibold text-emerald-900">
                  {{ paqueteriaService.enCaseta().length === 1 ? 'Tienes 1 paquete en caseta' : 'Tienes ' + paqueteriaService.enCaseta().length + ' paquetes en caseta' }}
                </p>
                <p class="text-xs text-emerald-800 mt-0.5">
                  {{ paqueteriaService.enCaseta().length === 1 ? 'Pasa a recogerlo con vigilancia.' : 'Pasa a recogerlos con vigilancia.' }}
                </p>
              </div>
            </div>
          }

          <section class="rounded-lg border border-slate-200 bg-white p-5 shadow-2xs space-y-4">
            <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
              <div>
                <h2 class="text-sm font-semibold text-slate-900">Mis paquetes</h2>
                <p class="text-xs text-slate-500 mt-0.5">
                  Consulta lo que espera tu vivienda y lo que ya llegó a caseta.
                </p>
              </div>
              <div class="flex items-center gap-2 self-start sm:self-auto">
                <button
                  type="button"
                  (click)="recargar()"
                  [disabled]="paqueteriaService.isLoading()"
                  class="h-8 px-3 inline-flex items-center gap-1.5 rounded-md border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-medium transition-colors shadow-2xs cursor-pointer disabled:opacity-50"
                  >
                  Actualizar
                </button>
                <button
                  type="button"
                  (click)="abrirFormulario()"
                  class="h-8 px-3 inline-flex items-center gap-1.5 rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs cursor-pointer"
                  >
                  <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                  </svg>
                  <span>Avisar un paquete</span>
                </button>
              </div>
            </div>

            <!-- Pestañas y búsqueda -->
            <div class="flex flex-col md:flex-row md:items-center justify-between gap-3">
              <div class="flex items-center gap-1.5" role="tablist" aria-label="Paquetes">
                <button
                  type="button"
                  role="tab"
                  [attr.aria-selected]="pestana() === 'pendientes'"
                  (click)="cambiarPestana('pendientes')"
                  class="h-8 px-3 rounded-md text-xs font-medium border transition-colors cursor-pointer"
                  [ngClass]="pestana() === 'pendientes' ? 'bg-slate-900 text-white border-slate-900' : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'"
                  >
                  Pendientes @if (mostrarConteos()) {({{ paqueteriaService.pendientes().length }})}
                </button>
                <button
                  type="button"
                  role="tab"
                  [attr.aria-selected]="pestana() === 'historial'"
                  (click)="cambiarPestana('historial')"
                  class="h-8 px-3 rounded-md text-xs font-medium border transition-colors cursor-pointer"
                  [ngClass]="pestana() === 'historial' ? 'bg-slate-900 text-white border-slate-900' : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'"
                  >
                  Historial @if (mostrarConteos()) {({{ paqueteriaService.historial().length }})}
                </button>
              </div>
              <div class="relative w-full md:w-80">
                <label for="busqueda-paquetes" class="sr-only">Buscar paquetes</label>
                <input
                  id="busqueda-paquetes"
                  type="search"
                  [ngModel]="busqueda()"
                  (ngModelChange)="busqueda.set($event)"
                  placeholder="Empresa, guía o destinatario..."
                  class="h-9 w-full text-xs rounded-lg border border-slate-300 bg-white px-3 text-slate-900 placeholder-slate-400 focus:outline-hidden focus:ring-2 focus:ring-[#111C99]"
                />
              </div>
            </div>

            @if (paqueteriaService.isLoading() && paqueteriaService.items().length === 0) {
              <div class="space-y-2" aria-hidden="true">
                @for (s of [1, 2]; track s) {
                  <div class="p-4 rounded-md bg-white border border-slate-200 animate-pulse h-20"></div>
                }
              </div>
            }

            @if (paqueteriaService.errorMessage(); as msg) {
              <div class="rounded-md border border-rose-200 bg-rose-50 p-3 text-xs text-rose-700 font-medium flex flex-wrap items-center justify-between gap-2" role="alert">
                <span>{{ msg }}</span>
                <button type="button" (click)="recargar()" class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-100 transition-colors cursor-pointer">
                  Reintentar
                </button>
              </div>
            }

            @if (!paqueteriaService.isLoading() && !paqueteriaService.errorMessage() && listaVisible().length === 0) {
              <div class="py-10 text-center text-xs text-slate-500 font-medium space-y-1">
                @if (busqueda().trim()) {
                  <p>Ningún paquete coincide con «{{ busqueda().trim() }}».</p>
                } @else if (pestana() === 'pendientes') {
                  <p>No tienes paquetes pendientes.</p>
                  <p class="text-slate-500">Cuando esperes un envío, avisa a caseta para que lo reciban de inmediato.</p>
                  <button type="button" (click)="abrirFormulario()" class="mt-2 h-8 px-3 inline-flex items-center rounded-md bg-[#111C99] hover:bg-[#0d1577] text-white text-xs font-medium transition-colors shadow-2xs cursor-pointer">
                    Avisar un paquete
                  </button>
                } @else {
                  <p>Todavía no hay paquetes en tu historial.</p>
                  <p class="text-slate-400">Los paquetes entregados o cancelados se mostrarán aquí.</p>
                }
              </div>
            }

            @if (listaVisible().length > 0) {
              <ul class="grid grid-cols-1 xl:grid-cols-2 gap-2.5 items-start">
                @for (p of listaVisible(); track p.id) {
                  <li
                    class="p-4 rounded-md border bg-white space-y-1.5"
                    [ngClass]="estadoDe(p) === 'recibido' ? 'border-emerald-300' : 'border-slate-200'"
                    >
                    <div class="flex flex-wrap items-center gap-2">
                      <p class="text-sm font-semibold text-slate-900">{{ p.servicioNombre || 'Paquete' }}</p>
                      <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border" [ngClass]="claseEstado(p)">
                        {{ etiquetaEstado(p) }}
                      </span>
                      @if (p.esInesperado) {
                        <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-amber-50 text-amber-700 border-amber-200">
                          Llegó sin avisar
                        </span>
                      }
                      @if (viviendas().length > 1 && p.numeroCasa) {
                        <span class="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-medium border bg-slate-50 text-slate-600 border-slate-200">
                          Casa {{ p.numeroCasa }}
                        </span>
                      }
                    </div>
                    <p class="text-xs text-slate-600">
                      Para {{ p.destinatarioNombre }}@if (p.numeroGuia) {
                        <span> · Guía {{ p.numeroGuia }}</span>
                      }
                    </p>
                    @if (p.descripcion) {
                      <p class="text-xs text-slate-500">{{ p.descripcion }}</p>
                    }
                    @if (ventana(p); as texto) {
                      <p class="text-xs text-slate-500">Lo esperas: {{ texto }}</p>
                    }
                    @if (p.notas) {
                      <p class="text-xs text-slate-500 italic">{{ p.notas }}</p>
                    }
                    @if (p.recibidoEn) {
                      <p class="text-xs text-slate-600">
                        En caseta desde {{ formatearFecha(p.recibidoEn) }}@if (p.ubicacionAlmacen) {
                          <span> · Ubicación: {{ p.ubicacionAlmacen }}</span>
                        }
                      </p>
                    }
                    @if (p.entregadoEn) {
                      <p class="text-xs text-slate-600">
                        Entregado{{ p.entregadoANombre ? ' a ' + p.entregadoANombre : '' }} el {{ formatearFecha(p.entregadoEn) }}
                      </p>
                    }
                    @if (estadoDe(p) === 'vencido') {
                      <p class="text-xs text-amber-700">La fecha en que lo esperabas ya pasó.</p>
                    }
                    @if (puedeModificar(p)) {
                      <div class="flex items-center gap-1.5 pt-1">
                        <button
                          type="button"
                          (click)="abrirFormulario(p)"
                          [attr.aria-label]="'Editar el paquete de ' + (p.servicioNombre || 'tu pedido')"
                          class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-slate-200 text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
                          >
                          Editar
                        </button>
                        <button
                          type="button"
                          (click)="confirmarCancelar(p)"
                          [attr.aria-label]="'Cancelar el aviso del paquete de ' + (p.servicioNombre || 'tu pedido')"
                          class="h-7 px-2.5 text-[11px] font-medium rounded-md border border-rose-200 text-rose-700 hover:bg-rose-50 transition-colors cursor-pointer"
                          >
                          Cancelar
                        </button>
                      </div>
                    }
                  </li>
                }
              </ul>
            }
          </section>
        }
      </main>
    </div>

    @if (formularioAbierto()) {
      <app-paquete-form
        [viviendas]="viviendas()"
        [viviendaInicial]="viviendas()[0]?.id ?? null"
        [servicios]="paqueteriaService.servicios()"
        [nombreSugerido]="nombreSugerido()"
        [paquete]="paqueteEditando()"
        (cerrado)="cerrarFormulario()"
        (guardado)="alGuardar()"
        (obsoleto)="alObsoleto()"
      />
    }
  `
})
export class PaqueteriaComponent implements OnInit {
  private readonly authService = inject(AuthService);
  private readonly viviendasService = inject(ViviendasService);
  readonly paqueteriaService = inject(PaqueteriaService);
  private readonly injector = inject(Injector);

  readonly currentUser = this.authService.currentUser;

  readonly isLoadingVivienda = signal<boolean>(true);
  readonly viviendas = signal<Vivienda[]>([]);
  readonly pestana = signal<Pestana>('pendientes');
  readonly busqueda = signal<string>('');
  readonly formularioAbierto = signal<boolean>(false);
  /** Paquete que se está corrigiendo; null cuando el formulario da de alta un aviso nuevo */
  readonly paqueteEditando = signal<Paquete | null>(null);

  /** Nombre de quien avisa; es el destinatario más común */
  readonly nombreSugerido = computed(() => {
    const u = this.currentUser();
    return [u?.nombre, u?.apellidos].filter(Boolean).join(' ');
  });

  /** Mientras llegan los primeros datos los contadores dirían "(0)" sin ser cierto, así que se ocultan */
  readonly mostrarConteos = computed(() => !(this.paqueteriaService.isLoading() && this.paqueteriaService.items().length === 0));

  /** Lista de la pestaña activa, ya filtrada por la búsqueda */
  readonly listaVisible = computed(() => {
    const base = this.pestana() === 'pendientes' ? this.paqueteriaService.pendientes() : this.paqueteriaService.historial();
    return base.filter(p => paqueteCoincideConBusqueda(p, this.busqueda()));
  });

  async ngOnInit(): Promise<void> {
    this.isLoadingVivienda.set(true);
    try {
      this.viviendas.set(await this.viviendasService.obtenerMisViviendas());
      if (this.viviendas().length > 0) {
        // El catálogo se pide en paralelo para que ya esté listo cuando se abra el formulario
        void this.paqueteriaService.cargarServicios();
        await this.paqueteriaService.cargar();
        // Los paquetes que registra la caseta aparecen solos, sin tocar "Actualizar"
        autoActualizar(this.injector, () => void this.paqueteriaService.cargar(true));
      }
    } finally {
      this.isLoadingVivienda.set(false);
    }
  }

  onLogout(): void {
    this.authService.logout();
  }

  cambiarPestana(pestana: Pestana): void {
    this.pestana.set(pestana);
  }

  async recargar(): Promise<void> {
    await this.paqueteriaService.cargar();
  }

  /** Sin paquete abre el aviso nuevo; con paquete, la corrección de ese aviso */
  abrirFormulario(paquete?: Paquete): void {
    // Si el catálogo no alcanzó a cargar se vuelve a pedir; si ya está, no se repite
    if (this.paqueteriaService.servicios().length === 0) void this.paqueteriaService.cargarServicios();
    this.paqueteEditando.set(paquete ?? null);
    this.formularioAbierto.set(true);
  }

  cerrarFormulario(): void {
    this.formularioAbierto.set(false);
    this.paqueteEditando.set(null);
  }

  /** El paquete ya cambió en caseta: se cierra el formulario y se trae la lista al día */
  alObsoleto(): void {
    this.cerrarFormulario();
    void this.recargar();
  }

  /** Cancelar o corregir solo aplica a un aviso vigente que aún no llegó a caseta */
  puedeModificar(p: Paquete): boolean {
    return puedeModificarPaquete(p);
  }

  async confirmarCancelar(p: Paquete): Promise<void> {
    const resultado = await Swal.fire({
      title: '¿Cancelar este aviso?',
      text: 'Caseta ya no esperará este paquete.',
      icon: 'warning',
      input: 'text',
      inputPlaceholder: 'Motivo (opcional)',
      inputAttributes: { maxlength: '200', 'aria-label': 'Motivo de la cancelación (opcional)' },
      showCancelButton: true,
      confirmButtonColor: '#EF4444',
      cancelButtonColor: '#64748B',
      confirmButtonText: 'Cancelar aviso',
      cancelButtonText: 'Volver'
    });
    if (!resultado.isConfirmed) return;

    try {
      await this.paqueteriaService.cancelar(p.id, typeof resultado.value === 'string' ? resultado.value : undefined);
      Swal.fire({ toast: true, position: 'top-end', icon: 'success', title: 'Aviso cancelado', showConfirmButton: false, timer: 2500 });
    } catch (err: any) {
      console.error('[PaqueteriaComponent] Error al cancelar el aviso:', err);
      const yaNoSePuede = err?.status === 404 || err?.status === 409;
      Swal.fire({
        icon: yaNoSePuede ? 'info' : 'error',
        title: yaNoSePuede ? 'Este paquete ya cambió' : 'No se pudo cancelar',
        text: yaNoSePuede
          ? 'Ya no se puede cancelar, por ejemplo porque llegó a caseta. Actualizamos tu lista.'
          : mensajeAmigable(err, 'No fue posible cancelar el aviso. Intenta de nuevo en unos segundos.'),
        confirmButtonColor: '#111C99'
      });
      if (yaNoSePuede) await this.recargar();
    }
  }

  /** El aviso nuevo es un paquete esperado: se muestra en Pendientes */
  alGuardar(): void {
    this.cerrarFormulario();
    this.pestana.set('pendientes');
    this.busqueda.set('');
  }

  /** Estado que se muestra: un esperado cuya ventana ya pasó figura como vencido aunque el backend aún no lo marque */
  estadoDe(p: Paquete) {
    return estadoEfectivoPaquete(p);
  }

  etiquetaEstado(p: Paquete): string {
    return ETIQUETAS_ESTADO_PAQUETE[estadoEfectivoPaquete(p)] ?? p.estado;
  }

  claseEstado(p: Paquete): string {
    return CLASES_ESTADO_PAQUETE[estadoEfectivoPaquete(p)] ?? 'bg-slate-100 text-slate-700 border-slate-200';
  }

  ventana(p: Paquete): string {
    return textoVentanaPaquete(p);
  }

  formatearFecha(iso: string | null | undefined): string {
    return formatearFechaVisita(iso);
  }
}
