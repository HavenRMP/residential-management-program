-- ==============================================================================
-- HAVEN - Parche: contrato y reglas de Reservas con Reservas.Api y la web
-- ------------------------------------------------------------------------------
-- Corrige en la base viva, sin tirarla, lo que 02_recrear.sql ya trae corregido:
--   * solicitar_reserva devuelve la reserva completa (vw_reservas_usuario): antes
--     devolvía la fila cruda y la web mostraba la reserva nueva sin área ni nombres.
--   * alta_area_comun y cambio_area_comun devuelven el área completa (vw_areas_comunes).
--   * cambio_area_comun, baja_area_comun y reactivar_area_comun reciben p_id (antes p_area_id).
--   * Nueva cancelar_reserva (la que llama el back), delega en cancelar_reserva_usuario.
--   * actualizar_bloqueo_area devuelve una lista, como la lee el back.
--   * Códigos de error RS0xx -> RE0xx / 22023, los que traduce RpcErrorMapper.
--   * Reglas de la web y el back: 7 a 30 días de anticipación, de 30 minutos a
--     12 horas (sin exigir horas exactas), una reserva por vivienda por día, y se
--     confirma entre 7 días y 72 horas antes (el cron expira las no confirmadas a las 72 h).
--   * Quita los cron jobs expirar_reservas_pendientes, expirar_reservas_sin_confirmar
--     y notificaciones_confirmacion_reservas: apuntan a funciones que no existen y
--     fallan siempre; su trabajo ya lo hace procesar_transiciones_reservas.
--
-- No borra tablas, vistas ni datos. Es seguro correrlo más de una vez.
-- Ejecutar desde el SQL Editor de Supabase o con:
--   psql "<connection string>" -v ON_ERROR_STOP=1 -f supabase/reset/parches/20261111_reservas_contrato_api.sql
-- ==============================================================================

BEGIN;

-- 1. Restricciones de la tabla con las reglas nuevas
ALTER TABLE public.reservas DROP CONSTRAINT IF EXISTS chk_reservas_duracion;
ALTER TABLE public.reservas ADD CONSTRAINT chk_reservas_duracion CHECK ((((tipo)::text = 'BLOQUEO'::text) OR ((fin - inicio) <= '12:00:00'::interval)));
ALTER TABLE public.reservas DROP CONSTRAINT IF EXISTS chk_reservas_fechas;
ALTER TABLE public.reservas ADD CONSTRAINT chk_reservas_fechas CHECK ((fin > inicio));

-- 2. Funciones que cambian el nombre de un parámetro: hay que borrarlas antes
DROP FUNCTION IF EXISTS public.cambio_area_comun(uuid, uuid, text, text, time without time zone, time without time zone);
DROP FUNCTION IF EXISTS public.baja_area_comun(uuid, uuid);
DROP FUNCTION IF EXISTS public.reactivar_area_comun(uuid, uuid);

