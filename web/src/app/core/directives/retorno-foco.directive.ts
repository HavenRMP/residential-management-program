import { Directive, OnDestroy } from '@angular/core';

/**
 * Para diálogos que aparecen y desaparecen del DOM: recuerda qué tenía el foco al abrirse y se lo devuelve
 * al cerrarse, para que quien navega con teclado no pierda su lugar en la página.
 */
@Directive({ selector: '[appRetornoFoco]', standalone: true })
export class RetornoFocoDirective implements OnDestroy {
  private readonly origen = document.activeElement instanceof HTMLElement ? document.activeElement : null;

  ngOnDestroy(): void {
    if (this.origen?.isConnected) this.origen.focus();
  }
}
