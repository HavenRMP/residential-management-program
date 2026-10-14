import { TestBed, fakeAsync, tick, discardPeriodicTasks } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import Swal from 'sweetalert2';
import { PING_TIMEOUT, PingService } from './ping.service';
import { environment } from '../../../environments/environment';

describe('PingService', () => {
  let service: PingService;
  let http: HttpTestingController;
  let fire: jasmine.Spy;

  const pingUsuarios = () => http.match(`${environment.services.usuarios}/api/auth/ping`);
  const titulos = () => fire.calls.allArgs().map(a => (a[0] as any).title as string);

  beforeEach(() => {
    spyOn(console, 'warn');
    fire = jasmine.createSpy('fire');
    spyOn(Swal, 'mixin').and.returnValue({ fire } as any);
    TestBed.configureTestingModule({ providers: [provideHttpClient(), provideHttpClientTesting()] });
    service = TestBed.inject(PingService);
    http = TestBed.inject(HttpTestingController);
  });

  it('despierta en silencio los demás microservicios, incluidos visitas y reservas', () => {
    service.checkBackendConnection();

    const bases = [
      environment.services.viviendas,
      environment.services.condominios,
      environment.services.avisos,
      environment.services.visitas,
      environment.services.reservas
    ];
    for (const base of bases) {
      expect(http.match(`${base}/swagger/v1/swagger.json`).length).toBe(1);
    }
    pingUsuarios().forEach(r => r.flush({ message: 'ok' }));
    expect(fire).not.toHaveBeenCalled();
  });

  it('despierta cada servicio una sola vez aunque varios compartan dirección o haya uno nuevo', () => {
    service.checkBackendConnection();

    const swagger = http.match(r => r.url.endsWith('/swagger/v1/swagger.json'));
    const urls = swagger.map(r => r.request.url);
    expect(new Set(urls).size).toBe(urls.length);
    // todos los de `environment.services` salvo `default` (repite viviendas) y `usuarios` (tiene su propio ping)
    const esperados = Object.entries(environment.services).filter(([n]) => !['default', 'usuarios'].includes(n));
    expect(urls.length).toBe(esperados.length);
    pingUsuarios().forEach(r => r.flush({ message: 'ok' }));
  });

  it('el despertar de los demás servicios no se corta a los 7 s: reservas puede tardar casi un minuto', fakeAsync(() => {
    service.checkBackendConnection();
    pingUsuarios().forEach(r => r.flush({ message: 'ok' }));

    tick(PING_TIMEOUT + 1000);

    const pendientes = http.match(r => r.url.endsWith('/swagger/v1/swagger.json'));
    expect(pendientes.every(r => !r.cancelled)).toBeTrue();
    pendientes.forEach(r => r.flush('{}'));
    discardPeriodicTasks();
  }));

  it('si el servidor responde no muestra ningún aviso ni datos internos como la versión de la base de datos', () => {
    service.checkBackendConnection();

    pingUsuarios().forEach(r => r.flush({ message: 'Backend conectado correctamente.', dbVersion: 'PostgreSQL 17.4' }));

    expect(fire).not.toHaveBeenCalled();
  });

  it('si tarda avisa una sola vez, en palabras sencillas y sin nombrar el proveedor', fakeAsync(() => {
    service.checkBackendConnection();
    pingUsuarios().forEach(r => r.flush('', { status: 503, statusText: 'Service Unavailable' }));

    expect(titulos()).toEqual(['Conectando con el servidor. Puede tardar unos segundos...']);

    tick(4000);
    pingUsuarios().forEach(r => r.flush('', { status: 503, statusText: 'Service Unavailable' }));

    expect(titulos().length).toBe(1);
    expect(titulos()[0]).not.toMatch(/render|cors|backend/i);
    discardPeriodicTasks();
    tick(4000);
    http.match(() => true);
  }));

  it('tras los reintentos avisa que no pudo conectar, sin hablar de CORS ni de modo seguro', fakeAsync(() => {
    service.checkBackendConnection();
    for (let intento = 0; intento < 3; intento++) {
      pingUsuarios().forEach(r => r.error(new ProgressEvent('error'), { status: 0 }));
      tick(4000);
    }

    const ultimo = titulos()[titulos().length - 1];
    expect(ultimo).toBe('No pudimos conectar con el servidor. Revisa tu conexión o intenta de nuevo en unos minutos.');
    expect(titulos().join(' ')).not.toMatch(/render|cors|backend|modo seguro/i);
    http.match(() => true);
  }));

  it('si el servidor no responde en el tiempo límite lo trata como un fallo', fakeAsync(() => {
    service.checkBackendConnection();

    tick(PING_TIMEOUT + 1);

    expect(titulos().length).toBe(1);
    discardPeriodicTasks();
    tick(4000);
    http.match(() => true);
  }));
});
