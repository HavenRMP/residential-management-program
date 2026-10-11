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

  it('respeta el microservicio indicado y las URL completas', () => {
    expect(api.resolveUrl('/api/paqueteria', 'viviendas')).toBe(`${environment.services.viviendas}/api/paqueteria`);
    expect(api.resolveUrl('https://otro.example.com/x')).toBe('https://otro.example.com/x');
  });
});
