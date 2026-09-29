-- ==============================================================================
-- Archivo: supabase/migrations/20260925000000_modulo_notificaciones.sql
-- Proyecto: HAVEN
-- Descripción: Módulo de notificaciones internas para eventos y alertas.
-- ==============================================================================

-- ==============================================================================
-- 1. TABLA BASE: NOTIFICACIONES E ÍNDICES
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.notificaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    tipo_evento VARCHAR(50) NOT NULL,
    titulo VARCHAR(150) NOT NULL,
    mensaje TEXT NOT NULL,
    url_redireccion TEXT NULL,
    leida BOOLEAN NOT NULL DEFAULT false,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índices de consulta requeridos
CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario_id 
    ON public.notificaciones(usuario_id);

CREATE INDEX IF NOT EXISTS idx_notificaciones_creado_en 
    ON public.notificaciones(creado_en DESC);

-- Índice parcial optimizado para consultar no leídas en tiempo real (<1ms)
CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario_no_leidas 
    ON public.notificaciones(usuario_id, creado_en DESC) 
    WHERE leida = false;