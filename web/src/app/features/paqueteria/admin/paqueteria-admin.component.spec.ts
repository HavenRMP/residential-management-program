import { Component, Input } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { PaqueteriaAdminComponent } from './paqueteria-admin.component';
import { PaqueteriaCasetaComponent } from '../caseta/paqueteria-caseta.component';

@Component({ selector: 'app-paqueteria-caseta', standalone: true, template: '<p>paquetes</p>' })
class PaqueteriaStub {
  @Input() soloLectura = false;
}

describe('PaqueteriaAdminComponent', () => {
  let fixture: ComponentFixture<PaqueteriaAdminComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [PaqueteriaAdminComponent], providers: [provideRouter([])] });
    TestBed.overrideComponent(PaqueteriaAdminComponent, {
      remove: { imports: [PaqueteriaCasetaComponent] },
      add: { imports: [PaqueteriaStub] }
    });
    fixture = TestBed.createComponent(PaqueteriaAdminComponent);
    fixture.detectChanges();
  });

  it('muestra el título y el camino de regreso al panel', () => {
    expect(fixture.nativeElement.querySelector('h1').textContent).toContain('Paquetería');
    expect(fixture.nativeElement.querySelector('nav').textContent).toContain('Panel');
    expect(fixture.nativeElement.querySelector('nav').textContent).toContain('Paquetería');
    expect(fixture.nativeElement.querySelector('nav a').getAttribute('href')).toBe('/dashboard/admin');
  });

  it('el administrador solo consulta: la vista de caseta se abre en solo lectura', () => {
    const vista = fixture.debugElement.children[0].query(el => el.name === 'app-paqueteria-caseta');

    expect(vista.componentInstance.soloLectura).toBeTrue();
  });
});
