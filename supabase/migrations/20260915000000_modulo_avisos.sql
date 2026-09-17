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