-- 3. alta_area_comun
CREATE OR REPLACE FUNCTION public.alta_area_comun(p_actor_id uuid, p_condominio_id uuid, p_nombre text, p_descripcion text DEFAULT NULL::text, p_hora_apertura time without time zone DEFAULT '08:00:00'::time without time zone, p_hora_cierre time without time zone DEFAULT '22:00:00'::time without time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_area RECORD;
    v_nombre_limpio TEXT;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id <> 1 THEN
        RAISE EXCEPTION 'Solo un administrador activo puede dar de alta áreas comunes.' USING ERRCODE = 'RE003';
    END IF;

    IF v_actor.condominio_id IS DISTINCT FROM p_condominio_id THEN
        RAISE EXCEPTION 'El administrador no pertenece al condominio especificado.' USING ERRCODE = 'RE014';
    END IF;

    v_nombre_limpio := trim(COALESCE(p_nombre, ''));
    IF length(v_nombre_limpio) = 0 OR length(v_nombre_limpio) > 100 THEN
        RAISE EXCEPTION 'El nombre del área es obligatorio y no puede exceder 100 caracteres.' USING ERRCODE = '22023';
    END IF;

    IF p_hora_cierre <= p_hora_apertura THEN
        RAISE EXCEPTION 'La hora de cierre debe ser posterior a la hora de apertura.' USING ERRCODE = 'RE005';
    END IF;

    IF EXTRACT(MINUTE FROM p_hora_apertura) <> 0 OR EXTRACT(SECOND FROM p_hora_apertura) <> 0
       OR EXTRACT(MINUTE FROM p_hora_cierre) <> 0 OR EXTRACT(SECOND FROM p_hora_cierre) <> 0 THEN
        RAISE EXCEPTION 'Las horas de apertura y cierre deben ser horas en punto (:00:00).' USING ERRCODE = 'RE005';
    END IF;

    INSERT INTO public.areas_comunes (
        condominio_id, nombre, descripcion, hora_apertura, hora_cierre, activo
    )
    VALUES (
        p_condominio_id, v_nombre_limpio, p_descripcion, p_hora_apertura, p_hora_cierre, true
    )
    RETURNING * INTO v_area;

    RETURN (SELECT to_jsonb(va.*) FROM public.vw_areas_comunes va WHERE va.id = v_area.id);
END;
$$;

ALTER FUNCTION public.alta_area_comun(p_actor_id uuid, p_condominio_id uuid, p_nombre text, p_descripcion text, p_hora_apertura time without time zone, p_hora_cierre time without time zone) OWNER TO postgres;
GRANT ALL ON FUNCTION public.alta_area_comun(p_actor_id uuid, p_condominio_id uuid, p_nombre text, p_descripcion text, p_hora_apertura time without time zone, p_hora_cierre time without time zone) TO service_role;

-- 4. cambio_area_comun
CREATE OR REPLACE FUNCTION public.cambio_area_comun(p_actor_id uuid, p_id uuid, p_nombre text DEFAULT NULL::text, p_descripcion text DEFAULT NULL::text, p_hora_apertura time without time zone DEFAULT NULL::time without time zone, p_hora_cierre time without time zone DEFAULT NULL::time without time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_area RECORD;
    v_apertura_final TIME;
    v_cierre_final TIME;
    v_nombre_final TEXT;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id <> 1 THEN
        RAISE EXCEPTION 'Solo un administrador activo puede modificar áreas comunes.' USING ERRCODE = 'RE003';
    END IF;

    SELECT * INTO v_area
    FROM public.areas_comunes
    WHERE id = p_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El área común no existe.' USING ERRCODE = 'RE001';
    END IF;

    IF v_area.condominio_id IS DISTINCT FROM v_actor.condominio_id THEN
        RAISE EXCEPTION 'No tienes permiso sobre áreas de otro condominio.' USING ERRCODE = 'RE014';
    END IF;

    v_nombre_final := COALESCE(NULLIF(trim(p_nombre), ''), v_area.nombre);
    v_apertura_final := COALESCE(p_hora_apertura, v_area.hora_apertura);
    v_cierre_final := COALESCE(p_hora_cierre, v_area.hora_cierre);

    IF v_cierre_final <= v_apertura_final THEN
        RAISE EXCEPTION 'La hora de cierre debe ser posterior a la hora de apertura.' USING ERRCODE = 'RE005';
    END IF;

    IF EXTRACT(MINUTE FROM v_apertura_final) <> 0 OR EXTRACT(SECOND FROM v_apertura_final) <> 0
       OR EXTRACT(MINUTE FROM v_cierre_final) <> 0 OR EXTRACT(SECOND FROM v_cierre_final) <> 0 THEN
        RAISE EXCEPTION 'Las horas de apertura y cierre deben ser horas en punto (:00:00).' USING ERRCODE = 'RE005';
    END IF;

    UPDATE public.areas_comunes
    SET nombre = v_nombre_final,
        descripcion = COALESCE(p_descripcion, descripcion),
        hora_apertura = v_apertura_final,
        hora_cierre = v_cierre_final
    WHERE id = p_id
    RETURNING * INTO v_area;

    RETURN (SELECT to_jsonb(va.*) FROM public.vw_areas_comunes va WHERE va.id = v_area.id);
END;
$$;

ALTER FUNCTION public.cambio_area_comun(p_actor_id uuid, p_id uuid, p_nombre text, p_descripcion text, p_hora_apertura time without time zone, p_hora_cierre time without time zone) OWNER TO postgres;
GRANT ALL ON FUNCTION public.cambio_area_comun(p_actor_id uuid, p_id uuid, p_nombre text, p_descripcion text, p_hora_apertura time without time zone, p_hora_cierre time without time zone) TO service_role;

-- 5. baja_area_comun
CREATE OR REPLACE FUNCTION public.baja_area_comun(p_actor_id uuid, p_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_area RECORD;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id <> 1 THEN
        RAISE EXCEPTION 'Solo un administrador activo puede desactivar áreas comunes.' USING ERRCODE = 'RE003';
    END IF;

    SELECT * INTO v_area
    FROM public.areas_comunes
    WHERE id = p_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El área común no existe.' USING ERRCODE = 'RE001';
    END IF;

    IF v_area.condominio_id IS DISTINCT FROM v_actor.condominio_id THEN
        RAISE EXCEPTION 'No tienes permiso sobre áreas de otro condominio.' USING ERRCODE = 'RE014';
    END IF;

    IF NOT v_area.activo THEN
        RETURN false;
    END IF;

    UPDATE public.areas_comunes
    SET activo = false
    WHERE id = p_id;

    RETURN true;
END;
$$;

ALTER FUNCTION public.baja_area_comun(p_actor_id uuid, p_id uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.baja_area_comun(p_actor_id uuid, p_id uuid) TO service_role;

-- 6. reactivar_area_comun
CREATE OR REPLACE FUNCTION public.reactivar_area_comun(p_actor_id uuid, p_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_area RECORD;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id <> 1 THEN
        RAISE EXCEPTION 'Solo un administrador activo puede reactivar áreas comunes.' USING ERRCODE = 'RE003';
    END IF;

    SELECT * INTO v_area
    FROM public.areas_comunes
    WHERE id = p_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El área común no existe.' USING ERRCODE = 'RE001';
    END IF;

    IF v_area.condominio_id IS DISTINCT FROM v_actor.condominio_id THEN
        RAISE EXCEPTION 'No tienes permiso sobre áreas de otro condominio.' USING ERRCODE = 'RE014';
    END IF;

    IF v_area.activo THEN
        RETURN false;
    END IF;

    UPDATE public.areas_comunes
    SET activo = true
    WHERE id = p_id;

    RETURN true;
END;
$$;

ALTER FUNCTION public.reactivar_area_comun(p_actor_id uuid, p_id uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.reactivar_area_comun(p_actor_id uuid, p_id uuid) TO service_role;

-- 7. solicitar_reserva
CREATE OR REPLACE FUNCTION public.solicitar_reserva(p_actor_id uuid, p_area_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_area RECORD;
    v_zona_horaria TEXT;
    v_vivienda_id INT;
    v_titular_id UUID;
    v_es_titular BOOLEAN := false;
    v_estado_inicial VARCHAR(25);
    v_inicio_local TIMESTAMP;
    v_fin_local TIMESTAMP;
    v_admin_id UUID;
    v_reserva RECORD;
    v_solicitante_nombre TEXT;
BEGIN
    SELECT id, rol_id, condominio_id, nombre, apellidos, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo THEN
        RAISE EXCEPTION 'Usuario solicitante no encontrado o inactivo.' USING ERRCODE = 'RE003';
    END IF;

    IF v_actor.rol_id <> 2 THEN
        RAISE EXCEPTION 'Solo los residentes pueden solicitar reservas.' USING ERRCODE = 'RE003';
    END IF;

    v_solicitante_nombre := trim(v_actor.nombre || ' ' || v_actor.apellidos);

    SELECT a.*, c.zona_horaria, c.activo AS condominio_activo
    INTO v_area
    FROM public.areas_comunes a
    JOIN public.condominios c ON c.id = a.condominio_id
    WHERE a.id = p_area_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El área común no existe.' USING ERRCODE = 'RE001';
    END IF;

    IF NOT v_area.activo OR NOT v_area.condominio_activo THEN
        RAISE EXCEPTION 'El área común se encuentra inactiva.' USING ERRCODE = 'RE001';
    END IF;

    IF v_actor.condominio_id IS DISTINCT FROM v_area.condominio_id THEN
        RAISE EXCEPTION 'No perteneces al condominio de esta área común.' USING ERRCODE = 'RE014';
    END IF;

    v_zona_horaria := v_area.zona_horaria;

    SELECT vr.vivienda_id, vr.usuario_id
    INTO v_vivienda_id, v_titular_id
    FROM public.vivienda_residente vr
    JOIN public.viviendas v ON v.id = vr.vivienda_id
    WHERE vr.usuario_id = p_actor_id
      AND v.condominio_id = v_area.condominio_id
      AND v.activo = true
    ORDER BY vr.fecha_ingreso ASC
    LIMIT 1;

    IF FOUND THEN
        v_es_titular := true;
        v_estado_inicial := 'PENDIENTE_ADMIN';
    ELSE
        SELECT vs.vivienda_id, vs.titular_id
        INTO v_vivienda_id, v_titular_id
        FROM public.vivienda_subusuarios vs
        JOIN public.viviendas v ON v.id = vs.vivienda_id
        JOIN public.usuarios ut ON ut.id = vs.titular_id
        WHERE vs.usuario_id = p_actor_id
          AND vs.activo = true
          AND v.condominio_id = v_area.condominio_id
          AND v.activo = true
          AND ut.activo = true
        ORDER BY vs.creado_en ASC
        LIMIT 1;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Debes tener una vivienda activa asignada como titular o subusuario para reservar.' USING ERRCODE = 'RE015';
        END IF;

        v_es_titular := false;
        v_estado_inicial := 'PENDIENTE_TITULAR';
    END IF;

    IF p_fin <= p_inicio THEN
        RAISE EXCEPTION 'La fecha/hora de fin debe ser posterior a la de inicio.' USING ERRCODE = 'RE006';
    END IF;

    IF (p_fin - p_inicio) < INTERVAL '30 minutes' OR (p_fin - p_inicio) > INTERVAL '12 hours' THEN
        RAISE EXCEPTION 'La duración de la reserva debe ser de entre 30 minutos y 12 horas.' USING ERRCODE = 'RE006';
    END IF;

    IF p_inicio < (now() + INTERVAL '7 days') THEN
        RAISE EXCEPTION 'Las reservas deben solicitarse con al menos 7 días de anticipación.' USING ERRCODE = 'RE007';
    END IF;

    IF p_inicio > (now() + INTERVAL '30 days') THEN
        RAISE EXCEPTION 'No se pueden solicitar reservas con más de 30 días de anticipación.' USING ERRCODE = 'RE007';
    END IF;

    v_inicio_local := p_inicio AT TIME ZONE v_zona_horaria;
    v_fin_local := p_fin AT TIME ZONE v_zona_horaria;

    IF v_inicio_local::DATE <> v_fin_local::DATE THEN
        RAISE EXCEPTION 'La reserva debe iniciar y finalizar el mismo día.' USING ERRCODE = 'RE005';
    END IF;

    IF v_inicio_local::TIME < v_area.hora_apertura OR v_fin_local::TIME > v_area.hora_cierre THEN
        RAISE EXCEPTION 'El horario solicitado está fuera del horario de operación del área (% a %).',
            v_area.hora_apertura, v_area.hora_cierre
            USING ERRCODE = 'RE005';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.reservas r
        WHERE r.area_id = p_area_id
          AND r.estado = 'CONFIRMADA'
          AND tstzrange(r.inicio, r.fin, '[)') && tstzrange(p_inicio, p_fin, '[)')
    ) THEN
        RAISE EXCEPTION 'El horario solicitado se traslapa con una reserva confirmada o bloqueo existente.' USING ERRCODE = 'RE009';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.reservas r
        WHERE r.vivienda_id = v_vivienda_id
          AND r.tipo = 'RESERVA'
          AND r.estado IN ('PENDIENTE_TITULAR', 'PENDIENTE_ADMIN', 'APROBADA', 'CONFIRMADA')
          AND (r.inicio AT TIME ZONE v_zona_horaria)::DATE = v_inicio_local::DATE
    ) THEN
        RAISE EXCEPTION 'Tu vivienda ya cuenta con una reserva para ese día.' USING ERRCODE = 'RE008';
    END IF;

    INSERT INTO public.reservas (
        area_id, condominio_id, titular_id, vivienda_id, solicitante_id,
        tipo, inicio, fin, estado
    )
    VALUES (
        p_area_id, v_area.condominio_id, v_titular_id, v_vivienda_id, p_actor_id,
        'RESERVA', p_inicio, p_fin, v_estado_inicial
    )
    RETURNING * INTO v_reserva;

    IF v_estado_inicial = 'PENDIENTE_TITULAR' THEN
        PERFORM public._insertar_notificacion_reserva(
            v_titular_id,
            'reserva_pendiente_titular',
            'Solicitud de reserva de subusuario',
            format('%s solicitó reservar %s para el %s. Requiere tu autorización.',
                v_solicitante_nombre,
                v_area.nombre,
                to_char(v_inicio_local, 'DD/MM/YYYY HH24:MI')),
            '/reservas/por-aprobar',
            v_reserva.id
        );
    ELSE
        SELECT id INTO v_admin_id
        FROM public.usuarios
        WHERE condominio_id = v_area.condominio_id
          AND rol_id = 1
          AND activo = true
        LIMIT 1;

        PERFORM public._insertar_notificacion_reserva(
            v_admin_id,
            'reserva_pendiente_admin',
            'Nueva solicitud de reserva',
            format('%s solicitó reservar %s para el %s.',
                v_solicitante_nombre,
                v_area.nombre,
                to_char(v_inicio_local, 'DD/MM/YYYY HH24:MI')),
            '/admin/reservas',
            v_reserva.id
        );
    END IF;

    RETURN (SELECT to_jsonb(vr.*) FROM public.vw_reservas_usuario vr WHERE vr.id = v_reserva.id);
END;
$$;

ALTER FUNCTION public.solicitar_reserva(p_actor_id uuid, p_area_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone) OWNER TO postgres;
GRANT ALL ON FUNCTION public.solicitar_reserva(p_actor_id uuid, p_area_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone) TO service_role;

-- 8. aprobar_reserva_titular
CREATE OR REPLACE FUNCTION public.aprobar_reserva_titular(p_actor_id uuid, p_reserva_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_reserva RECORD;
    v_area_nombre TEXT;
    v_zona_horaria TEXT;
    v_admin_id UUID;
BEGIN
    SELECT * INTO v_reserva
    FROM public.reservas
    WHERE id = p_reserva_id
    FOR UPDATE;

    IF NOT FOUND OR v_reserva.tipo <> 'RESERVA' THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_reserva.titular_id IS DISTINCT FROM p_actor_id THEN
        RAISE EXCEPTION 'Solo el titular de la vivienda puede autorizar esta solicitud.' USING ERRCODE = 'RE003';
    END IF;

    IF v_reserva.estado <> 'PENDIENTE_TITULAR' THEN
        RAISE EXCEPTION 'La reserva no se encuentra pendiente de autorización del titular (estado actual: %).', v_reserva.estado
            USING ERRCODE = 'RE004';
    END IF;

    IF v_reserva.inicio <= now() THEN
        RAISE EXCEPTION 'La fecha de inicio de la reserva ya ha vencido.' USING ERRCODE = 'RE012';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.reservas r
        WHERE r.area_id = v_reserva.area_id
          AND r.estado = 'CONFIRMADA'
          AND tstzrange(r.inicio, r.fin, '[)') && tstzrange(v_reserva.inicio, v_reserva.fin, '[)')
    ) THEN
        RAISE EXCEPTION 'El horario ya fue ocupado por otra reserva confirmada o bloqueo.' USING ERRCODE = 'RE009';
    END IF;

    UPDATE public.reservas
    SET estado = 'PENDIENTE_ADMIN',
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    SELECT a.nombre, c.zona_horaria INTO v_area_nombre, v_zona_horaria
    FROM public.areas_comunes a
    JOIN public.condominios c ON c.id = a.condominio_id
    WHERE a.id = v_reserva.area_id;

    SELECT id INTO v_admin_id
    FROM public.usuarios
    WHERE condominio_id = v_reserva.condominio_id
      AND rol_id = 1
      AND activo = true
    LIMIT 1;

    PERFORM public._insertar_notificacion_reserva(
        v_admin_id,
        'reserva_pendiente_admin',
        'Nueva solicitud de reserva',
        format('El titular autorizó una solicitud para reservar %s el %s.',
            v_area_nombre,
            to_char(v_reserva.inicio AT TIME ZONE v_zona_horaria, 'DD/MM/YYYY HH24:MI')),
        '/admin/reservas',
        p_reserva_id
    );

    PERFORM public._insertar_notificacion_reserva(
        v_reserva.solicitante_id,
        'reserva_autorizada_titular',
        'Solicitud autorizada por el titular',
        format('El titular autorizó tu solicitud para %s. Ahora está pendiente de aprobación por la administración.',
            v_area_nombre),
        '/reservas/mias',
        p_reserva_id
    );

    RETURN true;
END;
$$;

ALTER FUNCTION public.aprobar_reserva_titular(p_actor_id uuid, p_reserva_id uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.aprobar_reserva_titular(p_actor_id uuid, p_reserva_id uuid) TO service_role;

-- 9. rechazar_reserva_titular
CREATE OR REPLACE FUNCTION public.rechazar_reserva_titular(p_actor_id uuid, p_reserva_id uuid, p_motivo text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_reserva RECORD;
    v_area_nombre TEXT;
BEGIN
    SELECT * INTO v_reserva
    FROM public.reservas
    WHERE id = p_reserva_id
    FOR UPDATE;

    IF NOT FOUND OR v_reserva.tipo <> 'RESERVA' THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_reserva.titular_id IS DISTINCT FROM p_actor_id THEN
        RAISE EXCEPTION 'Solo el titular de la vivienda puede rechazar esta solicitud.' USING ERRCODE = 'RE003';
    END IF;

    IF v_reserva.estado <> 'PENDIENTE_TITULAR' THEN
        RAISE EXCEPTION 'La reserva no se encuentra pendiente de autorización del titular (estado actual: %).', v_reserva.estado
            USING ERRCODE = 'RE004';
    END IF;

    UPDATE public.reservas
    SET estado = 'RECHAZADA_TITULAR',
        motivo = COALESCE(NULLIF(trim(p_motivo), ''), motivo),
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    SELECT nombre INTO v_area_nombre FROM public.areas_comunes WHERE id = v_reserva.area_id;

    PERFORM public._insertar_notificacion_reserva(
        v_reserva.solicitante_id,
        'reserva_rechazada_titular',
        'Solicitud rechazada por el titular',
        format('El titular rechazó tu solicitud para reservar %s.%s',
            v_area_nombre,
            CASE WHEN p_motivo IS NOT NULL AND length(trim(p_motivo)) > 0 THEN ' Motivo: ' || trim(p_motivo) ELSE '' END),
        '/reservas/mias',
        p_reserva_id
    );

    RETURN true;
END;
$$;

ALTER FUNCTION public.rechazar_reserva_titular(p_actor_id uuid, p_reserva_id uuid, p_motivo text) OWNER TO postgres;
GRANT ALL ON FUNCTION public.rechazar_reserva_titular(p_actor_id uuid, p_reserva_id uuid, p_motivo text) TO service_role;

-- 10. aprobar_reserva_admin
CREATE OR REPLACE FUNCTION public.aprobar_reserva_admin(p_actor_id uuid, p_reserva_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_reserva RECORD;
    v_area RECORD;
    v_zona_horaria TEXT;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id <> 1 THEN
        RAISE EXCEPTION 'Solo un administrador activo puede aprobar reservas.' USING ERRCODE = 'RE003';
    END IF;

    SELECT * INTO v_reserva
    FROM public.reservas
    WHERE id = p_reserva_id
    FOR UPDATE;

    IF NOT FOUND OR v_reserva.tipo <> 'RESERVA' THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_reserva.condominio_id IS DISTINCT FROM v_actor.condominio_id THEN
        RAISE EXCEPTION 'No tienes permiso sobre reservas de otro condominio.' USING ERRCODE = 'RE014';
    END IF;

    IF v_reserva.estado <> 'PENDIENTE_ADMIN' THEN
        RAISE EXCEPTION 'La reserva no está en estado PENDIENTE_ADMIN (estado actual: %).', v_reserva.estado
            USING ERRCODE = 'RE004';
    END IF;

    IF v_reserva.inicio <= now() THEN
        RAISE EXCEPTION 'La fecha de inicio de la reserva ya ha vencido.' USING ERRCODE = 'RE012';
    END IF;

    SELECT a.*, c.zona_horaria INTO v_area
    FROM public.areas_comunes a
    JOIN public.condominios c ON c.id = a.condominio_id
    WHERE a.id = v_reserva.area_id;

    IF NOT v_area.activo THEN
        RAISE EXCEPTION 'El área común está inactiva y no permite aprobar reservas.' USING ERRCODE = 'RE001';
    END IF;

    v_zona_horaria := v_area.zona_horaria;

    IF EXISTS (
        SELECT 1
        FROM public.reservas r
        WHERE r.area_id = v_reserva.area_id
          AND r.estado = 'CONFIRMADA'
          AND tstzrange(r.inicio, r.fin, '[)') && tstzrange(v_reserva.inicio, v_reserva.fin, '[)')
    ) THEN
        RAISE EXCEPTION 'El horario ya fue ocupado por otra reserva confirmada o bloqueo.' USING ERRCODE = 'RE009';
    END IF;

    UPDATE public.reservas
    SET estado = 'APROBADA',
        aprobador_id = p_actor_id,
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    PERFORM public._insertar_notificacion_reserva(
        v_reserva.solicitante_id,
        'reserva_aprobada',
        'Reserva aprobada - Pendiente de confirmación',
        format('Tu reserva de %s para el %s fue aprobada. Debes confirmarla entre 7 días y 72 horas antes del evento.',
            v_area.nombre,
            to_char(v_reserva.inicio AT TIME ZONE v_zona_horaria, 'DD/MM/YYYY HH24:MI')),
        '/reservas/mias',
        p_reserva_id
    );

    IF v_reserva.titular_id IS DISTINCT FROM v_reserva.solicitante_id THEN
        PERFORM public._insertar_notificacion_reserva(
            v_reserva.titular_id,
            'reserva_aprobada',
            'Reserva de tu vivienda aprobada',
            format('La reserva de %s para el %s fue aprobada por administración. Requiere confirmación.',
                v_area.nombre,
                to_char(v_reserva.inicio AT TIME ZONE v_zona_horaria, 'DD/MM/YYYY HH24:MI')),
            '/reservas/mias',
            p_reserva_id
        );
    END IF;

    RETURN true;
END;
$$;

ALTER FUNCTION public.aprobar_reserva_admin(p_actor_id uuid, p_reserva_id uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.aprobar_reserva_admin(p_actor_id uuid, p_reserva_id uuid) TO service_role;

-- 11. rechazar_reserva_admin
CREATE OR REPLACE FUNCTION public.rechazar_reserva_admin(p_actor_id uuid, p_reserva_id uuid, p_motivo text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_reserva RECORD;
    v_area_nombre TEXT;
    v_motivo_limpio TEXT;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id <> 1 THEN
        RAISE EXCEPTION 'Solo un administrador activo puede rechazar reservas.' USING ERRCODE = 'RE003';
    END IF;

    v_motivo_limpio := trim(COALESCE(p_motivo, ''));
    IF length(v_motivo_limpio) = 0 THEN
        RAISE EXCEPTION 'El motivo de rechazo es obligatorio.' USING ERRCODE = 'RE010';
    END IF;

    SELECT * INTO v_reserva
    FROM public.reservas
    WHERE id = p_reserva_id
    FOR UPDATE;

    IF NOT FOUND OR v_reserva.tipo <> 'RESERVA' THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_reserva.condominio_id IS DISTINCT FROM v_actor.condominio_id THEN
        RAISE EXCEPTION 'No tienes permiso sobre reservas de otro condominio.' USING ERRCODE = 'RE014';
    END IF;

    IF v_reserva.estado <> 'PENDIENTE_ADMIN' THEN
        RAISE EXCEPTION 'Solo se pueden rechazar reservas en estado PENDIENTE_ADMIN (estado actual: %).', v_reserva.estado
            USING ERRCODE = 'RE004';
    END IF;

    UPDATE public.reservas
    SET estado = 'RECHAZADA_ADMIN',
        aprobador_id = p_actor_id,
        motivo = v_motivo_limpio,
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    SELECT nombre INTO v_area_nombre FROM public.areas_comunes WHERE id = v_reserva.area_id;

    PERFORM public._insertar_notificacion_reserva(
        v_reserva.solicitante_id,
        'reserva_rechazada_admin',
        'Reserva rechazada por administración',
        format('Tu solicitud de reserva para %s fue rechazada. Motivo: %s', v_area_nombre, v_motivo_limpio),
        '/reservas/mias',
        p_reserva_id
    );

    IF v_reserva.titular_id IS DISTINCT FROM v_reserva.solicitante_id THEN
        PERFORM public._insertar_notificacion_reserva(
            v_reserva.titular_id,
            'reserva_rechazada_admin',
            'Reserva de tu vivienda rechazada',
            format('La solicitud de reserva para %s fue rechazada por administración. Motivo: %s', v_area_nombre, v_motivo_limpio),
            '/reservas/mias',
            p_reserva_id
        );
    END IF;

    RETURN true;
END;
$$;

ALTER FUNCTION public.rechazar_reserva_admin(p_actor_id uuid, p_reserva_id uuid, p_motivo text) OWNER TO postgres;
GRANT ALL ON FUNCTION public.rechazar_reserva_admin(p_actor_id uuid, p_reserva_id uuid, p_motivo text) TO service_role;

-- 12. confirmar_reserva
CREATE OR REPLACE FUNCTION public.confirmar_reserva(p_actor_id uuid, p_reserva_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_reserva RECORD;
    v_area RECORD;
    v_zona_horaria TEXT;
    v_competidora RECORD;
BEGIN
    SELECT * INTO v_reserva
    FROM public.reservas
    WHERE id = p_reserva_id
    FOR UPDATE;

    IF NOT FOUND OR v_reserva.tipo <> 'RESERVA' THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF p_actor_id IS DISTINCT FROM v_reserva.solicitante_id
       AND p_actor_id IS DISTINCT FROM v_reserva.titular_id THEN
        RAISE EXCEPTION 'Solo el solicitante o el titular pueden confirmar esta reserva.' USING ERRCODE = 'RE003';
    END IF;

    IF v_reserva.estado <> 'APROBADA' THEN
        RAISE EXCEPTION 'Solo se pueden confirmar reservas en estado APROBADA (estado actual: %).', v_reserva.estado
            USING ERRCODE = 'RE004';
    END IF;

    IF now() < (v_reserva.inicio - INTERVAL '7 days') OR now() > (v_reserva.inicio - INTERVAL '72 hours') THEN
        RAISE EXCEPTION 'La reserva solo puede confirmarse entre 7 días y 72 horas antes del inicio.' USING ERRCODE = 'RE011';
    END IF;

    SELECT a.*, c.zona_horaria INTO v_area
    FROM public.areas_comunes a
    JOIN public.condominios c ON c.id = a.condominio_id
    WHERE a.id = v_reserva.area_id;

    IF NOT v_area.activo THEN
        RAISE EXCEPTION 'El área común está inactiva.' USING ERRCODE = 'RE001';
    END IF;

    v_zona_horaria := v_area.zona_horaria;

    BEGIN
        UPDATE public.reservas
        SET estado = 'CONFIRMADA',
            confirmada_en = timezone('utc'::text, now()),
            actualizado_en = timezone('utc'::text, now())
        WHERE id = p_reserva_id;
    EXCEPTION
        WHEN exclusion_violation THEN
            RAISE EXCEPTION 'El horario ya fue confirmado por otra reserva o bloqueo.' USING ERRCODE = 'RE009';
    END;

    PERFORM public._insertar_notificacion_reserva(
        v_reserva.solicitante_id,
        'reserva_confirmada',
        'Reserva confirmada',
        format('Tu reserva de %s para el %s ha quedado confirmada.',
            v_area.nombre,
            to_char(v_reserva.inicio AT TIME ZONE v_zona_horaria, 'DD/MM/YYYY HH24:MI')),
        '/reservas/mias',
        p_reserva_id
    );

    IF v_reserva.titular_id IS DISTINCT FROM v_reserva.solicitante_id THEN
        PERFORM public._insertar_notificacion_reserva(
            v_reserva.titular_id,
            'reserva_confirmada',
            'Reserva confirmada en tu vivienda',
            format('La reserva de %s para el %s ha quedado confirmada.',
                v_area.nombre,
                to_char(v_reserva.inicio AT TIME ZONE v_zona_horaria, 'DD/MM/YYYY HH24:MI')),
            '/reservas/mias',
            p_reserva_id
        );
    END IF;

    FOR v_competidora IN
        UPDATE public.reservas
        SET estado = 'CANCELADA_ADMIN',
            motivo = 'Horario confirmado por otro residente',
            actualizado_en = timezone('utc'::text, now())
        WHERE area_id = v_reserva.area_id
          AND id <> v_reserva.id
          AND tipo = 'RESERVA'
          AND estado IN ('PENDIENTE_TITULAR', 'PENDIENTE_ADMIN', 'APROBADA')
          AND tstzrange(inicio, fin, '[)') && tstzrange(v_reserva.inicio, v_reserva.fin, '[)')
        RETURNING id, solicitante_id, titular_id
    LOOP
        PERFORM public._insertar_notificacion_reserva(
            v_competidora.solicitante_id,
            'reserva_cancelada_colision',
            'Horario no disponible',
            format('Tu solicitud para %s fue cancelada porque otro residente confirmó primero ese horario.', v_area.nombre),
            '/reservas/mias',
            v_competidora.id
        );

        IF v_competidora.titular_id IS DISTINCT FROM v_competidora.solicitante_id THEN
            PERFORM public._insertar_notificacion_reserva(
                v_competidora.titular_id,
                'reserva_cancelada_colision',
                'Horario no disponible',
                format('La solicitud de tu vivienda para %s fue cancelada porque otro residente confirmó primero ese horario.', v_area.nombre),
                '/reservas/mias',
                v_competidora.id
            );
        END IF;
    END LOOP;

    RETURN true;
END;
$$;

ALTER FUNCTION public.confirmar_reserva(p_actor_id uuid, p_reserva_id uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.confirmar_reserva(p_actor_id uuid, p_reserva_id uuid) TO service_role;

-- 13. cancelar_reserva_usuario
CREATE OR REPLACE FUNCTION public.cancelar_reserva_usuario(p_actor_id uuid, p_reserva_id uuid, p_motivo text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_reserva RECORD;
    v_area_nombre TEXT;
BEGIN
    SELECT * INTO v_reserva
    FROM public.reservas
    WHERE id = p_reserva_id
    FOR UPDATE;

    IF NOT FOUND OR v_reserva.tipo <> 'RESERVA' THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF p_actor_id IS DISTINCT FROM v_reserva.solicitante_id
       AND p_actor_id IS DISTINCT FROM v_reserva.titular_id THEN
        RAISE EXCEPTION 'No tienes permiso para cancelar esta reserva.' USING ERRCODE = 'RE003';
    END IF;

    IF v_reserva.estado NOT IN ('PENDIENTE_TITULAR', 'PENDIENTE_ADMIN', 'APROBADA', 'CONFIRMADA') THEN
        RAISE EXCEPTION 'La reserva no se puede cancelar en su estado actual (%).', v_reserva.estado
            USING ERRCODE = 'RE004';
    END IF;

    IF v_reserva.inicio <= now() THEN
        RAISE EXCEPTION 'No se puede cancelar una reserva que ya inició.' USING ERRCODE = 'RE012';
    END IF;

    UPDATE public.reservas
    SET estado = 'CANCELADA_USUARIO',
        motivo = COALESCE(NULLIF(trim(p_motivo), ''), motivo),
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    SELECT nombre INTO v_area_nombre FROM public.areas_comunes WHERE id = v_reserva.area_id;

    IF p_actor_id = v_reserva.titular_id AND v_reserva.solicitante_id <> v_reserva.titular_id THEN
        PERFORM public._insertar_notificacion_reserva(
            v_reserva.solicitante_id,
            'reserva_cancelada_usuario',
            'Reserva cancelada por el titular',
            format('El titular de tu vivienda canceló la reserva de %s.', v_area_nombre),
            '/reservas/mias',
            p_reserva_id
        );
    ELSIF p_actor_id = v_reserva.solicitante_id AND v_reserva.titular_id <> v_reserva.solicitante_id THEN
        PERFORM public._insertar_notificacion_reserva(
            v_reserva.titular_id,
            'reserva_cancelada_usuario',
            'Reserva cancelada por subusuario',
            format('El subusuario canceló su reserva de %s.', v_area_nombre),
            '/reservas/mias',
            p_reserva_id
        );
    END IF;

    RETURN true;
END;
$$;

ALTER FUNCTION public.cancelar_reserva_usuario(p_actor_id uuid, p_reserva_id uuid, p_motivo text) OWNER TO postgres;
GRANT ALL ON FUNCTION public.cancelar_reserva_usuario(p_actor_id uuid, p_reserva_id uuid, p_motivo text) TO service_role;

-- 14. cancelar_reserva
CREATE OR REPLACE FUNCTION public.cancelar_reserva(p_actor_id uuid, p_reserva_id uuid, p_motivo text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT public.cancelar_reserva_usuario(p_actor_id, p_reserva_id, p_motivo);
$$;

ALTER FUNCTION public.cancelar_reserva(p_actor_id uuid, p_reserva_id uuid, p_motivo text) OWNER TO postgres;
GRANT ALL ON FUNCTION public.cancelar_reserva(p_actor_id uuid, p_reserva_id uuid, p_motivo text) TO service_role;

-- 15. cancelar_reserva_admin
CREATE OR REPLACE FUNCTION public.cancelar_reserva_admin(p_actor_id uuid, p_reserva_id uuid, p_motivo text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_reserva RECORD;
    v_area_nombre TEXT;
    v_motivo_limpio TEXT;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id <> 1 THEN
        RAISE EXCEPTION 'Solo un administrador activo puede cancelar reservas.' USING ERRCODE = 'RE003';
    END IF;

    v_motivo_limpio := trim(COALESCE(p_motivo, ''));
    IF length(v_motivo_limpio) = 0 THEN
        RAISE EXCEPTION 'El motivo de cancelación es obligatorio.' USING ERRCODE = 'RE010';
    END IF;

    SELECT * INTO v_reserva
    FROM public.reservas
    WHERE id = p_reserva_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_reserva.condominio_id IS DISTINCT FROM v_actor.condominio_id THEN
        RAISE EXCEPTION 'No tienes permiso sobre reservas de otro condominio.' USING ERRCODE = 'RE014';
    END IF;

    IF v_reserva.estado NOT IN ('PENDIENTE_TITULAR', 'PENDIENTE_ADMIN', 'APROBADA', 'CONFIRMADA') THEN
        RAISE EXCEPTION 'El registro no se puede cancelar en su estado actual (%).', v_reserva.estado
            USING ERRCODE = 'RE004';
    END IF;

    UPDATE public.reservas
    SET estado = 'CANCELADA_ADMIN',
        aprobador_id = p_actor_id,
        motivo = v_motivo_limpio,
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    IF v_reserva.tipo = 'RESERVA' THEN
        SELECT nombre INTO v_area_nombre FROM public.areas_comunes WHERE id = v_reserva.area_id;

        PERFORM public._insertar_notificacion_reserva(
            v_reserva.solicitante_id,
            'reserva_cancelada_admin',
            'Reserva cancelada por administración',
            format('La administración canceló tu reserva de %s. Motivo: %s', v_area_nombre, v_motivo_limpio),
            '/reservas/mias',
            p_reserva_id
        );

        IF v_reserva.titular_id IS DISTINCT FROM v_reserva.solicitante_id THEN
            PERFORM public._insertar_notificacion_reserva(
                v_reserva.titular_id,
                'reserva_cancelada_admin',
                'Reserva de tu vivienda cancelada',
                format('La administración canceló la reserva de %s. Motivo: %s', v_area_nombre, v_motivo_limpio),
                '/reservas/mias',
                p_reserva_id
            );
        END IF;
    END IF;

    RETURN true;
END;
$$;

ALTER FUNCTION public.cancelar_reserva_admin(p_actor_id uuid, p_reserva_id uuid, p_motivo text) OWNER TO postgres;
GRANT ALL ON FUNCTION public.cancelar_reserva_admin(p_actor_id uuid, p_reserva_id uuid, p_motivo text) TO service_role;

-- 16. marcar_reserva_no_utilizada
CREATE OR REPLACE FUNCTION public.marcar_reserva_no_utilizada(p_actor_id uuid, p_reserva_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_reserva RECORD;
    v_area_nombre TEXT;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id <> 1 THEN
        RAISE EXCEPTION 'Solo un administrador activo puede registrar incumplimientos (no-show).' USING ERRCODE = 'RE003';
    END IF;

    SELECT * INTO v_reserva
    FROM public.reservas
    WHERE id = p_reserva_id
    FOR UPDATE;

    IF NOT FOUND OR v_reserva.tipo <> 'RESERVA' THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_reserva.condominio_id IS DISTINCT FROM v_actor.condominio_id THEN
        RAISE EXCEPTION 'No tienes permiso sobre reservas de otro condominio.' USING ERRCODE = 'RE014';
    END IF;

    IF v_reserva.fin > now() THEN
        RAISE EXCEPTION 'Solo se puede marcar como no utilizada una vez concluido el horario de la reserva.' USING ERRCODE = 'RE013';
    END IF;

    IF v_reserva.estado NOT IN ('CONFIRMADA', 'FINALIZADA') THEN
        RAISE EXCEPTION 'Solo se pueden marcar como no utilizadas reservas confirmadas o finalizadas (estado actual: %).', v_reserva.estado
            USING ERRCODE = 'RE004';
    END IF;

    UPDATE public.reservas
    SET estado = 'NO_UTILIZADA',
        aprobador_id = p_actor_id,
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    SELECT nombre INTO v_area_nombre FROM public.areas_comunes WHERE id = v_reserva.area_id;

    PERFORM public._insertar_notificacion_reserva(
        v_reserva.titular_id,
        'reserva_no_utilizada',
        'Reserva marcada como no utilizada',
        format('La reserva de %s en tu vivienda fue registrada como no utilizada (No-Show).', v_area_nombre),
        '/reservas/mias',
        p_reserva_id
    );

    IF v_reserva.solicitante_id IS DISTINCT FROM v_reserva.titular_id THEN
        PERFORM public._insertar_notificacion_reserva(
            v_reserva.solicitante_id,
            'reserva_no_utilizada',
            'Reserva marcada como no utilizada',
            format('Tu reserva de %s fue registrada como no utilizada (No-Show).', v_area_nombre),
            '/reservas/mias',
            p_reserva_id
        );
    END IF;

    RETURN true;
END;
$$;

ALTER FUNCTION public.marcar_reserva_no_utilizada(p_actor_id uuid, p_reserva_id uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.marcar_reserva_no_utilizada(p_actor_id uuid, p_reserva_id uuid) TO service_role;

-- 17. crear_bloqueo_area
CREATE OR REPLACE FUNCTION public.crear_bloqueo_area(p_actor_id uuid, p_area_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_motivo text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_area RECORD;
    v_zona_horaria TEXT;
    v_motivo_limpio TEXT;
    v_bloqueo RECORD;
    v_afectada RECORD;
    v_canceladas_count INT := 0;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id <> 1 THEN
        RAISE EXCEPTION 'Solo un administrador activo puede crear bloqueos.' USING ERRCODE = 'RE003';
    END IF;

    v_motivo_limpio := trim(COALESCE(p_motivo, ''));
    IF length(v_motivo_limpio) = 0 THEN
        RAISE EXCEPTION 'El motivo del bloqueo es obligatorio.' USING ERRCODE = 'RE010';
    END IF;

    SELECT a.*, c.zona_horaria INTO v_area
    FROM public.areas_comunes a
    JOIN public.condominios c ON c.id = a.condominio_id
    WHERE a.id = p_area_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El área común no existe.' USING ERRCODE = 'RE001';
    END IF;

    IF v_area.condominio_id IS DISTINCT FROM v_actor.condominio_id THEN
        RAISE EXCEPTION 'No tienes permiso sobre áreas de otro condominio.' USING ERRCODE = 'RE014';
    END IF;

    v_zona_horaria := v_area.zona_horaria;

    IF p_fin <= p_inicio THEN
        RAISE EXCEPTION 'La fecha/hora de fin del bloqueo debe ser posterior a la de inicio.' USING ERRCODE = '22023';
    END IF;

    IF EXTRACT(MINUTE FROM (p_inicio AT TIME ZONE v_zona_horaria)) <> 0
       OR EXTRACT(SECOND FROM (p_inicio AT TIME ZONE v_zona_horaria)) <> 0
       OR EXTRACT(MINUTE FROM (p_fin AT TIME ZONE v_zona_horaria)) <> 0
       OR EXTRACT(SECOND FROM (p_fin AT TIME ZONE v_zona_horaria)) <> 0 THEN
        RAISE EXCEPTION 'Los bloqueos deben alinearse a horas exactas (:00:00).' USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.reservas r
        WHERE r.area_id = p_area_id
          AND r.tipo = 'BLOQUEO'
          AND r.estado = 'CONFIRMADA'
          AND tstzrange(r.inicio, r.fin, '[)') && tstzrange(p_inicio, p_fin, '[)')
    ) THEN
        RAISE EXCEPTION 'Ya existe otro bloqueo activo que se traslapa con este rango.' USING ERRCODE = 'RE009';
    END IF;

    FOR v_afectada IN
        UPDATE public.reservas
        SET estado = 'CANCELADA_ADMIN',
            aprobador_id = p_actor_id,
            motivo = 'Bloqueo administrativo: ' || v_motivo_limpio,
            actualizado_en = timezone('utc'::text, now())
        WHERE area_id = p_area_id
          AND tipo = 'RESERVA'
          AND estado IN ('PENDIENTE_TITULAR', 'PENDIENTE_ADMIN', 'APROBADA', 'CONFIRMADA')
          AND tstzrange(inicio, fin, '[)') && tstzrange(p_inicio, p_fin, '[)')
        RETURNING id, solicitante_id, titular_id
    LOOP
        v_canceladas_count := v_canceladas_count + 1;

        PERFORM public._insertar_notificacion_reserva(
            v_afectada.solicitante_id,
            'reserva_cancelada_bloqueo',
            'Reserva cancelada por bloqueo de área',
            format('Tu reserva de %s fue cancelada debido a un bloqueo administrativo: %s', v_area.nombre, v_motivo_limpio),
            '/reservas/mias',
            v_afectada.id
        );

        IF v_afectada.titular_id IS DISTINCT FROM v_afectada.solicitante_id THEN
            PERFORM public._insertar_notificacion_reserva(
                v_afectada.titular_id,
                'reserva_cancelada_bloqueo',
                'Reserva de tu vivienda cancelada por bloqueo',
                format('La reserva de %s fue cancelada debido a un bloqueo administrativo: %s', v_area.nombre, v_motivo_limpio),
                '/reservas/mias',
                v_afectada.id
            );
        END IF;
    END LOOP;

    INSERT INTO public.reservas (
        area_id, condominio_id, titular_id, vivienda_id, solicitante_id, aprobador_id,
        tipo, inicio, fin, estado, motivo, confirmada_en
    )
    VALUES (
        p_area_id, v_area.condominio_id, NULL, NULL, p_actor_id, p_actor_id,
        'BLOQUEO', p_inicio, p_fin, 'CONFIRMADA', v_motivo_limpio, timezone('utc'::text, now())
    )
    RETURNING * INTO v_bloqueo;

    RETURN jsonb_build_object(
        'bloqueo_id', v_bloqueo.id,
        'area_id', v_bloqueo.area_id,
        'inicio', v_bloqueo.inicio,
        'fin', v_bloqueo.fin,
        'motivo', v_bloqueo.motivo,
        'reservas_afectadas', v_canceladas_count
    );
END;
$$;

ALTER FUNCTION public.crear_bloqueo_area(p_actor_id uuid, p_area_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_motivo text) OWNER TO postgres;
GRANT ALL ON FUNCTION public.crear_bloqueo_area(p_actor_id uuid, p_area_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_motivo text) TO service_role;

-- 18. actualizar_bloqueo_area
CREATE OR REPLACE FUNCTION public.actualizar_bloqueo_area(p_actor_id uuid, p_bloqueo_id uuid, p_inicio timestamp with time zone DEFAULT NULL::timestamp with time zone, p_fin timestamp with time zone DEFAULT NULL::timestamp with time zone, p_motivo text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_bloqueo RECORD;
    v_area RECORD;
    v_zona_horaria TEXT;
    v_inicio_final TIMESTAMPTZ;
    v_fin_final TIMESTAMPTZ;
    v_motivo_final TEXT;
    v_afectada RECORD;
    v_canceladas_count INT := 0;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id <> 1 THEN
        RAISE EXCEPTION 'Solo un administrador activo puede actualizar bloqueos.' USING ERRCODE = 'RE003';
    END IF;

    SELECT * INTO v_bloqueo
    FROM public.reservas
    WHERE id = p_bloqueo_id
    FOR UPDATE;

    IF NOT FOUND OR v_bloqueo.tipo <> 'BLOQUEO' THEN
        RAISE EXCEPTION 'El bloqueo especificado no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_bloqueo.condominio_id IS DISTINCT FROM v_actor.condominio_id THEN
        RAISE EXCEPTION 'No tienes permiso sobre bloqueos de otro condominio.' USING ERRCODE = 'RE014';
    END IF;

    IF v_bloqueo.estado <> 'CONFIRMADA' THEN
        RAISE EXCEPTION 'Solo se pueden editar bloqueos activos (CONFIRMADA).' USING ERRCODE = 'RE004';
    END IF;

    SELECT a.*, c.zona_horaria INTO v_area
    FROM public.areas_comunes a
    JOIN public.condominios c ON c.id = a.condominio_id
    WHERE a.id = v_bloqueo.area_id;

    v_zona_horaria := v_area.zona_horaria;
    v_inicio_final := COALESCE(p_inicio, v_bloqueo.inicio);
    v_fin_final := COALESCE(p_fin, v_bloqueo.fin);
    v_motivo_final := COALESCE(NULLIF(trim(p_motivo), ''), v_bloqueo.motivo);

    IF v_fin_final <= v_inicio_final THEN
        RAISE EXCEPTION 'La fecha/hora de fin del bloqueo debe ser posterior a la de inicio.' USING ERRCODE = '22023';
    END IF;

    IF EXTRACT(MINUTE FROM (v_inicio_final AT TIME ZONE v_zona_horaria)) <> 0
       OR EXTRACT(SECOND FROM (v_inicio_final AT TIME ZONE v_zona_horaria)) <> 0
       OR EXTRACT(MINUTE FROM (v_fin_final AT TIME ZONE v_zona_horaria)) <> 0
       OR EXTRACT(SECOND FROM (v_fin_final AT TIME ZONE v_zona_horaria)) <> 0 THEN
        RAISE EXCEPTION 'Los bloqueos deben alinearse a horas exactas (:00:00).' USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.reservas r
        WHERE r.area_id = v_bloqueo.area_id
          AND r.id <> p_bloqueo_id
          AND r.tipo = 'BLOQUEO'
          AND r.estado = 'CONFIRMADA'
          AND tstzrange(r.inicio, r.fin, '[)') && tstzrange(v_inicio_final, v_fin_final, '[)')
    ) THEN
        RAISE EXCEPTION 'El nuevo rango se traslapa con otro bloqueo activo.' USING ERRCODE = 'RE009';
    END IF;

    FOR v_afectada IN
        UPDATE public.reservas
        SET estado = 'CANCELADA_ADMIN',
            aprobador_id = p_actor_id,
            motivo = 'Bloqueo administrativo: ' || v_motivo_final,
            actualizado_en = timezone('utc'::text, now())
        WHERE area_id = v_bloqueo.area_id
          AND id <> p_bloqueo_id
          AND tipo = 'RESERVA'
          AND estado IN ('PENDIENTE_TITULAR', 'PENDIENTE_ADMIN', 'APROBADA', 'CONFIRMADA')
          AND tstzrange(inicio, fin, '[)') && tstzrange(v_inicio_final, v_fin_final, '[)')
        RETURNING id, solicitante_id, titular_id
    LOOP
        v_canceladas_count := v_canceladas_count + 1;

        PERFORM public._insertar_notificacion_reserva(
            v_afectada.solicitante_id,
            'reserva_cancelada_bloqueo',
            'Reserva cancelada por bloqueo de área',
            format('Tu reserva de %s fue cancelada debido a un bloqueo administrativo: %s', v_area.nombre, v_motivo_final),
            '/reservas/mias',
            v_afectada.id
        );

        IF v_afectada.titular_id IS DISTINCT FROM v_afectada.solicitante_id THEN
            PERFORM public._insertar_notificacion_reserva(
                v_afectada.titular_id,
                'reserva_cancelada_bloqueo',
                'Reserva de tu vivienda cancelada por bloqueo',
                format('La reserva de %s fue cancelada debido a un bloqueo administrativo: %s', v_area.nombre, v_motivo_final),
                '/reservas/mias',
                v_afectada.id
            );
        END IF;
    END LOOP;

    UPDATE public.reservas
    SET inicio = v_inicio_final,
        fin = v_fin_final,
        motivo = v_motivo_final,
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_bloqueo_id
    RETURNING * INTO v_bloqueo;

    RETURN jsonb_build_array(jsonb_build_object(
        'bloqueo_id', v_bloqueo.id,
        'area_id', v_bloqueo.area_id,
        'inicio', v_bloqueo.inicio,
        'fin', v_bloqueo.fin,
        'motivo', v_bloqueo.motivo,
        'reservas_afectadas', v_canceladas_count
    ));
END;
$$;

ALTER FUNCTION public.actualizar_bloqueo_area(p_actor_id uuid, p_bloqueo_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_motivo text) OWNER TO postgres;
GRANT ALL ON FUNCTION public.actualizar_bloqueo_area(p_actor_id uuid, p_bloqueo_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_motivo text) TO service_role;

-- 19. eliminar_bloqueo_area
CREATE OR REPLACE FUNCTION public.eliminar_bloqueo_area(p_actor_id uuid, p_bloqueo_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_bloqueo RECORD;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id <> 1 THEN
        RAISE EXCEPTION 'Solo un administrador activo puede eliminar bloqueos.' USING ERRCODE = 'RE003';
    END IF;

    SELECT * INTO v_bloqueo
    FROM public.reservas
    WHERE id = p_bloqueo_id
    FOR UPDATE;

    IF NOT FOUND OR v_bloqueo.tipo <> 'BLOQUEO' THEN
        RAISE EXCEPTION 'El bloqueo especificado no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_bloqueo.condominio_id IS DISTINCT FROM v_actor.condominio_id THEN
        RAISE EXCEPTION 'No tienes permiso sobre bloqueos de otro condominio.' USING ERRCODE = 'RE014';
    END IF;

    IF v_bloqueo.estado <> 'CONFIRMADA' THEN
        RAISE EXCEPTION 'El bloqueo ya fue eliminado o cancelado.' USING ERRCODE = 'RE004';
    END IF;

    UPDATE public.reservas
    SET estado = 'CANCELADA_ADMIN',
        aprobador_id = p_actor_id,
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_bloqueo_id;

    RETURN true;
END;
$$;

ALTER FUNCTION public.eliminar_bloqueo_area(p_actor_id uuid, p_bloqueo_id uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.eliminar_bloqueo_area(p_actor_id uuid, p_bloqueo_id uuid) TO service_role;

-- 20. procesar_transiciones_reservas
CREATE OR REPLACE FUNCTION public.procesar_transiciones_reservas() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_rec RECORD;
    v_expiradas_confirmacion INT := 0;
    v_expiradas_pendientes INT := 0;
    v_finalizadas INT := 0;
    v_recordatorios INT := 0;
BEGIN
    FOR v_rec IN
        UPDATE public.reservas r
        SET estado = 'CANCELADA_EXPIRACION',
            motivo = 'No confirmada antes de 72 horas previas al inicio',
            actualizado_en = timezone('utc'::text, now())
        FROM public.areas_comunes a
        WHERE a.id = r.area_id
          AND r.tipo = 'RESERVA'
          AND r.estado = 'APROBADA'
          AND now() > (r.inicio - INTERVAL '72 hours')
        RETURNING r.id, r.solicitante_id, r.titular_id, a.nombre AS area_nombre
    LOOP
        v_expiradas_confirmacion := v_expiradas_confirmacion + 1;

        PERFORM public._insertar_notificacion_reserva(
            v_rec.solicitante_id,
            'reserva_expirada_confirmacion',
            'Reserva cancelada por falta de confirmación',
            format('Tu reserva de %s fue cancelada automáticamente por no confirmarse con al menos 72 horas de anticipación.', v_rec.area_nombre),
            '/reservas/mias',
            v_rec.id
        );

        IF v_rec.titular_id IS DISTINCT FROM v_rec.solicitante_id THEN
            PERFORM public._insertar_notificacion_reserva(
                v_rec.titular_id,
                'reserva_expirada_confirmacion',
                'Reserva cancelada por falta de confirmación',
                format('La reserva de %s en tu vivienda fue cancelada por no confirmarse a tiempo.', v_rec.area_nombre),
                '/reservas/mias',
                v_rec.id
            );
        END IF;
    END LOOP;

    FOR v_rec IN
        UPDATE public.reservas r
        SET estado = 'CANCELADA_EXPIRACION',
            motivo = 'Inicio alcanzado sin completar el flujo de aprobación',
            actualizado_en = timezone('utc'::text, now())
        FROM public.areas_comunes a
        WHERE a.id = r.area_id
          AND r.tipo = 'RESERVA'
          AND r.estado IN ('PENDIENTE_TITULAR', 'PENDIENTE_ADMIN')
          AND now() >= r.inicio
        RETURNING r.id, r.solicitante_id, r.titular_id, a.nombre AS area_nombre
    LOOP
        v_expiradas_pendientes := v_expiradas_pendientes + 1;

        PERFORM public._insertar_notificacion_reserva(
            v_rec.solicitante_id,
            'reserva_expirada_pendiente',
            'Solicitud de reserva expirada',
            format('Tu solicitud para %s expiró al alcanzarse la fecha de inicio sin aprobación.', v_rec.area_nombre),
            '/reservas/mias',
            v_rec.id
        );
    END LOOP;

    WITH fin_cte AS (
        UPDATE public.reservas
        SET estado = 'FINALIZADA',
            actualizado_en = timezone('utc'::text, now())
        WHERE estado = 'CONFIRMADA'
          AND fin <= now()
        RETURNING id
    )
    SELECT COUNT(*)::INT INTO v_finalizadas FROM fin_cte;

    FOR v_rec IN
        UPDATE public.reservas r
        SET recordatorio_24h_enviado = true
        FROM public.areas_comunes a, public.condominios c
        WHERE a.id = r.area_id
          AND c.id = r.condominio_id
          AND r.tipo = 'RESERVA'
          AND r.estado = 'CONFIRMADA'
          AND r.recordatorio_24h_enviado = false
          AND r.inicio > now()
          AND r.inicio <= (now() + INTERVAL '24 hours')
        RETURNING r.id, r.solicitante_id, r.titular_id, r.inicio, a.nombre AS area_nombre, c.zona_horaria
    LOOP
        v_recordatorios := v_recordatorios + 1;

        PERFORM public._insertar_notificacion_reserva(
            v_rec.solicitante_id,
            'reserva_recordatorio_24h',
            'Recordatorio de tu reserva',
            format('Te recordamos tu reserva confirmada de %s para el %s.',
                v_rec.area_nombre,
                to_char(v_rec.inicio AT TIME ZONE v_rec.zona_horaria, 'DD/MM/YYYY HH24:MI')),
            '/reservas/mias',
            v_rec.id
        );

        IF v_rec.titular_id IS DISTINCT FROM v_rec.solicitante_id THEN
            PERFORM public._insertar_notificacion_reserva(
                v_rec.titular_id,
                'reserva_recordatorio_24h',
                'Recordatorio de reserva en tu vivienda',
                format('Recordatorio: reserva confirmada de %s para el %s.',
                    v_rec.area_nombre,
                    to_char(v_rec.inicio AT TIME ZONE v_rec.zona_horaria, 'DD/MM/YYYY HH24:MI')),
                '/reservas/mias',
                v_rec.id
            );
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'expiradas_confirmacion', v_expiradas_confirmacion,
        'expiradas_pendientes', v_expiradas_pendientes,
        'finalizadas', v_finalizadas,
        'recordatorios_24h', v_recordatorios
    );
END;
$$;

ALTER FUNCTION public.procesar_transiciones_reservas() OWNER TO postgres;
GRANT ALL ON FUNCTION public.procesar_transiciones_reservas() TO service_role;

-- Cron jobs rotos
SELECT cron.unschedule(jobname) FROM cron.job
WHERE jobname IN ('expirar_reservas_pendientes', 'expirar_reservas_sin_confirmar', 'notificaciones_confirmacion_reservas');

COMMIT;

-- Recarga el caché de esquema de PostgREST para que vea las firmas nuevas.
NOTIFY pgrst, 'reload schema';
