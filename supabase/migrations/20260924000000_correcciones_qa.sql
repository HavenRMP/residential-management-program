-- ==============================================================================
-- Archivo: supabase/migrations/20260924000000_correcciones_qa.sql
-- Proyecto: HAVEN
-- Descripción: Correcciones de auditoría QA para asignación de residentes y avisos.
-- ==============================================================================

-- ==============================================================================
-- 1. CORRECCIÓN: ASIGNAR_RESIDENTE_VIVIENDA Y VINCULACIÓN DE CONDOMINIO
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.asignar_residente_vivienda(
    p_vivienda_id INTEGER,
    p_usuario_id UUID
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_vivienda RECORD;
    v_usuario RECORD;
    v_resultado JSONB;
BEGIN
    -- 1. Validar que la vivienda exista y esté activa
    SELECT id, condominio_id, activo
    INTO v_vivienda
    FROM public.viviendas
    WHERE id = p_vivienda_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La vivienda con ID % no existe.', p_vivienda_id USING ERRCODE = 'P0002';
    END IF;

    IF NOT v_vivienda.activo THEN
        RAISE EXCEPTION 'La vivienda con ID % se encuentra inactiva.', p_vivienda_id USING ERRCODE = 'P0003';
    END IF;

    -- 2. Validar que el usuario exista, esté activo y tenga rol_id = 2 (Residente)
    SELECT id, rol_id, activo
    INTO v_usuario
    FROM public.usuarios
    WHERE id = p_usuario_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El usuario con ID % no existe.', p_usuario_id USING ERRCODE = 'P0002';
    END IF;

    IF NOT v_usuario.activo THEN
        RAISE EXCEPTION 'El usuario con ID % se encuentra inactivo.', p_usuario_id USING ERRCODE = 'P0003';
    END IF;

    IF v_usuario.rol_id != 2 THEN
        RAISE EXCEPTION 'El usuario debe tener rol de Residente (rol_id = 2).' USING ERRCODE = 'P0001';
    END IF;

    -- 3. Insertar el vínculo en vivienda_residente (control de duplicados 23505 -> HTTP 409)
    BEGIN
        INSERT INTO public.vivienda_residente (vivienda_id, usuario_id)
        VALUES (p_vivienda_id, p_usuario_id);
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'El residente ya está vinculado a esta vivienda.' USING ERRCODE = '23505';
    END;

    -- 4. Sincronizar el condominio_id de la vivienda en el perfil del usuario
    UPDATE public.usuarios
    SET condominio_id = v_vivienda.condominio_id
    WHERE id = p_usuario_id;

    -- 5. Armar objeto JSON compuesto de retorno
    SELECT jsonb_build_object(
        'vivienda', row_to_json(vw_v),
        'residente', row_to_json(vw_u)
    ) INTO v_resultado
    FROM public.vw_viviendas vw_v, public.vw_usuarios vw_u
    WHERE vw_v.id = p_vivienda_id AND vw_u.id = p_usuario_id;

    RETURN v_resultado;
END;
$$;

GRANT EXECUTE ON FUNCTION public.asignar_residente_vivienda(INTEGER, UUID) TO service_role;

-- ------------------------------------------------------------------------------
-- Parche retroactivo: Asignar condominio_id a residentes existentes con valor nulo
-- ------------------------------------------------------------------------------
UPDATE public.usuarios u
SET condominio_id = v.condominio_id
FROM public.vivienda_residente vr
JOIN public.viviendas v ON v.id = vr.vivienda_id
WHERE u.id = vr.usuario_id
  AND u.condominio_id IS NULL;
  -- ==============================================================================
-- 2. CORRECCIÓN: CAMBIO_AVISO (Preservar vigencia y corregir tabla condominios)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.cambio_aviso(
    p_id UUID,
    p_actor_id UUID,
    p_titulo VARCHAR DEFAULT NULL,
    p_contenido TEXT DEFAULT NULL,
    p_duracion_dias INTEGER DEFAULT NULL,
    p_fecha_expiracion_manual TIMESTAMPTZ DEFAULT NULL
)
RETURNS public.vw_avisos_vigentes
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_aviso RECORD;
    v_resultado public.vw_avisos_vigentes;
    v_nueva_duracion INTEGER;
    v_nueva_fecha_manual TIMESTAMPTZ;
BEGIN
    -- Validar existencia del aviso
    SELECT * INTO v_aviso
    FROM public.avisos
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El aviso con ID % no existe.', p_id USING ERRCODE = 'P0002';
    END IF;

    -- Validar que no esté eliminado
    IF NOT v_aviso.activo THEN
        RAISE EXCEPTION 'No se puede modificar un aviso inactivo o eliminado.' USING ERRCODE = 'P0003';
    END IF;

    -- Si no se proporcionan nuevos valores de vigencia, se conservan los anteriores
    -- evitando recalcular y enviar el aviso a histórico involuntariamente
    IF p_duracion_dias IS NULL AND p_fecha_expiracion_manual IS NULL THEN
        v_nueva_duracion := v_aviso.duracion_dias;
        v_nueva_fecha_manual := v_aviso.fecha_expiracion_manual;
    ELSIF p_fecha_expiracion_manual IS NOT NULL THEN
        v_nueva_duracion := NULL;
        v_nueva_fecha_manual := p_fecha_expiracion_manual;
    ELSE
        v_nueva_duracion := p_duracion_dias;
        v_nueva_fecha_manual := NULL;
    END IF;

    -- Actualizar aviso
    UPDATE public.avisos
    SET
        titulo = COALESCE(NULLIF(trim(p_titulo), ''), titulo),
        contenido = COALESCE(NULLIF(trim(p_contenido), ''), contenido),
        duracion_dias = v_nueva_duracion,
        fecha_expiracion_manual = v_nueva_fecha_manual
    WHERE id = p_id;

    -- Retornar el registro desde la vista (referencia en plural condominios resuelta)
    SELECT * INTO v_resultado
    FROM public.vw_avisos_vigentes
    WHERE id = p_id;

    RETURN v_resultado;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cambio_aviso(UUID, UUID, VARCHAR, TEXT, INTEGER, TIMESTAMPTZ) TO service_role;
-- ==============================================================================
-- 3. MODIFICACIÓN: TABLA AVISOS (Prioridad y restricción CHECK)
-- ==============================================================================
ALTER TABLE public.avisos
ADD COLUMN IF NOT EXISTS prioridad VARCHAR(20) NOT NULL DEFAULT 'informativo';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_avisos_prioridad'
    ) THEN
        ALTER TABLE public.avisos
        ADD CONSTRAINT chk_avisos_prioridad 
        CHECK (prioridad IN ('informativo', 'urgente', 'mantenimiento', 'evento'));
    END IF;
