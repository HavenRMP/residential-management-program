import { Injectable, inject } from '@angular/core';
import { HttpParams } from '@angular/common/http';
import { ApiService } from './api.service';
import { Residente } from '../models/residente.model';
import { extractPagedItems } from '../models/pagination.model';
import { firstValueFrom } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class ResidentesService {
  private readonly apiService = inject(ApiService);

  async listar(sinVivienda: boolean = false): Promise<Residente[]> {
    try {
      let params = new HttpParams();
      if (sinVivienda) {
        params = params.set('sinVivienda', 'true');
      }
      const resp = await firstValueFrom(this.apiService.get<any>('/api/auth/residentes', params));
      return extractPagedItems<Residente>(resp);
    } catch {
      return [];
    }
  }

  crear(payload: {
    nombre: string;
    apellidos: string;
    telefono: string;
    email: string;
    password: string;
    rol: string;
  }): Promise<Residente> {
    return firstValueFrom(this.apiService.post<Residente>('/api/auth/register', payload));
  }
}

