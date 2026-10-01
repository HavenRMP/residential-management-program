-- ==============================================================================
-- Archivo: supabase/migrations/20260928080000_modulo_invitaciones_subusuarios.sql
-- Proyecto: HAVEN
-- Descripción: Módulo de Invitaciones y Sub-usuarios por Vivienda
-- ==============================================================================

-- ==============================================================================
-- 1. ESTRUCTURA DE TABLA Y RESTRICCIONES
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.invitaciones_subusuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vivienda_id INTEGER NOT NULL REFERENCES public.viviendas(id) ON DELETE CASCADE,
    creado_por UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE RESTRICT,
    email_invitado VARCHAR(255) NOT NULL,
    codigo_invitacion VARCHAR(8) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente' 
        CHECK (estado IN ('pendiente', 'aceptada', 'rechazada', 'expirada', 'revocada')),
    usuario_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    expira_en TIMESTAMPTZ NOT NULL DEFAULT (timezone('utc'::text, now()) + INTERVAL '24 hours'),
    respondido_en TIMESTAMPTZ,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índice para acelerar búsquedas por vivienda y estado
CREATE INDEX IF NOT EXISTS idx_invitaciones_subusuarios_vivienda 
ON public.invitaciones_subusuarios (vivienda_id, estado);

-- Índice único condicional: no permitir códigos duplicados en invitaciones pendientes
DROP INDEX IF EXISTS public.idx_codigo_invitacion_subusuario_vigente;
CREATE UNIQUE INDEX idx_codigo_invitacion_subusuario_vigente 
ON public.invitaciones_subusuarios (codigo_invitacion) 
WHERE estado = 'pendiente';