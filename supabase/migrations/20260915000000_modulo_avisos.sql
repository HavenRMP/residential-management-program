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

-- ==============================================================================
-- 3. TABLA DE BITÁCORA (AUDITORÍA FORENSE)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.avisos_bitacora (
    id BIGSERIAL PRIMARY KEY,
    registro_id TEXT NOT NULL,
    operacion VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    modificado_por TEXT,
    modificado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_avisos_bitacora_registro ON public.avisos_bitacora(registro_id);
CREATE INDEX IF NOT EXISTS idx_avisos_bitacora_fecha ON public.avisos_bitacora(modificado_en);

REVOKE ALL ON public.avisos_bitacora FROM authenticated, anon, service_role;

-- ==============================================================================
-- 4. TRIGGERS DE AUDITORÍA CONECTADOS A fn_auditoria()
-- ==============================================================================
DROP TRIGGER IF EXISTS trg_avisos_auditoria_insert ON public.avisos;
CREATE TRIGGER trg_avisos_auditoria_insert
    AFTER INSERT ON public.avisos
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_avisos_auditoria_update ON public.avisos;
CREATE TRIGGER trg_avisos_auditoria_update
    BEFORE UPDATE ON public.avisos
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_avisos_auditoria_delete ON public.avisos;
CREATE TRIGGER trg_avisos_auditoria_delete
    BEFORE DELETE ON public.avisos
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

    -- ==============================================================================
-- 5. VISTAS DE CONSULTA
-- ==============================================================================

-- A) Vista de Avisos Vigentes (Pantalla general para residentes y personal)
DROP VIEW IF EXISTS public.vw_avisos_vigentes CASCADE;
CREATE VIEW public.vw_avisos_vigentes AS
SELECT 
    a.id,
    a.condominio_id,
    c.nombre AS condominio_nombre,
    a.titulo,
    a.contenido,
    a.duracion_dias,
    a.fecha_expiracion_manual,
    a.fecha_publicacion,
    a.fecha_expiracion,
    a.activo,
    a.creado_por,
    u.nombre || ' ' || u.apellidos AS creado_por_nombre,
    a.creado_en
FROM public.avisos a
JOIN public.condominios c ON c.id = a.condominio_id
JOIN public.usuarios u ON u.id = a.creado_por
WHERE a.activo = true 
  AND a.fecha_expiracion > now();

-- B) Vista de Avisos Históricos (Auditoría y consulta administrativa)
DROP VIEW IF EXISTS public.vw_avisos_historico CASCADE;
CREATE VIEW public.vw_avisos_historico AS
SELECT 
    a.id,
    a.condominio_id,
    c.nombre AS condominio_nombre,
    a.titulo,
    a.contenido,
    a.duracion_dias,
    a.fecha_expiracion_manual,
    a.fecha_publicacion,
    a.fecha_expiracion,
    a.activo,
    CASE 
        WHEN a.activo = false THEN 'eliminado'
        ELSE 'expirado'
    END AS estado,
    a.creado_por,
    u.nombre || ' ' || u.apellidos AS creado_por_nombre,
    a.creado_en
FROM public.avisos a
JOIN public.condominios c ON c.id = a.condominio_id
JOIN public.usuarios u ON u.id = a.creado_por
WHERE a.activo = false 
   OR a.fecha_expiracion <= now();
-- ==============================================================================
-- 6. STORED PROCEDURES / RPCs
-- ==============================================================================