END $$;
-- ==============================================================================
-- 4. ACTUALIZACIÓN DE VISTAS CON SOPORTE DE PRIORIDAD
-- ==============================================================================
DROP VIEW IF EXISTS public.vw_avisos_vigentes CASCADE;
CREATE VIEW public.vw_avisos_vigentes AS
SELECT 
    a.id,
    a.condominio_id,
    c.nombre AS condominio_nombre,
    a.titulo,
    a.contenido,
    a.prioridad,
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

DROP VIEW IF EXISTS public.vw_avisos_historico CASCADE;
CREATE VIEW public.vw_avisos_historico AS
SELECT 
    a.id,
    a.condominio_id,
    c.nombre AS condominio_nombre,
    a.titulo,
    a.contenido,
    a.prioridad,
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
-- 5. ACTUALIZACIÓN DE STORED PROCEDURE: alta_aviso
-- ==============================================================================
DROP FUNCTION IF EXISTS public.alta_aviso(UUID, VARCHAR, TEXT, INTEGER, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS public.alta_aviso(UUID, VARCHAR, TEXT, INTEGER, TIMESTAMPTZ, VARCHAR);

CREATE OR REPLACE FUNCTION public.alta_aviso(
    p_creado_por UUID,
    p_titulo VARCHAR(200),
    p_contenido TEXT,
    p_duracion_dias INTEGER DEFAULT 7,
    p_fecha_expiracion TIMESTAMPTZ DEFAULT NULL,
    p_prioridad VARCHAR(20) DEFAULT 'informativo'
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
    v_prioridad VARCHAR(20);
    v_resultado JSONB;
BEGIN
    -- Validar que el creador sea Administrador (rol_id = 1) activo
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

    -- Validaciones de campos de texto
    IF NULLIF(TRIM(p_titulo), '') IS NULL THEN
        RAISE EXCEPTION 'El título del aviso no puede estar vacío.' USING ERRCODE = 'AV004';
    END IF;

    IF NULLIF(TRIM(p_contenido), '') IS NULL THEN
        RAISE EXCEPTION 'El contenido del aviso no puede estar vacío.' USING ERRCODE = 'AV005';
    END IF;

    -- Validar prioridad
    v_prioridad := LOWER(TRIM(COALESCE(p_prioridad, 'informativo')));
    IF v_prioridad NOT IN ('informativo', 'urgente', 'mantenimiento', 'evento') THEN
        RAISE EXCEPTION 'Prioridad no válida. Debe ser informativo, urgente, mantenimiento o evento.' USING ERRCODE = 'AV010';
    END IF;

    -- Manejo de vigencia
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

    -- Inserción
    INSERT INTO public.avisos (
        condominio_id,
        titulo,
        contenido,
        prioridad,
        duracion_dias,
        fecha_expiracion_manual,
        creado_por
    )
    VALUES (
        v_admin.condominio_id,
        TRIM(p_titulo),
        TRIM(p_contenido),
        v_prioridad,
        v_duracion_dias,
        v_fecha_expiracion_manual,
        p_creado_por
    )
    RETURNING id INTO v_id;

    -- Retornar el registro desde la vista
    SELECT to_jsonb(v.*)
    INTO v_resultado
    FROM public.vw_avisos_vigentes v
    WHERE v.id = v_id;

    RETURN v_resultado;
END;
$$;

GRANT EXECUTE ON FUNCTION public.alta_aviso(UUID, VARCHAR, TEXT, INTEGER, TIMESTAMPTZ, VARCHAR) TO service_role;