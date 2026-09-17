-- ==============================================================================
-- Archivo: supabase/migrations/20260916000000_viviendas_ocupacion.sql
-- Proyecto: HAVEN
-- Descripción: Incorporación de cálculo de ocupación y conteo de residentes
--              en vw_viviendas, actualización de SPs asociados y permisos.
-- ==============================================================================

-- 1. RECREACIÓN DE VISTA CON AGREGACIONES DE OCUPACIÓN
DROP VIEW IF EXISTS public.vw_viviendas CASCADE;

CREATE VIEW public.vw_viviendas AS
SELECT 
    v.id, 
    v.numero_casa, 
    v.tipo, 
    v.activo, 
    v.condominio_id,
    c.nombre AS condominio_nombre,
    COUNT(vr.usuario_id)::INTEGER AS total_residentes,
    (COUNT(vr.usuario_id) > 0) AS esta_ocupada,
    v.creado_en
FROM public.viviendas v
LEFT JOIN public.condominios c ON c.id = v.condominio_id
LEFT JOIN public.vivienda_residente vr ON vr.vivienda_id = v.id
WHERE v.activo = true
GROUP BY v.id, v.numero_casa, v.tipo, v.activo, v.condominio_id, c.nombre, v.creado_en;

-- 2. RESTAURACIÓN DE STORED PROCEDURES ASOCIADOS A vw_viviendas
CREATE OR REPLACE FUNCTION public.alta_vivienda(
    p_numero_casa VARCHAR(50), 
    p_condominio_id UUID,
    p_tipo VARCHAR(20) DEFAULT NULL
) 
RETURNS public.vw_viviendas
SECURITY DEFINER 
SET search_path = public 
LANGUAGE plpgsql AS $$
DECLARE
    v_resultado public.vw_viviendas;
    v_id INTEGER;
BEGIN
    INSERT INTO public.viviendas (numero_casa, condominio_id, tipo) 
    VALUES (p_numero_casa, p_condominio_id, p_tipo) 
    RETURNING id INTO v_id;
    
    SELECT * INTO v_resultado FROM public.vw_viviendas WHERE id = v_id;
    RETURN v_resultado;
END;
$$;

CREATE OR REPLACE FUNCTION public.alta_vivienda(
    p_numero_casa VARCHAR(50), 
    p_tipo VARCHAR(20) DEFAULT NULL
) 
RETURNS public.vw_viviendas
SECURITY DEFINER 
SET search_path = public 
LANGUAGE plpgsql AS $$
BEGIN
    RETURN public.alta_vivienda(
        p_numero_casa := p_numero_casa,
        p_condominio_id := 'a0000000-0000-0000-0000-000000000001'::UUID,
        p_tipo := p_tipo
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.cambio_vivienda(
    p_id INTEGER, 
    p_numero_casa VARCHAR(50) DEFAULT NULL, 
    p_tipo VARCHAR(20) DEFAULT NULL,
    p_condominio_id UUID DEFAULT NULL
) 
RETURNS public.vw_viviendas
SECURITY DEFINER 
SET search_path = public 
LANGUAGE plpgsql AS $$
DECLARE
    v_resultado public.vw_viviendas;
BEGIN
    UPDATE public.viviendas 
    SET 
        numero_casa = COALESCE(NULLIF(trim(p_numero_casa), ''), numero_casa),
        tipo = COALESCE(NULLIF(trim(p_tipo), ''), tipo),
        condominio_id = COALESCE(p_condominio_id, condominio_id)
    WHERE id = p_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vivienda con ID % no encontrada', p_id;
    END IF;

    SELECT * INTO v_resultado FROM public.vw_viviendas WHERE id = p_id;
    RETURN v_resultado;
END;
$$;

-- 3. PERMISOS Y RECARGA DE POSTGREST
GRANT SELECT ON public.vw_viviendas TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.alta_vivienda(VARCHAR, UUID, VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION public.alta_vivienda(VARCHAR, VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION public.cambio_vivienda(INTEGER, VARCHAR, VARCHAR, UUID) TO service_role;

NOTIFY pgrst, 'reload schema';