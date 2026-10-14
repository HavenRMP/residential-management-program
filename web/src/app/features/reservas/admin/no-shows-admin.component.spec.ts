import { ComponentFixture, TestBed } from '@angular/core/testing';
import { HttpParams } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { NoShowsAdminComponent } from './no-shows-admin.component';
import { ApiService } from '../../../core/services/api.service';
import { ReservasAdminService } from '../../../core/services/reservas-admin.service';
import { NoShow } from '../../../core/models/reserva.model';

const noShow = (id: string): NoShow => ({
  id, areaId: 'a1', areaNombre: 'Salón de usos múltiples', inicio: '2026-10-21T16:00:00Z', fin: '2026-10-21T18:00:00Z',
  titularId: 't1', titularNombre: 'Residente', titularApellidos: 'Prueba', viviendaId: 1, numeroCasa: 'A-12',
  solicitanteId: 's1', solicitanteNombre: 'Luis', solicitanteApellidos: 'Prueba'
});

describe('NoShowsAdminComponent', () => {
  let fixture: ComponentFixture<NoShowsAdminComponent>;
  let component: NoShowsAdminComponent;
  let api: jasmine.SpyObj<ApiService>;
  let items: NoShow[];
  let total: number;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const filas = () => Array.from(fixture.nativeElement.querySelectorAll('tbody tr') as NodeListOf<HTMLElement>);

  async function abrir(): Promise<void> {
    fixture = TestBed.createComponent(NoShowsAdminComponent);
    component = fixture.componentInstance;
    TestBed.inject(ReservasAdminService).areas.set([{ id: 'a1', nombre: 'Salón', horaApertura: '08:00:00', horaCierre: '22:00:00', zonaHoraria: 'America/Mexico_City', activo: true }]);
    fixture.detectChanges();
    await fixture.whenStable();
    await new Promise(r => setTimeout(r));
    fixture.detectChanges();
  }

  beforeEach(() => {
    items = [];
    total = 0;
    api = jasmine.createSpyObj('ApiService', ['get']);
    api.get.and.callFake((() => of({ items, totalCount: total || items.length })) as any);
    TestBed.configureTestingModule({ imports: [NoShowsAdminComponent], providers: [{ provide: ApiService, useValue: api }] });
  });

  it('muestra cada inasistencia con área, horario, vivienda, titular y quien solicitó', async () => {
    items = [noShow('n1')];
    await abrir();

    const fila = filas()[0].textContent!.replace(/\s+/g, ' ');
    expect(fila).toContain('Salón de usos múltiples');
    expect(fila).toContain('10:00 a 12:00');
    expect(fila).toContain('A-12');
    expect(fila).toContain('Residente Prueba');
    expect(fila).toContain('Luis Prueba');
  });

  it('sin inasistencias lo dice con claridad', async () => {
    await abrir();

    expect(texto()).toContain('Ninguna reserva se ha marcado como no utilizada.');
  });

  it('si falla muestra el error y Reintentar vuelve a pedir la misma página', async () => {
    spyOn(console, 'error');
    api.get.and.returnValue(throwError(() => ({ status: 500 })));
    await abrir();
    expect(texto()).toContain('No se pudo cargar el historial de inasistencias.');

    items = [noShow('n1')];
    api.get.and.callFake((() => of({ items, totalCount: 1 })) as any);
    (Array.from(fixture.nativeElement.querySelectorAll('button')) as HTMLButtonElement[]).find(b => b.textContent!.includes('Reintentar'))!.click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(filas().length).toBe(1);
  });

  it('con varias páginas muestra el total y pagina', async () => {
    items = Array.from({ length: 20 }, (_, i) => noShow(`n${i}`));
    total = 45;
    await abrir();
    expect(texto()).toContain('Página 1 de 3 · 45 en total');

    await component.irAPagina(2);

    expect((api.get.calls.mostRecent().args[1] as HttpParams).get('page')).toBe('2');
  });

  it('no sale del rango de páginas', async () => {
    await abrir();
    api.get.calls.reset();

    await component.irAPagina(0);
    await component.irAPagina(5);

    expect(api.get).not.toHaveBeenCalled();
  });
});
