import { ComponentFixture, TestBed } from '@angular/core/testing';
import { By } from '@angular/platform-browser';
import { of, throwError } from 'rxjs';
import Swal from 'sweetalert2';
import { AreasAdminComponent } from './areas-admin.component';
import { AreaFormComponent } from './area-form.component';
import { BloqueoFormComponent } from './bloqueo-form.component';
import { ApiService } from '../../../core/services/api.service';
import { AreaComun } from '../../../core/models/reserva.model';

const area = (id: string, nombre: string, activo = true, extra: Partial<AreaComun> = {}): AreaComun => ({
  id, nombre, horaApertura: '08:00:00', horaCierre: '22:00:00', zonaHoraria: 'America/Mexico_City', activo, ...extra
});

describe('AreasAdminComponent', () => {
  let fixture: ComponentFixture<AreasAdminComponent>;
  let component: AreasAdminComponent;
  let api: jasmine.SpyObj<ApiService>;
  let swal: jasmine.Spy;
  let areas: AreaComun[];

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const tarjetas = () => Array.from(fixture.nativeElement.querySelectorAll('ul li') as NodeListOf<HTMLElement>);
  const boton = (nombre: string, dentro: ParentNode = fixture.nativeElement) =>
    Array.from(dentro.querySelectorAll('button') as NodeListOf<HTMLButtonElement>).find(b => b.textContent!.trim().startsWith(nombre));

  async function abrir(): Promise<void> {
    fixture = TestBed.createComponent(AreasAdminComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    await fixture.whenStable();
    await new Promise(r => setTimeout(r));
    fixture.detectChanges();
  }

  beforeEach(() => {
    areas = [area('a1', 'Salón de usos múltiples', true, { descripcion: 'Para fiestas' }), area('a2', 'Alberca', false)];
    api = jasmine.createSpyObj('ApiService', ['get', 'post', 'patch']);
    api.get.and.callFake((() => of({ items: areas, totalCount: areas.length })) as any);
    api.post.and.returnValue(of(null));
    swal = spyOn(Swal, 'fire').and.resolveTo({ isConfirmed: true } as any);
    TestBed.configureTestingModule({ imports: [AreasAdminComponent], providers: [{ provide: ApiService, useValue: api }] });
  });

  it('lista todas las áreas, también las dadas de baja, con su horario y zona', async () => {
    await abrir();

    expect(tarjetas().length).toBe(2);
    expect(tarjetas()[0].textContent).toContain('Salón de usos múltiples');
    expect(tarjetas()[0].textContent).toContain('Para fiestas');
    expect(tarjetas()[0].textContent).toContain('Activa');
    expect(tarjetas()[0].textContent).toContain('Abierta de 08:00 a 22:00');
    expect(tarjetas()[0].textContent).toContain('America/Mexico_City');
    expect(tarjetas()[1].textContent).toContain('De baja');
  });

  it('un área activa ofrece Editar, Bloquear fechas y Dar de baja; una de baja solo Editar y Reactivar', async () => {
    await abrir();

    expect(boton('Editar', tarjetas()[0])).toBeDefined();
    expect(boton('Bloquear fechas', tarjetas()[0])).toBeDefined();
    expect(boton('Dar de baja', tarjetas()[0])).toBeDefined();
    expect(boton('Reactivar', tarjetas()[0])).toBeUndefined();

    expect(boton('Editar', tarjetas()[1])).toBeDefined();
    expect(boton('Reactivar', tarjetas()[1])).toBeDefined();
    expect(boton('Bloquear fechas', tarjetas()[1])).toBeUndefined();
    expect(boton('Dar de baja', tarjetas()[1])).toBeUndefined();
  });

  it('sin áreas explica que hay que dar de alta la primera', async () => {
    areas = [];
    await abrir();

    expect(texto()).toContain('Todavía no hay áreas comunes');
  });

  it('si no cargan muestra el error y deja reintentar', async () => {
    spyOn(console, 'error');
    api.get.and.returnValue(throwError(() => ({ status: 500, error: { error: 'Servicio no disponible' } })));
    await abrir();
    expect(texto()).toContain('Servicio no disponible');

    api.get.and.callFake((() => of({ items: areas, totalCount: 2 })) as any);
    boton('Reintentar')!.click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(texto()).not.toContain('Servicio no disponible');
    expect(tarjetas().length).toBe(2);
  });

  describe('formularios', () => {
    it('"Nueva área" abre el formulario de alta y se cierra al guardar', async () => {
      await abrir();

      boton('Nueva área')!.click();
      fixture.detectChanges();
      const form = fixture.debugElement.query(By.directive(AreaFormComponent));
      expect(form).not.toBeNull();
      expect((form.componentInstance as AreaFormComponent).area).toBeNull();

      (form.componentInstance as AreaFormComponent).guardado.emit(area('nueva', 'Nueva'));
      fixture.detectChanges();
      expect(fixture.debugElement.query(By.directive(AreaFormComponent))).toBeNull();
    });

    it('Editar abre el formulario con el área elegida y Cancelar lo cierra', async () => {
      await abrir();

      boton('Editar', tarjetas()[0])!.click();
      fixture.detectChanges();
      const form = fixture.debugElement.query(By.directive(AreaFormComponent)).componentInstance as AreaFormComponent;
      expect(form.area?.id).toBe('a1');

      form.cerrado.emit();
      fixture.detectChanges();
      expect(fixture.debugElement.query(By.directive(AreaFormComponent))).toBeNull();
      expect(component.areaEditando()).toBeNull();
    });

    it('Bloquear fechas abre el formulario de bloqueo con esa área y se cierra al crearlo', async () => {
      await abrir();

      boton('Bloquear fechas', tarjetas()[0])!.click();
      fixture.detectChanges();
      const form = fixture.debugElement.query(By.directive(BloqueoFormComponent)).componentInstance as BloqueoFormComponent;
      expect(form.area.id).toBe('a1');

      form.creado.emit({ bloqueoId: 'b', areaId: 'a1', inicio: 'i', fin: 'f', motivo: 'm', reservasAfectadas: 0 });
      fixture.detectChanges();
      expect(fixture.debugElement.query(By.directive(BloqueoFormComponent))).toBeNull();
    });
  });

  describe('baja y reactivación', () => {
    it('dar de baja pide confirmación, la da de baja y la tarjeta cambia', async () => {
      await abrir();

      await component.darDeBaja(areas[0]);
      fixture.detectChanges();

      expect((swal.calls.argsFor(0)[0] as any).text).toContain('Los residentes ya no podrán reservar Salón de usos múltiples');
      expect(api.post).toHaveBeenCalledWith('/api/areas/a1/baja', {}, undefined, 'reservas');
      expect(tarjetas()[0].textContent).toContain('De baja');
    });

    it('si se arrepiente no pasa nada', async () => {
      await abrir();
      swal.and.resolveTo({ isConfirmed: false } as any);

      await component.darDeBaja(areas[0]);

      expect(api.post).not.toHaveBeenCalled();
    });

    it('reactivar la habilita sin pedir confirmación', async () => {
      await abrir();

      await component.reactivar(areas[1]);
      fixture.detectChanges();

      expect(api.post).toHaveBeenCalledWith('/api/areas/a2/reactivar', {}, undefined, 'reservas');
      expect(tarjetas()[1].textContent).toContain('Activa');
    });

    it('si falla muestra el motivo; si el área ya cambió (409) vuelve a pedir la lista', async () => {
      spyOn(console, 'error');
      await abrir();
      api.post.and.returnValue(throwError(() => ({ status: 409, error: { error: 'El área ya estaba dada de baja.' } })));
      api.get.calls.reset();

      await component.reactivar(areas[1]);

      const aviso = swal.calls.mostRecent().args[0] as any;
      expect(aviso.icon).toBe('error');
      expect(aviso.text).toBe('El área ya estaba dada de baja.');
      expect(api.get).toHaveBeenCalled();
    });

    it('oculta el JSON técnico con un mensaje claro', async () => {
      spyOn(console, 'error');
      await abrir();
      api.post.and.returnValue(throwError(() => ({ status: 500, error: { error: 'Error desde Supabase: {"code":"XX000"}' } })));

      await component.reactivar(areas[1]);

      expect((swal.calls.mostRecent().args[0] as any).text).toBe('No fue posible completar la acción. Intenta de nuevo en unos segundos.');
    });
  });
});
