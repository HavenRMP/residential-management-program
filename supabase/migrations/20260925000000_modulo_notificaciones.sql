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
    -- ==============================================================================
-- 2. TABLA DE BITÁCORA (AUDITORÍA FORENSE)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.notificaciones_bitacora (
    id BIGSERIAL PRIMARY KEY,
    registro_id TEXT NOT NULL,
    operacion VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    modificado_por TEXT,
    modificado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_bitacora_registro 
    ON public.notificaciones_bitacora(registro_id);

CREATE INDEX IF NOT EXISTS idx_notificaciones_bitacora_fecha 
    ON public.notificaciones_bitacora(modificado_en);

REVOKE ALL ON public.notificaciones_bitacora FROM authenticated, anon, service_role;

-- ==============================================================================
-- 3. TRIGGERS DE AUDITORÍA CONECTADOS A fn_auditoria()
-- ==============================================================================
DROP TRIGGER IF EXISTS trg_notificaciones_auditoria_insert ON public.notificaciones;
CREATE TRIGGER trg_notificaciones_auditoria_insert
    AFTER INSERT ON public.notificaciones
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_notificaciones_auditoria_update ON public.notificaciones;
CREATE TRIGGER trg_notificaciones_auditoria_update
    BEFORE UPDATE ON public.notificaciones
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_notificaciones_auditoria_delete ON public.notificaciones;
CREATE TRIGGER trg_notificaciones_auditoria_delete
    BEFORE DELETE ON public.notificaciones
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();
    -- ==============================================================================
-- 4. VISTA DE CONSULTA: vw_notificaciones
-- ==============================================================================
DROP VIEW IF EXISTS public.vw_notificaciones CASCADE;

CREATE VIEW public.vw_notificaciones AS
SELECT 
    n.id,
    n.usuario_id,
    u.nombre || ' ' || u.apellidos AS usuario_nombre,
    u.email AS usuario_email,
    n.tipo_evento,
    n.titulo,
    n.mensaje,
    n.url_redireccion,
    n.leida,
    n.creado_en
FROM public.notificaciones n
JOIN public.usuarios u ON u.id = n.usuario_id;

-- Permisos de lectura
GRANT SELECT ON public.vw_notificaciones TO authenticated, service_role;
-- ==============================================================================
-- 5. STORED PROCEDURES / RPCs: alta_notificacion
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.alta_notificacion(
    p_usuario_id UUID,
    p_tipo_evento VARCHAR(50),
    p_titulo VARCHAR(150),
    p_mensaje TEXT,
    p_url_redireccion TEXT DEFAULT NULL
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_usuario RECORD;
    v_id UUID;
    v_resultado JSONB;
BEGIN
    -- Validar existencia del usuario destinatario
    SELECT id, activo
    INTO v_usuario
    FROM public.usuarios
    WHERE id = p_usuario_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El usuario destinatario con ID % no existe.', p_usuario_id USING ERRCODE = 'NT001';
    END IF;

    IF NOT v_usuario.activo THEN
        RAISE EXCEPTION 'No se pueden enviar notificaciones a un usuario inactivo.' USING ERRCODE = 'NT002';
    END IF;

    -- Validaciones de cadenas
    IF NULLIF(TRIM(p_tipo_evento), '') IS NULL THEN
        RAISE EXCEPTION 'El tipo de evento no puede estar vacío.' USING ERRCODE = 'NT003';
    END IF;

    IF NULLIF(TRIM(p_titulo), '') IS NULL THEN
        RAISE EXCEPTION 'El título de la notificación no puede estar vacío.' USING ERRCODE = 'NT004';
    END IF;

    IF NULLIF(TRIM(p_mensaje), '') IS NULL THEN
        RAISE EXCEPTION 'El mensaje de la notificación no puede estar vacío.' USING ERRCODE = 'NT005';
    END IF;

    -- Inserción
    INSERT INTO public.notificaciones (
        usuario_id,
        tipo_evento,
        titulo,
        mensaje,
        url_redireccion
    )
    VALUES (
        p_usuario_id,
        TRIM(p_tipo_evento),
        TRIM(p_titulo),
        TRIM(p_mensaje),
        NULLIF(TRIM(p_url_redireccion), '')
    )
    RETURNING id INTO v_id;

    -- Retornar el registro armado
    SELECT to_jsonb(vn.*)
    INTO v_resultado
    FROM public.vw_notificaciones vn
    WHERE vn.id = v_id;

    RETURN v_resultado;
END;
$$;