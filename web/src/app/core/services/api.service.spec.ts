import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { ApiService } from './api.service';
import { environment } from '../../../environments/environment';

describe('ApiService.resolveUrl', () => {
  let api: ApiService;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    api = TestBed.inject(ApiService);
  });

  it('enruta visitas y paquetería al microservicio de visitas', () => {
    expect(api.resolveUrl('/api/visitas/proximas')).toBe(`${environment.services.visitas}/api/visitas/proximas`);
    expect(api.resolveUrl('/api/paqueteria/mis-paquetes')).toBe(`${environment.services.visitas}/api/paqueteria/mis-paquetes`);
    expect(api.resolveUrl('/API/Paqueteria/servicios')).toBe(`${environment.services.visitas}/API/Paqueteria/servicios`);
  });

  it('enruta áreas, reservas, administración de reservas y bloqueos al microservicio de reservas', () => {
    for (const ruta of ['/api/areas', '/api/areas/abc/baja', '/api/reservas/mias', '/api/reservas/calendario', '/api/admin/reservas', '/api/admin/reservas/no-shows', '/api/admin/bloqueos']) {
      expect(api.resolveUrl(ruta)).withContext(ruta).toBe(`${environment.services.reservas}${ruta}`);
    }
  });

  it('enruta cargos, pagos, plantillas, saldos y comprobantes al microservicio de pagos', () => {
    for (const ruta of ['/api/cargos', '/api/cargos/abc/cancelar', '/api/pagos/reportar', '/api/pagos/abc/comprobante-url', '/api/plantillas-cargo/generar', '/api/saldos/mi-saldo', '/api/comprobantes']) {
      expect(api.resolveUrl(ruta)).withContext(ruta).toBe(`${environment.services.pagos}${ruta}`);
    }
  });

  it('respeta el microservicio indicado y las URL completas', () => {
    expect(api.resolveUrl('/api/paqueteria', 'viviendas')).toBe(`${environment.services.viviendas}/api/paqueteria`);
    expect(api.resolveUrl('https://otro.example.com/x')).toBe('https://otro.example.com/x');
  });
});
