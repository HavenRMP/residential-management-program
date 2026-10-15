import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { RetornoFocoDirective } from './retorno-foco.directive';

@Component({
  standalone: true,
  imports: [RetornoFocoDirective],
  template: `
    <button id="abrir" type="button" (click)="abierto.set(true)">Abrir</button>
    @if (abierto()) {
      <div appRetornoFoco role="dialog"><input id="campo" /></div>
    }
  `
})
class AnfitrionComponent {
  readonly abierto = signal(false);
}

describe('RetornoFocoDirective', () => {
  it('al cerrarse el diálogo devuelve el foco a lo que lo tenía al abrirse', () => {
    const fixture = TestBed.createComponent(AnfitrionComponent);
    document.body.appendChild(fixture.nativeElement);
    fixture.detectChanges();
    const abrir = fixture.nativeElement.querySelector('#abrir') as HTMLButtonElement;
    abrir.focus();

    fixture.componentInstance.abierto.set(true);
    fixture.detectChanges();
    (fixture.nativeElement.querySelector('#campo') as HTMLInputElement).focus();
    fixture.componentInstance.abierto.set(false);
    fixture.detectChanges();

    expect(document.activeElement).toBe(abrir);
    fixture.nativeElement.remove();
  });

  it('si quien tenía el foco ya no está en la página no falla', () => {
    const fixture = TestBed.createComponent(AnfitrionComponent);
    document.body.appendChild(fixture.nativeElement);
    fixture.detectChanges();
    const abrir = fixture.nativeElement.querySelector('#abrir') as HTMLButtonElement;
    abrir.focus();
    fixture.componentInstance.abierto.set(true);
    fixture.detectChanges();
    abrir.remove();

    expect(() => {
      fixture.componentInstance.abierto.set(false);
      fixture.detectChanges();
    }).not.toThrow();
    fixture.nativeElement.remove();
  });
});