-- A) ALTA AVISO
DROP FUNCTION IF EXISTS public.alta_aviso(UUID, VARCHAR, TEXT, INTEGER, TIMESTAMPTZ);
CREATE OR REPLACE FUNCTION public.alta_aviso(
    p_creado_por UUID,
    p_titulo VARCHAR(200),
    p_contenido TEXT,
    p_duracion_dias INTEGER DEFAULT 7,
    p_fecha_expiracion TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_admin RECORD;
    v_id UUID;
    v_duracion_dias INTEGER;
    v_fecha_expiracion_manual TIMESTAMPTZ;
    v_resultado JSONB;
BEGIN
    -- 1. Validar que creado_por sea Administrador (rol_id = 1) activo
    SELECT id, condominio_id, rol_id, activo
    INTO v_admin
    FROM public.usuarios
    WHERE id = p_creado_por;

    IF NOT FOUND OR NOT v_admin.activo THEN
        RAISE EXCEPTION 'El usuario creador no existe o no se encuentra activo.' USING ERRCODE = 'AV001';
    END IF;

    IF v_admin.rol_id != 1 THEN
        RAISE EXCEPTION 'Solo un Administrador activo puede publicar avisos.' USING ERRCODE = 'AV002';
    END IF;

    IF v_admin.condominio_id IS NULL THEN
        RAISE EXCEPTION 'El administrador no tiene un condominio asociado.' USING ERRCODE = 'AV003';
    END IF;

    -- 2. Validar cadenas obligatorias
    IF NULLIF(TRIM(p_titulo), '') IS NULL THEN
        RAISE EXCEPTION 'El título del aviso no puede estar vacío.' USING ERRCODE = 'AV004';
    END IF;

    IF NULLIF(TRIM(p_contenido), '') IS NULL THEN
        RAISE EXCEPTION 'El contenido del aviso no puede estar vacío.' USING ERRCODE = 'AV005';
    END IF;

    -- 3. Vigencia mutuamente excluyente
    IF p_fecha_expiracion IS NOT NULL THEN
        IF p_fecha_expiracion <= now() THEN
            RAISE EXCEPTION 'La fecha de expiración manual debe ser posterior a la fecha actual.' USING ERRCODE = 'AV006';
        END IF;
        v_fecha_expiracion_manual := p_fecha_expiracion;
        v_duracion_dias := NULL;
    ELSE
        v_duracion_dias := COALESCE(p_duracion_dias, 7);
        IF v_duracion_dias <= 0 THEN
            RAISE EXCEPTION 'La duración en días debe ser mayor a 0.' USING ERRCODE = 'AV007';
        END IF;
        v_fecha_expiracion_manual := NULL;
    END IF;

    -- 4. Inserción (condominio_id se toma internamente del administrador)
    INSERT INTO public.avisos (
        condominio_id,
        titulo,
        contenido,
        duracion_dias,
        fecha_expiracion_manual,
        creado_por
    )
    VALUES (
        v_admin.condominio_id,
        TRIM(p_titulo),
        TRIM(p_contenido),
        v_duracion_dias,
        v_fecha_expiracion_manual,
        p_creado_por
    )
    RETURNING id INTO v_id;

    -- 5. Retornar el registro desde la vista de vigentes
    SELECT to_jsonb(v.*)
    INTO v_resultado
    FROM public.vw_avisos_vigentes v
    WHERE v.id = v_id;

    RETURN v_resultado;
END;
$$;
-- B) CAMBIO AVISO
DROP FUNCTION IF EXISTS public.cambio_aviso(UUID, UUID, VARCHAR, TEXT, INTEGER, TIMESTAMPTZ);
CREATE OR REPLACE FUNCTION public.cambio_aviso(
    p_id UUID,
    p_actor_id UUID,
    p_titulo VARCHAR(200) DEFAULT NULL,
    p_contenido TEXT DEFAULT NULL,
    p_duracion_dias INTEGER DEFAULT NULL,
    p_fecha_expiracion TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_aviso RECORD;
    v_admin RECORD;
    v_nuevo_duracion_dias INTEGER;
    v_nueva_fecha_manual TIMESTAMPTZ;
    v_resultado JSONB;
BEGIN
    -- 1. Validar que el aviso exista
    SELECT id, condominio_id, duracion_dias, fecha_expiracion_manual, activo
    INTO v_aviso
    FROM public.avisos
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El aviso con ID % no existe.', p_id USING ERRCODE = 'AV008';
    END IF;

    -- 2. Validar que el actor sea Administrador activo del mismo condominio
    SELECT id, condominio_id, rol_id, activo
    INTO v_admin
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_admin.activo THEN
        RAISE EXCEPTION 'El usuario administrador no existe o está inactivo.' USING ERRCODE = 'AV001';
    END IF;

    IF v_admin.rol_id != 1 THEN
        RAISE EXCEPTION 'El actor no cuenta con privilegios de Administrador.' USING ERRCODE = 'AV002';
    END IF;

    IF v_admin.condominio_id IS NULL OR v_admin.condominio_id != v_aviso.condominio_id THEN
        RAISE EXCEPTION 'El administrador no pertenece al mismo condominio del aviso.' USING ERRCODE = 'AV009';
    END IF;

    -- 3. Regla de vigencia: fecha exacta gana sobre duración y viceversa; si no mandan ninguna, se mantiene
    IF p_fecha_expiracion IS NOT NULL THEN
        IF p_fecha_expiracion <= now() THEN
            RAISE EXCEPTION 'La fecha de expiración manual debe ser posterior a la fecha actual.' USING ERRCODE = 'AV006';
        END IF;
        v_nueva_fecha_manual := p_fecha_expiracion;
        v_nuevo_duracion_dias := NULL;
    ELSIF p_duracion_dias IS NOT NULL THEN
        IF p_duracion_dias <= 0 THEN
            RAISE EXCEPTION 'La duración en días debe ser mayor a 0.' USING ERRCODE = 'AV007';
        END IF;
        v_nuevo_duracion_dias := p_duracion_dias;
        v_nueva_fecha_manual := NULL;
    ELSE
        -- Mantener la vigencia anterior
        v_nuevo_duracion_dias := v_aviso.duracion_dias;
        v_nueva_fecha_manual := v_aviso.fecha_expiracion_manual;
    END IF;

    -- 4. Actualización dinámica
    UPDATE public.avisos
    SET
        titulo = COALESCE(NULLIF(TRIM(p_titulo), ''), titulo),
        contenido = COALESCE(NULLIF(TRIM(p_contenido), ''), contenido),
        duracion_dias = v_nuevo_duracion_dias,
        fecha_expiracion_manual = v_nueva_fecha_manual
    WHERE id = p_id;

    -- 5. Construcción del JSON de retorno
    SELECT jsonb_build_object(
        'id', a.id,
        'condominio_id', a.condominio_id,
        'condominio_nombre', c.nombre,
        'titulo', a.titulo,
        'contenido', a.contenido,
        'duracion_dias', a.duracion_dias,
        'fecha_expiracion_manual', a.fecha_expiracion_manual,
        'fecha_publicacion', a.fecha_publicacion,
        'fecha_expiracion', a.fecha_expiracion,
        'activo', a.activo,
        'creado_por', a.creado_por,
        'creado_por_nombre', u.nombre || ' ' || u.apellidos,
        'creado_en', a.creado_en
    )
    INTO v_resultado
    FROM public.avisos a
    JOIN public.condominio c ON c.id = a.condominio_id
    JOIN public.usuarios u ON u.id = a.creado_por
    WHERE a.id = p_id;

    RETURN v_resultado;
END;
$$;
-- C) BAJA AVISO
DROP FUNCTION IF EXISTS public.baja_aviso(UUID, UUID);
CREATE OR REPLACE FUNCTION public.baja_aviso(
    p_id UUID,
    p_actor_id UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_aviso RECORD;
    v_admin RECORD;
    v_filas_afectadas INTEGER;
BEGIN
    -- 1. Validar existencia del aviso
    SELECT id, condominio_id, activo
    INTO v_aviso
    FROM public.avisos
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El aviso con ID % no existe.', p_id USING ERRCODE = 'AV008';
    END IF;

    -- 2. Validar que el actor sea Administrador del mismo condominio
    SELECT id, condominio_id, rol_id, activo
    INTO v_admin
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_admin.activo THEN
        RAISE EXCEPTION 'El usuario administrador no existe o está inactivo.' USING ERRCODE = 'AV001';
    END IF;

    IF v_admin.rol_id != 1 THEN
        RAISE EXCEPTION 'El actor no cuenta con privilegios de Administrador.' USING ERRCODE = 'AV002';
    END IF;

    IF v_admin.condominio_id IS NULL OR v_admin.condominio_id != v_aviso.condominio_id THEN
        RAISE EXCEPTION 'El administrador no pertenece al mismo condominio del aviso.' USING ERRCODE = 'AV009';
    END IF;

    -- 3. Baja lógica
    UPDATE public.avisos
    SET activo = false
    WHERE id = p_id AND activo = true;

    GET DIAGNOSTICS v_filas_afectadas = ROW_COUNT;
    RETURN v_filas_afectadas > 0;
END;
$$;
-- ==============================================================================
-- 7. PERMISOS Y RECARGA DE POSTGREST
-- ==============================================================================
-- Revocación total sobre tablas físicas
REVOKE ALL ON public.avisos FROM authenticated, anon, service_role;

-- Vistas
GRANT SELECT ON public.vw_avisos_vigentes TO authenticated, service_role;
GRANT SELECT ON public.vw_avisos_historico TO service_role;

-- RPCs
GRANT EXECUTE ON FUNCTION public.alta_aviso(UUID, VARCHAR, TEXT, INTEGER, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION public.cambio_aviso(UUID, UUID, VARCHAR, TEXT, INTEGER, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION public.baja_aviso(UUID, UUID) TO service_role;

-- Recarga de esquema PostgREST
NOTIFY pgrst, 'reload schema';

-- ==============================================================================
-- 8. INCREMENTO SEMÁNTICO DE VERSIÓN (SemVer)
-- ==============================================================================
UPDATE public.version 
SET 
    numero_version = CASE 
        WHEN numero_version ~ '^[0-9]+\.[0-9]+(\.[0-9]+)?$' THEN
            split_part(numero_version, '.', 1) || '.' || 
            ((split_part(numero_version, '.', 2)::integer) + 1)::text || 
            CASE 
                WHEN split_part(numero_version, '.', 3) <> '' THEN '.' || split_part(numero_version, '.', 3) 
                ELSE '' 
            END
        WHEN numero_version ~ '^[0-9]+$' THEN
            ((numero_version::integer) + 1)::text
        ELSE numero_version || '.1'
    END,
    updated_at = now();