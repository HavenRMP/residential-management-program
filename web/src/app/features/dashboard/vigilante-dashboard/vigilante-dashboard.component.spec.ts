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
      set: { imports: [CommonModule, UserMenuStub, CasetaStub, DirectorioStub, AvisosStub, ReservasStub] }
    });
    fixture = TestBed.createComponent(VigilanteDashboardComponent);
    fixture.detectChanges();
  });

  it('abre en la vista de Caseta, con los avisos al lado, y oculta el directorio', () => {
    expect(pestanas().map(p => p.getAttribute('aria-selected'))).toEqual(['true', 'false', 'false']);
    expect(contenedorDe('app-caseta-visitas').parentElement!.classList.contains('hidden')).toBeFalse();
    expect(fixture.nativeElement.querySelector('app-avisos-caseta')).not.toBeNull();
    expect(contenedorDe('app-directorio-casas').classList.contains('hidden')).toBeTrue();
  });

  it('al elegir Directorio muestra la lista de personas y oculta la caseta', () => {
    pestanas()[1].click();
    fixture.detectChanges();

    expect(pestanas().map(p => p.getAttribute('aria-selected'))).toEqual(['false', 'true', 'false']);
    expect(contenedorDe('app-directorio-casas').classList.contains('hidden')).toBeFalse();
    expect(contenedorDe('app-caseta-visitas').parentElement!.classList.contains('hidden')).toBeTrue();
  });

  it('Reservas no se carga al entrar al portal: solo la primera vez que se abre', () => {
    expect(fixture.nativeElement.querySelector('app-reservas-caseta')).toBeNull();

    pestanas()[2].click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-reservas-caseta')).not.toBeNull();
    expect(pestanas().map(p => p.getAttribute('aria-selected'))).toEqual(['false', 'false', 'true']);
    expect(contenedorDe('app-reservas-caseta').classList.contains('hidden')).toBeFalse();
    expect(contenedorDe('app-caseta-visitas').parentElement!.classList.contains('hidden')).toBeTrue();
    expect(contenedorDe('app-directorio-casas').classList.contains('hidden')).toBeTrue();
  });

  it('al salir de Reservas se oculta sin destruirse, para conservar el periodo y el área elegidos', () => {
    pestanas()[2].click();
    fixture.detectChanges();
    const reservas = fixture.nativeElement.querySelector('app-reservas-caseta');

    pestanas()[0].click();
    fixture.detectChanges();

    expect(contenedorDe('app-reservas-caseta').classList.contains('hidden')).toBeTrue();
    pestanas()[2].click();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-reservas-caseta')).toBe(reservas);
  });

  it('cambiar de vista no destruye la caseta, para conservar su búsqueda y su pestaña', () => {
    const caseta = fixture.nativeElement.querySelector('app-caseta-visitas');

    pestanas()[1].click();
    fixture.detectChanges();
    pestanas()[0].click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-caseta-visitas')).toBe(caseta);
  });
});
