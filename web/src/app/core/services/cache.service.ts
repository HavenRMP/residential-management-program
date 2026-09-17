import { Injectable } from '@angular/core';

export interface CacheEntry<T> {
  data: T;
  timestamp: number;
  tag: string;
  ttlMs: number;
}

@Injectable({
  providedIn: 'root'
})
export class CacheService {
  private readonly cache = new Map<string, CacheEntry<any>>();
  private readonly DEFAULT_TTL_MS = 10_000; // 10 segundos para frescura de datos en tiempo casi real

  /**
   * Obtiene un elemento en caché si existe y no ha expirado.
   */
  get<T>(key: string): T | null {
    const entry = this.cache.get(key);
    if (!entry) return null;

    const isExpired = Date.now() - entry.timestamp > entry.ttlMs;
    if (isExpired) {
      this.cache.delete(key);
      return null;
    }

    return entry.data as T;
  }

  /**
   * Guarda un elemento en caché asignándole un tag para invalidación atómica en mutaciones.
   */
  set<T>(key: string, data: T, tag: string = 'general', ttlMs: number = this.DEFAULT_TTL_MS): void {
    this.cache.set(key, {
      data,
      timestamp: Date.now(),
      tag,
      ttlMs
    });
  }

  /**
   * Invalida una clave específica.
   */
  invalidate(key: string): void {
    this.cache.delete(key);
  }

  /**
   * Invalida todas las entradas asociadas a un tag (ej: 'viviendas', 'residentes', 'avisos').
   * Garantiza que cualquier alta, baja o edición (CRUD) muestre datos frescos inmediatamente.
   */
  invalidateTag(tag: string): void {
    for (const [key, entry] of this.cache.entries()) {
      if (entry.tag === tag) {
        this.cache.delete(key);
      }
    }
  }

  /**
   * Invalida automáticamente por endpoint cuando ocurre un POST/PUT/PATCH/DELETE.
   */
  invalidateForEndpoint(endpoint: string): void {
    const lower = endpoint.toLowerCase();
    if (lower.includes('vivienda') || lower.includes('codigo')) {
      this.invalidateTag('viviendas');
    }
    if (lower.includes('residente') || lower.includes('usuario') || lower.includes('register')) {
      this.invalidateTag('residentes');
      this.invalidateTag('viviendas');
    }
    if (lower.includes('aviso')) {
      this.invalidateTag('avisos');
    }
    if (lower.includes('condominio')) {
      this.invalidateTag('condominios');
    }
  }

  /**
   * Limpia toda la memoria de caché.
   */
  clear(): void {
    this.cache.clear();
  }
}
