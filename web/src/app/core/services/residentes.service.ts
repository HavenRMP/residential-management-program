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
      let params = new HttpParams().set('pageSize', '100');
      if (sinVivienda) {
        params = params.set('sinVivienda', 'true');
      }
      const resp = await firstValueFrom(this.apiService.get<any>('/api/auth/residentes', params));
      const items = extractPagedItems<Residente>(resp);
      this.cacheService.set(cacheKey, items, 'residentes');
      return items;
    } catch (err) {
      console.warn('[ResidentesService] Error al listar residentes:', err);
      throw err;
    }
  }
}

