import { TestBed } from '@angular/core/testing';
import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { authInterceptor, _reset401Debounce } from './auth.interceptor';
import { AuthService } from '../services/auth.service';
import { environment } from '../../../environments/environment';
import { signal } from '@angular/core';

describe('authInterceptor', () => {
  let httpTestingController: HttpTestingController;
  let httpClient: HttpClient;
  let mockAuthService: any;

  beforeEach(() => {
    _reset401Debounce();
    mockAuthService = {
      currentSession: signal<any>({ access_token: 'fake-jwt-token' }),
      logout: jasmine.createSpy('logout')
    };

    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: mockAuthService },
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting()
      ]
    });

    httpClient = TestBed.inject(HttpClient);
    httpTestingController = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpTestingController.verify();
  });

  it('should attach Authorization Bearer header for API requests', () => {
    const testUrl = `${environment.apiUrl}/api/auth/me`;

    httpClient.get(testUrl).subscribe();

    const req = httpTestingController.expectOne(testUrl);
    expect(req.request.headers.has('Authorization')).toBeTrue();
    expect(req.request.headers.get('Authorization')).toBe('Bearer fake-jwt-token');
    req.flush({});
  });

  it('should NOT attach Authorization header for non-API requests (e.g. Supabase)', () => {
    const testUrl = 'https://qunkgbmxmxmjponyxzdu.supabase.co/rest/v1/';

    httpClient.get(testUrl).subscribe();

    const req = httpTestingController.expectOne(testUrl);
    expect(req.request.headers.has('Authorization')).toBeFalse();
    req.flush({});
  });

  it('should invoke logout on 401 error', () => {
    const testUrl = `${environment.apiUrl}/api/residents`;

    httpClient.get(testUrl).subscribe({
      error: (err) => expect(err.status).toBe(401)
    });

    const req = httpTestingController.expectOne(testUrl);
    req.flush('Unauthorized', { status: 401, statusText: 'Unauthorized' });

    expect(mockAuthService.logout).toHaveBeenCalled();
  });

  it('should NOT invoke logout on 403 error', () => {
    const testUrl = `${environment.apiUrl}/api/residents`;

    httpClient.get(testUrl).subscribe({
      error: (err) => expect(err.status).toBe(403)
    });

    const req = httpTestingController.expectOne(testUrl);
    req.flush('Forbidden', { status: 403, statusText: 'Forbidden' });

    expect(mockAuthService.logout).not.toHaveBeenCalled();
  });

  it('should debounce concurrent 401 errors so logout is only invoked once', () => {
    const url1 = `${environment.apiUrl}/api/residents`;
    const url2 = `${environment.apiUrl}/api/viviendas`;

    httpClient.get(url1).subscribe({ error: () => {} });
    httpClient.get(url2).subscribe({ error: () => {} });

    const req1 = httpTestingController.expectOne(url1);
    const req2 = httpTestingController.expectOne(url2);

    req1.flush('Unauthorized', { status: 401, statusText: 'Unauthorized' });
    req2.flush('Unauthorized', { status: 401, statusText: 'Unauthorized' });

    expect(mockAuthService.logout).toHaveBeenCalledTimes(1);
  });
});
