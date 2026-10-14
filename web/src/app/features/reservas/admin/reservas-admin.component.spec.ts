import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { By } from '@angular/platform-browser';
import { of } from 'rxjs';
import { ReservasAdminComponent } from './reservas-admin.component';
import { ReservasAdminListaComponent } from './reservas-admin-lista.component';
import { AreasAdminComponent } from './areas-admin.component';
import { NoShowsAdminComponent } from './no-shows-admin.component';
import { ApiService } from '../../../core/services/api.service';

describe('ReservasAdminComponent', () => {
  let fixture: ComponentFixture<ReservasAdminComponent>;
  let api: jasmine.SpyObj<ApiService>;

  const texto = () => (fixture.nativeElement.textContent as string).replace(/\s+/g, ' ');
  const pestana = (nombre: string) =>
    (Array.from(fixture.nativeElement.querySelectorAll('[role="tab"]')) as HTMLButtonElement[]).find(b => b.textContent!.trim() === nombre)!;

  beforeEach(async () => {
    api = jasmine.createSpyObj('ApiService', ['get', 'post', 'put']);
    api.get.and.callFake((() => of({ items: [], totalCount: 0 })) as any);
    TestBed.configureTestingModule({
      imports: [ReservasAdminComponent],
      providers: [provideRouter([]), { provide: ApiService, useValue: api }]
    });
    fixture = TestBed.createComponent(ReservasAdminComponent);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
  });

  it('abre en Reservas, con el título y las tres pestañas', () => {
    expect(texto()).toContain('Reservas de áreas comunes');
    expect(['Reservas', 'Áreas', 'No utilizadas'].every(n => !!pestana(n))).toBeTrue();
    expect(pestana('Reservas').getAttribute('aria-selected')).toBe('true');
    expect(fixture.debugElement.query(By.directive(ReservasAdminListaComponent))).not.toBeNull();
  });

  it('carga las áreas al abrir, porque el listado las necesita para el filtro y la zona horaria', () => {
    expect(api.get.calls.allArgs().some(a => a[0] === '/api/areas')).toBeTrue();
  });

  it('cambia de pestaña a Áreas y a No utilizadas, mostrando solo la elegida', () => {
    pestana('Áreas').click();
    fixture.detectChanges();
    expect(fixture.debugElement.query(By.directive(AreasAdminComponent))).not.toBeNull();
    expect(fixture.debugElement.query(By.directive(ReservasAdminListaComponent))).toBeNull();

    pestana('No utilizadas').click();
    fixture.detectChanges();
    expect(fixture.debugElement.query(By.directive(NoShowsAdminComponent))).not.toBeNull();
    expect(fixture.debugElement.query(By.directive(AreasAdminComponent))).toBeNull();
    expect(pestana('No utilizadas').getAttribute('aria-selected')).toBe('true');
  });
});
