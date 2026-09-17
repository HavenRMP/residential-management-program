-- ==============================================================================
-- Archivo: supabase/migrations/20260915000000_modulo_avisos.sql
-- Proyecto: HAVEN
-- Descripción: Módulo de avisos, auditoría, vistas y procedimientos RPC.
-- ==============================================================================

-- ==============================================================================
-- 1. FUNCIÓN AUXILIAR INMUTABLE (Cálculo de expiración)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.fn_calcular_expiracion_aviso(
    p_manual TIMESTAMPTZ,
    p_publicacion TIMESTAMPTZ,
    p_duracion_dias INTEGER
)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_manual IS NOT NULL THEN
        RETURN p_manual;
    END IF;
    RETURN p_publicacion + (COALESCE(p_duracion_dias, 7) * INTERVAL '1 day');
END;
$$;
-- ==============================================================================
-- 2. TABLA BASE: AVISOS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.avisos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE RESTRICT,
    titulo VARCHAR(200) NOT NULL,
    contenido TEXT NOT NULL,
    duracion_dias INTEGER NULL DEFAULT 7,
    fecha_expiracion_manual TIMESTAMPTZ NULL,
    fecha_publicacion TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    fecha_expiracion TIMESTAMPTZ GENERATED ALWAYS AS (
        public.fn_calcular_expiracion_aviso(fecha_expiracion_manual, fecha_publicacion, duracion_dias)
    ) STORED,
    activo BOOLEAN NOT NULL DEFAULT true,
    creado_por UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE RESTRICT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),

    -- Restricciones de vigencia
    CONSTRAINT chk_avisos_vigencia_minima 
        CHECK (duracion_dias IS NOT NULL OR fecha_expiracion_manual IS NOT NULL),
    CONSTRAINT chk_avisos_vigencia_excluyente 
        CHECK (NOT (duracion_dias IS NOT NULL AND fecha_expiracion_manual IS NOT NULL)),
    CONSTRAINT chk_avisos_duracion_positiva 
        CHECK (duracion_dias IS NULL OR duracion_dias > 0)
);

-- Índices de consulta requeridos
CREATE INDEX IF NOT EXISTS idx_avisos_condominio_id ON public.avisos(condominio_id);
CREATE INDEX IF NOT EXISTS idx_avisos_fecha_expiracion ON public.avisos(fecha_expiracion);
CREATE INDEX IF NOT EXISTS idx_avisos_activo ON public.avisos(activo);