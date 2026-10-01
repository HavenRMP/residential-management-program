import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { signal } from '@angular/core';
import Swal from 'sweetalert2';
import { VisitasComponent } from './visitas.component';
import { VisitasService } from '../../core/services/visitas.service';
import { ViviendasService } from '../../core/services/viviendas.service';
import { AuthService } from '../../core/services/auth.service';
import { Visita } from '../../core/models/visita.model';

const visita: Visita = {
  id: 'v-1',
  viviendaId: 33,
  numeroCasa: 'PRUEBA-01',
  nombreVisitante: 'Juan',
  apellidosVisitante: 'Pérez',
  motivo: 'personal',
  numAcompanantes: 0,
  fechaLlegadaEsperada: '2026-10-01T15:00:00Z',
  vigenciaHasta: '2026-10-02T15:00:00Z',
  codigo: 'ABC123',
  estado: 'programada',
  creadoEn: '2026-09-30T10:00:00Z'
};

describe('VisitasComponent (código de acceso)', () => {
  let component: VisitasComponent;
  let clipboard: jasmine.Spy;

  beforeEach(() => {
    spyOn(Swal, 'fire').and.returnValue(Promise.resolve({} as any));
    clipboard = jasmine.createSpy('writeText').and.returnValue(Promise.resolve());
    spyOnProperty(navigator, 'clipboard', 'get').and.returnValue({ writeText: clipboard } as unknown as Clipboard);

    TestBed.configureTestingModule({
      imports: [VisitasComponent],
      providers: [
        provideRouter([]),
        {
          provide: VisitasService,
          useValue: {
            PAGE_SIZE: 10,
            items: signal([visita]),
            totalCount: signal(1),
            page: signal(1),
            isLoading: signal(false),
            errorMessage: signal(null),
            cargar: jasmine.createSpy('cargar')
          }
        },
        { provide: ViviendasService, useValue: { obtenerMisViviendas: () => Promise.resolve([{ id: 33 }]) } },
        { provide: AuthService, useValue: { currentUser: signal(null), logout: () => undefined } }
      ]
    });

    component = TestBed.createComponent(VisitasComponent).componentInstance;
  });

  it('copia solo el código al portapapeles', async () => {
    await component.copiarCodigo(visita);

    expect(clipboard).toHaveBeenCalledOnceWith('ABC123');
  });

  it('usa el diálogo nativo de compartir con un mensaje que incluye el código y la casa', async () => {
    const share = jasmine.createSpy('share').and.returnValue(Promise.resolve());
    Object.defineProperty(navigator, 'share', { value: share, configurable: true });

    await component.compartirCodigo(visita);

    const datos = share.calls.mostRecent().args[0] as { text: string };
    expect(datos.text).toContain('ABC123');
    expect(datos.text).toContain('PRUEBA-01');
    expect(clipboard).not.toHaveBeenCalled();
    delete (navigator as any).share;
  });

  it('sin diálogo nativo de compartir copia el mensaje completo', async () => {
    // Chrome define share en el prototipo: se sombrea con undefined para simular escritorio sin Web Share API
    Object.defineProperty(navigator, 'share', { value: undefined, configurable: true });

    await component.compartirCodigo(visita);

    expect(clipboard.calls.mostRecent().args[0]).toContain('ABC123');
    delete (navigator as any).share;
  });

  it('no hace nada si la visita no tiene código', async () => {
    await component.copiarCodigo({ ...visita, codigo: null });

    expect(clipboard).not.toHaveBeenCalled();
  });

  it('muestra el QR del código con un diálogo que incluye la imagen', () => {
    component.verQr(visita);

    const opciones = (Swal.fire as unknown as jasmine.Spy).calls.mostRecent().args[0] as { imageUrl: string; text: string };
    expect(opciones.imageUrl).toMatch(/^data:image\/svg\+xml/);
    expect(opciones.text).toContain('ABC123');
  });

  it('no abre el QR si la visita no tiene código', () => {
    component.verQr({ ...visita, codigo: null });

    expect(Swal.fire).not.toHaveBeenCalled();
  });
});

describe('VisitasComponent (fecha y vigencia)', () => {
  let component: VisitasComponent;

  const enHoras = (h: number) => {
    const d = new Date(Date.now() + h * 3_600_000);
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [VisitasComponent],
      providers: [
        provideRouter([]),
        {
          provide: VisitasService,
          useValue: {
            PAGE_SIZE: 10, items: signal([]), totalCount: signal(0), page: signal(1),
            isLoading: signal(false), errorMessage: signal(null), cargar: jasmine.createSpy('cargar')
          }
        },
        { provide: ViviendasService, useValue: { obtenerMisViviendas: () => Promise.resolve([{ id: 33 }]) } },
        { provide: AuthService, useValue: { currentUser: signal(null), logout: () => undefined } }
      ]
    });
    component = TestBed.createComponent(VisitasComponent).componentInstance;
    component.form = {
      ...component.form, nombreVisitante: 'Juan', apellidosVisitante: 'Pérez', motivo: 'personal',
      numAcompanantes: 0, horasVigencia: 24
    };
  });

  it('bloquea una visita cuya llegada más vigencia ya pasó', () => {
    component.form.fechaLlegada = enHoras(-48);

    expect(component.visitaYaVencida()).toBeTrue();
    expect(component.esFormularioValido()).toBeFalse();
  });

  it('permite una llegada pasada si la vigencia sigue abierta', () => {
    component.form.fechaLlegada = enHoras(-2);

    expect(component.visitaYaVencida()).toBeFalse();
    expect(component.esFormularioValido()).toBeTrue();
  });

  it('permite una llegada futura', () => {
    component.form.fechaLlegada = enHoras(5);

    expect(component.visitaYaVencida()).toBeFalse();
    expect(component.esFormularioValido()).toBeTrue();
  });

  it('sin fecha no marca vencida pero el formulario tampoco es válido', () => {
    component.form.fechaLlegada = '';

    expect(component.visitaYaVencida()).toBeFalse();
    expect(component.esFormularioValido()).toBeFalse();
  });
});
