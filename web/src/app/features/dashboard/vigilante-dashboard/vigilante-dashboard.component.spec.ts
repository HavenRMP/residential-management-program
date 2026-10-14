import { Component, EventEmitter, Input, Output, signal, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { VigilanteDashboardComponent } from './vigilante-dashboard.component';
import { AuthService } from '../../../core/services/auth.service';

@Component({ selector: 'app-user-menu', standalone: true, changeDetection: ChangeDetectionStrategy.Eager,
 template: '' })
class UserMenuStub {
  @Input() user: unknown;
  @Output() logout = new EventEmitter<void>();
}
@Component({ selector: 'app-caseta-visitas', standalone: true, changeDetection: ChangeDetectionStrategy.Eager,
 template: '<p>caseta</p>' })
class CasetaStub {}
@Component({ selector: 'app-directorio-casas', standalone: true, changeDetection: ChangeDetectionStrategy.Eager,
 template: '<p>directorio</p>' })
class DirectorioStub {}
@Component({ selector: 'app-paqueteria-caseta', standalone: true, changeDetection: ChangeDetectionStrategy.Eager,
 template: '<p>paquetes</p>' })
class PaquetesStub {}
@Component({ selector: 'app-reservas-caseta', standalone: true, changeDetection: ChangeDetectionStrategy.Eager,
 template: '<p>reservas</p>' })
class ReservasStub {}
@Component({ selector: 'app-avisos-caseta', standalone: true, changeDetection: ChangeDetectionStrategy.Eager,
 template: '<p>avisos</p>' })
class AvisosStub {}

describe('VigilanteDashboardComponent', () => {
  let fixture: ComponentFixture<VigilanteDashboardComponent>;

  const pestanas = () => Array.from(fixture.nativeElement.querySelectorAll('[role="tab"]') as NodeListOf<HTMLButtonElement>);
  const contenedorDe = (selector: string) => fixture.nativeElement.querySelector(selector).parentElement as HTMLElement;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [VigilanteDashboardComponent],
      providers: [{ provide: AuthService, useValue: { currentUser: signal(null), logout: () => undefined } }]
    }).overrideComponent(VigilanteDashboardComponent, {
      set: { imports: [CommonModule, UserMenuStub, CasetaStub, DirectorioStub, AvisosStub, ReservasStub, PaquetesStub] }
    });
    fixture = TestBed.createComponent(VigilanteDashboardComponent);
    fixture.detectChanges();
  });

  it('abre en la vista de Caseta, con los avisos al lado, y oculta el directorio', () => {
    expect(pestanas().map(p => p.textContent!.trim())).toEqual(['Caseta', 'Paquetes', 'Directorio', 'Reservas']);
    expect(pestanas().map(p => p.getAttribute('aria-selected'))).toEqual(['true', 'false', 'false', 'false']);
    expect(contenedorDe('app-caseta-visitas').parentElement!.classList.contains('hidden')).toBeFalse();
    expect(fixture.nativeElement.querySelector('app-avisos-caseta')).not.toBeNull();
    expect(contenedorDe('app-directorio-casas').classList.contains('hidden')).toBeTrue();
  });

  it('al elegir Directorio muestra la lista de personas y oculta la caseta', () => {
    pestanas()[2].click();
    fixture.detectChanges();

    expect(pestanas().map(p => p.getAttribute('aria-selected'))).toEqual(['false', 'false', 'true', 'false']);
    expect(contenedorDe('app-directorio-casas').classList.contains('hidden')).toBeFalse();
    expect(contenedorDe('app-caseta-visitas').parentElement!.classList.contains('hidden')).toBeTrue();
  });

  it('Reservas no se carga al entrar al portal: solo la primera vez que se abre', () => {
    expect(fixture.nativeElement.querySelector('app-reservas-caseta')).toBeNull();

    pestanas()[3].click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-reservas-caseta')).not.toBeNull();
    expect(pestanas().map(p => p.getAttribute('aria-selected'))).toEqual(['false', 'false', 'false', 'true']);
    expect(contenedorDe('app-reservas-caseta').classList.contains('hidden')).toBeFalse();
    expect(contenedorDe('app-caseta-visitas').parentElement!.classList.contains('hidden')).toBeTrue();
    expect(contenedorDe('app-directorio-casas').classList.contains('hidden')).toBeTrue();
  });

  it('al salir de Reservas se oculta sin destruirse, para conservar el periodo y el área elegidos', () => {
    pestanas()[3].click();
    fixture.detectChanges();
    const reservas = fixture.nativeElement.querySelector('app-reservas-caseta');

    pestanas()[0].click();
    fixture.detectChanges();

    expect(contenedorDe('app-reservas-caseta').classList.contains('hidden')).toBeTrue();
    pestanas()[3].click();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-reservas-caseta')).toBe(reservas);
  });

  it('Paquetes no se carga al entrar al portal: solo la primera vez que se abre', () => {
    expect(fixture.nativeElement.querySelector('app-paqueteria-caseta')).toBeNull();

    pestanas()[1].click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-paqueteria-caseta')).not.toBeNull();
    expect(pestanas().map(p => p.getAttribute('aria-selected'))).toEqual(['false', 'true', 'false', 'false']);
    expect(contenedorDe('app-paqueteria-caseta').classList.contains('hidden')).toBeFalse();
    expect(contenedorDe('app-caseta-visitas').parentElement!.classList.contains('hidden')).toBeTrue();
  });

  it('al salir de Paquetes se oculta sin destruirse, para conservar la pestaña y la búsqueda', () => {
    pestanas()[1].click();
    fixture.detectChanges();
    const paquetes = fixture.nativeElement.querySelector('app-paqueteria-caseta');

    pestanas()[0].click();
    fixture.detectChanges();

    expect(contenedorDe('app-paqueteria-caseta').classList.contains('hidden')).toBeTrue();
    pestanas()[1].click();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-paqueteria-caseta')).toBe(paquetes);
  });

  it('cambiar de vista no destruye la caseta, para conservar su búsqueda y su pestaña', () => {
    const caseta = fixture.nativeElement.querySelector('app-caseta-visitas');

    pestanas()[2].click();
    fixture.detectChanges();
    pestanas()[0].click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-caseta-visitas')).toBe(caseta);
  });
});
