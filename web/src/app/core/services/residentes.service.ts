import { Injectable, inject } from '@angular/core';
import { HttpParams } from '@angular/common/http';
import { ApiService } from './api.service';
import { CacheService } from './cache.service';
import { Residente } from '../models/residente.model';
import { extractPagedItems } from '../models/pagination.model';
import { firstValueFrom } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class ResidentesService {
  private readonly apiService = inject(ApiService);
  private readonly cacheService = inject(CacheService);

  async listar(sinVivienda: boolean = false, forceRefresh: boolean = false): Promise<Residente[]> {
    const cacheKey = `residentes_list_${sinVivienda}`;
    if (!forceRefresh) {
      const cached = this.cacheService.get<Residente[]>(cacheKey);
      if (cached) return cached;
    }

    try {
      let params = new HttpParams();
      if (sinVivienda) {
        params = params.set('sinVivienda', 'true');
      }
      const resp = await firstValueFrom(this.apiService.get<any>('/api/auth/residentes', params));
      const items = extractPagedItems<Residente>(resp);
      this.cacheService.set(cacheKey, items, 'residentes');
      return items;
    } catch {
      return [];
    }
  }

  async crear(payload: {
    nombre: string;
    apellidos: string;
    telefono: string;
    email: string;
    password: string;
    rol: string;
  }): Promise<Residente> {
    const result = await firstValueFrom(this.apiService.post<Residente>('/api/auth/register', payload));
    this.cacheService.invalidateTag('residentes');
    this.cacheService.invalidateTag('viviendas');
    return result;
  }
}

