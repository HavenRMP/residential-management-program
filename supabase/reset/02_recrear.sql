-- ==============================================================================
-- HAVEN - Paso 2 de 3: recrear la estructura
-- ------------------------------------------------------------------------------
-- Crea el esquema public (tablas, vistas, funciones, tipos, triggers, RLS y
-- permisos), los triggers sobre auth.users, el bucket y las politicas de storage,
-- el event trigger de RLS y los cron jobs. No carga datos.
-- Requiere haber ejecutado antes 01_tirar.sql.
--
-- Orden de ejecucion: 01_tirar.sql -> 02_recrear.sql -> 03_seed.sql
-- Cada archivo corre en su propia transaccion: si algo falla, ese paso no se aplica.
-- Ejecutar desde el SQL Editor de Supabase o con:
--   psql "<connection string session pooler>" -v ON_ERROR_STOP=1 -f supabase/reset/<archivo>
-- ==============================================================================

BEGIN;

-- 2.0 Extensiones requeridas
CREATE EXTENSION IF NOT EXISTS pgcrypto    WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS btree_gist  WITH SCHEMA public;

-- 2.1 Esquema public (estructura, RLS, politicas, permisos)
--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.11 (Debian 17.11-1.pgdg13+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA IF NOT EXISTS public;



--
-- Name: _insertar_notificacion_reserva(uuid, character varying, character varying, text, text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._insertar_notificacion_reserva(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text DEFAULT '/reservas'::text, p_reserva_id uuid DEFAULT NULL::uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    IF p_usuario_id IS NULL THEN
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_usuario_id AND activo = true) THEN
        INSERT INTO public.notificaciones (
            usuario_id, tipo_evento, titulo, mensaje, url_redireccion, reserva_id, push_enviado
        )
        VALUES (
            p_usuario_id, p_tipo_evento, p_titulo, p_mensaje, p_url_redireccion, p_reserva_id, false
        );
    END IF;
END;
$$;


ALTER FUNCTION public._insertar_notificacion_reserva(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text, p_reserva_id uuid) OWNER TO postgres;

--
-- Name: _proyectar_paquete_dto(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._proyectar_paquete_dto(p_paquete_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_res JSONB;
BEGIN
    SELECT jsonb_build_object(
        'id', p.id,
        'condominio_id', p.condominio_id,
        'condominio_nombre', p.condominio_nombre,
        'vivienda_id', p.vivienda_id,
        'numero_casa', p.numero_casa,
        'servicio_id', p.servicio_id,
        'servicio_nombre', p.servicio_nombre,
        'destinatario_nombre', p.destinatario_nombre,
        'numero_guia', p.numero_guia,
        'descripcion', p.descripcion,
        'notas', p.notas,
        'fecha_esperada_desde', p.fecha_esperada_desde,
        'fecha_esperada_hasta', p.fecha_esperada_hasta,
        'estado', p.estado,
        'es_inesperado', p.es_inesperado,
        'ubicacion_almacen', p.ubicacion_almacen,
        'recibido_en', p.recibido_en,
        'recibido_por_nombre', p.recibido_por_nombre,
        'entregado_en', p.entregado_en,
        'entregado_a_nombre', p.entregado_a_nombre,
        'entregado_por_nombre', p.entregado_por_nombre,
        'creado_por', p.creado_por,
        'creado_Por_nombre', COALESCE(p.creado_por_nombre, 'Residente'),
        'creado_por_nombre', COALESCE(p.creado_por_nombre, 'Residente'),
        'creado_en', p.creado_en
    ) INTO v_res
    FROM public.vw_paquetes_historico p
    WHERE p.id = p_paquete_id;

    RETURN v_res;
END;
$$;


ALTER FUNCTION public._proyectar_paquete_dto(p_paquete_id uuid) OWNER TO postgres;

--
-- Name: _proyectar_visita_dto(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._proyectar_visita_dto(p_visita_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_res JSONB;
BEGIN
    SELECT jsonb_build_object(
        'id', vi.id,
        'vivienda_id', vi.vivienda_id,
        'numero_casa', v.numero_casa,
        'condominio_id', vi.condominio_id,
        'nombre_visitante', vi.nombre_visitante,
        'apellidos_visitante', vi.apellidos_visitante,
        'telefono_visitante', vi.telefono_visitante,
        'motivo', vi.motivo,
        'num_acompanantes', vi.num_acompanantes,
        'vehiculo_placas', vi.vehiculo_placas,
        'notas', vi.notas,
        'fecha_llegada_esperada', vi.fecha_llegada_esperada,
        'fecha_expiracion', vi.fecha_expiracion,
        'estado', CASE
            WHEN vi.estado = 'programada' AND now() > vi.fecha_expiracion THEN 'expirada'
            ELSE vi.estado
        END,
        'estado_calculado', CASE
            WHEN vi.estado = 'programada' AND now() > vi.fecha_expiracion THEN 'expirada'
            ELSE vi.estado
        END,
        'hora_entrada', vi.hora_entrada,
        'hora_salida', vi.hora_salida,
        'codigo_acceso', vi.codigo_acceso,
        'creado_por', vi.creado_por,
        'creado_por_nombre', TRIM(u.nombre || ' ' || u.apellidos),
        'creado_en', vi.creado_en
    ) INTO v_res
    FROM public.visitas vi
    JOIN public.viviendas v ON v.id = vi.vivienda_id
    JOIN public.usuarios u ON u.id = vi.creado_por
    WHERE vi.id = p_visita_id;

    RETURN v_res;
END;
$$;


ALTER FUNCTION public._proyectar_visita_dto(p_visita_id uuid) OWNER TO postgres;

--
-- Name: _recalcular_estado_cargo(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._recalcular_estado_cargo(p_cargo_id uuid) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_monto_cargo NUMERIC(12,2);
    v_total_pagos NUMERIC(12,2);
    v_total_saldo NUMERIC(12,2);
    v_total_cubierto NUMERIC(12,2);
    v_nuevo_estado VARCHAR(20);
    v_estado_actual VARCHAR(20);
BEGIN
    SELECT monto, estado INTO v_monto_cargo, v_estado_actual 
    FROM public.cargos 
    WHERE id = p_cargo_id 
    FOR UPDATE;

    IF v_estado_actual = 'Cancelado' THEN
        RETURN 'Cancelado';
    END IF;

    -- Suma de amortizaciones de pagos confirmados no revertidos
    SELECT COALESCE(SUM(monto_cubierto), 0.00) INTO v_total_pagos
    FROM public.pagos
    WHERE cargo_id = p_cargo_id 
      AND estado = 'Confirmado' 
      AND es_reversa = false;

    -- Suma neta de saldo a favor aplicado al cargo (Aplicacion - ReversoAplicacion)
    SELECT COALESCE(
        SUM(
            CASE 
                WHEN tipo = 'Aplicacion' THEN monto 
                WHEN tipo = 'ReversoAplicacion' THEN -monto 
                ELSE 0.00 
            END
        ), 0.00) INTO v_total_saldo
    FROM public.movimientos_saldo_favor
    WHERE cargo_id = p_cargo_id;

    v_total_cubierto := v_total_pagos + v_total_saldo;

    IF v_total_cubierto <= 0 THEN
        v_nuevo_estado := 'Pendiente';
    ELSIF v_total_cubierto < v_monto_cargo THEN
        v_nuevo_estado := 'Parcial';
    ELSE
        v_nuevo_estado := 'Pagado';
    END IF;

    UPDATE public.cargos 
    SET estado = v_nuevo_estado 
    WHERE id = p_cargo_id;

    RETURN v_nuevo_estado;
END;
$$;


ALTER FUNCTION public._recalcular_estado_cargo(p_cargo_id uuid) OWNER TO postgres;

--
-- Name: actualizar_bloqueo_area(uuid, uuid, timestamp with time zone, timestamp with time zone, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.actualizar_bloqueo_area(p_actor_id uuid, p_bloqueo_id uuid, p_inicio timestamp with time zone DEFAULT NULL::timestamp with time zone, p_fin timestamp with time zone DEFAULT NULL::timestamp with time zone, p_motivo text DEFAULT NULL::text) RETURNS jsonb
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

--
-- Name: alta_area_comun(uuid, uuid, text, text, time without time zone, time without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.alta_area_comun(p_actor_id uuid, p_condominio_id uuid, p_nombre text, p_descripcion text DEFAULT NULL::text, p_hora_apertura time without time zone DEFAULT '08:00:00'::time without time zone, p_hora_cierre time without time zone DEFAULT '22:00:00'::time without time zone) RETURNS jsonb
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

--
-- Name: alta_aviso(uuid, text, text, integer, timestamp with time zone, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.alta_aviso(p_creado_por uuid, p_titulo text, p_contenido text, p_duracion_dias integer DEFAULT NULL::integer, p_fecha_expiracion timestamp with time zone DEFAULT NULL::timestamp with time zone, p_prioridad text DEFAULT 'normal'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_aviso RECORD;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_creado_por;

    IF NOT FOUND OR v_actor.activo = false THEN
        RAISE EXCEPTION 'Usuario actor no encontrado o inactivo' USING ERRCODE = 'AV001';
    END IF;

    IF v_actor.rol_id <> 1 THEN
        RAISE EXCEPTION 'Solo un administrador puede publicar avisos' USING ERRCODE = 'AV002';
    END IF;

    IF v_actor.condominio_id IS NULL THEN
        RAISE EXCEPTION 'El administrador no tiene un condominio asignado' USING ERRCODE = 'AV003';
    END IF;

    IF p_titulo IS NULL OR trim(p_titulo) = '' OR char_length(p_titulo) > 150 THEN
        RAISE EXCEPTION 'El título es obligatorio y no puede exceder 150 caracteres' USING ERRCODE = 'AV004';
    END IF;

    IF p_contenido IS NULL OR trim(p_contenido) = '' THEN
        RAISE EXCEPTION 'El contenido del aviso es obligatorio' USING ERRCODE = 'AV005';
    END IF;

    IF (p_duracion_dias IS NOT NULL AND p_fecha_expiracion IS NOT NULL) OR
       (p_duracion_dias IS NULL AND p_fecha_expiracion IS NULL) THEN
        RAISE EXCEPTION 'Debe especificar duracion_dias o fecha_expiracion, pero no ambos' USING ERRCODE = 'AV006';
    END IF;

    IF p_duracion_dias IS NOT NULL AND p_duracion_dias <= 0 THEN
        RAISE EXCEPTION 'La duración en días debe ser mayor a 0' USING ERRCODE = 'AV007';
    END IF;

    IF p_fecha_expiracion IS NOT NULL AND p_fecha_expiracion <= timezone('utc'::text, now()) THEN
        RAISE EXCEPTION 'La fecha de expiración debe ser futura' USING ERRCODE = 'AV007';
    END IF;

    INSERT INTO public.avisos (
        condominio_id, titulo, contenido, prioridad, duracion_dias, fecha_expiracion_manual, creado_por, activo
    )
    VALUES (
        v_actor.condominio_id,
        trim(p_titulo),
        trim(p_contenido),
        COALESCE(p_prioridad, 'normal'),
        p_duracion_dias,
        p_fecha_expiracion,
        p_creado_por,
        true
    )
    RETURNING * INTO v_aviso;

    RETURN to_jsonb(v_aviso);
END;
$$;


ALTER FUNCTION public.alta_aviso(p_creado_por uuid, p_titulo text, p_contenido text, p_duracion_dias integer, p_fecha_expiracion timestamp with time zone, p_prioridad text) OWNER TO postgres;

--
-- Name: alta_condominio(text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.alta_condominio(p_nombre text, p_direccion text DEFAULT NULL::text, p_zona_horaria text DEFAULT 'America/Mexico_City'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_condominio RECORD;
BEGIN
    INSERT INTO public.condominios (nombre, direccion, zona_horaria, activo)
    VALUES (p_nombre, p_direccion, COALESCE(p_zona_horaria, 'America/Mexico_City'), true)
    RETURNING * INTO v_condominio;

    RETURN to_jsonb(v_condominio);
END;
$$;


ALTER FUNCTION public.alta_condominio(p_nombre text, p_direccion text, p_zona_horaria text) OWNER TO postgres;

--
-- Name: alta_notificacion(uuid, character varying, character varying, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.alta_notificacion(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


ALTER FUNCTION public.alta_notificacion(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text) OWNER TO postgres;

--
-- Name: alta_paquete_esperado(uuid, integer, text, integer, text, text, text, text, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.alta_paquete_esperado(p_actor_id uuid, p_vivienda_id integer, p_destinatario_nombre text, p_servicio_id integer DEFAULT NULL::integer, p_servicio_nombre text DEFAULT NULL::text, p_numero_guia text DEFAULT NULL::text, p_descripcion text DEFAULT NULL::text, p_notas text DEFAULT NULL::text, p_fecha_esperada_desde timestamp with time zone DEFAULT NULL::timestamp with time zone, p_fecha_esperada_hasta timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_condominio_id UUID;
    v_pertenece BOOLEAN;
    v_servicio_nombre_final VARCHAR(50);
    v_paquete_id UUID;
BEGIN
    SELECT condominio_id INTO v_condominio_id
    FROM public.viviendas
    WHERE id = p_vivienda_id AND activo = true;

    IF v_condominio_id IS NULL THEN
        RAISE EXCEPTION 'La vivienda especificada no existe o está inactiva.' USING ERRCODE = 'PQ002';
    END IF;

    SELECT (
        EXISTS (SELECT 1 FROM public.vivienda_residente WHERE vivienda_id = p_vivienda_id AND usuario_id = p_actor_id)
        OR
        EXISTS (SELECT 1 FROM public.vivienda_subusuarios WHERE vivienda_id = p_vivienda_id AND usuario_id = p_actor_id AND activo = true)
    ) INTO v_pertenece;

    IF NOT v_pertenece THEN
        RAISE EXCEPTION 'No tienes permiso para registrar paquetes en esta vivienda.' USING ERRCODE = 'PQ001';
    END IF;

    IF p_servicio_id IS NOT NULL THEN
        SELECT nombre INTO v_servicio_nombre_final
        FROM public.servicios_paqueteria
        WHERE id = p_servicio_id AND activo = true
          AND (condominio_id IS NULL OR condominio_id = v_condominio_id);

        IF v_servicio_nombre_final IS NULL THEN
            RAISE EXCEPTION 'El servicio de paquetería indicado no fue encontrado o está inactivo.' USING ERRCODE = 'PQ002';
        END IF;
    ELSE
        v_servicio_nombre_final := NULLIF(btrim(p_servicio_nombre), '');
    END IF;

    IF v_servicio_nombre_final IS NULL THEN
        RAISE EXCEPTION 'Debe especificar un servicio de paquetería válido.' USING ERRCODE = 'PQ004';
    END IF;

    IF p_fecha_esperada_desde IS NOT NULL AND p_fecha_esperada_hasta IS NOT NULL AND p_fecha_esperada_hasta <= p_fecha_esperada_desde THEN
        RAISE EXCEPTION 'La fecha esperada final debe ser posterior a la inicial.' USING ERRCODE = 'PQ004';
    END IF;

    IF p_numero_guia IS NOT NULL AND length(btrim(p_numero_guia)) > 0 THEN
        IF EXISTS (
            SELECT 1 FROM public.paquetes
            WHERE condominio_id = v_condominio_id
              AND LOWER(btrim(numero_guia)) = LOWER(btrim(p_numero_guia))
              AND estado IN ('esperado', 'recibido')
        ) THEN
            RAISE EXCEPTION 'El número de guía ya está registrado en otro paquete activo.' USING ERRCODE = 'PQ008';
        END IF;
    END IF;

    INSERT INTO public.paquetes (
        condominio_id, vivienda_id, servicio_id, servicio_nombre, empresa_paqueteria,
        destinatario_nombre, numero_guia, descripcion, notas,
        fecha_esperada, fecha_esperada_desde, fecha_esperada_hasta,
        estado, es_inesperado, creado_por
    )
    VALUES (
        v_condominio_id,
        p_vivienda_id,
        p_servicio_id,
        v_servicio_nombre_final,
        v_servicio_nombre_final,
        btrim(p_destinatario_nombre),
        NULLIF(btrim(p_numero_guia), ''),
        p_descripcion,
        p_notas,
        COALESCE(p_fecha_esperada_desde::DATE, CURRENT_DATE),
        COALESCE(p_fecha_esperada_desde, timezone('utc'::text, now())),
        COALESCE(p_fecha_esperada_hasta, COALESCE(p_fecha_esperada_desde, timezone('utc'::text, now())) + INTERVAL '7 days'),
        'esperado',
        false,
        p_actor_id
    )
    RETURNING id INTO v_paquete_id;

    RETURN public._proyectar_paquete_dto(v_paquete_id);
END;
$$;


ALTER FUNCTION public.alta_paquete_esperado(p_actor_id uuid, p_vivienda_id integer, p_destinatario_nombre text, p_servicio_id integer, p_servicio_nombre text, p_numero_guia text, p_descripcion text, p_notas text, p_fecha_esperada_desde timestamp with time zone, p_fecha_esperada_hasta timestamp with time zone) OWNER TO postgres;

--
-- Name: alta_servicio_paqueteria(uuid, text, text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.alta_servicio_paqueteria(p_condominio_id uuid, p_nombre text, p_icono_url text DEFAULT NULL::text, p_actor_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_servicio RECORD;
BEGIN
    IF p_actor_id IS NOT NULL THEN
        SELECT id, rol_id, condominio_id, activo INTO v_actor
        FROM public.usuarios
        WHERE id = p_actor_id;

        IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id <> 1 OR v_actor.condominio_id <> p_condominio_id THEN
            RAISE EXCEPTION 'El actor no tiene permisos de administración en el condominio.' USING ERRCODE = 'PQ005';
        END IF;
    END IF;

    IF p_nombre IS NULL OR length(btrim(p_nombre)) = 0 THEN
        RAISE EXCEPTION 'El nombre del servicio de paquetería es obligatorio.' USING ERRCODE = 'PQ004';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.servicios_paqueteria
        WHERE (condominio_id = p_condominio_id OR es_sistema = true)
          AND LOWER(btrim(nombre)) = LOWER(btrim(p_nombre))
          AND activo = true
    ) THEN
        RAISE EXCEPTION 'Ya existe un servicio de paquetería activo con ese nombre en el condominio.' USING ERRCODE = 'PQ006';
    END IF;

    INSERT INTO public.servicios_paqueteria (
        condominio_id, nombre, icono_url, es_sistema, activo, creado_por
    )
    VALUES (
        p_condominio_id, btrim(p_nombre), p_icono_url, false, true, p_actor_id
    )
    RETURNING id, condominio_id, nombre, icono_url, activo, es_sistema, creado_en
    INTO v_servicio;

    RETURN to_jsonb(v_servicio);
END;
$$;


ALTER FUNCTION public.alta_servicio_paqueteria(p_condominio_id uuid, p_nombre text, p_icono_url text, p_actor_id uuid) OWNER TO postgres;

--
-- Name: alta_usuario(uuid, text, text, text, text, integer, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.alta_usuario(p_id uuid, p_email text, p_nombre text, p_apellidos text, p_telefono text, p_rol_id integer DEFAULT 2, p_condominio_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_usuario RECORD;
BEGIN
    IF p_rol_id = 3 AND p_condominio_id IS NULL THEN
        RAISE EXCEPTION 'El personal de vigilancia debe estar asociado obligatoriamente a un condominio'
            USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.usuarios (id, rol_id, condominio_id, email, nombre, apellidos, telefono, activo)
    VALUES (
        p_id,
        COALESCE(p_rol_id, 2),
        p_condominio_id,
        p_email,
        p_nombre,
        p_apellidos,
        p_telefono,
        true
    )
    ON CONFLICT (id) DO UPDATE SET
        rol_id = EXCLUDED.rol_id,
        condominio_id = COALESCE(EXCLUDED.condominio_id, public.usuarios.condominio_id),
        email = EXCLUDED.email,
        nombre = EXCLUDED.nombre,
        apellidos = EXCLUDED.apellidos,
        telefono = EXCLUDED.telefono,
        activo = true
    RETURNING * INTO v_usuario;

    RETURN to_jsonb(v_usuario);
END;
$$;


ALTER FUNCTION public.alta_usuario(p_id uuid, p_email text, p_nombre text, p_apellidos text, p_telefono text, p_rol_id integer, p_condominio_id uuid) OWNER TO postgres;

--
-- Name: alta_visita(uuid, integer, character varying, character varying, character varying, character varying, integer, character varying, text, timestamp with time zone, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.alta_visita(p_actor_id uuid, p_vivienda_id integer, p_nombre_visitante character varying, p_apellidos_visitante character varying, p_telefono_visitante character varying, p_motivo character varying, p_num_acompanantes integer, p_vehiculo_placas character varying, p_notas text, p_fecha_llegada_esperada timestamp with time zone, p_horas_vigencia integer DEFAULT 24) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_condominio_id UUID;
    v_pertenece BOOLEAN;
    v_codigo VARCHAR(10);
    v_visita_id UUID;
    v_existe_codigo BOOLEAN;
    v_fecha_expiracion TIMESTAMPTZ;
BEGIN
    SELECT condominio_id INTO v_condominio_id
    FROM public.viviendas
    WHERE id = p_vivienda_id AND activo = true;

    IF v_condominio_id IS NULL THEN
        RAISE EXCEPTION 'La vivienda especificada no existe o está inactiva.' USING ERRCODE = 'VI009';
    END IF;

    SELECT (
        EXISTS (SELECT 1 FROM public.vivienda_residente WHERE vivienda_id = p_vivienda_id AND usuario_id = p_actor_id)
        OR
        EXISTS (SELECT 1 FROM public.vivienda_subusuarios WHERE vivienda_id = p_vivienda_id AND usuario_id = p_actor_id AND activo = true)
    ) INTO v_pertenece;

    IF NOT v_pertenece THEN
        RAISE EXCEPTION 'No tienes permiso para registrar visitas en esta vivienda.' USING ERRCODE = 'VI002';
    END IF;

    v_fecha_expiracion := p_fecha_llegada_esperada + (COALESCE(p_horas_vigencia, 24) || ' hours')::INTERVAL;

    IF v_fecha_expiracion <= now() THEN
        RAISE EXCEPTION 'VI008: La visita ya expiró o su vigencia ha concluido respecto a la fecha actual.' USING ERRCODE = 'VI008';
    END IF;

    LOOP
        v_codigo := 'VIS-' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT), 1, 6));
        SELECT EXISTS (SELECT 1 FROM public.visitas WHERE codigo_acceso = v_codigo) INTO v_existe_codigo;
        EXIT WHEN NOT v_existe_codigo;
    END LOOP;

    INSERT INTO public.visitas (
        vivienda_id, condominio_id, nombre_visitante, apellidos_visitante,
        telefono_visitante, motivo, num_acompanantes, vehiculo_placas,
        notas, fecha_llegada_esperada, fecha_expiracion, codigo_acceso,
        estado, creado_por
    )
    VALUES (
        p_vivienda_id, v_condominio_id, p_nombre_visitante, p_apellidos_visitante,
        p_telefono_visitante, LOWER(TRIM(p_motivo)), COALESCE(p_num_acompanantes, 0), p_vehiculo_placas,
        p_notas, p_fecha_llegada_esperada, v_fecha_expiracion, v_codigo,
        'programada', p_actor_id
    )
    RETURNING id INTO v_visita_id;

    RETURN public._proyectar_visita_dto(v_visita_id);
END;
$$;


ALTER FUNCTION public.alta_visita(p_actor_id uuid, p_vivienda_id integer, p_nombre_visitante character varying, p_apellidos_visitante character varying, p_telefono_visitante character varying, p_motivo character varying, p_num_acompanantes integer, p_vehiculo_placas character varying, p_notas text, p_fecha_llegada_esperada timestamp with time zone, p_horas_vigencia integer) OWNER TO postgres;

--
-- Name: alta_vivienda(uuid, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.alta_vivienda(p_condominio_id uuid, p_numero_casa text, p_tipo text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_vivienda RECORD;
    v_condominio_activo BOOLEAN;
    v_condominio_nombre TEXT;
BEGIN
    SELECT activo, nombre INTO v_condominio_activo, v_condominio_nombre
    FROM public.condominios
    WHERE id = p_condominio_id;

    IF NOT FOUND OR NOT v_condominio_activo THEN
        RAISE EXCEPTION 'El condominio especificado no existe o está inactivo.';
    END IF;

    INSERT INTO public.viviendas (condominio_id, numero_casa, tipo, activo)
    VALUES (p_condominio_id, p_numero_casa, p_tipo, true)
    RETURNING * INTO v_vivienda;

    RETURN jsonb_build_object(
        'id', v_vivienda.id,
        'numero_casa', v_vivienda.numero_casa,
        'tipo', v_vivienda.tipo,
        'activo', v_vivienda.activo,
        'condominio_id', v_vivienda.condominio_id,
        'condominio_nombre', v_condominio_nombre,
        'creado_en', v_vivienda.creado_en,
        'total_residentes', 0,
        'esta_ocupada', false
    );
END;
$$;


ALTER FUNCTION public.alta_vivienda(p_condominio_id uuid, p_numero_casa text, p_tipo text) OWNER TO postgres;

--
-- Name: aprobar_reserva_admin(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.aprobar_reserva_admin(p_actor_id uuid, p_reserva_id uuid) RETURNS boolean
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

--
-- Name: aprobar_reserva_titular(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.aprobar_reserva_titular(p_actor_id uuid, p_reserva_id uuid) RETURNS boolean
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

--
-- Name: asignar_condominio_admin(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.asignar_condominio_admin(p_usuario_id uuid, p_condominio_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_usuario RECORD;
    v_condominio_activo BOOLEAN;
    v_admin_existente UUID;
BEGIN
    SELECT * INTO v_usuario FROM public.usuarios WHERE id = p_usuario_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuario no encontrado' USING ERRCODE = 'P0001';
    END IF;

    IF v_usuario.rol_id <> 1 THEN
        RAISE EXCEPTION 'El usuario no tiene rol de Administrador' USING ERRCODE = 'P0002';
    END IF;

    IF v_usuario.activo = false THEN
        RAISE EXCEPTION 'El usuario está inactivo' USING ERRCODE = 'P0003';
    END IF;

    SELECT activo INTO v_condominio_activo FROM public.condominios WHERE id = p_condominio_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Condominio no encontrado' USING ERRCODE = 'P0004';
    END IF;

    IF v_condominio_activo = false THEN
        RAISE EXCEPTION 'El condominio está inactivo' USING ERRCODE = 'P0005';
    END IF;

    SELECT id INTO v_admin_existente
    FROM public.usuarios
    WHERE condominio_id = p_condominio_id
      AND rol_id = 1
      AND activo = true
      AND id <> p_usuario_id;

    IF FOUND THEN
        RAISE EXCEPTION 'Ya existe un administrador activo en este condominio' USING ERRCODE = '23505';
    END IF;

    UPDATE public.usuarios
    SET condominio_id = p_condominio_id
    WHERE id = p_usuario_id
    RETURNING * INTO v_usuario;

    RETURN to_jsonb(v_usuario);
END;
$$;


ALTER FUNCTION public.asignar_condominio_admin(p_usuario_id uuid, p_condominio_id uuid) OWNER TO postgres;

--
-- Name: asignar_residente(integer, uuid, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.asignar_residente(p_vivienda_id integer, p_usuario_id uuid, p_es_propietario boolean DEFAULT true) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_vivienda RECORD;
    v_usuario RECORD;
    v_asignacion RECORD;
BEGIN
    SELECT id, condominio_id, activo INTO v_vivienda
    FROM public.viviendas
    WHERE id = p_vivienda_id;

    IF NOT FOUND OR NOT v_vivienda.activo THEN
        RAISE EXCEPTION 'Vivienda no encontrada o inactiva.' USING ERRCODE = 'P0001';
    END IF;

    SELECT id, rol_id, condominio_id, activo INTO v_usuario
    FROM public.usuarios
    WHERE id = p_usuario_id;

    IF NOT FOUND OR NOT v_usuario.activo THEN
        RAISE EXCEPTION 'Usuario no encontrado o inactivo.' USING ERRCODE = 'P0002';
    END IF;

    IF v_usuario.rol_id <> 2 THEN
        RAISE EXCEPTION 'El usuario no tiene el rol de Residente.' USING ERRCODE = 'P0003';
    END IF;

    IF v_usuario.condominio_id IS NOT NULL AND v_usuario.condominio_id <> v_vivienda.condominio_id THEN
        RAISE EXCEPTION 'El residente pertenece a otro condominio.' USING ERRCODE = 'P0004';
    END IF;

    INSERT INTO public.vivienda_residente (vivienda_id, usuario_id, es_propietario)
    VALUES (p_vivienda_id, p_usuario_id, COALESCE(p_es_propietario, true))
    RETURNING * INTO v_asignacion;

    IF v_usuario.condominio_id IS NULL THEN
        UPDATE public.usuarios
        SET condominio_id = v_vivienda.condominio_id
        WHERE id = p_usuario_id;
    END IF;

    RETURN to_jsonb(v_asignacion);
END;
$$;


ALTER FUNCTION public.asignar_residente(p_vivienda_id integer, p_usuario_id uuid, p_es_propietario boolean) OWNER TO postgres;

--
-- Name: asignar_residente_vivienda(integer, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.asignar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


ALTER FUNCTION public.asignar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) OWNER TO postgres;

--
-- Name: baja_area_comun(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.baja_area_comun(p_actor_id uuid, p_id uuid) RETURNS boolean
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

--
-- Name: baja_aviso(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.baja_aviso(p_id uuid, p_actor_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_aviso RECORD;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR v_actor.activo = false THEN
        RAISE EXCEPTION 'Usuario actor no encontrado o inactivo' USING ERRCODE = 'AV001';
    END IF;

    IF v_actor.rol_id <> 1 THEN
        RAISE EXCEPTION 'Solo un administrador puede eliminar avisos' USING ERRCODE = 'AV002';
    END IF;

    SELECT * INTO v_aviso
    FROM public.avisos
    WHERE id = p_id AND activo = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aviso no encontrado o ya inactivo' USING ERRCODE = 'AV008';
    END IF;

    IF v_aviso.condominio_id <> v_actor.condominio_id THEN
        RAISE EXCEPTION 'No tienes permiso para eliminar avisos de otro condominio' USING ERRCODE = 'AV009';
    END IF;

    UPDATE public.avisos
    SET activo = false
    WHERE id = p_id;

    RETURN true;
END;
$$;


ALTER FUNCTION public.baja_aviso(p_id uuid, p_actor_id uuid) OWNER TO postgres;

--
-- Name: baja_condominio(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.baja_condominio(p_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    UPDATE public.condominios
    SET activo = false
    WHERE id = p_id AND activo = true;

    IF FOUND THEN
        UPDATE public.viviendas
        SET activo = false
        WHERE condominio_id = p_id AND activo = true;
        RETURN true;
    END IF;

    RETURN false;
END;
$$;


ALTER FUNCTION public.baja_condominio(p_id uuid) OWNER TO postgres;

--
-- Name: baja_servicio_paqueteria(integer, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.baja_servicio_paqueteria(p_id integer, p_actor_id uuid DEFAULT NULL::uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_servicio RECORD;
BEGIN
    SELECT * INTO v_servicio
    FROM public.servicios_paqueteria
    WHERE id = p_id AND activo = true
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    IF v_servicio.es_sistema THEN
        RAISE EXCEPTION 'No se puede modificar o eliminar un servicio de paquetería del sistema.' USING ERRCODE = 'PQ007';
    END IF;

    IF p_actor_id IS NOT NULL THEN
        SELECT id, rol_id, condominio_id, activo INTO v_actor
        FROM public.usuarios
        WHERE id = p_actor_id;

        IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id <> 1 OR v_actor.condominio_id <> v_servicio.condominio_id THEN
            RAISE EXCEPTION 'El actor no tiene permisos de administración sobre este servicio.' USING ERRCODE = 'PQ005';
        END IF;
    END IF;

    UPDATE public.servicios_paqueteria
    SET activo = false
    WHERE id = p_id;

    RETURN true;
END;
$$;


ALTER FUNCTION public.baja_servicio_paqueteria(p_id integer, p_actor_id uuid) OWNER TO postgres;

--
-- Name: baja_subusuario(integer, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.baja_subusuario(p_vivienda_id integer, p_usuario_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_filas INTEGER;
BEGIN
    -- Desactivar el vínculo activo (baja lógica)
    UPDATE public.vivienda_subusuarios
    SET activo = false
    WHERE vivienda_id = p_vivienda_id 
      AND usuario_id = p_usuario_id
      AND activo = true;

    GET DIAGNOSTICS v_filas = ROW_COUNT;

    -- Fallback: si no estaba con activo=true, verificar eliminación directa
    IF v_filas = 0 THEN
        DELETE FROM public.vivienda_subusuarios
        WHERE vivienda_id = p_vivienda_id 
          AND usuario_id = p_usuario_id;
        GET DIAGNOSTICS v_filas = ROW_COUNT;
    END IF;

    RETURN v_filas > 0;
END;
$$;


ALTER FUNCTION public.baja_subusuario(p_vivienda_id integer, p_usuario_id uuid) OWNER TO postgres;

--
-- Name: baja_usuario(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.baja_usuario(p_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    UPDATE public.usuarios
    SET activo = false
    WHERE id = p_id AND activo = true;

    RETURN FOUND;
END;
$$;


ALTER FUNCTION public.baja_usuario(p_id uuid) OWNER TO postgres;

--
-- Name: baja_vivienda(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.baja_vivienda(p_id integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    UPDATE public.viviendas
    SET activo = false
    WHERE id = p_id AND activo = true;

    RETURN FOUND;
END;
$$;


ALTER FUNCTION public.baja_vivienda(p_id integer) OWNER TO postgres;

--
-- Name: cambio_area_comun(uuid, uuid, text, text, time without time zone, time without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cambio_area_comun(p_actor_id uuid, p_id uuid, p_nombre text DEFAULT NULL::text, p_descripcion text DEFAULT NULL::text, p_hora_apertura time without time zone DEFAULT NULL::time without time zone, p_hora_cierre time without time zone DEFAULT NULL::time without time zone) RETURNS jsonb
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

--
-- Name: cambio_aviso(uuid, uuid, text, text, integer, timestamp with time zone, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cambio_aviso(p_id uuid, p_actor_id uuid, p_titulo text DEFAULT NULL::text, p_contenido text DEFAULT NULL::text, p_duracion_dias integer DEFAULT NULL::integer, p_fecha_expiracion timestamp with time zone DEFAULT NULL::timestamp with time zone, p_prioridad text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_aviso RECORD;
    v_nuevo_duracion INT;
    v_nueva_fecha TIMESTAMPTZ;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR v_actor.activo = false THEN
        RAISE EXCEPTION 'Usuario actor no encontrado o inactivo' USING ERRCODE = 'AV001';
    END IF;

    IF v_actor.rol_id <> 1 THEN
        RAISE EXCEPTION 'Solo un administrador puede editar avisos' USING ERRCODE = 'AV002';
    END IF;

    SELECT * INTO v_aviso
    FROM public.avisos
    WHERE id = p_id AND activo = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aviso no encontrado o ya fue eliminado' USING ERRCODE = 'AV008';
    END IF;

    IF v_aviso.condominio_id <> v_actor.condominio_id THEN
        RAISE EXCEPTION 'No tienes permiso para modificar avisos de otro condominio' USING ERRCODE = 'AV009';
    END IF;

    IF p_duracion_dias IS NOT NULL AND p_fecha_expiracion IS NOT NULL THEN
        RAISE EXCEPTION 'No puede enviar duracion_dias y fecha_expiracion simultáneamente' USING ERRCODE = 'AV006';
    END IF;

    IF p_duracion_dias IS NOT NULL THEN
        IF p_duracion_dias <= 0 THEN
            RAISE EXCEPTION 'La duración en días debe ser mayor a 0' USING ERRCODE = 'AV007';
        END IF;
        v_nuevo_duracion := p_duracion_dias;
        v_nueva_fecha := NULL;
    ELSIF p_fecha_expiracion IS NOT NULL THEN
        IF p_fecha_expiracion <= timezone('utc'::text, now()) THEN
            RAISE EXCEPTION 'La fecha de expiración debe ser futura' USING ERRCODE = 'AV007';
        END IF;
        v_nuevo_duracion := NULL;
        v_nueva_fecha := p_fecha_expiracion;
    ELSE
        v_nuevo_duracion := v_aviso.duracion_dias;
        v_nueva_fecha := v_aviso.fecha_expiracion_manual;
    END IF;

    IF p_titulo IS NOT NULL AND (trim(p_titulo) = '' OR char_length(p_titulo) > 150) THEN
        RAISE EXCEPTION 'El título no puede estar vacío ni exceder 150 caracteres' USING ERRCODE = 'AV004';
    END IF;

    IF p_contenido IS NOT NULL AND trim(p_contenido) = '' THEN
        RAISE EXCEPTION 'El contenido no puede estar vacío' USING ERRCODE = 'AV005';
    END IF;

    UPDATE public.avisos
    SET
        titulo = COALESCE(trim(p_titulo), titulo),
        contenido = COALESCE(trim(p_contenido), contenido),
        prioridad = COALESCE(p_prioridad, prioridad),
        duracion_dias = v_nuevo_duracion,
        fecha_expiracion_manual = v_nueva_fecha
    WHERE id = p_id
    RETURNING * INTO v_aviso;

    RETURN to_jsonb(v_aviso);
END;
$$;


ALTER FUNCTION public.cambio_aviso(p_id uuid, p_actor_id uuid, p_titulo text, p_contenido text, p_duracion_dias integer, p_fecha_expiracion timestamp with time zone, p_prioridad text) OWNER TO postgres;

--
-- Name: cambio_condominio(uuid, text, text, boolean, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cambio_condominio(p_id uuid, p_nombre text DEFAULT NULL::text, p_direccion text DEFAULT NULL::text, p_activo boolean DEFAULT NULL::boolean, p_zona_horaria text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_condominio RECORD;
BEGIN
    UPDATE public.condominios
    SET
        nombre = COALESCE(p_nombre, nombre),
        direccion = COALESCE(p_direccion, direccion),
        activo = COALESCE(p_activo, activo),
        zona_horaria = COALESCE(p_zona_horaria, zona_horaria)
    WHERE id = p_id
    RETURNING * INTO v_condominio;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    RETURN to_jsonb(v_condominio);
END;
$$;


ALTER FUNCTION public.cambio_condominio(p_id uuid, p_nombre text, p_direccion text, p_activo boolean, p_zona_horaria text) OWNER TO postgres;

--
-- Name: cambio_paquete_esperado(uuid, uuid, text, integer, text, text, text, text, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cambio_paquete_esperado(p_id uuid, p_actor_id uuid, p_destinatario_nombre text DEFAULT NULL::text, p_servicio_id integer DEFAULT NULL::integer, p_servicio_nombre text DEFAULT NULL::text, p_numero_guia text DEFAULT NULL::text, p_descripcion text DEFAULT NULL::text, p_notas text DEFAULT NULL::text, p_fecha_esperada_desde timestamp with time zone DEFAULT NULL::timestamp with time zone, p_fecha_esperada_hasta timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_paquete RECORD;
    v_es_autorizado BOOLEAN;
    v_servicio_nombre_final VARCHAR(50);
BEGIN
    SELECT * INTO v_paquete FROM public.paquetes WHERE id = p_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El paquete no existe.' USING ERRCODE = 'PQ002';
    END IF;

    SELECT (
        v_paquete.creado_por = p_actor_id
        OR EXISTS (
            SELECT 1 FROM public.vivienda_residente
            WHERE vivienda_id = v_paquete.vivienda_id AND usuario_id = p_actor_id
        )
    ) INTO v_es_autorizado;

    IF NOT v_es_autorizado THEN
        RAISE EXCEPTION 'No tienes permiso para modificar este paquete.' USING ERRCODE = 'PQ001';
    END IF;

    IF v_paquete.estado <> 'esperado' THEN
        RAISE EXCEPTION 'Solo se pueden editar paquetes en estado esperado.' USING ERRCODE = 'PQ003';
    END IF;

    IF p_servicio_id IS NOT NULL THEN
        SELECT nombre INTO v_servicio_nombre_final
        FROM public.servicios_paqueteria
        WHERE id = p_servicio_id AND activo = true;
    ELSIF p_servicio_nombre IS NOT NULL THEN
        v_servicio_nombre_final := NULLIF(btrim(p_servicio_nombre), '');
    ELSE
        v_servicio_nombre_final := v_paquete.servicio_nombre;
    END IF;

    UPDATE public.paquetes
    SET
        destinatario_nombre = COALESCE(NULLIF(btrim(p_destinatario_nombre), ''), destinatario_nombre),
        servicio_id = COALESCE(p_servicio_id, servicio_id),
        servicio_nombre = COALESCE(v_servicio_nombre_final, servicio_nombre),
        empresa_paqueteria = COALESCE(v_servicio_nombre_final, empresa_paqueteria),
        numero_guia = COALESCE(NULLIF(btrim(p_numero_guia), ''), numero_guia),
        descripcion = COALESCE(p_descripcion, descripcion),
        notas = COALESCE(p_notas, notas),
        fecha_esperada_desde = COALESCE(p_fecha_esperada_desde, fecha_esperada_desde),
        fecha_esperada_hasta = COALESCE(p_fecha_esperada_hasta, fecha_esperada_hasta),
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_id;

    RETURN public._proyectar_paquete_dto(p_id);
END;
$$;


ALTER FUNCTION public.cambio_paquete_esperado(p_id uuid, p_actor_id uuid, p_destinatario_nombre text, p_servicio_id integer, p_servicio_nombre text, p_numero_guia text, p_descripcion text, p_notas text, p_fecha_esperada_desde timestamp with time zone, p_fecha_esperada_hasta timestamp with time zone) OWNER TO postgres;

--
-- Name: cambio_usuario(uuid, text, text, text, integer, uuid, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cambio_usuario(p_id uuid, p_nombre text DEFAULT NULL::text, p_apellidos text DEFAULT NULL::text, p_telefono text DEFAULT NULL::text, p_rol_id integer DEFAULT NULL::integer, p_condominio_id uuid DEFAULT NULL::uuid, p_debe_cambiar_password boolean DEFAULT NULL::boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_usuario RECORD;
    v_rol_final INT;
    v_condominio_final UUID;
BEGIN
    SELECT rol_id, condominio_id INTO v_rol_final, v_condominio_final
    FROM public.usuarios
    WHERE id = p_id AND activo = true;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    v_rol_final := COALESCE(p_rol_id, v_rol_final);
    v_condominio_final := COALESCE(p_condominio_id, v_condominio_final);

    IF v_rol_final = 3 AND v_condominio_final IS NULL THEN
        RAISE EXCEPTION 'El personal de vigilancia debe estar asociado obligatoriamente a un condominio'
            USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.usuarios
    SET
        nombre = COALESCE(p_nombre, nombre),
        apellidos = COALESCE(p_apellidos, apellidos),
        telefono = COALESCE(p_telefono, telefono),
        rol_id = v_rol_final,
        condominio_id = v_condominio_final,
        debe_cambiar_password = COALESCE(p_debe_cambiar_password, debe_cambiar_password)
    WHERE id = p_id AND activo = true
    RETURNING * INTO v_usuario;

    RETURN to_jsonb(v_usuario);
END;
$$;


ALTER FUNCTION public.cambio_usuario(p_id uuid, p_nombre text, p_apellidos text, p_telefono text, p_rol_id integer, p_condominio_id uuid, p_debe_cambiar_password boolean) OWNER TO postgres;

--
-- Name: cambio_visita(uuid, uuid, character varying, character varying, character varying, character varying, integer, character varying, text, timestamp with time zone, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cambio_visita(p_id uuid, p_actor_id uuid, p_nombre_visitante character varying DEFAULT NULL::character varying, p_apellidos_visitante character varying DEFAULT NULL::character varying, p_telefono_visitante character varying DEFAULT NULL::character varying, p_motivo character varying DEFAULT NULL::character varying, p_num_acompanantes integer DEFAULT NULL::integer, p_vehiculo_placas character varying DEFAULT NULL::character varying, p_notas text DEFAULT NULL::text, p_fecha_llegada_esperada timestamp with time zone DEFAULT NULL::timestamp with time zone, p_horas_vigencia integer DEFAULT NULL::integer) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_visita RECORD;
    v_es_autorizado BOOLEAN;
    v_nueva_llegada TIMESTAMPTZ;
    v_nueva_expiracion TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_visita FROM public.visitas WHERE id = p_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La visita no existe.' USING ERRCODE = 'VI001';
    END IF;

    SELECT (
        v_visita.creado_por = p_actor_id
        OR EXISTS (
            SELECT 1 FROM public.vivienda_residente
            WHERE vivienda_id = v_visita.vivienda_id AND usuario_id = p_actor_id
        )
    ) INTO v_es_autorizado;

    IF NOT v_es_autorizado THEN
        RAISE EXCEPTION 'No tienes permiso para modificar esta visita.' USING ERRCODE = 'VI002';
    END IF;

    IF v_visita.estado <> 'programada' THEN
        RAISE EXCEPTION 'Solo se pueden editar visitas en estado programada.' USING ERRCODE = 'VI003';
    END IF;

    v_nueva_llegada := COALESCE(p_fecha_llegada_esperada, v_visita.fecha_llegada_esperada);

    IF p_horas_vigencia IS NOT NULL THEN
        v_nueva_expiracion := v_nueva_llegada + (p_horas_vigencia || ' hours')::INTERVAL;
    ELSIF p_fecha_llegada_esperada IS NOT NULL THEN
        v_nueva_expiracion := v_nueva_llegada + (v_visita.fecha_expiracion - v_visita.fecha_llegada_esperada);
    ELSE
        v_nueva_expiracion := v_visita.fecha_expiracion;
    END IF;

    UPDATE public.visitas
    SET
        nombre_visitante = COALESCE(p_nombre_visitante, nombre_visitante),
        apellidos_visitante = COALESCE(p_apellidos_visitante, apellidos_visitante),
        telefono_visitante = COALESCE(p_telefono_visitante, telefono_visitante),
        motivo = COALESCE(LOWER(TRIM(p_motivo)), motivo),
        num_acompanantes = COALESCE(p_num_acompanantes, num_acompanantes),
        vehiculo_placas = COALESCE(p_vehiculo_placas, vehiculo_placas),
        notas = COALESCE(p_notas, notas),
        fecha_llegada_esperada = v_nueva_llegada,
        fecha_expiracion = v_nueva_expiracion
    WHERE id = p_id;

    RETURN true;
END;
$$;


ALTER FUNCTION public.cambio_visita(p_id uuid, p_actor_id uuid, p_nombre_visitante character varying, p_apellidos_visitante character varying, p_telefono_visitante character varying, p_motivo character varying, p_num_acompanantes integer, p_vehiculo_placas character varying, p_notas text, p_fecha_llegada_esperada timestamp with time zone, p_horas_vigencia integer) OWNER TO postgres;

--
-- Name: cambio_vivienda(integer, text, text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cambio_vivienda(p_id integer, p_numero_casa text DEFAULT NULL::text, p_tipo text DEFAULT NULL::text, p_activo boolean DEFAULT NULL::boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_vivienda RECORD;
BEGIN
    UPDATE public.viviendas
    SET
        numero_casa = COALESCE(p_numero_casa, numero_casa),
        tipo = COALESCE(p_tipo, tipo),
        activo = COALESCE(p_activo, activo)
    WHERE id = p_id AND activo = true
    RETURNING * INTO v_vivienda;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    RETURN to_jsonb(v_vivienda);
END;
$$;


ALTER FUNCTION public.cambio_vivienda(p_id integer, p_numero_casa text, p_tipo text, p_activo boolean) OWNER TO postgres;

--
-- Name: cancelar_invitacion_subusuario(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cancelar_invitacion_subusuario(p_id uuid DEFAULT NULL::uuid, p_invitacion_id uuid DEFAULT NULL::uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor_id UUID;
    v_target_id UUID;
    v_invitacion RECORD;
BEGIN
    v_actor_id := auth.uid();
    v_target_id := COALESCE(p_id, p_invitacion_id);

    IF v_target_id IS NULL THEN
        RETURN false;
    END IF;

    SELECT * INTO v_invitacion
    FROM public.invitaciones_subusuarios
    WHERE id = v_target_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    IF v_actor_id IS NOT NULL AND COALESCE(v_invitacion.titular_id, v_invitacion.creado_por) <> v_actor_id THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.vivienda_residente
            WHERE vivienda_id = v_invitacion.vivienda_id AND usuario_id = v_actor_id
        ) THEN
            RAISE EXCEPTION 'No tienes permiso para cancelar esta invitación.' USING ERRCODE = 'SB005';
        END IF;
    END IF;

    UPDATE public.invitaciones_subusuarios
    SET estado = 'CANCELADA'
    WHERE id = v_target_id
      AND UPPER(estado) = 'PENDIENTE';

    RETURN FOUND;
END;
$$;


ALTER FUNCTION public.cancelar_invitacion_subusuario(p_id uuid, p_invitacion_id uuid) OWNER TO postgres;

--
-- Name: cancelar_paquete_esperado(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cancelar_paquete_esperado(p_id uuid, p_actor_id uuid, p_motivo text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_paquete RECORD;
    v_es_autorizado BOOLEAN;
BEGIN
    SELECT * INTO v_paquete FROM public.paquetes WHERE id = p_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    SELECT (
        v_paquete.creado_por = p_actor_id
        OR EXISTS (
            SELECT 1 FROM public.vivienda_residente
            WHERE vivienda_id = v_paquete.vivienda_id AND usuario_id = p_actor_id
        )
    ) INTO v_es_autorizado;

    IF NOT v_es_autorizado THEN
        RAISE EXCEPTION 'No tienes permiso para cancelar este paquete.' USING ERRCODE = 'PQ001';
    END IF;

    IF v_paquete.estado <> 'esperado' THEN
        RAISE EXCEPTION 'Solo se pueden cancelar paquetes que aún estén en estado esperado.' USING ERRCODE = 'PQ003';
    END IF;

    UPDATE public.paquetes
    SET estado = 'cancelado',
        motivo_cancelacion = COALESCE(p_motivo, motivo_cancelacion),
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_id;

    RETURN true;
END;
$$;


ALTER FUNCTION public.cancelar_paquete_esperado(p_id uuid, p_actor_id uuid, p_motivo text) OWNER TO postgres;

--
-- Name: cancelar_reserva_admin(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cancelar_reserva_admin(p_actor_id uuid, p_reserva_id uuid, p_motivo text) RETURNS boolean
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

--
-- Name: cancelar_reserva_usuario(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cancelar_reserva_usuario(p_actor_id uuid, p_reserva_id uuid, p_motivo text DEFAULT NULL::text) RETURNS boolean
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

--
-- Name: cancelar_reserva(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cancelar_reserva(p_actor_id uuid, p_reserva_id uuid, p_motivo text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT public.cancelar_reserva_usuario(p_actor_id, p_reserva_id, p_motivo);
$$;


ALTER FUNCTION public.cancelar_reserva(p_actor_id uuid, p_reserva_id uuid, p_motivo text) OWNER TO postgres;

--
-- Name: cancelar_visita(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cancelar_visita(p_id uuid, p_actor_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_visita RECORD;
    v_es_autorizado BOOLEAN;
BEGIN
    SELECT * INTO v_visita FROM public.visitas WHERE id = p_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    SELECT (
        v_visita.creado_por = p_actor_id
        OR EXISTS (
            SELECT 1 FROM public.vivienda_residente
            WHERE vivienda_id = v_visita.vivienda_id AND usuario_id = p_actor_id
        )
    ) INTO v_es_autorizado;

    IF NOT v_es_autorizado THEN
        RAISE EXCEPTION 'No tienes permiso para cancelar esta visita.' USING ERRCODE = 'VI002';
    END IF;

    IF v_visita.estado <> 'programada' THEN
        RAISE EXCEPTION 'Solo se pueden cancelar visitas que aún estén programadas.' USING ERRCODE = 'VI003';
    END IF;

    UPDATE public.visitas
    SET estado = 'cancelada'
    WHERE id = p_id;

    RETURN true;
END;
$$;


ALTER FUNCTION public.cancelar_visita(p_id uuid, p_actor_id uuid) OWNER TO postgres;

--
-- Name: confirmar_reserva(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.confirmar_reserva(p_actor_id uuid, p_reserva_id uuid) RETURNS boolean
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

--
-- Name: crear_bloqueo_area(uuid, uuid, timestamp with time zone, timestamp with time zone, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.crear_bloqueo_area(p_actor_id uuid, p_area_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_motivo text) RETURNS jsonb
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

--
-- Name: crear_notificacion(uuid, character varying, character varying, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.crear_notificacion(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_id UUID;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_usuario_id AND activo = true) THEN
        RAISE EXCEPTION 'El usuario destinatario no existe o está inactivo.' USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO public.notificaciones (
        usuario_id, tipo_evento, titulo, mensaje, url_redireccion
    )
    VALUES (
        p_usuario_id, p_tipo_evento, p_titulo, p_mensaje, p_url_redireccion
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;


ALTER FUNCTION public.crear_notificacion(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text) OWNER TO postgres;

--
-- Name: desasignar_residente(integer, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.desasignar_residente(p_vivienda_id integer, p_usuario_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_otras_asignaciones INT;
BEGIN
    DELETE FROM public.vivienda_residente
    WHERE vivienda_id = p_vivienda_id AND usuario_id = p_usuario_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    SELECT COUNT(*)::INT INTO v_otras_asignaciones
    FROM public.vivienda_residente
    WHERE usuario_id = p_usuario_id;

    IF v_otras_asignaciones = 0 THEN
        UPDATE public.usuarios
        SET condominio_id = NULL
        WHERE id = p_usuario_id AND rol_id = 2;
    END IF;

    RETURN true;
END;
$$;


ALTER FUNCTION public.desasignar_residente(p_vivienda_id integer, p_usuario_id uuid) OWNER TO postgres;

--
-- Name: eliminar_bloqueo_area(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.eliminar_bloqueo_area(p_actor_id uuid, p_bloqueo_id uuid) RETURNS boolean
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

--
-- Name: entregar_paquete_residente(uuid, text, text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.entregar_paquete_residente(p_paquete_id uuid, p_entregado_a_nombre text, p_foto_url text DEFAULT NULL::text, p_actor_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_paquete RECORD;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id NOT IN (1, 3) THEN
        RAISE EXCEPTION 'Solo personal de vigilancia o administración puede entregar paquetes.' USING ERRCODE = 'PQ005';
    END IF;

    SELECT * INTO v_paquete FROM public.paquetes WHERE id = p_paquete_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El paquete no existe.' USING ERRCODE = 'PQ002';
    END IF;

    IF v_paquete.condominio_id <> v_actor.condominio_id THEN
        RAISE EXCEPTION 'No puedes operar paquetes de otro condominio.' USING ERRCODE = 'PQ005';
    END IF;

    IF v_paquete.estado <> 'recibido' THEN
        RAISE EXCEPTION 'Solo se pueden entregar paquetes que hayan sido recibidos en caseta (estado actual: %).', v_paquete.estado
            USING ERRCODE = 'PQ003';
    END IF;

    UPDATE public.paquetes
    SET estado = 'entregado',
        entregado_en = timezone('utc'::text, now()),
        entregado_por = p_actor_id,
        entregado_a_nombre = btrim(p_entregado_a_nombre),
        foto_url = COALESCE(p_foto_url, foto_url),
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_paquete_id;

    IF v_paquete.creado_por IS NOT NULL THEN
        PERFORM public.crear_notificacion(
            v_paquete.creado_por,
            'paquete_entregado',
            'Paquete entregado',
            format('El paquete de %s para %s ha sido entregado a %s.', COALESCE(v_paquete.servicio_nombre, 'paquetería'), v_paquete.destinatario_nombre, btrim(p_entregado_a_nombre)),
            '/paqueteria'
        );
    END IF;

    RETURN public._proyectar_paquete_dto(p_paquete_id);
END;
$$;


ALTER FUNCTION public.entregar_paquete_residente(p_paquete_id uuid, p_entregado_a_nombre text, p_foto_url text, p_actor_id uuid) OWNER TO postgres;

--
-- Name: fn_auditoria(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_auditoria() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
DECLARE
    v_usuario_id UUID;
    v_tabla_bitacora TEXT;
BEGIN
    v_usuario_id := auth.uid();
    v_tabla_bitacora := TG_TABLE_NAME || '_bitacora';

    IF (TG_OP = 'INSERT') THEN
        EXECUTE format(
            'INSERT INTO public.%I (operacion, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES ($1, current_user, $2, NULL, $3)',
            v_tabla_bitacora
        ) USING TG_OP, v_usuario_id, to_jsonb(NEW);
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        EXECUTE format(
            'INSERT INTO public.%I (operacion, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES ($1, current_user, $2, $3, $4)',
            v_tabla_bitacora
        ) USING TG_OP, v_usuario_id, to_jsonb(OLD), to_jsonb(NEW);
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        EXECUTE format(
            'INSERT INTO public.%I (operacion, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES ($1, current_user, $2, $3, NULL)',
            v_tabla_bitacora
        ) USING TG_OP, v_usuario_id, to_jsonb(OLD);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$_$;


ALTER FUNCTION public.fn_auditoria() OWNER TO postgres;

--
-- Name: fn_generar_codigo_invitacion_subusuario(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_generar_codigo_invitacion_subusuario() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_caracteres TEXT := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; -- Excluye caracteres ambiguos (0, O, 1, I)
    v_resultado TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..8 LOOP
        v_resultado := v_resultado || substr(v_caracteres, (random() * length(v_caracteres) + 1)::integer, 1);
    END LOOP;
    RETURN v_resultado;
END;
$$;


ALTER FUNCTION public.fn_generar_codigo_invitacion_subusuario() OWNER TO postgres;

--
-- Name: fn_mi_condominio_id(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_mi_condominio_id() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT condominio_id FROM public.usuarios WHERE id = auth.uid();
$$;


ALTER FUNCTION public.fn_mi_condominio_id() OWNER TO postgres;

--
-- Name: fn_mi_rol_id(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_mi_rol_id() RETURNS integer
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT rol_id FROM public.usuarios WHERE id = auth.uid();
$$;


ALTER FUNCTION public.fn_mi_rol_id() OWNER TO postgres;

--
-- Name: fn_pertenezco_a_vivienda(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_pertenezco_a_vivienda(p_vivienda_id integer) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.vivienda_residente
        WHERE vivienda_id = p_vivienda_id
          AND usuario_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1
        FROM public.vivienda_subusuarios
        WHERE vivienda_id = p_vivienda_id
          AND usuario_id = auth.uid()
          AND activo = true
    );
$$;


ALTER FUNCTION public.fn_pertenezco_a_vivienda(p_vivienda_id integer) OWNER TO postgres;

--
-- Name: fn_soy_titular_vivienda(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_soy_titular_vivienda(p_vivienda_id integer) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.vivienda_residente
        WHERE vivienda_id = p_vivienda_id
          AND usuario_id = auth.uid()
    );
$$;


ALTER FUNCTION public.fn_soy_titular_vivienda(p_vivienda_id integer) OWNER TO postgres;

--
-- Name: fn_sync_usuario_app_metadata(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_sync_usuario_app_metadata() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_rol_nombre TEXT;
BEGIN
    SELECT nombre INTO v_rol_nombre FROM public.roles WHERE id = NEW.rol_id;

    UPDATE auth.users
    SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb)
        || jsonb_build_object(
            'rol_id', NEW.rol_id,
            'rol', COALESCE(v_rol_nombre, 'Residente'),
            'condominio_id', NEW.condominio_id
        )
    WHERE id = NEW.id;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_sync_usuario_app_metadata() OWNER TO postgres;

--
-- Name: generar_codigo_condominio(uuid, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generar_codigo_condominio(p_condominio_id uuid, p_minutos_vigencia integer DEFAULT 60) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_condominio RECORD;
    v_codigo VARCHAR(20);
    v_existe BOOLEAN;
    v_registro RECORD;
    v_minutos INT;
BEGIN
    SELECT * INTO v_condominio
    FROM public.condominios
    WHERE id = p_condominio_id AND activo = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Condominio no encontrado o inactivo.' USING ERRCODE = 'P0002';
    END IF;

    v_minutos := COALESCE(p_minutos_vigencia, 60);
    IF v_minutos <= 0 THEN
        v_minutos := 60;
    END IF;

    LOOP
        v_codigo := 'CD-' || UPPER(SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6));
        SELECT EXISTS (SELECT 1 FROM public.codigos_condominio WHERE codigo = v_codigo) INTO v_existe;
        EXIT WHEN NOT v_existe;
    END LOOP;

    INSERT INTO public.codigos_condominio (condominio_id, codigo, expira_en, creado_por)
    VALUES (
        p_condominio_id,
        v_codigo,
        timezone('utc'::text, now()) + (v_minutos || ' minutes')::INTERVAL,
        auth.uid()
    )
    RETURNING id, condominio_id, codigo, expira_en, usado_por, usado_en, creado_en
    INTO v_registro;

    RETURN to_jsonb(v_registro);
END;
$$;


ALTER FUNCTION public.generar_codigo_condominio(p_condominio_id uuid, p_minutos_vigencia integer) OWNER TO postgres;

--
-- Name: generar_codigo_vivienda(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generar_codigo_vivienda(p_vivienda_id integer, p_minutos_vigencia integer DEFAULT 60) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_vivienda RECORD;
    v_codigo VARCHAR(20);
    v_existe BOOLEAN;
    v_registro RECORD;
    v_minutos INT;
BEGIN
    SELECT * INTO v_vivienda
    FROM public.viviendas
    WHERE id = p_vivienda_id AND activo = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vivienda no encontrada o inactiva.' USING ERRCODE = 'P0001';
    END IF;

    v_minutos := COALESCE(p_minutos_vigencia, 60);
    IF v_minutos <= 0 THEN
        v_minutos := 60;
    END IF;

    LOOP
        v_codigo := 'VV-' || UPPER(SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6));
        SELECT EXISTS (SELECT 1 FROM public.codigos_vivienda WHERE codigo = v_codigo) INTO v_existe;
        EXIT WHEN NOT v_existe;
    END LOOP;

    INSERT INTO public.codigos_vivienda (vivienda_id, codigo, expira_en, creado_por)
    VALUES (
        p_vivienda_id,
        v_codigo,
        timezone('utc'::text, now()) + (v_minutos || ' minutes')::INTERVAL,
        auth.uid()
    )
    RETURNING id, vivienda_id, codigo, expira_en, usado_por, usado_en, creado_en
    INTO v_registro;

    RETURN to_jsonb(v_registro);
END;
$$;


ALTER FUNCTION public.generar_codigo_vivienda(p_vivienda_id integer, p_minutos_vigencia integer) OWNER TO postgres;

--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_rol_id INT := 2;
    v_condominio_id UUID := NULL;
BEGIN
    IF NEW.raw_app_meta_data IS NOT NULL AND NEW.raw_app_meta_data ? 'rol_id' THEN
        BEGIN
            v_rol_id := (NEW.raw_app_meta_data->>'rol_id')::INT;
        EXCEPTION WHEN OTHERS THEN
            v_rol_id := 2;
        END;
    END IF;

    IF NEW.raw_app_meta_data IS NOT NULL AND NEW.raw_app_meta_data ? 'condominio_id' AND NEW.raw_app_meta_data->>'condominio_id' IS NOT NULL THEN
        BEGIN
            v_condominio_id := (NEW.raw_app_meta_data->>'condominio_id')::UUID;
        EXCEPTION WHEN OTHERS THEN
            v_condominio_id := NULL;
        END;
    END IF;

    INSERT INTO public.usuarios (id, rol_id, condominio_id, email, nombre, apellidos, telefono)
    VALUES (
        NEW.id,
        v_rol_id,
        v_condominio_id,
        NEW.email,
        COALESCE(
            NULLIF(NEW.raw_user_meta_data->>'nombre', ''),
            NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
            NULLIF(NEW.raw_user_meta_data->>'name', ''),
            'Pendiente'
        ),
        COALESCE(
            NULLIF(NEW.raw_user_meta_data->>'apellidos', ''),
            'Pendiente'
        ),
        COALESCE(
            NEW.raw_user_meta_data->>'telefono',
            NEW.phone
        )
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.handle_new_user() OWNER TO postgres;

--
-- Name: handle_user_metadata_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.handle_user_metadata_update() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    IF (OLD.raw_user_meta_data IS DISTINCT FROM NEW.raw_user_meta_data) THEN
        UPDATE public.usuarios
        SET
            nombre = COALESCE(
                NULLIF(NEW.raw_user_meta_data->>'nombre', ''),
                NULLIF(NEW.raw_user_meta_data->>'full_name', ''),
                NULLIF(NEW.raw_user_meta_data->>'name', ''),
                nombre
            ),
            apellidos = COALESCE(
                NULLIF(NEW.raw_user_meta_data->>'apellidos', ''),
                apellidos
            ),
            telefono = COALESCE(
                NEW.raw_user_meta_data->>'telefono',
                NEW.phone,
                telefono
            )
        WHERE id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.handle_user_metadata_update() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: condominios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.condominios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    direccion text,
    zona_horaria text DEFAULT 'America/Mexico_City'::text NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


ALTER TABLE public.condominios OWNER TO postgres;

--
-- Name: invitaciones_subusuarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invitaciones_subusuarios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    vivienda_id integer NOT NULL,
    creado_por uuid NOT NULL,
    email_invitado character varying(255) NOT NULL,
    codigo_invitacion character varying(8) NOT NULL,
    estado character varying(20) DEFAULT 'pendiente'::character varying NOT NULL,
    usuario_id uuid,
    expira_en timestamp with time zone DEFAULT (timezone('utc'::text, now()) + '24:00:00'::interval) NOT NULL,
    respondido_en timestamp with time zone,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    parentesco character varying(50) DEFAULT 'Familiar'::character varying,
    invitado_id uuid,
    titular_id uuid,
    CONSTRAINT invitaciones_subusuarios_estado_check CHECK ((upper((estado)::text) = ANY (ARRAY['PENDIENTE'::text, 'ACEPTADA'::text, 'RECHAZADA'::text, 'EXPIRADA'::text, 'CANCELADA'::text, 'REVOCADA'::text])))
);


ALTER TABLE public.invitaciones_subusuarios OWNER TO postgres;

--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios (
    id uuid NOT NULL,
    rol_id integer DEFAULT 2 NOT NULL,
    condominio_id uuid,
    email text NOT NULL,
    nombre text NOT NULL,
    apellidos text NOT NULL,
    telefono text,
    activo boolean DEFAULT true NOT NULL,
    debe_cambiar_password boolean DEFAULT false NOT NULL,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT chk_vigilancia_condominio_requerido CHECK (((rol_id <> 3) OR (condominio_id IS NOT NULL)))
);


ALTER TABLE public.usuarios OWNER TO postgres;

--
-- Name: viviendas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.viviendas (
    id integer NOT NULL,
    condominio_id uuid NOT NULL,
    numero_casa text NOT NULL,
    tipo text,
    activo boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


ALTER TABLE public.viviendas OWNER TO postgres;

--
-- Name: vw_invitaciones_subusuarios; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_invitaciones_subusuarios AS
 SELECT i.id,
    i.vivienda_id,
    v.numero_casa,
    v.condominio_id,
    c.nombre AS condominio_nombre,
    i.creado_por AS titular_id,
    TRIM(BOTH FROM ((u_titular.nombre || ' '::text) || COALESCE(u_titular.apellidos, (''::character varying)::text))) AS titular_nombre,
    i.usuario_id AS invitado_id,
    i.email_invitado AS invitado_email,
    i.codigo_invitacion AS codigo,
    i.codigo_invitacion,
    COALESCE(i.parentesco, 'Familiar'::character varying) AS parentesco,
    i.estado,
    i.expira_en,
    i.creado_en
   FROM ((((public.invitaciones_subusuarios i
     JOIN public.viviendas v ON ((v.id = i.vivienda_id)))
     LEFT JOIN public.condominios c ON ((c.id = v.condominio_id)))
     LEFT JOIN public.usuarios u_titular ON ((u_titular.id = i.creado_por)))
     LEFT JOIN public.usuarios u_invitado ON ((u_invitado.id = i.usuario_id)));


ALTER VIEW public.vw_invitaciones_subusuarios OWNER TO postgres;

--
-- Name: invitar_subusuario(integer, character varying, character varying, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.invitar_subusuario(p_vivienda_id integer, p_email character varying, p_parentesco character varying DEFAULT 'Familiar'::character varying, p_creado_por uuid DEFAULT NULL::uuid) RETURNS public.vw_invitaciones_subusuarios
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor_id UUID;
    v_invitado_id UUID;
    v_subusuarios_activos INTEGER := 0;
    v_invitaciones_pendientes INTEGER := 0;
    v_codigo VARCHAR(8);
    v_invitacion_id UUID;
    v_resultado public.vw_invitaciones_subusuarios;
BEGIN
    -- 1. Resolver ejecutor (parámetro explícito o contexto de sesión)
    v_actor_id := COALESCE(p_creado_por, auth.uid());
    IF v_actor_id IS NULL THEN
        RAISE EXCEPTION 'No se proporcionó un ID de usuario creador válido'
            USING ERRCODE = '42501';
    END IF;

    -- 2. Validar existencia del usuario por correo electrónico
    SELECT id INTO v_invitado_id 
    FROM public.usuarios 
    WHERE LOWER(TRIM(email)) = LOWER(TRIM(p_email));

    IF v_invitado_id IS NULL THEN
        RAISE EXCEPTION 'Usuario con email % no encontrado en el sistema', p_email
            USING ERRCODE = 'P0002';
    END IF;

    -- Validar que no sea auto-invitación
    IF v_invitado_id = v_actor_id THEN
        RAISE EXCEPTION 'No puedes invitarte a ti mismo como sub-usuario'
            USING ERRCODE = 'SU003';
    END IF;

    -- 3. Validar que el invitado no sea el residente titular de esta casa
    IF EXISTS (
        SELECT 1 FROM public.vivienda_residente 
        WHERE vivienda_id = p_vivienda_id AND usuario_id = v_invitado_id
    ) THEN
        RAISE EXCEPTION 'El usuario ya es el residente titular de esta vivienda'
            USING ERRCODE = 'SU002';
    END IF;

    -- 4. Validar que el usuario no sea ya sub-usuario activo
    IF EXISTS (
        SELECT 1 FROM public.vivienda_subusuarios
        WHERE vivienda_id = p_vivienda_id 
          AND usuario_id = v_invitado_id 
          AND activo = true
    ) THEN
        RAISE EXCEPTION 'El usuario ya es sub-usuario activo de esta vivienda'
            USING ERRCODE = '23505';
    END IF;

    -- 5. REGLA ESTRICTA DE CUPO: Máximo 2 entre residentes secundarios activos e invitaciones vigentes
    SELECT COUNT(*) INTO v_subusuarios_activos
    FROM public.vivienda_subusuarios
    WHERE vivienda_id = p_vivienda_id AND activo = true;

    SELECT COUNT(*) INTO v_invitaciones_pendientes
    FROM public.invitaciones_subusuarios
    WHERE vivienda_id = p_vivienda_id 
      AND LOWER(estado) = 'pendiente'
      AND expira_en > now();

    IF (v_subusuarios_activos + v_invitaciones_pendientes) >= 2 THEN
        RAISE EXCEPTION 'Límite de sub-usuarios excedido para esta vivienda (máximo 2 entre residentes activos e invitaciones pendientes)'
            USING ERRCODE = 'SU001';
    END IF;

    -- 6. Validar que no exista ya una invitación pendiente vigente para este mismo usuario
    IF EXISTS (
        SELECT 1 FROM public.invitaciones_subusuarios
        WHERE vivienda_id = p_vivienda_id 
          AND (usuario_id = v_invitado_id OR LOWER(email_invitado) = LOWER(TRIM(p_email)))
          AND LOWER(estado) = 'pendiente'
          AND expira_en > now()
    ) THEN
        RAISE EXCEPTION 'Ya existe una invitación pendiente vigente para este usuario en esta vivienda'
            USING ERRCODE = 'SU002';
    END IF;

    -- 7. Generar código alfanumérico único con resolución de colisiones
    LOOP
        v_codigo := public.fn_generar_codigo_invitacion_subusuario();
        BEGIN
            INSERT INTO public.invitaciones_subusuarios (
                vivienda_id,
                creado_por,
                email_invitado,
                codigo_invitacion,
                estado,
                usuario_id,
                parentesco,
                expira_en
            ) VALUES (
                p_vivienda_id,
                v_actor_id,
                LOWER(TRIM(p_email)),
                v_codigo,
                'pendiente',
                v_invitado_id,
                COALESCE(NULLIF(TRIM(p_parentesco), ''), 'Familiar'),
                timezone('utc'::text, now()) + INTERVAL '24 hours'
            ) RETURNING id INTO v_invitacion_id;

            EXIT;
        EXCEPTION WHEN unique_violation THEN
            -- Reintenta generar otro código si choca con uno pendiente activo
        END;
    END LOOP;

    -- 8. Disparar notificación interna al usuario invitado
    BEGIN
        PERFORM public.alta_notificacion(
            v_invitado_id, 
            'INVITACION', 
            'Invitación a vivienda', 
            'Has recibido una invitación para unirte a una vivienda como co-habitante.', 
            '/panel/invitaciones'
        );
    EXCEPTION WHEN OTHERS THEN
        -- Silenciar si la notificación opcional no está en el entorno
    END;

    -- 9. Retornar fila formateada desde la vista
    SELECT * INTO v_resultado 
    FROM public.vw_invitaciones_subusuarios 
    WHERE id = v_invitacion_id;

    RETURN v_resultado;
END;
$$;


ALTER FUNCTION public.invitar_subusuario(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) OWNER TO postgres;

--
-- Name: invitar_subusuario_por_email(integer, character varying, character varying, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.invitar_subusuario_por_email(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) RETURNS public.vw_invitaciones_subusuarios
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    RETURN public.invitar_subusuario(p_vivienda_id, p_email, p_parentesco, p_creado_por);
END;
$$;


ALTER FUNCTION public.invitar_subusuario_por_email(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) OWNER TO postgres;

--
-- Name: liberar_notificacion_push(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.liberar_notificacion_push(p_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    UPDATE public.notificaciones
    SET push_reclamado_en = NULL
    WHERE id = p_id AND push_enviado = false;

    RETURN FOUND;
END;
$$;


ALTER FUNCTION public.liberar_notificacion_push(p_id uuid) OWNER TO postgres;

--
-- Name: marcar_notificacion_leida(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.marcar_notificacion_leida(p_notificacion_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_usuario_actual UUID;
BEGIN
    v_usuario_actual := auth.uid();

    UPDATE public.notificaciones
    SET leida = true
    WHERE id = p_notificacion_id
      AND (v_usuario_actual IS NULL OR usuario_id = v_usuario_actual)
      AND leida = false;

    RETURN FOUND;
END;
$$;


ALTER FUNCTION public.marcar_notificacion_leida(p_notificacion_id uuid) OWNER TO postgres;

--
-- Name: marcar_notificacion_leida(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.marcar_notificacion_leida(p_id uuid, p_usuario_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_afectados INTEGER;
BEGIN
    UPDATE public.notificaciones
    SET leida = true
    WHERE id = p_id 
      AND usuario_id = p_usuario_id
      AND leida = false;

    GET DIAGNOSTICS v_afectados = ROW_COUNT;
    RETURN v_afectados > 0;
END;
$$;


ALTER FUNCTION public.marcar_notificacion_leida(p_id uuid, p_usuario_id uuid) OWNER TO postgres;

--
-- Name: marcar_notificacion_push_enviada(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.marcar_notificacion_push_enviada(p_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    UPDATE public.notificaciones
    SET push_enviado = true,
        push_reclamado_en = timezone('utc'::text, now())
    WHERE id = p_id;

    RETURN FOUND;
END;
$$;


ALTER FUNCTION public.marcar_notificacion_push_enviada(p_id uuid) OWNER TO postgres;

--
-- Name: marcar_reserva_no_utilizada(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.marcar_reserva_no_utilizada(p_actor_id uuid, p_reserva_id uuid) RETURNS boolean
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

--
-- Name: marcar_todas_notificaciones_leidas(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.marcar_todas_notificaciones_leidas() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_usuario_actual UUID;
    v_actualizadas INT;
BEGIN
    v_usuario_actual := auth.uid();

    WITH filas_actualizadas AS (
        UPDATE public.notificaciones
        SET leida = true
        WHERE usuario_id = v_usuario_actual
          AND leida = false
        RETURNING id
    )
    SELECT COUNT(*)::INT INTO v_actualizadas FROM filas_actualizadas;

    RETURN v_actualizadas;
END;
$$;


ALTER FUNCTION public.marcar_todas_notificaciones_leidas() OWNER TO postgres;

--
-- Name: marcar_todas_notificaciones_leidas(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.marcar_todas_notificaciones_leidas(p_usuario_id uuid) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_afectados INTEGER;
BEGIN
    UPDATE public.notificaciones
    SET leida = true
    WHERE usuario_id = p_usuario_id 
      AND leida = false;

    GET DIAGNOSTICS v_afectados = ROW_COUNT;
    RETURN v_afectados;
END;
$$;


ALTER FUNCTION public.marcar_todas_notificaciones_leidas(p_usuario_id uuid) OWNER TO postgres;

--
-- Name: procesar_transiciones_reservas(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.procesar_transiciones_reservas() RETURNS jsonb
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

--
-- Name: quitar_residente_vivienda(integer, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.quitar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_filas_afectadas INTEGER;
BEGIN
    DELETE FROM public.vivienda_residente 
    WHERE vivienda_id = p_vivienda_id AND usuario_id = p_usuario_id;

    GET DIAGNOSTICS v_filas_afectadas = ROW_COUNT;
    RETURN v_filas_afectadas > 0;
END;
$$;


ALTER FUNCTION public.quitar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) OWNER TO postgres;

--
-- Name: reactivar_area_comun(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.reactivar_area_comun(p_actor_id uuid, p_id uuid) RETURNS boolean
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

--
-- Name: reactivar_usuario(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.reactivar_usuario(p_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    UPDATE public.usuarios
    SET activo = true
    WHERE id = p_id AND activo = false;

    RETURN FOUND;
END;
$$;


ALTER FUNCTION public.reactivar_usuario(p_id uuid) OWNER TO postgres;

--
-- Name: rechazar_reserva_admin(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rechazar_reserva_admin(p_actor_id uuid, p_reserva_id uuid, p_motivo text) RETURNS boolean
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

--
-- Name: rechazar_reserva_titular(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rechazar_reserva_titular(p_actor_id uuid, p_reserva_id uuid, p_motivo text DEFAULT NULL::text) RETURNS boolean
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

--
-- Name: recibir_paquete_caseta(uuid, integer, text, integer, text, text, text, text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.recibir_paquete_caseta(p_paquete_id uuid DEFAULT NULL::uuid, p_vivienda_id integer DEFAULT NULL::integer, p_destinatario_nombre text DEFAULT NULL::text, p_servicio_id integer DEFAULT NULL::integer, p_servicio_nombre text DEFAULT NULL::text, p_numero_guia text DEFAULT NULL::text, p_descripcion text DEFAULT NULL::text, p_ubicacion_almacen text DEFAULT NULL::text, p_actor_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_paquete RECORD;
    v_vivienda RECORD;
    v_servicio_nombre_final VARCHAR(50);
    v_target_id UUID;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id NOT IN (1, 3) THEN
        RAISE EXCEPTION 'Solo personal de vigilancia o administración puede recibir paquetes en caseta.' USING ERRCODE = 'PQ005';
    END IF;

    IF p_paquete_id IS NOT NULL THEN
        SELECT * INTO v_paquete FROM public.paquetes WHERE id = p_paquete_id FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'El paquete no existe.' USING ERRCODE = 'PQ002';
        END IF;

        IF v_paquete.condominio_id <> v_actor.condominio_id THEN
            RAISE EXCEPTION 'No puedes operar paquetes de otro condominio.' USING ERRCODE = 'PQ005';
        END IF;

        IF v_paquete.estado <> 'esperado' THEN
            RAISE EXCEPTION 'El paquete no está en estado esperado (estado actual: %).', v_paquete.estado USING ERRCODE = 'PQ003';
        END IF;

        IF p_servicio_id IS NOT NULL THEN
            SELECT nombre INTO v_servicio_nombre_final FROM public.servicios_paqueteria WHERE id = p_servicio_id;
        ELSE
            v_servicio_nombre_final := COALESCE(NULLIF(btrim(p_servicio_nombre), ''), v_paquete.servicio_nombre);
        END IF;

        UPDATE public.paquetes
        SET estado = 'recibido',
            recibido_en = timezone('utc'::text, now()),
            recibido_por = p_actor_id,
            servicio_id = COALESCE(p_servicio_id, servicio_id),
            servicio_nombre = COALESCE(v_servicio_nombre_final, servicio_nombre),
            empresa_paqueteria = COALESCE(v_servicio_nombre_final, empresa_paqueteria),
            numero_guia = COALESCE(NULLIF(btrim(p_numero_guia), ''), numero_guia),
            descripcion = COALESCE(NULLIF(btrim(p_descripcion), ''), descripcion),
            ubicacion_almacen = COALESCE(NULLIF(btrim(p_ubicacion_almacen), ''), ubicacion_almacen),
            actualizado_en = timezone('utc'::text, now())
        WHERE id = p_paquete_id;

        v_target_id := p_paquete_id;
    ELSE
        -- Recepción de paquete inesperado directamente en caseta
        IF p_vivienda_id IS NULL OR p_destinatario_nombre IS NULL OR length(btrim(p_destinatario_nombre)) = 0 THEN
            RAISE EXCEPTION 'Debe especificar la vivienda y el destinatario para registrar un paquete no esperado.' USING ERRCODE = 'PQ004';
        END IF;

        SELECT * INTO v_vivienda FROM public.viviendas WHERE id = p_vivienda_id AND activo = true;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'La vivienda especificada no existe o está inactiva.' USING ERRCODE = 'PQ002';
        END IF;

        IF v_vivienda.condominio_id <> v_actor.condominio_id THEN
            RAISE EXCEPTION 'La vivienda no pertenece al condominio del vigilante.' USING ERRCODE = 'PQ005';
        END IF;

        IF p_servicio_id IS NOT NULL THEN
            SELECT nombre INTO v_servicio_nombre_final FROM public.servicios_paqueteria WHERE id = p_servicio_id;
        ELSE
            v_servicio_nombre_final := COALESCE(NULLIF(btrim(p_servicio_nombre), ''), 'Otro');
        END IF;

        INSERT INTO public.paquetes (
            condominio_id, vivienda_id, servicio_id, servicio_nombre, empresa_paqueteria,
            destinatario_nombre, numero_guia, descripcion, ubicacion_almacen,
            estado, es_inesperado, recibido_en, recibido_por, creado_por
        )
        VALUES (
            v_vivienda.condominio_id,
            p_vivienda_id,
            p_servicio_id,
            v_servicio_nombre_final,
            v_servicio_nombre_final,
            btrim(p_destinatario_nombre),
            NULLIF(btrim(p_numero_guia), ''),
            p_descripcion,
            NULLIF(btrim(p_ubicacion_almacen), ''),
            'recibido',
            true,
            timezone('utc'::text, now()),
            p_actor_id,
            p_actor_id
        )
        RETURNING id INTO v_target_id;
    END IF;

    RETURN public._proyectar_paquete_dto(v_target_id);
END;
$$;


ALTER FUNCTION public.recibir_paquete_caseta(p_paquete_id uuid, p_vivienda_id integer, p_destinatario_nombre text, p_servicio_id integer, p_servicio_nombre text, p_numero_guia text, p_descripcion text, p_ubicacion_almacen text, p_actor_id uuid) OWNER TO postgres;

--
-- Name: reclamar_notificaciones_push_reservas(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.reclamar_notificaciones_push_reservas(p_limite integer DEFAULT 25) RETURNS TABLE(id uuid, usuario_id uuid, tipo_evento character varying, titulo character varying, mensaje text, url_redireccion text, reserva_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    RETURN QUERY
    WITH reclamadas AS (
        SELECT n.id
        FROM public.notificaciones n
        WHERE n.push_enviado = false
          AND n.reserva_id IS NOT NULL
          AND (n.push_reclamado_en IS NULL OR n.push_reclamado_en < now() - INTERVAL '5 minutes')
        ORDER BY n.creado_en ASC
        LIMIT GREATEST(COALESCE(p_limite, 25), 1)
        FOR UPDATE SKIP LOCKED
    )
    UPDATE public.notificaciones t
    SET push_reclamado_en = timezone('utc'::text, now())
    FROM reclamadas r
    WHERE t.id = r.id
    RETURNING
        t.id,
        t.usuario_id,
        t.tipo_evento,
        t.titulo,
        t.mensaje,
        t.url_redireccion,
        t.reserva_id;
END;
$$;


ALTER FUNCTION public.reclamar_notificaciones_push_reservas(p_limite integer) OWNER TO postgres;

--
-- Name: redimir_codigo_condominio(text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.redimir_codigo_condominio(p_codigo text, p_usuario_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_codigo RECORD;
    v_usuario RECORD;
    v_rol_nombre TEXT;
BEGIN
    SELECT * INTO v_codigo
    FROM public.codigos_condominio
    WHERE UPPER(TRIM(codigo)) = UPPER(TRIM(p_codigo))
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El código de condominio no existe.' USING ERRCODE = 'CD001';
    END IF;

    IF v_codigo.usado_por IS NOT NULL THEN
        RAISE EXCEPTION 'El código ya fue utilizado.' USING ERRCODE = 'CD002';
    END IF;

    IF v_codigo.expira_en < timezone('utc'::text, now()) THEN
        RAISE EXCEPTION 'El código ha expirado o fue invalidado.' USING ERRCODE = 'CD003';
    END IF;

    SELECT * INTO v_usuario
    FROM public.usuarios
    WHERE id = p_usuario_id AND activo = true
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuario no encontrado.' USING ERRCODE = 'P0002';
    END IF;

    IF v_usuario.condominio_id IS NOT NULL AND v_usuario.condominio_id <> v_codigo.condominio_id THEN
        RAISE EXCEPTION 'El usuario ya pertenece a otro condominio.' USING ERRCODE = 'CD004';
    END IF;

    UPDATE public.usuarios
    SET condominio_id = v_codigo.condominio_id
    WHERE id = p_usuario_id
    RETURNING * INTO v_usuario;

    UPDATE public.codigos_condominio
    SET usado_por = p_usuario_id,
        usado_en = timezone('utc'::text, now())
    WHERE id = v_codigo.id;

    SELECT nombre INTO v_rol_nombre FROM public.roles WHERE id = v_usuario.rol_id;

    RETURN jsonb_build_object(
        'id', v_usuario.id,
        'rol_id', v_usuario.rol_id,
        'rol_nombre', COALESCE(v_rol_nombre, 'Residente'),
        'email', v_usuario.email,
        'nombre', v_usuario.nombre,
        'apellidos', v_usuario.apellidos,
        'telefono', v_usuario.telefono,
        'condominio_id', v_usuario.condominio_id,
        'activo', v_usuario.activo,
        'debe_cambiar_password', v_usuario.debe_cambiar_password,
        'creado_en', v_usuario.creado_en
    );
END;
$$;


ALTER FUNCTION public.redimir_codigo_condominio(p_codigo text, p_usuario_id uuid) OWNER TO postgres;

--
-- Name: redimir_codigo_subusuario(character varying, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.redimir_codigo_subusuario(p_codigo character varying, p_usuario_id uuid DEFAULT NULL::uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_invitacion_id UUID;
    v_actor_id UUID;
BEGIN
    v_actor_id := COALESCE(p_usuario_id, auth.uid());
    IF v_actor_id IS NULL THEN
        RAISE EXCEPTION 'No se proporcionó un ID de usuario válido ni existe una sesión activa'
            USING ERRCODE = '42501';
    END IF;

    SELECT id INTO v_invitacion_id
    FROM public.invitaciones_subusuarios
    WHERE codigo_invitacion = UPPER(TRIM(p_codigo))
      AND UPPER(estado) = 'PENDIENTE'
      AND expira_en > now();

    IF v_invitacion_id IS NULL THEN
        RAISE EXCEPTION 'El código de invitación no existe, ya fue utilizado o ha expirado'
            USING ERRCODE = 'CD001';
    END IF;

    RETURN public.responder_invitacion_subusuario(v_invitacion_id, v_actor_id, 'ACEPTADA');
END;
$$;


ALTER FUNCTION public.redimir_codigo_subusuario(p_codigo character varying, p_usuario_id uuid) OWNER TO postgres;

--
-- Name: redimir_codigo_vivienda(text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.redimir_codigo_vivienda(p_codigo text, p_usuario_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_codigo RECORD;
    v_vivienda RECORD;
    v_usuario RECORD;
    v_condominio_nombre TEXT;
    v_total_residentes INT;
BEGIN
    SELECT * INTO v_codigo
    FROM public.codigos_vivienda
    WHERE UPPER(TRIM(codigo)) = UPPER(TRIM(p_codigo))
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El código de vivienda no existe.' USING ERRCODE = 'VV001';
    END IF;

    IF v_codigo.usado_por IS NOT NULL THEN
        RAISE EXCEPTION 'El código de vivienda ya fue utilizado.' USING ERRCODE = 'VV002';
    END IF;

    IF v_codigo.expira_en < timezone('utc'::text, now()) THEN
        RAISE EXCEPTION 'El código de vivienda ha expirado.' USING ERRCODE = 'VV003';
    END IF;

    SELECT * INTO v_vivienda
    FROM public.viviendas
    WHERE id = v_codigo.vivienda_id AND activo = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La vivienda asociada al código no existe o está inactiva.' USING ERRCODE = 'VV001';
    END IF;

    SELECT * INTO v_usuario
    FROM public.usuarios
    WHERE id = p_usuario_id AND activo = true
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuario no encontrado.' USING ERRCODE = 'P0002';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.vivienda_residente
        WHERE vivienda_id = v_vivienda.id AND usuario_id = p_usuario_id
    ) THEN
        RAISE EXCEPTION 'El usuario ya está asignado a esta vivienda.' USING ERRCODE = 'VV004';
    END IF;

    IF v_usuario.condominio_id IS NOT NULL AND v_usuario.condominio_id <> v_vivienda.condominio_id THEN
        RAISE EXCEPTION 'El usuario pertenece a un condominio distinto al de la vivienda.' USING ERRCODE = 'VV005';
    END IF;

    INSERT INTO public.vivienda_residente (vivienda_id, usuario_id, es_propietario)
    VALUES (v_vivienda.id, p_usuario_id, true);

    IF v_usuario.condominio_id IS NULL THEN
        UPDATE public.usuarios
        SET condominio_id = v_vivienda.condominio_id
        WHERE id = p_usuario_id
        RETURNING * INTO v_usuario;
    END IF;

    UPDATE public.codigos_vivienda
    SET usado_por = p_usuario_id,
        usado_en = timezone('utc'::text, now())
    WHERE id = v_codigo.id;

    SELECT nombre INTO v_condominio_nombre
    FROM public.condominios
    WHERE id = v_vivienda.condominio_id;

    SELECT COUNT(*)::INT INTO v_total_residentes
    FROM public.vivienda_residente vr
    JOIN public.usuarios u ON u.id = vr.usuario_id AND u.activo = true
    WHERE vr.vivienda_id = v_vivienda.id;

    RETURN jsonb_build_object(
        'vivienda', jsonb_build_object(
            'id', v_vivienda.id,
            'numero_casa', v_vivienda.numero_casa,
            'tipo', v_vivienda.tipo,
            'activo', v_vivienda.activo,
            'condominio_id', v_vivienda.condominio_id,
            'condominio_nombre', COALESCE(v_condominio_nombre, ''),
            'creado_en', v_vivienda.creado_en,
            'total_residentes', v_total_residentes,
            'esta_ocupada', (v_total_residentes > 0)
        ),
        'residente', jsonb_build_object(
            'id', v_usuario.id,
            'email', v_usuario.email,
            'nombre', v_usuario.nombre,
            'apellidos', v_usuario.apellidos,
            'telefono', v_usuario.telefono
        )
    );
END;
$$;


ALTER FUNCTION public.redimir_codigo_vivienda(p_codigo text, p_usuario_id uuid) OWNER TO postgres;

--
-- Name: registrar_entrada_visita(uuid, uuid, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.registrar_entrada_visita(p_visita_id uuid, p_actor_id uuid, p_vehiculo_placas character varying DEFAULT NULL::character varying) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_visita RECORD;
    v_numero_casa TEXT;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id NOT IN (1, 3) THEN
        RAISE EXCEPTION 'Solo vigilancia o administración pueden registrar entradas.' USING ERRCODE = 'VI002';
    END IF;

    SELECT * INTO v_visita FROM public.visitas WHERE id = p_visita_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La visita no existe.' USING ERRCODE = 'VI001';
    END IF;

    IF v_visita.condominio_id <> v_actor.condominio_id THEN
        RAISE EXCEPTION 'No puedes operar visitas de otro condominio.' USING ERRCODE = 'VI002';
    END IF;

    IF v_visita.estado = 'en_curso' THEN
        RAISE EXCEPTION 'La visita ya se encuentra en curso.' USING ERRCODE = 'VI006';
    END IF;

    IF v_visita.estado <> 'programada' THEN
        RAISE EXCEPTION 'La visita no está en estado programada (estado actual: %).', v_visita.estado
            USING ERRCODE = 'VI003';
    END IF;

    IF now() > v_visita.fecha_expiracion THEN
        RAISE EXCEPTION 'El código de acceso de esta visita ha expirado.' USING ERRCODE = 'VI005';
    END IF;

    UPDATE public.visitas
    SET estado = 'en_curso',
        hora_entrada = timezone('utc'::text, now()),
        registrado_entrada_por = p_actor_id,
        vehiculo_placas = COALESCE(NULLIF(TRIM(p_vehiculo_placas), ''), vehiculo_placas)
    WHERE id = p_visita_id;

    SELECT numero_casa INTO v_numero_casa FROM public.viviendas WHERE id = v_visita.vivienda_id;

    PERFORM public.crear_notificacion(
        v_visita.creado_por,
        'llegada_visita',
        'Tu visita ha llegado',
        format('%s %s ha ingresado al condominio hacia la vivienda %s.', v_visita.nombre_visitante, v_visita.apellidos_visitante, v_numero_casa),
        '/mis-visitas'
    );

    RETURN public._proyectar_visita_dto(p_visita_id);
END;
$$;


ALTER FUNCTION public.registrar_entrada_visita(p_visita_id uuid, p_actor_id uuid, p_vehiculo_placas character varying) OWNER TO postgres;

--
-- Name: registrar_salida_visita(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.registrar_salida_visita(p_visita_id uuid, p_actor_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_visita RECORD;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id NOT IN (1, 3) THEN
        RAISE EXCEPTION 'Solo vigilancia o administración pueden registrar salidas.' USING ERRCODE = 'VI002';
    END IF;

    SELECT * INTO v_visita FROM public.visitas WHERE id = p_visita_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La visita no existe.' USING ERRCODE = 'VI001';
    END IF;

    IF v_visita.condominio_id <> v_actor.condominio_id THEN
        RAISE EXCEPTION 'No puedes operar visitas de otro condominio.' USING ERRCODE = 'VI002';
    END IF;

    IF v_visita.estado <> 'en_curso' THEN
        RAISE EXCEPTION 'Solo se puede registrar la salida de visitas que estén en curso.' USING ERRCODE = 'VI007';
    END IF;

    UPDATE public.visitas
    SET estado = 'finalizada',
        hora_salida = timezone('utc'::text, now()),
        registrado_salida_por = p_actor_id
    WHERE id = p_visita_id;

    RETURN public._proyectar_visita_dto(p_visita_id);
END;
$$;


ALTER FUNCTION public.registrar_salida_visita(p_visita_id uuid, p_actor_id uuid) OWNER TO postgres;

--
-- Name: responder_invitacion_subusuario(uuid, uuid, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.responder_invitacion_subusuario(p_invitacion_id uuid, p_usuario_id uuid DEFAULT NULL::uuid, p_respuesta character varying DEFAULT 'ACEPTADA'::character varying) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_invitacion public.invitaciones_subusuarios%ROWTYPE;
    v_condominio_id UUID;
    v_respuesta_limpia VARCHAR;
    v_actor_id UUID;
    v_invitado_esperado UUID;
BEGIN
    -- 1. Resolver usuario ejecutor (parámetro explícito o contexto de auth)
    v_actor_id := COALESCE(p_usuario_id, auth.uid());
    IF v_actor_id IS NULL THEN
        RAISE EXCEPTION 'No se proporcionó un ID de usuario válido ni existe una sesión activa'
            USING ERRCODE = '42501';
    END IF;

    -- 2. Limpiar y validar respuesta permitida
    v_respuesta_limpia := UPPER(TRIM(COALESCE(p_respuesta, 'ACEPTADA')));
    IF v_respuesta_limpia NOT IN ('ACEPTADA', 'RECHAZADA') THEN
        RAISE EXCEPTION 'Respuesta no válida. Los valores permitidos son ACEPTADA o RECHAZADA'
            USING ERRCODE = '22023';
    END IF;

    -- 3. Validar existencia de la invitación
    SELECT * INTO v_invitacion
    FROM public.invitaciones_subusuarios
    WHERE id = p_invitacion_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invitación con ID % no encontrada', p_invitacion_id
            USING ERRCODE = 'P0002';
    END IF;

    -- 4. Validar estado PENDIENTE
    IF UPPER(v_invitacion.estado) <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'La invitación no se encuentra en estado PENDIENTE (estado actual: %)', v_invitacion.estado
            USING ERRCODE = 'SU004';
    END IF;

    -- 5. Validar que quien responde sea el invitado destinatario
    v_invitado_esperado := COALESCE(v_invitacion.usuario_id, v_invitacion.invitado_id);
    IF v_invitado_esperado IS NULL THEN
        SELECT id INTO v_invitado_esperado 
        FROM public.usuarios 
        WHERE LOWER(email) = LOWER(v_invitacion.email_invitado);
    END IF;

    IF v_invitado_esperado IS NOT NULL AND v_invitado_esperado <> v_actor_id THEN
        RAISE EXCEPTION 'El usuario no tiene autorización para responder esta invitación. [invitado esperado: %, recibido: %]', 
            v_invitado_esperado, v_actor_id
            USING ERRCODE = '42501';
    END IF;

    -- 6. Actualizar estado y fecha de respuesta
    UPDATE public.invitaciones_subusuarios
    SET estado = v_respuesta_limpia,
        respondido_en = timezone('utc'::text, now()),
        usuario_id = COALESCE(usuario_id, v_actor_id)
    WHERE id = p_invitacion_id;

    -- 7. Si fue ACEPTADA: registrar en vivienda_subusuarios (sin titular_id) y sincronizar condominio_id
    IF v_respuesta_limpia = 'ACEPTADA' THEN
        INSERT INTO public.vivienda_subusuarios (
            vivienda_id, 
            usuario_id, 
            parentesco, 
            activo
        )
        VALUES (
            v_invitacion.vivienda_id, 
            v_actor_id, 
            COALESCE(v_invitacion.parentesco, 'Familiar'), 
            true
        )
        ON CONFLICT (vivienda_id, usuario_id) DO UPDATE
        SET activo = true,
            parentesco = EXCLUDED.parentesco;

        -- Obtener condominio_id de la casa asignada
        SELECT condominio_id INTO v_condominio_id
        FROM public.viviendas
        WHERE id = v_invitacion.vivienda_id;

        -- Sincronizar condominio_id en el perfil del usuario
        UPDATE public.usuarios
        SET condominio_id = v_condominio_id
        WHERE id = v_actor_id;
    END IF;

    RETURN TRUE;
END;
$$;


ALTER FUNCTION public.responder_invitacion_subusuario(p_invitacion_id uuid, p_usuario_id uuid, p_respuesta character varying) OWNER TO postgres;

--
-- Name: revocar_subusuario(integer, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.revocar_subusuario(p_vivienda_id integer, p_subusuario_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_titular_id UUID;
    v_es_titular BOOLEAN;
BEGIN
    v_titular_id := auth.uid();

    SELECT EXISTS (
        SELECT 1 FROM public.vivienda_residente
        WHERE vivienda_id = p_vivienda_id AND usuario_id = v_titular_id
    ) INTO v_es_titular;

    IF NOT v_es_titular THEN
        RAISE EXCEPTION 'No tienes permisos de titular sobre esta vivienda para revocar subusuarios.'
            USING ERRCODE = 'SB005';
    END IF;

    UPDATE public.vivienda_subusuarios
    SET activo = false,
        actualizado_en = timezone('utc'::text, now())
    WHERE vivienda_id = p_vivienda_id
      AND (usuario_id = p_subusuario_id OR id = p_subusuario_id)
      AND activo = true;

    RETURN FOUND;
END;
$$;


ALTER FUNCTION public.revocar_subusuario(p_vivienda_id integer, p_subusuario_id uuid) OWNER TO postgres;

--
-- Name: rls_auto_enable(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rls_auto_enable() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
    cmd RECORD;
BEGIN
    FOR cmd IN
        SELECT *
        FROM pg_event_trigger_ddl_commands()
        WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
          AND object_type IN ('table', 'partitioned table')
    LOOP
        IF cmd.schema_name IS NOT NULL
           AND cmd.schema_name IN ('public')
           AND cmd.schema_name NOT IN ('pg_catalog', 'information_schema')
           AND cmd.schema_name NOT LIKE 'pg_toast%'
           AND cmd.schema_name NOT LIKE 'pg_temp%'
        THEN
            BEGIN
                EXECUTE format('ALTER TABLE IF EXISTS %s ENABLE ROW LEVEL SECURITY', cmd.object_identity);
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE LOG 'rls_auto_enable: no se pudo activar RLS en %', cmd.object_identity;
            END;
        END IF;
    END LOOP;
END;
$$;


ALTER FUNCTION public.rls_auto_enable() OWNER TO postgres;

--
-- Name: rpc_anular_pago(uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rpc_anular_pago(p_pago_id uuid, p_motivo text, p_actor_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_pago_orig RECORD;
    v_pago_reversa public.pagos%ROWTYPE;
    v_cargo RECORD;
    v_mov_abono public.movimientos_saldo_favor%ROWTYPE;
    v_mov_saldo_reverso public.movimientos_saldo_favor%ROWTYPE;
    v_actor UUID;
    v_saldo_favor_actual NUMERIC(12,2);
    v_resultado JSONB;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());

    SELECT * INTO v_pago_orig FROM public.pagos WHERE id = p_pago_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El pago especificado no existe' USING ERRCODE = 'PG000';
    END IF;

    IF v_pago_orig.estado <> 'Confirmado' THEN
        RAISE EXCEPTION 'Solo se pueden anular pagos en estado Confirmado' USING ERRCODE = 'PG004';
    END IF;

    SELECT * INTO v_cargo FROM public.cargos WHERE id = v_pago_orig.cargo_id FOR UPDATE;

    -- Validar si el pago generó un abono que ya fue consumido
    SELECT * INTO v_mov_abono 
    FROM public.movimientos_saldo_favor 
    WHERE pago_id = p_pago_id AND tipo = 'Abono';

    IF FOUND THEN
        SELECT saldo_a_favor INTO v_saldo_favor_actual 
        FROM public.v_saldo_vivienda 
        WHERE vivienda_id = v_cargo.vivienda_id;

        IF v_saldo_favor_actual < v_mov_abono.monto THEN
            RAISE EXCEPTION 'Saldo a favor insuficiente para anular el pago (el excedente ya fue utilizado)' USING ERRCODE = 'PG007';
        END IF;

        INSERT INTO public.movimientos_saldo_favor (
            condominio_id, vivienda_id, tipo, monto, pago_id, cargo_id, movimiento_origen_id, motivo, creado_por
        ) VALUES (
            v_cargo.condominio_id, v_cargo.vivienda_id, 'ReversoAbono', v_mov_abono.monto, p_pago_id, v_cargo.id,
            v_mov_abono.id, 'Reverso de abono por anulación de pago: ' || TRIM(p_motivo), v_actor
        ) RETURNING * INTO v_mov_saldo_reverso;
    END IF;

    -- 1. Marcar pago original como Anulado
    UPDATE public.pagos 
    SET estado = 'Anulado',
        motivo_anulacion = p_motivo,
        anulado_por = v_actor,
        anulado_en = timezone('utc'::text, now())
    WHERE id = p_pago_id
    RETURNING * INTO v_pago_orig;

    -- 2. Crear fila inmutable de reversa contable
    INSERT INTO public.pagos (
        cargo_id,
        monto,
        monto_cubierto,
        monto_excedente,
        fecha_pago,
        metodo,
        referencia,
        banco_origen,
        estado,
        origen,
        es_reversa,
        pago_original_id,
        motivo_anulacion,
        registrado_por,
        creado_en,
        confirmado_por,
        confirmado_en
    ) VALUES (
        v_pago_orig.cargo_id,
        v_pago_orig.monto,
        v_pago_orig.monto_cubierto,
        v_pago_orig.monto_excedente,
        (timezone('America/Mexico_City', now()))::date,
        v_pago_orig.metodo,
        CONCAT('REV-', COALESCE(v_pago_orig.referencia, substr(v_pago_orig.id::text, 1, 8))),
        v_pago_orig.banco_origen,
        'Confirmado',
        'Admin',
        true,
        v_pago_orig.id,
        p_motivo,
        v_actor,
        timezone('utc'::text, now()),
        v_actor,
        timezone('utc'::text, now())
    ) RETURNING * INTO v_pago_reversa;

    -- 3. Recalcular estado del cargo
    PERFORM public._recalcular_estado_cargo(v_cargo.id);

    SELECT saldo_a_favor INTO v_saldo_favor_actual 
    FROM public.v_saldo_vivienda 
    WHERE vivienda_id = v_cargo.vivienda_id;

    SELECT jsonb_build_object(
        'pago_anulado', to_jsonb(v_pago_orig),
        'pago_reversa', to_jsonb(v_pago_reversa),
        'cargo', (SELECT to_jsonb(vc) FROM public.vw_cargos vc WHERE vc.id = v_cargo.id),
        'movimiento_saldo', CASE WHEN v_mov_saldo_reverso.id IS NOT NULL THEN to_jsonb(v_mov_saldo_reverso) ELSE NULL END,
        'saldo_a_favor', COALESCE(v_saldo_favor_actual, 0.00)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;


ALTER FUNCTION public.rpc_anular_pago(p_pago_id uuid, p_motivo text, p_actor_id uuid) OWNER TO postgres;

--
-- Name: rpc_aplicar_saldo_favor(uuid, numeric, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rpc_aplicar_saldo_favor(p_cargo_id uuid, p_monto numeric, p_actor_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_cargo RECORD;
    v_saldo_vivienda RECORD;
    v_mov public.movimientos_saldo_favor%ROWTYPE;
    v_actor UUID;
    v_saldo_pendiente NUMERIC(12,2);
    v_saldo_favor_final NUMERIC(12,2);
    v_resultado JSONB;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());

    IF p_monto <= 0 THEN
        RAISE EXCEPTION 'El monto a aplicar debe ser mayor a 0' USING ERRCODE = 'PG008';
    END IF;

    SELECT * INTO v_cargo FROM public.cargos WHERE id = p_cargo_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cargo especificado no existe' USING ERRCODE = 'PG000';
    END IF;

    IF v_cargo.estado = 'Cancelado' THEN
        RAISE EXCEPTION 'No se puede aplicar saldo a un cargo cancelado' USING ERRCODE = 'PG001';
    END IF;

    IF v_cargo.estado = 'Pagado' THEN
        RAISE EXCEPTION 'El cargo ya se encuentra totalmente pagado' USING ERRCODE = 'PG010';
    END IF;

    -- Bloqueo a nivel vivienda para evitar concurrencia
    SELECT * INTO v_saldo_vivienda 
    FROM public.v_saldo_vivienda 
    WHERE vivienda_id = v_cargo.vivienda_id;

    IF v_saldo_vivienda.saldo_a_favor < p_monto THEN
        RAISE EXCEPTION 'Saldo a favor insuficiente para cubrir el monto especificado' USING ERRCODE = 'PG007';
    END IF;

    SELECT saldo_pendiente INTO v_saldo_pendiente 
    FROM public.vw_cargos 
    WHERE id = p_cargo_id;

    IF p_monto > v_saldo_pendiente THEN
        RAISE EXCEPTION 'El monto a aplicar excede el saldo pendiente del cargo' USING ERRCODE = 'PG008';
    END IF;

    INSERT INTO public.movimientos_saldo_favor (
        condominio_id, vivienda_id, tipo, monto, cargo_id, motivo, creado_por
    ) VALUES (
        v_cargo.condominio_id, v_cargo.vivienda_id, 'Aplicacion', p_monto, p_cargo_id,
        'Aplicación manual de saldo a favor', v_actor
    ) RETURNING * INTO v_mov;

    PERFORM public._recalcular_estado_cargo(p_cargo_id);

    SELECT saldo_a_favor INTO v_saldo_favor_final 
    FROM public.v_saldo_vivienda 
    WHERE vivienda_id = v_cargo.vivienda_id;

    SELECT jsonb_build_object(
        'movimiento', to_jsonb(v_mov),
        'cargo', (SELECT to_jsonb(vc) FROM public.vw_cargos vc WHERE vc.id = p_cargo_id),
        'saldo_a_favor', COALESCE(v_saldo_favor_final, 0.00)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;


ALTER FUNCTION public.rpc_aplicar_saldo_favor(p_cargo_id uuid, p_monto numeric, p_actor_id uuid) OWNER TO postgres;

--
-- Name: rpc_cancelar_cargo(uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rpc_cancelar_cargo(p_cargo_id uuid, p_motivo text, p_actor_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_cargo RECORD;
    v_tiene_pagos BOOLEAN;
    v_tiene_saldo BOOLEAN;
    v_actor UUID;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());

    SELECT * INTO v_cargo FROM public.cargos WHERE id = p_cargo_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cargo especificado no existe' USING ERRCODE = 'PG000';
    END IF;

    IF v_cargo.estado = 'Cancelado' THEN
        RAISE EXCEPTION 'El cargo ya se encuentra cancelado' USING ERRCODE = 'PG005';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.pagos 
        WHERE cargo_id = p_cargo_id 
          AND estado IN ('Confirmado', 'PendienteConfirmacion')
    ) INTO v_tiene_pagos;

    SELECT EXISTS (
        SELECT 1 FROM public.movimientos_saldo_favor 
        WHERE cargo_id = p_cargo_id AND tipo = 'Aplicacion'
    ) INTO v_tiene_saldo;

    IF v_tiene_pagos OR v_tiene_saldo THEN
        RAISE EXCEPTION 'No se puede cancelar un cargo con pagos o aplicaciones de saldo vigentes' USING ERRCODE = 'PG006';
    END IF;

    UPDATE public.cargos 
    SET estado = 'Cancelado',
        motivo_cancelacion = p_motivo,
        cancelado_por = v_actor,
        cancelado_en = timezone('utc'::text, now())
    WHERE id = p_cargo_id
    RETURNING * INTO v_cargo;

    RETURN jsonb_build_object('cargo', to_jsonb(v_cargo));
END;
$$;


ALTER FUNCTION public.rpc_cancelar_cargo(p_cargo_id uuid, p_motivo text, p_actor_id uuid) OWNER TO postgres;

--
-- Name: rpc_confirmar_pago(uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rpc_confirmar_pago(p_pago_id uuid, p_actor_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_pago RECORD;
    v_cargo RECORD;
    v_mov_saldo public.movimientos_saldo_favor%ROWTYPE;
    v_actor UUID;
    v_saldo_pendiente NUMERIC(12,2);
    v_cubierto NUMERIC(12,2);
    v_excedente NUMERIC(12,2);
    v_saldo_favor_actual NUMERIC(12,2);
    v_resultado JSONB;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());

    SELECT * INTO v_pago FROM public.pagos WHERE id = p_pago_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El pago especificado no existe' USING ERRCODE = 'PG000';
    END IF;

    IF v_pago.estado <> 'PendienteConfirmacion' THEN
        RAISE EXCEPTION 'Solo se pueden confirmar pagos en estado PendienteConfirmacion' USING ERRCODE = 'PG002';
    END IF;

    SELECT * INTO v_cargo FROM public.cargos WHERE id = v_pago.cargo_id FOR UPDATE;
    IF v_cargo.estado = 'Cancelado' THEN
        RAISE EXCEPTION 'No se puede confirmar un pago sobre un cargo cancelado' USING ERRCODE = 'PG001';
    END IF;

    SELECT saldo_pendiente INTO v_saldo_pendiente FROM public.vw_cargos WHERE id = v_cargo.id;

    IF v_pago.monto <= v_saldo_pendiente THEN
        v_cubierto := v_pago.monto;
        v_excedente := 0.00;
    ELSE
        v_cubierto := v_saldo_pendiente;
        v_excedente := v_pago.monto - v_saldo_pendiente;
    END IF;

    UPDATE public.pagos 
    SET estado = 'Confirmado',
        monto_cubierto = v_cubierto,
        monto_excedente = v_excedente,
        confirmado_por = v_actor,
        confirmado_en = timezone('utc'::text, now())
    WHERE id = p_pago_id
    RETURNING * INTO v_pago;

    IF v_excedente > 0 THEN
        INSERT INTO public.movimientos_saldo_favor (
            condominio_id, vivienda_id, tipo, monto, pago_id, cargo_id, motivo, creado_por
        ) VALUES (
            v_cargo.condominio_id, v_cargo.vivienda_id, 'Abono', v_excedente, v_pago.id, v_cargo.id,
            'Excedente acreditado automáticamente de pago confirmado', v_actor
        ) RETURNING * INTO v_mov_saldo;
    END IF;

    PERFORM public._recalcular_estado_cargo(v_cargo.id);

    SELECT saldo_a_favor INTO v_saldo_favor_actual 
    FROM public.v_saldo_vivienda 
    WHERE vivienda_id = v_cargo.vivienda_id;

    SELECT jsonb_build_object(
        'pago', to_jsonb(v_pago),
        'cargo', (SELECT to_jsonb(vc) FROM public.vw_cargos vc WHERE vc.id = v_cargo.id),
        'movimiento_saldo', CASE WHEN v_mov_saldo.id IS NOT NULL THEN to_jsonb(v_mov_saldo) ELSE NULL END,
        'saldo_a_favor', COALESCE(v_saldo_favor_actual, 0.00)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;


ALTER FUNCTION public.rpc_confirmar_pago(p_pago_id uuid, p_actor_id uuid) OWNER TO postgres;

--
-- Name: rpc_depurar_comprobantes_antiguos(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rpc_depurar_comprobantes_antiguos(p_dias_confirmados integer DEFAULT 90, p_dias_rechazados integer DEFAULT 30) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_rutas TEXT[];
    v_objetos_eliminados INT := 0;
    v_pagos_actualizados INT := 0;
BEGIN
    SELECT ARRAY_AGG(DISTINCT p.comprobante_ruta)
    INTO v_rutas
    FROM public.pagos p
    WHERE p.comprobante_ruta IS NOT NULL
      AND (
          (p.estado = 'Confirmado' AND p.confirmado_en <= timezone('utc'::text, now()) - make_interval(days => COALESCE(p_dias_confirmados, 90)))
          OR
          (p.estado = 'Rechazado' AND p.rechazado_en <= timezone('utc'::text, now()) - make_interval(days => COALESCE(p_dias_rechazados, 30)))
      );

    IF v_rutas IS NULL OR array_length(v_rutas, 1) IS NULL THEN
        RETURN jsonb_build_object(
            'objetos_storage_eliminados', 0,
            'pagos_actualizados', 0
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'storage'
          AND table_name = 'objects'
    ) THEN
        DELETE FROM storage.objects
        WHERE bucket_id = 'comprobantes'
          AND name = ANY(v_rutas);

        GET DIAGNOSTICS v_objetos_eliminados = ROW_COUNT;
    END IF;

    UPDATE public.pagos
    SET comprobante_ruta = NULL
    WHERE comprobante_ruta = ANY(v_rutas);

    GET DIAGNOSTICS v_pagos_actualizados = ROW_COUNT;

    RETURN jsonb_build_object(
        'objetos_storage_eliminados', v_objetos_eliminados,
        'pagos_actualizados', v_pagos_actualizados
    );
END;
$$;


ALTER FUNCTION public.rpc_depurar_comprobantes_antiguos(p_dias_confirmados integer, p_dias_rechazados integer) OWNER TO postgres;

--
-- Name: rpc_generar_cargos_mensuales(date, uuid, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rpc_generar_cargos_mensuales(p_periodo date DEFAULT (date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone))::date, p_condominio_id uuid DEFAULT NULL::uuid, p_creado_por uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_periodo DATE;
    v_evaluadas INT := 0;
    v_generados INT := 0;
    v_omitidos INT := 0;
    v_plantilla RECORD;
    v_creador UUID;
    v_cargo_id UUID;
    v_fecha_vencimiento DATE;
BEGIN
    v_periodo := COALESCE(p_periodo, date_trunc('month', CURRENT_DATE)::DATE);

    IF EXTRACT(DAY FROM v_periodo) <> 1 THEN
        RAISE EXCEPTION 'El periodo (%) debe ser el primer día del mes (YYYY-MM-01).', v_periodo
            USING ERRCODE = '22023';
    END IF;

    FOR v_plantilla IN
        SELECT pc.*
        FROM public.plantillas_cargo pc
        JOIN public.viviendas v ON v.id = pc.vivienda_id
        JOIN public.condominios co ON co.id = pc.condominio_id
        WHERE pc.activa = true
          AND v.activo = true
          AND co.activo = true
          AND (p_condominio_id IS NULL OR pc.condominio_id = p_condominio_id)
          AND pc.vigencia_inicio <= (v_periodo + INTERVAL '1 month - 1 day')::DATE
          AND (pc.vigencia_fin IS NULL OR pc.vigencia_fin >= v_periodo)
    LOOP
        v_evaluadas := v_evaluadas + 1;
        v_creador := COALESCE(p_creado_por, v_plantilla.creado_por);
        v_fecha_vencimiento := make_date(
            EXTRACT(YEAR FROM v_periodo)::INT,
            EXTRACT(MONTH FROM v_periodo)::INT,
            v_plantilla.dia_vencimiento::INT
        );

        v_cargo_id := NULL;

        INSERT INTO public.cargos (
            condominio_id, vivienda_id, plantilla_id, periodo,
            tipo, concepto, monto,
            estado, fecha_vencimiento, responsable_pago, creado_por
        )
        VALUES (
            v_plantilla.condominio_id, v_plantilla.vivienda_id, v_plantilla.id, v_periodo,
            v_plantilla.tipo, v_plantilla.concepto, v_plantilla.monto,
            'Pendiente', v_fecha_vencimiento, v_plantilla.responsable_pago, v_creador
        )
        ON CONFLICT (plantilla_id, periodo) DO NOTHING
        RETURNING id INTO v_cargo_id;

        IF v_cargo_id IS NOT NULL THEN
            v_generados := v_generados + 1;
        ELSE
            v_omitidos := v_omitidos + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'periodo', v_periodo,
        'plantillas_evaluadas', v_evaluadas,
        'cargos_generados', v_generados,
        'cargos_omitidos_por_duplicado', v_omitidos
    );
END;
$$;


ALTER FUNCTION public.rpc_generar_cargos_mensuales(p_periodo date, p_condominio_id uuid, p_creado_por uuid) OWNER TO postgres;

--
-- Name: rpc_rechazar_pago(uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rpc_rechazar_pago(p_pago_id uuid, p_motivo text, p_actor_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_pago RECORD;
    v_actor UUID;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());

    SELECT * INTO v_pago FROM public.pagos WHERE id = p_pago_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El pago especificado no existe' USING ERRCODE = 'PG000';
    END IF;

    IF v_pago.estado <> 'PendienteConfirmacion' THEN
        RAISE EXCEPTION 'Solo se pueden rechazar pagos en estado PendienteConfirmacion' USING ERRCODE = 'PG003';
    END IF;

    UPDATE public.pagos 
    SET estado = 'Rechazado',
        motivo_rechazo = p_motivo,
        rechazado_por = v_actor,
        rechazado_en = timezone('utc'::text, now())
    WHERE id = p_pago_id
    RETURNING * INTO v_pago;

    RETURN jsonb_build_object('pago', to_jsonb(v_pago));
END;
$$;


ALTER FUNCTION public.rpc_rechazar_pago(p_pago_id uuid, p_motivo text, p_actor_id uuid) OWNER TO postgres;

--
-- Name: rpc_registrar_pago(uuid, numeric, date, text, text, text, text, text, text, text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rpc_registrar_pago(p_cargo_id uuid, p_monto numeric, p_fecha_pago date, p_metodo text, p_origen text, p_estado text, p_referencia text DEFAULT NULL::text, p_banco_origen text DEFAULT NULL::text, p_comprobante_ruta text DEFAULT NULL::text, p_comprobante_hash text DEFAULT NULL::text, p_actor_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_cargo RECORD;
    v_pago RECORD;
    v_mov_saldo public.movimientos_saldo_favor%ROWTYPE;
    v_estado_inicial VARCHAR(30);
    v_actor UUID;
    v_saldo_pendiente NUMERIC(12,2);
    v_cubierto NUMERIC(12,2) := 0.00;
    v_excedente NUMERIC(12,2) := 0.00;
    v_saldo_favor_actual NUMERIC(12,2);
    v_resultado JSONB;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());

    SELECT * INTO v_cargo FROM public.cargos WHERE id = p_cargo_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cargo especificado no existe' USING ERRCODE = 'PG000';
    END IF;

    IF v_cargo.estado = 'Cancelado' THEN
        RAISE EXCEPTION 'No se puede registrar un pago en un cargo cancelado' USING ERRCODE = 'PG001';
    END IF;

    v_estado_inicial := p_estado;
    IF v_estado_inicial NOT IN ('Confirmado', 'PendienteConfirmacion') THEN
        RAISE EXCEPTION 'Estado inicial inválido para registro de pago' USING ERRCODE = 'PG001';
    END IF;

    -- Calcular cobertura y excedente
    SELECT saldo_pendiente INTO v_saldo_pendiente FROM public.vw_cargos WHERE id = p_cargo_id;

    IF v_estado_inicial = 'Confirmado' THEN
        IF p_monto <= v_saldo_pendiente THEN
            v_cubierto := p_monto;
            v_excedente := 0.00;
        ELSE
            v_cubierto := v_saldo_pendiente;
            v_excedente := p_monto - v_saldo_pendiente;
        END IF;
    ELSE
        -- Si queda pendiente de confirmación, el monto cubierto se asienta al confirmar
        v_cubierto := LEAST(p_monto, v_saldo_pendiente);
        v_excedente := GREATEST(p_monto - v_saldo_pendiente, 0.00);
    END IF;

    INSERT INTO public.pagos (
        cargo_id,
        monto,
        monto_cubierto,
        monto_excedente,
        fecha_pago,
        metodo,
        referencia,
        banco_origen,
        estado,
        origen,
        comprobante_ruta,
        comprobante_hash,
        es_reversa,
        registrado_por,
        confirmado_por,
        confirmado_en
    ) VALUES (
        p_cargo_id,
        p_monto,
        v_cubierto,
        v_excedente,
        p_fecha_pago,
        p_metodo,
        p_referencia,
        p_banco_origen,
        v_estado_inicial,
        p_origen,
        p_comprobante_ruta,
        p_comprobante_hash,
        false,
        v_actor,
        CASE WHEN v_estado_inicial = 'Confirmado' THEN v_actor ELSE NULL END,
        CASE WHEN v_estado_inicial = 'Confirmado' THEN timezone('utc'::text, now()) ELSE NULL END
    ) RETURNING * INTO v_pago;

    -- Si fue confirmado y hay excedente, acreditar a saldo a favor
    IF v_estado_inicial = 'Confirmado' THEN
        IF v_excedente > 0 THEN
            INSERT INTO public.movimientos_saldo_favor (
                condominio_id, vivienda_id, tipo, monto, pago_id, cargo_id, motivo, creado_por
            ) VALUES (
                v_cargo.condominio_id, v_cargo.vivienda_id, 'Abono', v_excedente, v_pago.id, v_cargo.id,
                'Excedente acreditado automáticamente de pago confirmado', v_actor
            ) RETURNING * INTO v_mov_saldo;
        END IF;

        PERFORM public._recalcular_estado_cargo(p_cargo_id);
    END IF;

    SELECT saldo_a_favor INTO v_saldo_favor_actual 
    FROM public.v_saldo_vivienda 
    WHERE vivienda_id = v_cargo.vivienda_id;

    SELECT jsonb_build_object(
        'pago', to_jsonb(v_pago),
        'cargo', (SELECT to_jsonb(vc) FROM public.vw_cargos vc WHERE vc.id = p_cargo_id),
        'movimiento_saldo', CASE WHEN v_mov_saldo.id IS NOT NULL THEN to_jsonb(v_mov_saldo) ELSE NULL END,
        'saldo_a_favor', COALESCE(v_saldo_favor_actual, 0.00)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;


ALTER FUNCTION public.rpc_registrar_pago(p_cargo_id uuid, p_monto numeric, p_fecha_pago date, p_metodo text, p_origen text, p_estado text, p_referencia text, p_banco_origen text, p_comprobante_ruta text, p_comprobante_hash text, p_actor_id uuid) OWNER TO postgres;

--
-- Name: rpc_revertir_aplicacion_saldo(uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rpc_revertir_aplicacion_saldo(p_movimiento_id uuid, p_motivo text, p_actor_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_mov_orig RECORD;
    v_mov_reverso public.movimientos_saldo_favor%ROWTYPE;
    v_cargo RECORD;
    v_actor UUID;
    v_saldo_favor_final NUMERIC(12,2);
    v_resultado JSONB;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());

    IF NULLIF(TRIM(p_motivo), '') IS NULL THEN
        RAISE EXCEPTION 'El motivo de reversión es obligatorio' USING ERRCODE = 'PG009';
    END IF;

    SELECT * INTO v_mov_orig 
    FROM public.movimientos_saldo_favor 
    WHERE id = p_movimiento_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El movimiento especificado no existe' USING ERRCODE = 'PG000';
    END IF;

    IF v_mov_orig.tipo <> 'Aplicacion' THEN
        RAISE EXCEPTION 'Solo se pueden revertir movimientos de tipo Aplicacion' USING ERRCODE = 'PG009';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.movimientos_saldo_favor 
        WHERE movimiento_origen_id = p_movimiento_id AND tipo = 'ReversoAplicacion'
    ) THEN
        RAISE EXCEPTION 'El movimiento ya fue revertido con anterioridad' USING ERRCODE = 'PG009';
    END IF;

    SELECT * INTO v_cargo FROM public.cargos WHERE id = v_mov_orig.cargo_id FOR UPDATE;

    INSERT INTO public.movimientos_saldo_favor (
        condominio_id, vivienda_id, tipo, monto, cargo_id, movimiento_origen_id, motivo, creado_por
    ) VALUES (
        v_mov_orig.condominio_id, v_mov_orig.vivienda_id, 'ReversoAplicacion', v_mov_orig.monto,
        v_mov_orig.cargo_id, p_movimiento_id, TRIM(p_motivo), v_actor
    ) RETURNING * INTO v_mov_reverso;

    IF v_cargo.id IS NOT NULL THEN
        PERFORM public._recalcular_estado_cargo(v_cargo.id);
    END IF;

    SELECT saldo_a_favor INTO v_saldo_favor_final 
    FROM public.v_saldo_vivienda 
    WHERE vivienda_id = v_mov_orig.vivienda_id;

    SELECT jsonb_build_object(
        'movimiento', to_jsonb(v_mov_reverso),
        'cargo', CASE WHEN v_cargo.id IS NOT NULL THEN (SELECT to_jsonb(vc) FROM public.vw_cargos vc WHERE vc.id = v_cargo.id) ELSE NULL END,
        'saldo_a_favor', COALESCE(v_saldo_favor_final, 0.00)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;


ALTER FUNCTION public.rpc_revertir_aplicacion_saldo(p_movimiento_id uuid, p_motivo text, p_actor_id uuid) OWNER TO postgres;

--
-- Name: solicitar_reserva(uuid, uuid, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.solicitar_reserva(p_actor_id uuid, p_area_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone) RETURNS jsonb
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

--
-- Name: validar_codigo_visita(character varying, uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validar_codigo_visita(p_codigo character varying, p_actor_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_actor RECORD;
    v_visita RECORD;
BEGIN
    SELECT id, rol_id, condominio_id, activo INTO v_actor
    FROM public.usuarios
    WHERE id = p_actor_id;

    IF NOT FOUND OR NOT v_actor.activo OR v_actor.rol_id NOT IN (1, 3) THEN
        RAISE EXCEPTION 'No tienes permisos para validar códigos de visita.' USING ERRCODE = 'VI002';
    END IF;

    SELECT * INTO v_visita
    FROM public.visitas
    WHERE UPPER(TRIM(codigo_acceso)) = UPPER(TRIM(p_codigo));

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El código de acceso no existe.' USING ERRCODE = 'VI004';
    END IF;

    IF v_visita.condominio_id <> v_actor.condominio_id THEN
        RAISE EXCEPTION 'El actor no pertenece al mismo condominio de la visita.' USING ERRCODE = 'VI002';
    END IF;

    IF v_visita.estado = 'programada' AND now() > v_visita.fecha_expiracion THEN
        RAISE EXCEPTION 'El código de acceso ha expirado.' USING ERRCODE = 'VI005';
    END IF;

    RETURN public._proyectar_visita_dto(v_visita.id);
END;
$$;


ALTER FUNCTION public.validar_codigo_visita(p_codigo character varying, p_actor_id uuid) OWNER TO postgres;

--
-- Name: areas_comunes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.areas_comunes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condominio_id uuid NOT NULL,
    nombre text NOT NULL,
    descripcion text,
    hora_apertura time without time zone NOT NULL,
    hora_cierre time without time zone NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT chk_areas_horario CHECK ((hora_cierre > hora_apertura))
);


ALTER TABLE public.areas_comunes OWNER TO postgres;

--
-- Name: areas_comunes_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.areas_comunes_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.areas_comunes_bitacora OWNER TO postgres;

--
-- Name: areas_comunes_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.areas_comunes_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.areas_comunes_bitacora_id_seq OWNER TO postgres;

--
-- Name: areas_comunes_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.areas_comunes_bitacora_id_seq OWNED BY public.areas_comunes_bitacora.id;


--
-- Name: avisos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.avisos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condominio_id uuid NOT NULL,
    titulo character varying(150) NOT NULL,
    contenido text NOT NULL,
    prioridad character varying(20) DEFAULT 'normal'::character varying,
    duracion_dias integer,
    fecha_expiracion_manual timestamp with time zone,
    fecha_publicacion timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    creado_por uuid NOT NULL,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT avisos_duracion_dias_check CHECK (((duracion_dias IS NULL) OR (duracion_dias > 0))),
    CONSTRAINT chk_expiracion_aviso CHECK ((((duracion_dias IS NOT NULL) AND (fecha_expiracion_manual IS NULL)) OR ((duracion_dias IS NULL) AND (fecha_expiracion_manual IS NOT NULL))))
);


ALTER TABLE public.avisos OWNER TO postgres;

--
-- Name: avisos_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.avisos_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.avisos_bitacora OWNER TO postgres;

--
-- Name: avisos_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.avisos_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.avisos_bitacora_id_seq OWNER TO postgres;

--
-- Name: avisos_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.avisos_bitacora_id_seq OWNED BY public.avisos_bitacora.id;


--
-- Name: cargos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cargos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condominio_id uuid NOT NULL,
    vivienda_id integer NOT NULL,
    plantilla_id uuid,
    tipo character varying(20) NOT NULL,
    concepto character varying(200) NOT NULL,
    monto numeric(12,2) NOT NULL,
    periodo date,
    fecha_vencimiento date NOT NULL,
    estado character varying(20) DEFAULT 'Pendiente'::character varying NOT NULL,
    responsable_pago character varying(20) DEFAULT 'Residente'::character varying NOT NULL,
    motivo_cancelacion text,
    cancelado_por uuid,
    cancelado_en timestamp with time zone,
    creado_por uuid,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT cargos_estado_check CHECK (((estado)::text = ANY (ARRAY[('Pendiente'::character varying)::text, ('Parcial'::character varying)::text, ('Pagado'::character varying)::text, ('Cancelado'::character varying)::text]))),
    CONSTRAINT cargos_monto_check CHECK ((monto > (0)::numeric)),
    CONSTRAINT cargos_responsable_pago_check CHECK (((responsable_pago)::text = ANY (ARRAY[('Propietario'::character varying)::text, ('Residente'::character varying)::text]))),
    CONSTRAINT cargos_tipo_check CHECK (((tipo)::text = ANY (ARRAY[('Renta'::character varying)::text, ('Mantenimiento'::character varying)::text, ('Servicio'::character varying)::text, ('Multa'::character varying)::text, ('Otro'::character varying)::text]))),
    CONSTRAINT chk_cargo_periodo_mes CHECK (((periodo IS NULL) OR (periodo = (date_trunc('month'::text, (periodo)::timestamp with time zone))::date))),
    CONSTRAINT chk_cargo_periodo_requerido CHECK (((((tipo)::text = ANY (ARRAY[('Renta'::character varying)::text, ('Mantenimiento'::character varying)::text])) AND (periodo IS NOT NULL)) OR ((tipo)::text <> ALL (ARRAY[('Renta'::character varying)::text, ('Mantenimiento'::character varying)::text]))))
);


ALTER TABLE public.cargos OWNER TO postgres;

--
-- Name: cargos_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cargos_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.cargos_bitacora OWNER TO postgres;

--
-- Name: cargos_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cargos_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cargos_bitacora_id_seq OWNER TO postgres;

--
-- Name: cargos_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cargos_bitacora_id_seq OWNED BY public.cargos_bitacora.id;


--
-- Name: codigos_condominio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.codigos_condominio (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condominio_id uuid NOT NULL,
    codigo character varying(20) NOT NULL,
    expira_en timestamp with time zone NOT NULL,
    usado_por uuid,
    usado_en timestamp with time zone,
    creado_por uuid,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


ALTER TABLE public.codigos_condominio OWNER TO postgres;

--
-- Name: codigos_condominio_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.codigos_condominio_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.codigos_condominio_bitacora OWNER TO postgres;

--
-- Name: codigos_condominio_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.codigos_condominio_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.codigos_condominio_bitacora_id_seq OWNER TO postgres;

--
-- Name: codigos_condominio_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.codigos_condominio_bitacora_id_seq OWNED BY public.codigos_condominio_bitacora.id;


--
-- Name: codigos_vivienda; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.codigos_vivienda (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    vivienda_id integer NOT NULL,
    codigo character varying(20) NOT NULL,
    expira_en timestamp with time zone NOT NULL,
    usado_por uuid,
    usado_en timestamp with time zone,
    creado_por uuid,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


ALTER TABLE public.codigos_vivienda OWNER TO postgres;

--
-- Name: codigos_vivienda_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.codigos_vivienda_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.codigos_vivienda_bitacora OWNER TO postgres;

--
-- Name: codigos_vivienda_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.codigos_vivienda_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.codigos_vivienda_bitacora_id_seq OWNER TO postgres;

--
-- Name: codigos_vivienda_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.codigos_vivienda_bitacora_id_seq OWNED BY public.codigos_vivienda_bitacora.id;


--
-- Name: condominios_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.condominios_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.condominios_bitacora OWNER TO postgres;

--
-- Name: condominios_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.condominios_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.condominios_bitacora_id_seq OWNER TO postgres;

--
-- Name: condominios_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.condominios_bitacora_id_seq OWNED BY public.condominios_bitacora.id;


--
-- Name: invitaciones_subusuarios_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invitaciones_subusuarios_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.invitaciones_subusuarios_bitacora OWNER TO postgres;

--
-- Name: invitaciones_subusuarios_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.invitaciones_subusuarios_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invitaciones_subusuarios_bitacora_id_seq OWNER TO postgres;

--
-- Name: invitaciones_subusuarios_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.invitaciones_subusuarios_bitacora_id_seq OWNED BY public.invitaciones_subusuarios_bitacora.id;


--
-- Name: movimientos_saldo_favor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.movimientos_saldo_favor (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condominio_id uuid NOT NULL,
    vivienda_id integer NOT NULL,
    tipo character varying(25) NOT NULL,
    monto numeric(12,2) NOT NULL,
    pago_id uuid,
    cargo_id uuid,
    movimiento_origen_id uuid,
    motivo text,
    creado_por uuid,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT movimientos_saldo_favor_monto_check CHECK ((monto > (0)::numeric)),
    CONSTRAINT movimientos_saldo_favor_tipo_check CHECK (((tipo)::text = ANY (ARRAY[('Abono'::character varying)::text, ('Aplicacion'::character varying)::text, ('ReversoAbono'::character varying)::text, ('ReversoAplicacion'::character varying)::text])))
);


ALTER TABLE public.movimientos_saldo_favor OWNER TO postgres;

--
-- Name: movimientos_saldo_favor_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.movimientos_saldo_favor_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.movimientos_saldo_favor_bitacora OWNER TO postgres;

--
-- Name: movimientos_saldo_favor_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.movimientos_saldo_favor_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.movimientos_saldo_favor_bitacora_id_seq OWNER TO postgres;

--
-- Name: movimientos_saldo_favor_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.movimientos_saldo_favor_bitacora_id_seq OWNED BY public.movimientos_saldo_favor_bitacora.id;


--
-- Name: notificaciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notificaciones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    tipo_evento character varying(50) NOT NULL,
    titulo character varying(150) NOT NULL,
    mensaje text NOT NULL,
    url_redireccion text,
    leida boolean DEFAULT false NOT NULL,
    reserva_id uuid,
    push_enviado boolean DEFAULT false NOT NULL,
    push_reclamado_en timestamp with time zone,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


ALTER TABLE public.notificaciones OWNER TO postgres;

--
-- Name: notificaciones_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notificaciones_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.notificaciones_bitacora OWNER TO postgres;

--
-- Name: notificaciones_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notificaciones_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notificaciones_bitacora_id_seq OWNER TO postgres;

--
-- Name: notificaciones_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notificaciones_bitacora_id_seq OWNED BY public.notificaciones_bitacora.id;


--
-- Name: pagos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pagos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cargo_id uuid NOT NULL,
    monto numeric(12,2) NOT NULL,
    monto_cubierto numeric(12,2) DEFAULT 0.00 NOT NULL,
    monto_excedente numeric(12,2) DEFAULT 0.00 NOT NULL,
    fecha_pago date DEFAULT (timezone('America/Mexico_City'::text, now()))::date NOT NULL,
    metodo character varying(20) NOT NULL,
    referencia character varying(100),
    banco_origen character varying(100),
    estado character varying(30) NOT NULL,
    origen character varying(20) NOT NULL,
    comprobante_ruta text,
    comprobante_hash character varying(64),
    es_reversa boolean DEFAULT false NOT NULL,
    pago_original_id uuid,
    motivo_rechazo text,
    motivo_anulacion text,
    registrado_por uuid,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    confirmado_por uuid,
    confirmado_en timestamp with time zone,
    rechazado_por uuid,
    rechazado_en timestamp with time zone,
    anulado_por uuid,
    anulado_en timestamp with time zone,
    CONSTRAINT pagos_estado_check CHECK (((estado)::text = ANY (ARRAY[('PendienteConfirmacion'::character varying)::text, ('Confirmado'::character varying)::text, ('Rechazado'::character varying)::text, ('Anulado'::character varying)::text]))),
    CONSTRAINT pagos_metodo_check CHECK (((metodo)::text = ANY (ARRAY[('Efectivo'::character varying)::text, ('Transferencia'::character varying)::text, ('Deposito'::character varying)::text, ('Otro'::character varying)::text]))),
    CONSTRAINT pagos_monto_check CHECK ((monto > (0)::numeric)),
    CONSTRAINT pagos_origen_check CHECK (((origen)::text = ANY (ARRAY[('Admin'::character varying)::text, ('Inquilino'::character varying)::text])))
);


ALTER TABLE public.pagos OWNER TO postgres;

--
-- Name: pagos_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pagos_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.pagos_bitacora OWNER TO postgres;

--
-- Name: pagos_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pagos_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pagos_bitacora_id_seq OWNER TO postgres;

--
-- Name: pagos_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pagos_bitacora_id_seq OWNED BY public.pagos_bitacora.id;


--
-- Name: paquetes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.paquetes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condominio_id uuid NOT NULL,
    vivienda_id integer NOT NULL,
    servicio_id integer,
    servicio_nombre character varying(50),
    empresa_paqueteria character varying(50),
    destinatario_nombre character varying(100) NOT NULL,
    numero_guia character varying(100),
    descripcion character varying(250),
    notas text,
    fecha_esperada date,
    fecha_esperada_desde timestamp with time zone,
    fecha_esperada_hasta timestamp with time zone,
    estado character varying(20) DEFAULT 'esperado'::character varying NOT NULL,
    es_inesperado boolean DEFAULT false NOT NULL,
    ubicacion_almacen character varying(50),
    recibido_en timestamp with time zone,
    recibido_por uuid,
    entregado_en timestamp with time zone,
    entregado_por uuid,
    entregado_a uuid,
    entregado_a_nombre character varying(100),
    foto_url text,
    motivo_cancelacion text,
    creado_por uuid,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    actualizado_en timestamp with time zone DEFAULT timezone('utc'::text, now()),
    CONSTRAINT paquetes_estado_check CHECK (((estado)::text = ANY (ARRAY[('esperado'::character varying)::text, ('recibido'::character varying)::text, ('entregado'::character varying)::text, ('cancelado'::character varying)::text, ('vencido'::character varying)::text, ('devuelto'::character varying)::text, ('expirado'::character varying)::text])))
);


ALTER TABLE public.paquetes OWNER TO postgres;

--
-- Name: paquetes_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.paquetes_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.paquetes_bitacora OWNER TO postgres;

--
-- Name: paquetes_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.paquetes_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.paquetes_bitacora_id_seq OWNER TO postgres;

--
-- Name: paquetes_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.paquetes_bitacora_id_seq OWNED BY public.paquetes_bitacora.id;


--
-- Name: plantillas_cargo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.plantillas_cargo (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    condominio_id uuid NOT NULL,
    vivienda_id integer NOT NULL,
    tipo character varying(20) NOT NULL,
    concepto character varying(200) NOT NULL,
    monto numeric(12,2) NOT NULL,
    dia_vencimiento integer NOT NULL,
    vigencia_inicio date NOT NULL,
    vigencia_fin date,
    responsable_pago character varying(20) DEFAULT 'Residente'::character varying NOT NULL,
    activa boolean DEFAULT true NOT NULL,
    creado_por uuid,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    modificado_por uuid,
    modificado_en timestamp with time zone,
    CONSTRAINT chk_plantilla_vigencia CHECK (((vigencia_fin IS NULL) OR (vigencia_fin >= vigencia_inicio))),
    CONSTRAINT plantillas_cargo_dia_vencimiento_check CHECK (((dia_vencimiento >= 1) AND (dia_vencimiento <= 31))),
    CONSTRAINT plantillas_cargo_monto_check CHECK ((monto > (0)::numeric)),
    CONSTRAINT plantillas_cargo_responsable_pago_check CHECK (((responsable_pago)::text = ANY (ARRAY[('Propietario'::character varying)::text, ('Residente'::character varying)::text]))),
    CONSTRAINT plantillas_cargo_tipo_check CHECK (((tipo)::text = ANY (ARRAY[('Renta'::character varying)::text, ('Mantenimiento'::character varying)::text, ('Servicio'::character varying)::text, ('Multa'::character varying)::text, ('Otro'::character varying)::text])))
);


ALTER TABLE public.plantillas_cargo OWNER TO postgres;

--
-- Name: plantillas_cargo_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.plantillas_cargo_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.plantillas_cargo_bitacora OWNER TO postgres;

--
-- Name: plantillas_cargo_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.plantillas_cargo_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plantillas_cargo_bitacora_id_seq OWNER TO postgres;

--
-- Name: plantillas_cargo_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.plantillas_cargo_bitacora_id_seq OWNED BY public.plantillas_cargo_bitacora.id;


--
-- Name: reservas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reservas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    area_id uuid NOT NULL,
    condominio_id uuid NOT NULL,
    titular_id uuid,
    vivienda_id integer,
    solicitante_id uuid NOT NULL,
    aprobador_id uuid,
    tipo character varying(15) NOT NULL,
    inicio timestamp with time zone NOT NULL,
    fin timestamp with time zone NOT NULL,
    estado character varying(25) NOT NULL,
    motivo text,
    confirmada_en timestamp with time zone,
    recordatorio_24h_enviado boolean DEFAULT false NOT NULL,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    actualizado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT chk_reservas_duracion CHECK ((((tipo)::text = 'BLOQUEO'::text) OR ((fin - inicio) <= '12:00:00'::interval))),
    CONSTRAINT chk_reservas_fechas CHECK ((fin > inicio)),
    CONSTRAINT chk_reservas_tipo_campos CHECK (((((tipo)::text = 'RESERVA'::text) AND (titular_id IS NOT NULL) AND (vivienda_id IS NOT NULL)) OR (((tipo)::text = 'BLOQUEO'::text) AND (titular_id IS NULL) AND (vivienda_id IS NULL) AND (motivo IS NOT NULL) AND (length(TRIM(BOTH FROM motivo)) > 0)))),
    CONSTRAINT reservas_estado_check CHECK (((estado)::text = ANY (ARRAY[('PENDIENTE_TITULAR'::character varying)::text, ('PENDIENTE_ADMIN'::character varying)::text, ('APROBADA'::character varying)::text, ('CONFIRMADA'::character varying)::text, ('RECHAZADA_TITULAR'::character varying)::text, ('RECHAZADA_ADMIN'::character varying)::text, ('CANCELADA_USUARIO'::character varying)::text, ('CANCELADA_ADMIN'::character varying)::text, ('CANCELADA_EXPIRACION'::character varying)::text, ('FINALIZADA'::character varying)::text, ('NO_UTILIZADA'::character varying)::text]))),
    CONSTRAINT reservas_tipo_check CHECK (((tipo)::text = ANY (ARRAY[('RESERVA'::character varying)::text, ('BLOQUEO'::character varying)::text])))
);


ALTER TABLE public.reservas OWNER TO postgres;

--
-- Name: reservas_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reservas_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.reservas_bitacora OWNER TO postgres;

--
-- Name: reservas_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.reservas_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.reservas_bitacora_id_seq OWNER TO postgres;

--
-- Name: reservas_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.reservas_bitacora_id_seq OWNED BY public.reservas_bitacora.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    nombre text NOT NULL,
    descripcion text
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- Name: roles_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.roles_bitacora OWNER TO postgres;

--
-- Name: roles_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.roles_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.roles_bitacora_id_seq OWNER TO postgres;

--
-- Name: roles_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.roles_bitacora_id_seq OWNED BY public.roles_bitacora.id;


--
-- Name: servicios_paqueteria; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.servicios_paqueteria (
    id integer NOT NULL,
    condominio_id uuid,
    nombre character varying(50) NOT NULL,
    icono_url text,
    es_sistema boolean DEFAULT false NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    creado_por uuid,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


ALTER TABLE public.servicios_paqueteria OWNER TO postgres;

--
-- Name: servicios_paqueteria_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.servicios_paqueteria_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.servicios_paqueteria_bitacora OWNER TO postgres;

--
-- Name: servicios_paqueteria_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.servicios_paqueteria_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.servicios_paqueteria_bitacora_id_seq OWNER TO postgres;

--
-- Name: servicios_paqueteria_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.servicios_paqueteria_bitacora_id_seq OWNED BY public.servicios_paqueteria_bitacora.id;


--
-- Name: servicios_paqueteria_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.servicios_paqueteria_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.servicios_paqueteria_id_seq OWNER TO postgres;

--
-- Name: servicios_paqueteria_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.servicios_paqueteria_id_seq OWNED BY public.servicios_paqueteria.id;


--
-- Name: usuarios_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.usuarios_bitacora OWNER TO postgres;

--
-- Name: usuarios_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuarios_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usuarios_bitacora_id_seq OWNER TO postgres;

--
-- Name: usuarios_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuarios_bitacora_id_seq OWNED BY public.usuarios_bitacora.id;


--
-- Name: vw_cargos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_cargos AS
 SELECT c.id,
    c.condominio_id,
    co.nombre AS condominio_nombre,
    c.vivienda_id,
    v.numero_casa,
    c.plantilla_id,
    c.periodo,
    c.tipo,
    c.concepto,
    c.monto,
    ((COALESCE(pagos_agg.monto_pagado, 0.00) + COALESCE(saldo_agg.saldo_aplicado, 0.00)))::numeric(12,2) AS monto_pagado_confirmado,
        CASE
            WHEN ((c.estado)::text = 'Cancelado'::text) THEN 0.00
            ELSE (GREATEST((c.monto - (COALESCE(pagos_agg.monto_pagado, 0.00) + COALESCE(saldo_agg.saldo_aplicado, 0.00))), 0.00))::numeric(12,2)
        END AS saldo_pendiente,
    c.estado,
    c.fecha_vencimiento,
    ((c.fecha_vencimiento < (timezone('America/Mexico_City'::text, now()))::date) AND ((c.estado)::text = ANY (ARRAY[('Pendiente'::character varying)::text, ('Parcial'::character varying)::text]))) AS esta_vencido,
    c.responsable_pago,
    c.motivo_cancelacion,
    c.cancelado_por,
    c.cancelado_en,
    c.creado_por,
    c.creado_en
   FROM ((((public.cargos c
     JOIN public.condominios co ON ((co.id = c.condominio_id)))
     JOIN public.viviendas v ON ((v.id = c.vivienda_id)))
     LEFT JOIN ( SELECT pagos.cargo_id,
            sum(pagos.monto_cubierto) AS monto_pagado
           FROM public.pagos
          WHERE (((pagos.estado)::text = 'Confirmado'::text) AND (pagos.es_reversa = false))
          GROUP BY pagos.cargo_id) pagos_agg ON ((pagos_agg.cargo_id = c.id)))
     LEFT JOIN ( SELECT movimientos_saldo_favor.cargo_id,
            sum(
                CASE
                    WHEN ((movimientos_saldo_favor.tipo)::text = 'Aplicacion'::text) THEN movimientos_saldo_favor.monto
                    WHEN ((movimientos_saldo_favor.tipo)::text = 'ReversoAplicacion'::text) THEN (- movimientos_saldo_favor.monto)
                    ELSE 0.00
                END) AS saldo_aplicado
           FROM public.movimientos_saldo_favor
          WHERE (movimientos_saldo_favor.cargo_id IS NOT NULL)
          GROUP BY movimientos_saldo_favor.cargo_id) saldo_agg ON ((saldo_agg.cargo_id = c.id)));


ALTER VIEW public.vw_cargos OWNER TO postgres;

--
-- Name: v_saldo_vivienda; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_saldo_vivienda AS
 SELECT v.id AS vivienda_id,
    v.condominio_id,
    v.numero_casa,
    (COALESCE(sum(c.saldo_pendiente) FILTER (WHERE ((c.estado)::text = ANY (ARRAY[('Pendiente'::character varying)::text, ('Parcial'::character varying)::text]))), 0.00))::numeric(12,2) AS total_pendiente,
    (COALESCE(sum(c.saldo_pendiente) FILTER (WHERE (((c.estado)::text = ANY (ARRAY[('Pendiente'::character varying)::text, ('Parcial'::character varying)::text])) AND (c.esta_vencido = true))), 0.00))::numeric(12,2) AS total_vencido,
    (count(c.id) FILTER (WHERE ((c.estado)::text = ANY (ARRAY[('Pendiente'::character varying)::text, ('Parcial'::character varying)::text]))))::integer AS total_cargos_abiertos,
    (COALESCE(( SELECT sum(
                CASE
                    WHEN ((ms.tipo)::text = ANY (ARRAY[('Abono'::character varying)::text, ('ReversoAplicacion'::character varying)::text])) THEN ms.monto
                    ELSE (- ms.monto)
                END) AS sum
           FROM public.movimientos_saldo_favor ms
          WHERE (ms.vivienda_id = v.id)), 0.00))::numeric(12,2) AS saldo_a_favor
   FROM (public.viviendas v
     LEFT JOIN public.vw_cargos c ON ((c.vivienda_id = v.id)))
  WHERE (v.activo = true)
  GROUP BY v.id, v.condominio_id, v.numero_casa;


ALTER VIEW public.v_saldo_vivienda OWNER TO postgres;

--
-- Name: version; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.version (
    id integer NOT NULL,
    numero_version text NOT NULL,
    descripcion text,
    aplicado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


ALTER TABLE public.version OWNER TO postgres;

--
-- Name: version_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.version_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.version_bitacora OWNER TO postgres;

--
-- Name: version_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.version_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.version_bitacora_id_seq OWNER TO postgres;

--
-- Name: version_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.version_bitacora_id_seq OWNED BY public.version_bitacora.id;


--
-- Name: version_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.version_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.version_id_seq OWNER TO postgres;

--
-- Name: version_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.version_id_seq OWNED BY public.version.id;


--
-- Name: visitas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.visitas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    vivienda_id integer NOT NULL,
    condominio_id uuid NOT NULL,
    nombre_visitante character varying(100) NOT NULL,
    apellidos_visitante character varying(100) NOT NULL,
    telefono_visitante character varying(20),
    motivo character varying(30) NOT NULL,
    num_acompanantes integer DEFAULT 0 NOT NULL,
    vehiculo_placas character varying(15),
    notas text,
    fecha_llegada_esperada timestamp with time zone NOT NULL,
    fecha_expiracion timestamp with time zone NOT NULL,
    codigo_acceso character varying(10) NOT NULL,
    estado character varying(20) DEFAULT 'programada'::character varying NOT NULL,
    hora_entrada timestamp with time zone,
    hora_salida timestamp with time zone,
    registrado_entrada_por uuid,
    registrado_salida_por uuid,
    creado_por uuid NOT NULL,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT chk_visitas_fechas CHECK ((fecha_expiracion > fecha_llegada_esperada)),
    CONSTRAINT visitas_estado_check CHECK (((estado)::text = ANY (ARRAY[('programada'::character varying)::text, ('en_curso'::character varying)::text, ('finalizada'::character varying)::text, ('cancelada'::character varying)::text]))),
    CONSTRAINT visitas_motivo_check CHECK (((motivo)::text = ANY (ARRAY[('personal'::character varying)::text, ('familiar'::character varying)::text, ('proveedor'::character varying)::text, ('paqueteria'::character varying)::text, ('servicio'::character varying)::text]))),
    CONSTRAINT visitas_num_acompanantes_check CHECK (((num_acompanantes >= 0) AND (num_acompanantes <= 20)))
);


ALTER TABLE public.visitas OWNER TO postgres;

--
-- Name: visitas_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.visitas_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.visitas_bitacora OWNER TO postgres;

--
-- Name: visitas_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.visitas_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.visitas_bitacora_id_seq OWNER TO postgres;

--
-- Name: visitas_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.visitas_bitacora_id_seq OWNED BY public.visitas_bitacora.id;


--
-- Name: vivienda_residente; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vivienda_residente (
    id integer NOT NULL,
    vivienda_id integer NOT NULL,
    usuario_id uuid NOT NULL,
    es_propietario boolean DEFAULT true NOT NULL,
    fecha_ingreso timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


ALTER TABLE public.vivienda_residente OWNER TO postgres;

--
-- Name: vivienda_residente_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vivienda_residente_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.vivienda_residente_bitacora OWNER TO postgres;

--
-- Name: vivienda_residente_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vivienda_residente_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vivienda_residente_bitacora_id_seq OWNER TO postgres;

--
-- Name: vivienda_residente_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vivienda_residente_bitacora_id_seq OWNED BY public.vivienda_residente_bitacora.id;


--
-- Name: vivienda_residente_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vivienda_residente_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vivienda_residente_id_seq OWNER TO postgres;

--
-- Name: vivienda_residente_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vivienda_residente_id_seq OWNED BY public.vivienda_residente.id;


--
-- Name: vivienda_subusuarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vivienda_subusuarios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    vivienda_id integer NOT NULL,
    usuario_id uuid NOT NULL,
    titular_id uuid,
    parentesco character varying(50) DEFAULT 'Familiar'::character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    actualizado_en timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


ALTER TABLE public.vivienda_subusuarios OWNER TO postgres;

--
-- Name: vivienda_subusuarios_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vivienda_subusuarios_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.vivienda_subusuarios_bitacora OWNER TO postgres;

--
-- Name: vivienda_subusuarios_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vivienda_subusuarios_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vivienda_subusuarios_bitacora_id_seq OWNER TO postgres;

--
-- Name: vivienda_subusuarios_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vivienda_subusuarios_bitacora_id_seq OWNED BY public.vivienda_subusuarios_bitacora.id;


--
-- Name: viviendas_bitacora; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.viviendas_bitacora (
    id bigint NOT NULL,
    operacion character varying(10) NOT NULL,
    fecha_hora timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    usuario_bd text DEFAULT CURRENT_USER,
    usuario_id uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb
);


ALTER TABLE public.viviendas_bitacora OWNER TO postgres;

--
-- Name: viviendas_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.viviendas_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.viviendas_bitacora_id_seq OWNER TO postgres;

--
-- Name: viviendas_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.viviendas_bitacora_id_seq OWNED BY public.viviendas_bitacora.id;


--
-- Name: viviendas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.viviendas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.viviendas_id_seq OWNER TO postgres;

--
-- Name: viviendas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.viviendas_id_seq OWNED BY public.viviendas.id;


--
-- Name: vw_areas_comunes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_areas_comunes WITH (security_invoker='true') AS
 SELECT a.id,
    a.condominio_id,
    c.nombre AS condominio_nombre,
    c.zona_horaria,
    a.nombre,
    a.descripcion,
    a.hora_apertura,
    a.hora_cierre,
    a.activo,
    a.creado_en
   FROM (public.areas_comunes a
     JOIN public.condominios c ON ((c.id = a.condominio_id)))
  WHERE (c.activo = true);


ALTER VIEW public.vw_areas_comunes OWNER TO postgres;

--
-- Name: vw_avisos_historico; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_avisos_historico WITH (security_invoker='true') AS
 SELECT a.id,
    a.condominio_id,
    c.nombre AS condominio_nombre,
    a.titulo,
    a.contenido,
    COALESCE(a.prioridad, 'normal'::character varying) AS prioridad,
    a.duracion_dias,
    a.fecha_expiracion_manual,
    a.fecha_publicacion,
    COALESCE(a.fecha_expiracion_manual, (a.fecha_publicacion + ((a.duracion_dias || ' days'::text))::interval)) AS fecha_expiracion,
    a.activo,
    a.creado_por,
    TRIM(BOTH FROM ((u.nombre || ' '::text) || u.apellidos)) AS creado_por_nombre,
    a.creado_en,
        CASE
            WHEN (a.activo = false) THEN 'ELIMINADO'::text
            WHEN (timezone('utc'::text, now()) >= COALESCE(a.fecha_expiracion_manual, (a.fecha_publicacion + ((a.duracion_dias || ' days'::text))::interval))) THEN 'EXPIRADO'::text
            ELSE 'VIGENTE'::text
        END AS estado
   FROM ((public.avisos a
     JOIN public.condominios c ON ((a.condominio_id = c.id)))
     JOIN public.usuarios u ON ((a.creado_por = u.id)));


ALTER VIEW public.vw_avisos_historico OWNER TO postgres;

--
-- Name: vw_avisos_vigentes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_avisos_vigentes WITH (security_invoker='true') AS
 SELECT a.id,
    a.condominio_id,
    c.nombre AS condominio_nombre,
    a.titulo,
    a.contenido,
    COALESCE(a.prioridad, 'normal'::character varying) AS prioridad,
    a.duracion_dias,
    a.fecha_expiracion_manual,
    a.fecha_publicacion,
    COALESCE(a.fecha_expiracion_manual, (a.fecha_publicacion + ((a.duracion_dias || ' days'::text))::interval)) AS fecha_expiracion,
    a.activo,
    a.creado_por,
    TRIM(BOTH FROM ((u.nombre || ' '::text) || u.apellidos)) AS creado_por_nombre,
    a.creado_en,
    'VIGENTE'::text AS estado
   FROM ((public.avisos a
     JOIN public.condominios c ON ((a.condominio_id = c.id)))
     JOIN public.usuarios u ON ((a.creado_por = u.id)))
  WHERE ((a.activo = true) AND (c.activo = true) AND (timezone('utc'::text, now()) < COALESCE(a.fecha_expiracion_manual, (a.fecha_publicacion + ((a.duracion_dias || ' days'::text))::interval))));


ALTER VIEW public.vw_avisos_vigentes OWNER TO postgres;

--
-- Name: vw_calendario_reservas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_calendario_reservas WITH (security_invoker='true') AS
 SELECT r.id,
    r.area_id,
    a.nombre AS area_nombre,
    r.condominio_id,
    r.inicio,
    r.fin,
    r.tipo,
    r.estado,
        CASE
            WHEN ((r.tipo)::text = 'BLOQUEO'::text) THEN NULL::text
            ELSE ut.nombre
        END AS titular_nombre,
        CASE
            WHEN ((r.tipo)::text = 'BLOQUEO'::text) THEN NULL::text
            ELSE ut.apellidos
        END AS titular_apellidos,
        CASE
            WHEN ((r.tipo)::text = 'BLOQUEO'::text) THEN NULL::text
            ELSE v.numero_casa
        END AS numero_casa,
        CASE
            WHEN ((r.tipo)::text = 'BLOQUEO'::text) THEN r.motivo
            ELSE NULL::text
        END AS motivo
   FROM (((public.reservas r
     JOIN public.areas_comunes a ON ((a.id = r.area_id)))
     LEFT JOIN public.usuarios ut ON ((ut.id = r.titular_id)))
     LEFT JOIN public.viviendas v ON ((v.id = r.vivienda_id)))
  WHERE ((r.estado)::text = 'CONFIRMADA'::text);


ALTER VIEW public.vw_calendario_reservas OWNER TO postgres;

--
-- Name: vw_calendario_reservas_limitado; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_calendario_reservas_limitado WITH (security_invoker='true') AS
 SELECT r.id,
    r.area_id,
    a.nombre AS area_nombre,
    r.condominio_id,
    r.inicio,
    r.fin,
    r.tipo,
    r.estado
   FROM (public.reservas r
     JOIN public.areas_comunes a ON ((a.id = r.area_id)))
  WHERE ((r.estado)::text = 'CONFIRMADA'::text);


ALTER VIEW public.vw_calendario_reservas_limitado OWNER TO postgres;

--
-- Name: vw_condominios; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_condominios WITH (security_invoker='true') AS
 SELECT id,
    nombre,
    direccion,
    zona_horaria,
    activo,
    creado_en
   FROM public.condominios
  WHERE (activo = true);


ALTER VIEW public.vw_condominios OWNER TO postgres;

--
-- Name: vw_mis_paquetes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_mis_paquetes WITH (security_invoker='true') AS
 SELECT p.id,
    p.condominio_id,
    c.nombre AS condominio_nombre,
    p.vivienda_id,
    v.numero_casa,
    p.servicio_id,
    COALESCE(p.servicio_nombre, sp.nombre, p.empresa_paqueteria) AS servicio_nombre,
    p.destinatario_nombre,
    p.numero_guia,
    p.descripcion,
    p.notas,
    p.fecha_esperada_desde,
    p.fecha_esperada_hasta,
        CASE
            WHEN (((p.estado)::text = 'esperado'::text) AND (p.fecha_esperada_hasta IS NOT NULL) AND (now() > p.fecha_esperada_hasta)) THEN 'vencido'::character varying
            ELSE p.estado
        END AS estado,
    p.es_inesperado,
    p.ubicacion_almacen,
    p.recibido_en,
    TRIM(BOTH FROM ((ur.nombre || ' '::text) || ur.apellidos)) AS recibido_por_nombre,
    p.entregado_en,
    COALESCE(p.entregado_a_nombre, (TRIM(BOTH FROM ((ua.nombre || ' '::text) || ua.apellidos)))::character varying) AS entregado_a_nombre,
    TRIM(BOTH FROM ((ue.nombre || ' '::text) || ue.apellidos)) AS entregado_por_nombre,
    p.creado_por,
    p.creado_en
   FROM ((((((public.paquetes p
     JOIN public.condominios c ON ((p.condominio_id = c.id)))
     JOIN public.viviendas v ON ((p.vivienda_id = v.id)))
     LEFT JOIN public.servicios_paqueteria sp ON ((p.servicio_id = sp.id)))
     LEFT JOIN public.usuarios ur ON ((p.recibido_por = ur.id)))
     LEFT JOIN public.usuarios ue ON ((p.entregado_por = ue.id)))
     LEFT JOIN public.usuarios ua ON ((p.entregado_a = ua.id)));


ALTER VIEW public.vw_mis_paquetes OWNER TO postgres;

--
-- Name: vw_mis_visitas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_mis_visitas WITH (security_invoker='true') AS
 SELECT vi.id,
    vi.vivienda_id,
    v.numero_casa,
    vi.condominio_id,
    vi.nombre_visitante,
    vi.apellidos_visitante,
    vi.telefono_visitante,
    vi.motivo,
    vi.num_acompanantes,
    vi.vehiculo_placas,
    vi.notas,
    vi.fecha_llegada_esperada,
    vi.fecha_expiracion,
    vi.codigo_acceso,
        CASE
            WHEN (((vi.estado)::text = 'programada'::text) AND (now() > vi.fecha_expiracion)) THEN 'expirada'::character varying
            ELSE vi.estado
        END AS estado,
        CASE
            WHEN (((vi.estado)::text = 'programada'::text) AND (now() > vi.fecha_expiracion)) THEN 'expirada'::character varying
            ELSE vi.estado
        END AS estado_calculado,
    vi.hora_entrada,
    vi.hora_salida,
    vi.creado_por,
    TRIM(BOTH FROM ((u.nombre || ' '::text) || u.apellidos)) AS creado_por_nombre,
    vi.creado_en
   FROM ((public.visitas vi
     JOIN public.viviendas v ON ((vi.vivienda_id = v.id)))
     JOIN public.usuarios u ON ((vi.creado_por = u.id)));


ALTER VIEW public.vw_mis_visitas OWNER TO postgres;

--
-- Name: vw_mis_viviendas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_mis_viviendas WITH (security_invoker='true') AS
 SELECT DISTINCT v.id AS vivienda_id,
    v.numero_casa,
    v.tipo,
    v.activo,
    v.creado_en
   FROM (public.viviendas v
     JOIN public.condominios c ON ((v.condominio_id = c.id)))
  WHERE ((v.activo = true) AND (c.activo = true) AND ((EXISTS ( SELECT 1
           FROM public.vivienda_residente vr
          WHERE ((vr.vivienda_id = v.id) AND (vr.usuario_id = auth.uid())))) OR (EXISTS ( SELECT 1
           FROM public.vivienda_subusuarios vs
          WHERE ((vs.vivienda_id = v.id) AND (vs.usuario_id = auth.uid()) AND (vs.activo = true))))));


ALTER VIEW public.vw_mis_viviendas OWNER TO postgres;

--
-- Name: vw_movimientos_saldo_favor; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_movimientos_saldo_favor AS
 SELECT id,
    condominio_id,
    vivienda_id,
    tipo,
    monto,
        CASE
            WHEN ((tipo)::text = ANY (ARRAY[('Abono'::character varying)::text, ('ReversoAplicacion'::character varying)::text])) THEN monto
            ELSE (- monto)
        END AS monto_con_signo,
    pago_id,
    cargo_id,
    movimiento_origen_id,
    motivo,
    creado_por,
    creado_en
   FROM public.movimientos_saldo_favor m;


ALTER VIEW public.vw_movimientos_saldo_favor OWNER TO postgres;

--
-- Name: vw_no_shows; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_no_shows WITH (security_invoker='true') AS
 SELECT r.id,
    r.area_id,
    a.nombre AS area_nombre,
    r.condominio_id,
    r.inicio,
    r.fin,
    r.titular_id,
    ut.nombre AS titular_nombre,
    ut.apellidos AS titular_apellidos,
    r.vivienda_id,
    v.numero_casa,
    r.solicitante_id,
    us.nombre AS solicitante_nombre,
    us.apellidos AS solicitante_apellidos,
    r.creado_en
   FROM ((((public.reservas r
     JOIN public.areas_comunes a ON ((a.id = r.area_id)))
     JOIN public.usuarios ut ON ((ut.id = r.titular_id)))
     JOIN public.viviendas v ON ((v.id = r.vivienda_id)))
     JOIN public.usuarios us ON ((us.id = r.solicitante_id)))
  WHERE ((r.estado)::text = 'NO_UTILIZADA'::text);


ALTER VIEW public.vw_no_shows OWNER TO postgres;

--
-- Name: vw_notificaciones; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_notificaciones WITH (security_invoker='true') AS
 SELECT n.id,
    n.usuario_id,
    TRIM(BOTH FROM ((u.nombre || ' '::text) || u.apellidos)) AS usuario_nombre,
    u.email AS usuario_email,
    n.tipo_evento,
    n.titulo,
    n.mensaje,
    n.url_redireccion,
    n.leida,
    n.creado_en
   FROM (public.notificaciones n
     JOIN public.usuarios u ON ((n.usuario_id = u.id)));


ALTER VIEW public.vw_notificaciones OWNER TO postgres;

--
-- Name: vw_pagos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_pagos AS
 SELECT p.id,
    p.cargo_id,
    c.condominio_id,
    c.vivienda_id,
    v.numero_casa,
    c.tipo AS cargo_tipo,
    c.concepto AS cargo_concepto,
    p.monto,
    p.monto_cubierto,
    p.monto_excedente,
    p.fecha_pago,
    p.metodo,
    p.referencia,
    p.banco_origen,
    p.estado,
    p.origen,
    ((p.comprobante_ruta IS NOT NULL) AND (TRIM(BOTH FROM p.comprobante_ruta) <> ''::text)) AS tiene_comprobante,
    p.comprobante_ruta,
    p.comprobante_hash,
    p.es_reversa,
    p.pago_original_id,
    p.motivo_rechazo,
    p.motivo_anulacion,
    p.registrado_por,
    p.creado_en,
    p.confirmado_por,
    p.confirmado_en,
    p.rechazado_por,
    p.rechazado_en,
    p.anulado_por,
    p.anulado_en
   FROM ((public.pagos p
     JOIN public.cargos c ON ((c.id = p.cargo_id)))
     JOIN public.viviendas v ON ((v.id = c.vivienda_id)));


ALTER VIEW public.vw_pagos OWNER TO postgres;

--
-- Name: vw_paquetes_caseta; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_paquetes_caseta WITH (security_invoker='true') AS
 SELECT p.id,
    p.condominio_id,
    p.vivienda_id,
    v.numero_casa,
    p.servicio_id,
    COALESCE(p.servicio_nombre, sp.nombre, p.empresa_paqueteria) AS servicio_nombre,
    COALESCE(p.empresa_paqueteria, p.servicio_nombre, sp.nombre) AS empresa_paqueteria,
    p.destinatario_nombre,
    p.numero_guia,
    p.descripcion,
    p.notas,
    p.fecha_esperada,
    p.fecha_esperada_desde,
    p.fecha_esperada_hasta,
        CASE
            WHEN (((p.estado)::text = 'esperado'::text) AND (p.fecha_esperada_hasta IS NOT NULL) AND (now() > p.fecha_esperada_hasta)) THEN 'vencido'::character varying
            ELSE p.estado
        END AS estado,
    p.es_inesperado,
    p.ubicacion_almacen,
    p.recibido_en,
    TRIM(BOTH FROM ((ur.nombre || ' '::text) || ur.apellidos)) AS recibido_por_nombre,
    p.entregado_en,
    COALESCE(p.entregado_a_nombre, (TRIM(BOTH FROM ((ua.nombre || ' '::text) || ua.apellidos)))::character varying) AS entregado_a_nombre,
    p.foto_url,
    p.creado_por,
    COALESCE(TRIM(BOTH FROM ((uc.nombre || ' '::text) || uc.apellidos)), 'Caseta / Vigilancia'::text) AS creado_por_nombre,
    p.creado_en
   FROM (((((public.paquetes p
     JOIN public.viviendas v ON ((p.vivienda_id = v.id)))
     LEFT JOIN public.servicios_paqueteria sp ON ((p.servicio_id = sp.id)))
     LEFT JOIN public.usuarios uc ON ((p.creado_por = uc.id)))
     LEFT JOIN public.usuarios ur ON ((p.recibido_por = ur.id)))
     LEFT JOIN public.usuarios ua ON ((p.entregado_a = ua.id)));


ALTER VIEW public.vw_paquetes_caseta OWNER TO postgres;

--
-- Name: vw_paquetes_historico; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_paquetes_historico WITH (security_invoker='true') AS
 SELECT p.id,
    p.condominio_id,
    c.nombre AS condominio_nombre,
    p.vivienda_id,
    v.numero_casa,
    p.servicio_id,
    COALESCE(p.servicio_nombre, sp.nombre, p.empresa_paqueteria) AS servicio_nombre,
    p.destinatario_nombre,
    p.numero_guia,
    p.descripcion,
    p.notas,
    p.fecha_esperada_desde,
    p.fecha_esperada_hasta,
        CASE
            WHEN (((p.estado)::text = 'esperado'::text) AND (p.fecha_esperada_hasta IS NOT NULL) AND (now() > p.fecha_esperada_hasta)) THEN 'vencido'::character varying
            ELSE p.estado
        END AS estado,
    p.es_inesperado,
    p.ubicacion_almacen,
    p.recibido_en,
    p.recibido_por,
    TRIM(BOTH FROM ((ur.nombre || ' '::text) || ur.apellidos)) AS recibido_por_nombre,
    p.entregado_en,
    COALESCE(p.entregado_a_nombre, (TRIM(BOTH FROM ((ua.nombre || ' '::text) || ua.apellidos)))::character varying) AS entregado_a_nombre,
    p.entregado_por,
    TRIM(BOTH FROM ((ue.nombre || ' '::text) || ue.apellidos)) AS entregado_por_nombre,
    p.creado_por,
    COALESCE(TRIM(BOTH FROM ((uc.nombre || ' '::text) || uc.apellidos)), 'Caseta / Vigilancia'::text) AS creado_por_nombre,
    p.creado_en,
    p.actualizado_en
   FROM (((((((public.paquetes p
     JOIN public.condominios c ON ((p.condominio_id = c.id)))
     JOIN public.viviendas v ON ((p.vivienda_id = v.id)))
     LEFT JOIN public.servicios_paqueteria sp ON ((p.servicio_id = sp.id)))
     LEFT JOIN public.usuarios uc ON ((p.creado_por = uc.id)))
     LEFT JOIN public.usuarios ur ON ((p.recibido_por = ur.id)))
     LEFT JOIN public.usuarios ue ON ((p.entregado_por = ue.id)))
     LEFT JOIN public.usuarios ua ON ((p.entregado_a = ua.id)));


ALTER VIEW public.vw_paquetes_historico OWNER TO postgres;

--
-- Name: vw_paquetes_residente; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_paquetes_residente WITH (security_invoker='true') AS
 SELECT p.id,
    p.vivienda_id,
    v.numero_casa,
    p.destinatario_nombre,
    COALESCE(p.empresa_paqueteria, p.servicio_nombre, sp.nombre) AS empresa_paqueteria,
    p.numero_guia,
    p.descripcion,
    p.fecha_esperada,
    p.estado,
    p.recibido_en,
    p.entregado_en,
    COALESCE(TRIM(BOTH FROM ((ua.nombre || ' '::text) || ua.apellidos)), (p.entregado_a_nombre)::text) AS entregado_a_nombre,
    p.foto_url,
    p.creado_por,
    TRIM(BOTH FROM ((uc.nombre || ' '::text) || uc.apellidos)) AS creado_por_nombre,
    p.creado_en
   FROM ((((public.paquetes p
     JOIN public.viviendas v ON ((p.vivienda_id = v.id)))
     LEFT JOIN public.servicios_paqueteria sp ON ((p.servicio_id = sp.id)))
     LEFT JOIN public.usuarios uc ON ((p.creado_por = uc.id)))
     LEFT JOIN public.usuarios ua ON ((p.entregado_a = ua.id)));


ALTER VIEW public.vw_paquetes_residente OWNER TO postgres;

--
-- Name: vw_plantillas_cargo; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_plantillas_cargo AS
 SELECT pc.id,
    pc.condominio_id,
    co.nombre AS condominio_nombre,
    pc.vivienda_id,
    v.numero_casa,
    pc.tipo,
    pc.concepto,
    pc.monto,
    pc.monto AS monto_base,
    pc.dia_vencimiento,
    pc.vigencia_inicio,
    pc.vigencia_fin,
    pc.responsable_pago,
    pc.activa,
    pc.creado_por,
    pc.creado_en,
    pc.modificado_por,
    pc.modificado_en
   FROM ((public.plantillas_cargo pc
     JOIN public.condominios co ON ((co.id = pc.condominio_id)))
     JOIN public.viviendas v ON ((v.id = pc.vivienda_id)));


ALTER VIEW public.vw_plantillas_cargo OWNER TO postgres;

--
-- Name: vw_reservas_admin; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_reservas_admin WITH (security_invoker='true') AS
 SELECT r.id,
    r.area_id,
    a.nombre AS area_nombre,
    r.condominio_id,
    r.tipo,
    r.estado,
    r.inicio,
    r.fin,
    r.titular_id,
    ut.nombre AS titular_nombre,
    ut.apellidos AS titular_apellidos,
    r.vivienda_id,
    v.numero_casa,
    r.solicitante_id,
    us.nombre AS solicitante_nombre,
    us.apellidos AS solicitante_apellidos,
    r.aprobador_id,
    ua.nombre AS aprobador_nombre,
    ua.apellidos AS aprobador_apellidos,
    r.motivo,
    r.confirmada_en,
    r.creado_en,
    r.actualizado_en,
    ( SELECT (count(*))::integer AS count
           FROM public.reservas r2
          WHERE ((r2.titular_id = r.titular_id) AND ((r2.estado)::text = 'NO_UTILIZADA'::text))) AS no_shows_titular,
    ( SELECT (count(*))::integer AS count
           FROM public.reservas r3
          WHERE ((r3.solicitante_id = r.solicitante_id) AND ((r3.estado)::text = 'NO_UTILIZADA'::text))) AS no_shows_solicitante
   FROM (((((public.reservas r
     JOIN public.areas_comunes a ON ((a.id = r.area_id)))
     LEFT JOIN public.usuarios ut ON ((ut.id = r.titular_id)))
     LEFT JOIN public.viviendas v ON ((v.id = r.vivienda_id)))
     JOIN public.usuarios us ON ((us.id = r.solicitante_id)))
     LEFT JOIN public.usuarios ua ON ((ua.id = r.aprobador_id)));


ALTER VIEW public.vw_reservas_admin OWNER TO postgres;

--
-- Name: vw_reservas_pendientes_titular; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_reservas_pendientes_titular WITH (security_invoker='true') AS
 SELECT r.id,
    r.area_id,
    a.nombre AS area_nombre,
    r.condominio_id,
    r.inicio,
    r.fin,
    r.titular_id,
    r.vivienda_id,
    v.numero_casa,
    r.solicitante_id,
    us.nombre AS solicitante_nombre,
    us.apellidos AS solicitante_apellidos,
    us.email AS solicitante_email,
    vs.parentesco,
    r.creado_en
   FROM ((((public.reservas r
     JOIN public.areas_comunes a ON ((a.id = r.area_id)))
     JOIN public.viviendas v ON ((v.id = r.vivienda_id)))
     JOIN public.usuarios us ON ((us.id = r.solicitante_id)))
     LEFT JOIN public.vivienda_subusuarios vs ON (((vs.vivienda_id = r.vivienda_id) AND (vs.usuario_id = r.solicitante_id) AND (vs.activo = true))))
  WHERE (((r.tipo)::text = 'RESERVA'::text) AND ((r.estado)::text = 'PENDIENTE_TITULAR'::text));


ALTER VIEW public.vw_reservas_pendientes_titular OWNER TO postgres;

--
-- Name: vw_reservas_usuario; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_reservas_usuario WITH (security_invoker='true') AS
 SELECT r.id,
    r.area_id,
    a.nombre AS area_nombre,
    r.condominio_id,
    r.tipo,
    r.estado,
    r.inicio,
    r.fin,
    r.titular_id,
    ut.nombre AS titular_nombre,
    ut.apellidos AS titular_apellidos,
    r.vivienda_id,
    v.numero_casa,
    r.solicitante_id,
    us.nombre AS solicitante_nombre,
    us.apellidos AS solicitante_apellidos,
    r.aprobador_id,
    ua.nombre AS aprobador_nombre,
    ua.apellidos AS aprobador_apellidos,
    r.motivo,
    r.confirmada_en,
    r.creado_en,
    r.actualizado_en
   FROM (((((public.reservas r
     JOIN public.areas_comunes a ON ((a.id = r.area_id)))
     LEFT JOIN public.usuarios ut ON ((ut.id = r.titular_id)))
     LEFT JOIN public.viviendas v ON ((v.id = r.vivienda_id)))
     JOIN public.usuarios us ON ((us.id = r.solicitante_id)))
     LEFT JOIN public.usuarios ua ON ((ua.id = r.aprobador_id)))
  WHERE ((r.tipo)::text = 'RESERVA'::text);


ALTER VIEW public.vw_reservas_usuario OWNER TO postgres;

--
-- Name: vw_residentes_sin_vivienda; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_residentes_sin_vivienda WITH (security_invoker='true') AS
 SELECT u.id,
    u.email,
    u.nombre,
    u.apellidos,
    COALESCE(u.telefono, ''::text) AS telefono,
    r.nombre AS rol,
    r.id AS rol_id,
    u.condominio_id,
    c.nombre AS condominio_nombre,
    u.creado_en
   FROM ((((public.usuarios u
     JOIN public.roles r ON ((u.rol_id = r.id)))
     LEFT JOIN public.condominios c ON ((u.condominio_id = c.id)))
     LEFT JOIN public.vivienda_residente vr ON ((u.id = vr.usuario_id)))
     LEFT JOIN public.vivienda_subusuarios vs ON (((u.id = vs.usuario_id) AND (vs.activo = true))))
  WHERE ((u.activo = true) AND (u.rol_id = 2) AND (vr.id IS NULL) AND (vs.id IS NULL));


ALTER VIEW public.vw_residentes_sin_vivienda OWNER TO postgres;

--
-- Name: vw_servicios_paqueteria; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_servicios_paqueteria WITH (security_invoker='true') AS
 SELECT id,
    condominio_id,
    nombre,
    icono_url,
    activo,
    es_sistema,
    creado_en
   FROM public.servicios_paqueteria;


ALTER VIEW public.vw_servicios_paqueteria OWNER TO postgres;

--
-- Name: vw_subusuarios_vivienda; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_subusuarios_vivienda WITH (security_invoker='true') AS
 SELECT vs.id,
    vs.vivienda_id,
    v.numero_casa,
    vs.usuario_id AS subusuario_id,
    u.nombre,
    u.apellidos,
    u.email,
    u.telefono,
    vs.parentesco,
    vs.titular_id,
    ut.nombre AS titular_nombre,
    ut.apellidos AS titular_apellidos,
    vs.activo,
    vs.creado_en
   FROM (((public.vivienda_subusuarios vs
     JOIN public.viviendas v ON ((vs.vivienda_id = v.id)))
     JOIN public.usuarios u ON ((vs.usuario_id = u.id)))
     JOIN public.usuarios ut ON ((vs.titular_id = ut.id)))
  WHERE ((vs.activo = true) AND (u.activo = true));


ALTER VIEW public.vw_subusuarios_vivienda OWNER TO postgres;

--
-- Name: vw_usuarios; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_usuarios WITH (security_invoker='true') AS
 SELECT u.id,
    u.email,
    u.nombre,
    u.apellidos,
    COALESCE(u.telefono, ''::text) AS telefono,
    r.nombre AS rol,
    r.id AS rol_id,
    u.condominio_id,
    c.nombre AS condominio_nombre,
    u.activo,
    u.debe_cambiar_password,
    u.creado_en,
    r.nombre AS rol_nombre
   FROM ((public.usuarios u
     JOIN public.roles r ON ((u.rol_id = r.id)))
     LEFT JOIN public.condominios c ON ((u.condominio_id = c.id)))
  WHERE (u.activo = true);


ALTER VIEW public.vw_usuarios OWNER TO postgres;

--
-- Name: vw_version; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_version WITH (security_invoker='true') AS
 SELECT id,
    numero_version,
    descripcion,
    aplicado_en
   FROM public.version
  ORDER BY id DESC
 LIMIT 1;


ALTER VIEW public.vw_version OWNER TO postgres;

--
-- Name: vw_vigilantes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_vigilantes WITH (security_invoker='true') AS
 SELECT id,
    email,
    nombre,
    apellidos,
    COALESCE(telefono, ''::text) AS telefono,
    activo,
    creado_en,
    condominio_id
   FROM public.usuarios u
  WHERE (rol_id = 3);


ALTER VIEW public.vw_vigilantes OWNER TO postgres;

--
-- Name: vw_visitas_historico; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_visitas_historico WITH (security_invoker='true') AS
 SELECT vi.id,
    vi.condominio_id,
    vi.vivienda_id,
    v.numero_casa,
    vi.nombre_visitante,
    vi.apellidos_visitante,
    vi.telefono_visitante,
    vi.motivo,
    vi.num_acompanantes,
    vi.vehiculo_placas,
    vi.notas,
    vi.fecha_llegada_esperada,
    vi.fecha_expiracion,
    vi.codigo_acceso,
        CASE
            WHEN (((vi.estado)::text = 'programada'::text) AND (now() > vi.fecha_expiracion)) THEN 'expirada'::character varying
            ELSE vi.estado
        END AS estado,
        CASE
            WHEN (((vi.estado)::text = 'programada'::text) AND (now() > vi.fecha_expiracion)) THEN 'expirada'::character varying
            ELSE vi.estado
        END AS estado_calculado,
    vi.hora_entrada,
    TRIM(BOTH FROM ((ue.nombre || ' '::text) || ue.apellidos)) AS registrado_entrada_por_nombre,
    vi.hora_salida,
    TRIM(BOTH FROM ((us.nombre || ' '::text) || us.apellidos)) AS registrado_salida_por_nombre,
    vi.creado_por,
    TRIM(BOTH FROM ((uc.nombre || ' '::text) || uc.apellidos)) AS creado_por_nombre,
    vi.creado_en
   FROM ((((public.visitas vi
     JOIN public.viviendas v ON ((vi.vivienda_id = v.id)))
     JOIN public.usuarios uc ON ((vi.creado_por = uc.id)))
     LEFT JOIN public.usuarios ue ON ((vi.registrado_entrada_por = ue.id)))
     LEFT JOIN public.usuarios us ON ((vi.registrado_salida_por = us.id)));


ALTER VIEW public.vw_visitas_historico OWNER TO postgres;

--
-- Name: vw_visitas_proximas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_visitas_proximas WITH (security_invoker='true') AS
 SELECT vi.id,
    vi.vivienda_id,
    v.numero_casa,
    vi.condominio_id,
    vi.nombre_visitante,
    vi.apellidos_visitante,
    vi.telefono_visitante,
    vi.motivo,
    vi.num_acompanantes,
    vi.vehiculo_placas,
    vi.notas,
    vi.fecha_llegada_esperada,
    vi.fecha_expiracion,
    vi.codigo_acceso,
    vi.estado,
    vi.estado AS estado_calculado,
    vi.hora_entrada,
    vi.hora_salida,
    vi.creado_por,
    TRIM(BOTH FROM ((u.nombre || ' '::text) || u.apellidos)) AS creado_por_nombre,
    vi.creado_en
   FROM ((public.visitas vi
     JOIN public.viviendas v ON ((vi.vivienda_id = v.id)))
     JOIN public.usuarios u ON ((vi.creado_por = u.id)))
  WHERE (((vi.estado)::text = 'programada'::text) AND (now() <= vi.fecha_expiracion));


ALTER VIEW public.vw_visitas_proximas OWNER TO postgres;

--
-- Name: vw_vivienda_subusuarios; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_vivienda_subusuarios WITH (security_invoker='true') AS
 SELECT vs.id,
    vs.vivienda_id,
    v.numero_casa,
    vs.usuario_id,
    TRIM(BOTH FROM ((u.nombre || ' '::text) || u.apellidos)) AS usuario_nombre,
    u.email AS usuario_email,
    COALESCE(u.telefono, ''::text) AS usuario_telefono,
    vs.titular_id,
    TRIM(BOTH FROM ((ut.nombre || ' '::text) || ut.apellidos)) AS titular_nombre,
    vs.parentesco,
    vs.activo,
    vs.creado_en
   FROM (((public.vivienda_subusuarios vs
     JOIN public.viviendas v ON ((vs.vivienda_id = v.id)))
     JOIN public.usuarios u ON ((vs.usuario_id = u.id)))
     JOIN public.usuarios ut ON ((vs.titular_id = ut.id)))
  WHERE ((vs.activo = true) AND (u.activo = true));


ALTER VIEW public.vw_vivienda_subusuarios OWNER TO postgres;

--
-- Name: vw_vivienda_usuarios; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_vivienda_usuarios WITH (security_invoker='true') AS
 SELECT vr.vivienda_id,
    vr.usuario_id
   FROM ((public.vivienda_residente vr
     JOIN public.viviendas v ON ((v.id = vr.vivienda_id)))
     JOIN public.usuarios u ON ((u.id = vr.usuario_id)))
  WHERE ((v.activo = true) AND (u.activo = true));


ALTER VIEW public.vw_vivienda_usuarios OWNER TO postgres;

--
-- Name: vw_viviendas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_viviendas WITH (security_invoker='true') AS
 SELECT v.id,
    v.numero_casa,
    v.tipo,
    v.activo,
    v.condominio_id,
    c.nombre AS condominio_nombre,
    v.creado_en,
    (count(u.id))::integer AS total_residentes,
    (count(u.id) > 0) AS esta_ocupada
   FROM (((public.viviendas v
     JOIN public.condominios c ON ((v.condominio_id = c.id)))
     LEFT JOIN public.vivienda_residente vr ON ((v.id = vr.vivienda_id)))
     LEFT JOIN public.usuarios u ON (((vr.usuario_id = u.id) AND (u.activo = true))))
  WHERE ((v.activo = true) AND (c.activo = true))
  GROUP BY v.id, v.numero_casa, v.tipo, v.activo, v.condominio_id, c.nombre, v.creado_en;


ALTER VIEW public.vw_viviendas OWNER TO postgres;

--
-- Name: vw_viviendas_con_residentes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_viviendas_con_residentes WITH (security_invoker='true') AS
 SELECT v.id,
    v.numero_casa,
    v.tipo,
    v.activo,
    v.condominio_id,
    c.nombre AS condominio_nombre,
    v.creado_en,
    COALESCE(res.total_residentes, 0) AS total_residentes,
    (COALESCE(res.total_residentes, 0) > 0) AS esta_ocupada,
    COALESCE(res.residentes, '[]'::json) AS residentes,
    COALESCE(sub.subusuarios, '[]'::json) AS subusuarios
   FROM (((public.viviendas v
     JOIN public.condominios c ON ((v.condominio_id = c.id)))
     LEFT JOIN LATERAL ( SELECT (count(u.id))::integer AS total_residentes,
            json_agg(json_build_object('id', u.id, 'email', u.email, 'nombre', u.nombre, 'apellidos', u.apellidos, 'telefono', u.telefono, 'rol_id', u.rol_id, 'es_propietario', vr.es_propietario, 'fecha_ingreso', vr.fecha_ingreso) ORDER BY vr.fecha_ingreso) FILTER (WHERE (u.id IS NOT NULL)) AS residentes
           FROM (public.vivienda_residente vr
             JOIN public.usuarios u ON (((vr.usuario_id = u.id) AND (u.activo = true))))
          WHERE (vr.vivienda_id = v.id)) res ON (true))
     LEFT JOIN LATERAL ( SELECT json_agg(json_build_object('id', vs.id, 'usuario_id', vs.usuario_id, 'vivienda_id', vs.vivienda_id, 'nombre', TRIM(BOTH FROM ((u.nombre || ' '::text) || u.apellidos)), 'email', u.email, 'telefono', u.telefono, 'parentesco', vs.parentesco, 'activo', vs.activo) ORDER BY vs.creado_en) FILTER (WHERE (vs.id IS NOT NULL)) AS subusuarios
           FROM (public.vivienda_subusuarios vs
             JOIN public.usuarios u ON (((vs.usuario_id = u.id) AND (u.activo = true))))
          WHERE ((vs.vivienda_id = v.id) AND (vs.activo = true))) sub ON (true))
  WHERE ((v.activo = true) AND (c.activo = true));


ALTER VIEW public.vw_viviendas_con_residentes OWNER TO postgres;

--
-- Name: vw_viviendas_residentes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_viviendas_residentes WITH (security_invoker='true') AS
 SELECT v.id AS vivienda_id,
    v.numero_casa,
    v.tipo,
    v.activo,
    v.creado_en,
    COALESCE(json_agg(json_build_object('id', u.id, 'email', u.email, 'nombre', u.nombre, 'apellidos', u.apellidos, 'telefono', COALESCE(u.telefono, ''::text), 'rol', r.nombre, 'rol_id', r.id, 'condominio_id', u.condominio_id, 'creado_en', u.creado_en) ORDER BY vr.fecha_ingreso) FILTER (WHERE (u.id IS NOT NULL)), '[]'::json) AS residentes
   FROM (((public.viviendas v
     LEFT JOIN public.vivienda_residente vr ON ((v.id = vr.vivienda_id)))
     LEFT JOIN public.usuarios u ON (((vr.usuario_id = u.id) AND (u.activo = true))))
     LEFT JOIN public.roles r ON ((u.rol_id = r.id)))
  WHERE (v.activo = true)
  GROUP BY v.id, v.numero_casa, v.tipo, v.activo, v.creado_en;


ALTER VIEW public.vw_viviendas_residentes OWNER TO postgres;

--
-- Name: areas_comunes_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas_comunes_bitacora ALTER COLUMN id SET DEFAULT nextval('public.areas_comunes_bitacora_id_seq'::regclass);


--
-- Name: avisos_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.avisos_bitacora ALTER COLUMN id SET DEFAULT nextval('public.avisos_bitacora_id_seq'::regclass);


--
-- Name: cargos_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargos_bitacora ALTER COLUMN id SET DEFAULT nextval('public.cargos_bitacora_id_seq'::regclass);


--
-- Name: codigos_condominio_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_condominio_bitacora ALTER COLUMN id SET DEFAULT nextval('public.codigos_condominio_bitacora_id_seq'::regclass);


--
-- Name: codigos_vivienda_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_vivienda_bitacora ALTER COLUMN id SET DEFAULT nextval('public.codigos_vivienda_bitacora_id_seq'::regclass);


--
-- Name: condominios_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.condominios_bitacora ALTER COLUMN id SET DEFAULT nextval('public.condominios_bitacora_id_seq'::regclass);


--
-- Name: invitaciones_subusuarios_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invitaciones_subusuarios_bitacora ALTER COLUMN id SET DEFAULT nextval('public.invitaciones_subusuarios_bitacora_id_seq'::regclass);


--
-- Name: movimientos_saldo_favor_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientos_saldo_favor_bitacora ALTER COLUMN id SET DEFAULT nextval('public.movimientos_saldo_favor_bitacora_id_seq'::regclass);


--
-- Name: notificaciones_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificaciones_bitacora ALTER COLUMN id SET DEFAULT nextval('public.notificaciones_bitacora_id_seq'::regclass);


--
-- Name: pagos_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos_bitacora ALTER COLUMN id SET DEFAULT nextval('public.pagos_bitacora_id_seq'::regclass);


--
-- Name: paquetes_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paquetes_bitacora ALTER COLUMN id SET DEFAULT nextval('public.paquetes_bitacora_id_seq'::regclass);


--
-- Name: plantillas_cargo_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plantillas_cargo_bitacora ALTER COLUMN id SET DEFAULT nextval('public.plantillas_cargo_bitacora_id_seq'::regclass);


--
-- Name: reservas_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservas_bitacora ALTER COLUMN id SET DEFAULT nextval('public.reservas_bitacora_id_seq'::regclass);


--
-- Name: roles_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles_bitacora ALTER COLUMN id SET DEFAULT nextval('public.roles_bitacora_id_seq'::regclass);


--
-- Name: servicios_paqueteria id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.servicios_paqueteria ALTER COLUMN id SET DEFAULT nextval('public.servicios_paqueteria_id_seq'::regclass);


--
-- Name: servicios_paqueteria_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.servicios_paqueteria_bitacora ALTER COLUMN id SET DEFAULT nextval('public.servicios_paqueteria_bitacora_id_seq'::regclass);


--
-- Name: usuarios_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_bitacora ALTER COLUMN id SET DEFAULT nextval('public.usuarios_bitacora_id_seq'::regclass);


--
-- Name: version id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.version ALTER COLUMN id SET DEFAULT nextval('public.version_id_seq'::regclass);


--
-- Name: version_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.version_bitacora ALTER COLUMN id SET DEFAULT nextval('public.version_bitacora_id_seq'::regclass);


--
-- Name: visitas_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visitas_bitacora ALTER COLUMN id SET DEFAULT nextval('public.visitas_bitacora_id_seq'::regclass);


--
-- Name: vivienda_residente id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivienda_residente ALTER COLUMN id SET DEFAULT nextval('public.vivienda_residente_id_seq'::regclass);


--
-- Name: vivienda_residente_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivienda_residente_bitacora ALTER COLUMN id SET DEFAULT nextval('public.vivienda_residente_bitacora_id_seq'::regclass);


--
-- Name: vivienda_subusuarios_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivienda_subusuarios_bitacora ALTER COLUMN id SET DEFAULT nextval('public.vivienda_subusuarios_bitacora_id_seq'::regclass);


--
-- Name: viviendas id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.viviendas ALTER COLUMN id SET DEFAULT nextval('public.viviendas_id_seq'::regclass);


--
-- Name: viviendas_bitacora id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.viviendas_bitacora ALTER COLUMN id SET DEFAULT nextval('public.viviendas_bitacora_id_seq'::regclass);


--
-- Name: areas_comunes_bitacora areas_comunes_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas_comunes_bitacora
    ADD CONSTRAINT areas_comunes_bitacora_pkey PRIMARY KEY (id);


--
-- Name: areas_comunes areas_comunes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas_comunes
    ADD CONSTRAINT areas_comunes_pkey PRIMARY KEY (id);


--
-- Name: avisos_bitacora avisos_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.avisos_bitacora
    ADD CONSTRAINT avisos_bitacora_pkey PRIMARY KEY (id);


--
-- Name: avisos avisos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.avisos
    ADD CONSTRAINT avisos_pkey PRIMARY KEY (id);


--
-- Name: cargos_bitacora cargos_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargos_bitacora
    ADD CONSTRAINT cargos_bitacora_pkey PRIMARY KEY (id);


--
-- Name: cargos cargos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargos
    ADD CONSTRAINT cargos_pkey PRIMARY KEY (id);


--
-- Name: codigos_condominio_bitacora codigos_condominio_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_condominio_bitacora
    ADD CONSTRAINT codigos_condominio_bitacora_pkey PRIMARY KEY (id);


--
-- Name: codigos_condominio codigos_condominio_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_condominio
    ADD CONSTRAINT codigos_condominio_codigo_key UNIQUE (codigo);


--
-- Name: codigos_condominio codigos_condominio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_condominio
    ADD CONSTRAINT codigos_condominio_pkey PRIMARY KEY (id);


--
-- Name: codigos_vivienda_bitacora codigos_vivienda_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_vivienda_bitacora
    ADD CONSTRAINT codigos_vivienda_bitacora_pkey PRIMARY KEY (id);


--
-- Name: codigos_vivienda codigos_vivienda_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_vivienda
    ADD CONSTRAINT codigos_vivienda_codigo_key UNIQUE (codigo);


--
-- Name: codigos_vivienda codigos_vivienda_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_vivienda
    ADD CONSTRAINT codigos_vivienda_pkey PRIMARY KEY (id);


--
-- Name: condominios_bitacora condominios_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.condominios_bitacora
    ADD CONSTRAINT condominios_bitacora_pkey PRIMARY KEY (id);


--
-- Name: condominios condominios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.condominios
    ADD CONSTRAINT condominios_pkey PRIMARY KEY (id);


--
-- Name: invitaciones_subusuarios_bitacora invitaciones_subusuarios_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invitaciones_subusuarios_bitacora
    ADD CONSTRAINT invitaciones_subusuarios_bitacora_pkey PRIMARY KEY (id);


--
-- Name: invitaciones_subusuarios invitaciones_subusuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invitaciones_subusuarios
    ADD CONSTRAINT invitaciones_subusuarios_pkey PRIMARY KEY (id);


--
-- Name: movimientos_saldo_favor_bitacora movimientos_saldo_favor_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientos_saldo_favor_bitacora
    ADD CONSTRAINT movimientos_saldo_favor_bitacora_pkey PRIMARY KEY (id);


--
-- Name: movimientos_saldo_favor movimientos_saldo_favor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientos_saldo_favor
    ADD CONSTRAINT movimientos_saldo_favor_pkey PRIMARY KEY (id);


--
-- Name: notificaciones_bitacora notificaciones_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificaciones_bitacora
    ADD CONSTRAINT notificaciones_bitacora_pkey PRIMARY KEY (id);


--
-- Name: notificaciones notificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_pkey PRIMARY KEY (id);


--
-- Name: pagos_bitacora pagos_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos_bitacora
    ADD CONSTRAINT pagos_bitacora_pkey PRIMARY KEY (id);


--
-- Name: pagos pagos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_pkey PRIMARY KEY (id);


--
-- Name: paquetes_bitacora paquetes_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paquetes_bitacora
    ADD CONSTRAINT paquetes_bitacora_pkey PRIMARY KEY (id);


--
-- Name: paquetes paquetes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT paquetes_pkey PRIMARY KEY (id);


--
-- Name: plantillas_cargo_bitacora plantillas_cargo_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plantillas_cargo_bitacora
    ADD CONSTRAINT plantillas_cargo_bitacora_pkey PRIMARY KEY (id);


--
-- Name: plantillas_cargo plantillas_cargo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plantillas_cargo
    ADD CONSTRAINT plantillas_cargo_pkey PRIMARY KEY (id);


--
-- Name: reservas_bitacora reservas_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservas_bitacora
    ADD CONSTRAINT reservas_bitacora_pkey PRIMARY KEY (id);


--
-- Name: reservas reservas_no_overlap_confirmadas; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT reservas_no_overlap_confirmadas EXCLUDE USING gist (area_id WITH =, tstzrange(inicio, fin, '[)'::text) WITH &&) WHERE (((estado)::text = 'CONFIRMADA'::text));


--
-- Name: reservas reservas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT reservas_pkey PRIMARY KEY (id);


--
-- Name: roles_bitacora roles_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles_bitacora
    ADD CONSTRAINT roles_bitacora_pkey PRIMARY KEY (id);


--
-- Name: roles roles_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_nombre_key UNIQUE (nombre);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: servicios_paqueteria_bitacora servicios_paqueteria_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.servicios_paqueteria_bitacora
    ADD CONSTRAINT servicios_paqueteria_bitacora_pkey PRIMARY KEY (id);


--
-- Name: servicios_paqueteria servicios_paqueteria_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.servicios_paqueteria
    ADD CONSTRAINT servicios_paqueteria_pkey PRIMARY KEY (id);


--
-- Name: areas_comunes uq_areas_comunes_condominio_nombre; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas_comunes
    ADD CONSTRAINT uq_areas_comunes_condominio_nombre UNIQUE (condominio_id, nombre);


--
-- Name: cargos uq_cargos_plantilla_periodo; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargos
    ADD CONSTRAINT uq_cargos_plantilla_periodo UNIQUE (plantilla_id, periodo);


--
-- Name: usuarios_bitacora usuarios_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios_bitacora
    ADD CONSTRAINT usuarios_bitacora_pkey PRIMARY KEY (id);


--
-- Name: usuarios usuarios_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_email_key UNIQUE (email);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);


--
-- Name: version_bitacora version_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.version_bitacora
    ADD CONSTRAINT version_bitacora_pkey PRIMARY KEY (id);


--
-- Name: version version_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.version
    ADD CONSTRAINT version_pkey PRIMARY KEY (id);


--
-- Name: visitas_bitacora visitas_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visitas_bitacora
    ADD CONSTRAINT visitas_bitacora_pkey PRIMARY KEY (id);


--
-- Name: visitas visitas_codigo_acceso_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visitas
    ADD CONSTRAINT visitas_codigo_acceso_key UNIQUE (codigo_acceso);


--
-- Name: visitas visitas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visitas
    ADD CONSTRAINT visitas_pkey PRIMARY KEY (id);


--
-- Name: vivienda_residente_bitacora vivienda_residente_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivienda_residente_bitacora
    ADD CONSTRAINT vivienda_residente_bitacora_pkey PRIMARY KEY (id);


--
-- Name: vivienda_residente vivienda_residente_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivienda_residente
    ADD CONSTRAINT vivienda_residente_pkey PRIMARY KEY (id);


--
-- Name: vivienda_residente vivienda_residente_vivienda_id_usuario_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivienda_residente
    ADD CONSTRAINT vivienda_residente_vivienda_id_usuario_id_key UNIQUE (vivienda_id, usuario_id);


--
-- Name: vivienda_subusuarios_bitacora vivienda_subusuarios_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivienda_subusuarios_bitacora
    ADD CONSTRAINT vivienda_subusuarios_bitacora_pkey PRIMARY KEY (id);


--
-- Name: vivienda_subusuarios vivienda_subusuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivienda_subusuarios
    ADD CONSTRAINT vivienda_subusuarios_pkey PRIMARY KEY (id);


--
-- Name: vivienda_subusuarios vivienda_subusuarios_vivienda_id_usuario_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivienda_subusuarios
    ADD CONSTRAINT vivienda_subusuarios_vivienda_id_usuario_id_key UNIQUE (vivienda_id, usuario_id);


--
-- Name: viviendas_bitacora viviendas_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.viviendas_bitacora
    ADD CONSTRAINT viviendas_bitacora_pkey PRIMARY KEY (id);


--
-- Name: viviendas viviendas_condominio_id_numero_casa_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.viviendas
    ADD CONSTRAINT viviendas_condominio_id_numero_casa_key UNIQUE (condominio_id, numero_casa);


--
-- Name: viviendas viviendas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.viviendas
    ADD CONSTRAINT viviendas_pkey PRIMARY KEY (id);


--
-- Name: idx_areas_comunes_condominio_activo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_areas_comunes_condominio_activo ON public.areas_comunes USING btree (condominio_id, activo);


--
-- Name: idx_avisos_condominio_activo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_avisos_condominio_activo ON public.avisos USING btree (condominio_id, activo, fecha_publicacion DESC);


--
-- Name: idx_cargos_condominio_vencimiento; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cargos_condominio_vencimiento ON public.cargos USING btree (condominio_id, fecha_vencimiento);


--
-- Name: idx_cargos_periodo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cargos_periodo ON public.cargos USING btree (periodo);


--
-- Name: idx_cargos_vivienda_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cargos_vivienda_estado ON public.cargos USING btree (vivienda_id, estado);


--
-- Name: idx_codigo_invitacion_subusuario_vigente; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_codigo_invitacion_subusuario_vigente ON public.invitaciones_subusuarios USING btree (codigo_invitacion) WHERE ((estado)::text = 'pendiente'::text);


--
-- Name: idx_codigos_condominio_codigo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_codigos_condominio_codigo ON public.codigos_condominio USING btree (codigo);


--
-- Name: idx_codigos_condominio_condominio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_codigos_condominio_condominio ON public.codigos_condominio USING btree (condominio_id);


--
-- Name: idx_codigos_vivienda_codigo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_codigos_vivienda_codigo ON public.codigos_vivienda USING btree (codigo);


--
-- Name: idx_codigos_vivienda_vivienda; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_codigos_vivienda_vivienda ON public.codigos_vivienda USING btree (vivienda_id);


--
-- Name: idx_invitaciones_subusuarios_vivienda; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_invitaciones_subusuarios_vivienda ON public.invitaciones_subusuarios USING btree (vivienda_id, estado);


--
-- Name: idx_mov_saldo_cargo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mov_saldo_cargo ON public.movimientos_saldo_favor USING btree (cargo_id);


--
-- Name: idx_mov_saldo_pago; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mov_saldo_pago ON public.movimientos_saldo_favor USING btree (pago_id);


--
-- Name: idx_mov_saldo_vivienda; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mov_saldo_vivienda ON public.movimientos_saldo_favor USING btree (vivienda_id);


--
-- Name: idx_notificaciones_creado_en; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notificaciones_creado_en ON public.notificaciones USING btree (creado_en DESC);


--
-- Name: idx_notificaciones_push_pendientes; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notificaciones_push_pendientes ON public.notificaciones USING btree (creado_en) WHERE ((push_enviado = false) AND (reserva_id IS NOT NULL));


--
-- Name: idx_notificaciones_usuario_leida; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notificaciones_usuario_leida ON public.notificaciones USING btree (usuario_id, leida);


--
-- Name: idx_pagos_anti_duplicado_hash; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_pagos_anti_duplicado_hash ON public.pagos USING btree (comprobante_hash) WHERE (((estado)::text <> ALL (ARRAY[('Rechazado'::character varying)::text, ('Anulado'::character varying)::text])) AND (comprobante_hash IS NOT NULL) AND (TRIM(BOTH FROM comprobante_hash) <> ''::text));


--
-- Name: idx_pagos_anti_duplicado_ref; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_pagos_anti_duplicado_ref ON public.pagos USING btree (referencia, monto, fecha_pago) WHERE (((estado)::text <> ALL (ARRAY[('Rechazado'::character varying)::text, ('Anulado'::character varying)::text])) AND (referencia IS NOT NULL) AND (TRIM(BOTH FROM referencia) <> ''::text));


--
-- Name: idx_pagos_cargo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pagos_cargo ON public.pagos USING btree (cargo_id);


--
-- Name: idx_pagos_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pagos_estado ON public.pagos USING btree (estado);


--
-- Name: idx_pagos_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pagos_fecha ON public.pagos USING btree (fecha_pago);


--
-- Name: idx_paquetes_condominio_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_paquetes_condominio_estado ON public.paquetes USING btree (condominio_id, estado);


--
-- Name: idx_paquetes_numero_guia; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_paquetes_numero_guia ON public.paquetes USING btree (condominio_id, numero_guia) WHERE (numero_guia IS NOT NULL);


--
-- Name: idx_paquetes_vivienda; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_paquetes_vivienda ON public.paquetes USING btree (vivienda_id, estado);


--
-- Name: idx_plantillas_condominio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_plantillas_condominio ON public.plantillas_cargo USING btree (condominio_id);


--
-- Name: idx_plantillas_vivienda; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_plantillas_vivienda ON public.plantillas_cargo USING btree (vivienda_id);


--
-- Name: idx_plantillas_vivienda_tipo_concepto_activa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_plantillas_vivienda_tipo_concepto_activa ON public.plantillas_cargo USING btree (vivienda_id, tipo, concepto) WHERE (activa = true);


--
-- Name: idx_reservas_area_inicio_fin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reservas_area_inicio_fin ON public.reservas USING btree (area_id, inicio, fin);


--
-- Name: idx_reservas_condominio_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reservas_condominio_estado ON public.reservas USING btree (condominio_id, estado);


--
-- Name: idx_reservas_solicitante_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reservas_solicitante_estado ON public.reservas USING btree (solicitante_id, estado);


--
-- Name: idx_reservas_titular_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reservas_titular_estado ON public.reservas USING btree (titular_id, estado);


--
-- Name: idx_servicios_paqueteria_condominio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_servicios_paqueteria_condominio ON public.servicios_paqueteria USING btree (condominio_id, activo);


--
-- Name: idx_unico_admin_por_condominio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_unico_admin_por_condominio ON public.usuarios USING btree (condominio_id) WHERE ((rol_id = 1) AND (activo = true) AND (condominio_id IS NOT NULL));


--
-- Name: idx_usuarios_condominio_rol; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usuarios_condominio_rol ON public.usuarios USING btree (condominio_id, rol_id, activo);


--
-- Name: idx_visitas_codigo_acceso; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_visitas_codigo_acceso ON public.visitas USING btree (codigo_acceso);


--
-- Name: idx_visitas_condominio_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_visitas_condominio_id ON public.visitas USING btree (condominio_id);


--
-- Name: idx_visitas_creado_por; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_visitas_creado_por ON public.visitas USING btree (creado_por);


--
-- Name: idx_visitas_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_visitas_estado ON public.visitas USING btree (estado);


--
-- Name: idx_visitas_vivienda_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_visitas_vivienda_id ON public.visitas USING btree (vivienda_id);


--
-- Name: idx_vivienda_residente_usuario; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_vivienda_residente_usuario ON public.vivienda_residente USING btree (usuario_id);


--
-- Name: idx_vivienda_residente_vivienda; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_vivienda_residente_vivienda ON public.vivienda_residente USING btree (vivienda_id);


--
-- Name: idx_vivienda_subusuarios_usuario; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_vivienda_subusuarios_usuario ON public.vivienda_subusuarios USING btree (usuario_id, activo);


--
-- Name: idx_vivienda_subusuarios_vivienda; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_vivienda_subusuarios_vivienda ON public.vivienda_subusuarios USING btree (vivienda_id, activo);


--
-- Name: idx_viviendas_condominio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_viviendas_condominio ON public.viviendas USING btree (condominio_id, activo);


--
-- Name: areas_comunes trg_auditoria_areas_comunes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_areas_comunes AFTER INSERT OR DELETE OR UPDATE ON public.areas_comunes FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: avisos trg_auditoria_avisos; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_avisos AFTER INSERT OR DELETE OR UPDATE ON public.avisos FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: cargos trg_auditoria_cargos_del; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_cargos_del BEFORE DELETE ON public.cargos FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: cargos trg_auditoria_cargos_ins; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_cargos_ins AFTER INSERT ON public.cargos FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: cargos trg_auditoria_cargos_upd; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_cargos_upd BEFORE UPDATE ON public.cargos FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: codigos_condominio trg_auditoria_codigos_condominio; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_codigos_condominio AFTER INSERT OR DELETE OR UPDATE ON public.codigos_condominio FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: codigos_vivienda trg_auditoria_codigos_vivienda; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_codigos_vivienda AFTER INSERT OR DELETE OR UPDATE ON public.codigos_vivienda FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: condominios trg_auditoria_condominios; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_condominios AFTER INSERT OR DELETE OR UPDATE ON public.condominios FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: movimientos_saldo_favor trg_auditoria_mov_saldo_del; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_mov_saldo_del BEFORE DELETE ON public.movimientos_saldo_favor FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: movimientos_saldo_favor trg_auditoria_mov_saldo_ins; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_mov_saldo_ins AFTER INSERT ON public.movimientos_saldo_favor FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: movimientos_saldo_favor trg_auditoria_mov_saldo_upd; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_mov_saldo_upd BEFORE UPDATE ON public.movimientos_saldo_favor FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: notificaciones trg_auditoria_notificaciones; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_notificaciones AFTER INSERT OR DELETE OR UPDATE ON public.notificaciones FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: pagos trg_auditoria_pagos_del; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_pagos_del BEFORE DELETE ON public.pagos FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: pagos trg_auditoria_pagos_ins; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_pagos_ins AFTER INSERT ON public.pagos FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: pagos trg_auditoria_pagos_upd; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_pagos_upd BEFORE UPDATE ON public.pagos FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: paquetes trg_auditoria_paquetes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_paquetes AFTER INSERT OR DELETE OR UPDATE ON public.paquetes FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: plantillas_cargo trg_auditoria_plantillas_cargo_del; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_plantillas_cargo_del BEFORE DELETE ON public.plantillas_cargo FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: plantillas_cargo trg_auditoria_plantillas_cargo_ins; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_plantillas_cargo_ins AFTER INSERT ON public.plantillas_cargo FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: plantillas_cargo trg_auditoria_plantillas_cargo_upd; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_plantillas_cargo_upd BEFORE UPDATE ON public.plantillas_cargo FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: reservas trg_auditoria_reservas; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_reservas AFTER INSERT OR DELETE OR UPDATE ON public.reservas FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: roles trg_auditoria_roles; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_roles AFTER INSERT OR DELETE OR UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: servicios_paqueteria trg_auditoria_servicios_paqueteria; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_servicios_paqueteria AFTER INSERT OR DELETE OR UPDATE ON public.servicios_paqueteria FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: usuarios trg_auditoria_usuarios; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_usuarios AFTER INSERT OR DELETE OR UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: version trg_auditoria_version; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_version AFTER INSERT OR DELETE OR UPDATE ON public.version FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: visitas trg_auditoria_visitas; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_visitas AFTER INSERT OR DELETE OR UPDATE ON public.visitas FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: vivienda_residente trg_auditoria_vivienda_residente; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_vivienda_residente AFTER INSERT OR DELETE OR UPDATE ON public.vivienda_residente FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: vivienda_subusuarios trg_auditoria_vivienda_subusuarios; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_vivienda_subusuarios AFTER INSERT OR DELETE OR UPDATE ON public.vivienda_subusuarios FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: viviendas trg_auditoria_viviendas; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_viviendas AFTER INSERT OR DELETE OR UPDATE ON public.viviendas FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: invitaciones_subusuarios trg_invitaciones_subusuarios_auditoria_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_invitaciones_subusuarios_auditoria_delete BEFORE DELETE ON public.invitaciones_subusuarios FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: invitaciones_subusuarios trg_invitaciones_subusuarios_auditoria_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_invitaciones_subusuarios_auditoria_insert AFTER INSERT ON public.invitaciones_subusuarios FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: invitaciones_subusuarios trg_invitaciones_subusuarios_auditoria_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_invitaciones_subusuarios_auditoria_update BEFORE UPDATE ON public.invitaciones_subusuarios FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();


--
-- Name: usuarios trg_sync_usuario_app_metadata; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_sync_usuario_app_metadata AFTER INSERT OR UPDATE OF rol_id, condominio_id ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.fn_sync_usuario_app_metadata();


--
-- Name: areas_comunes areas_comunes_condominio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.areas_comunes
    ADD CONSTRAINT areas_comunes_condominio_id_fkey FOREIGN KEY (condominio_id) REFERENCES public.condominios(id) ON DELETE CASCADE;


--
-- Name: avisos avisos_condominio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.avisos
    ADD CONSTRAINT avisos_condominio_id_fkey FOREIGN KEY (condominio_id) REFERENCES public.condominios(id) ON DELETE CASCADE;


--
-- Name: avisos avisos_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.avisos
    ADD CONSTRAINT avisos_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE RESTRICT;


--
-- Name: cargos cargos_cancelado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargos
    ADD CONSTRAINT cargos_cancelado_por_fkey FOREIGN KEY (cancelado_por) REFERENCES auth.users(id);


--
-- Name: cargos cargos_condominio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargos
    ADD CONSTRAINT cargos_condominio_id_fkey FOREIGN KEY (condominio_id) REFERENCES public.condominios(id) ON DELETE RESTRICT;


--
-- Name: cargos cargos_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargos
    ADD CONSTRAINT cargos_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES auth.users(id);


--
-- Name: cargos cargos_plantilla_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargos
    ADD CONSTRAINT cargos_plantilla_id_fkey FOREIGN KEY (plantilla_id) REFERENCES public.plantillas_cargo(id) ON DELETE SET NULL;


--
-- Name: cargos cargos_vivienda_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cargos
    ADD CONSTRAINT cargos_vivienda_id_fkey FOREIGN KEY (vivienda_id) REFERENCES public.viviendas(id) ON DELETE RESTRICT;


--
-- Name: codigos_condominio codigos_condominio_condominio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_condominio
    ADD CONSTRAINT codigos_condominio_condominio_id_fkey FOREIGN KEY (condominio_id) REFERENCES public.condominios(id) ON DELETE CASCADE;


--
-- Name: codigos_condominio codigos_condominio_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_condominio
    ADD CONSTRAINT codigos_condominio_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: codigos_condominio codigos_condominio_usado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_condominio
    ADD CONSTRAINT codigos_condominio_usado_por_fkey FOREIGN KEY (usado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: codigos_vivienda codigos_vivienda_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_vivienda
    ADD CONSTRAINT codigos_vivienda_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: codigos_vivienda codigos_vivienda_usado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_vivienda
    ADD CONSTRAINT codigos_vivienda_usado_por_fkey FOREIGN KEY (usado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: codigos_vivienda codigos_vivienda_vivienda_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.codigos_vivienda
    ADD CONSTRAINT codigos_vivienda_vivienda_id_fkey FOREIGN KEY (vivienda_id) REFERENCES public.viviendas(id) ON DELETE CASCADE;


--
-- Name: invitaciones_subusuarios invitaciones_subusuarios_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invitaciones_subusuarios
    ADD CONSTRAINT invitaciones_subusuarios_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE RESTRICT;


--
-- Name: invitaciones_subusuarios invitaciones_subusuarios_invitado_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invitaciones_subusuarios
    ADD CONSTRAINT invitaciones_subusuarios_invitado_id_fkey FOREIGN KEY (invitado_id) REFERENCES public.usuarios(id);


--
-- Name: invitaciones_subusuarios invitaciones_subusuarios_titular_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invitaciones_subusuarios
    ADD CONSTRAINT invitaciones_subusuarios_titular_id_fkey FOREIGN KEY (titular_id) REFERENCES public.usuarios(id);


--
-- Name: invitaciones_subusuarios invitaciones_subusuarios_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invitaciones_subusuarios
    ADD CONSTRAINT invitaciones_subusuarios_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: invitaciones_subusuarios invitaciones_subusuarios_vivienda_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invitaciones_subusuarios
    ADD CONSTRAINT invitaciones_subusuarios_vivienda_id_fkey FOREIGN KEY (vivienda_id) REFERENCES public.viviendas(id) ON DELETE CASCADE;


--
-- Name: movimientos_saldo_favor movimientos_saldo_favor_cargo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientos_saldo_favor
    ADD CONSTRAINT movimientos_saldo_favor_cargo_id_fkey FOREIGN KEY (cargo_id) REFERENCES public.cargos(id) ON DELETE SET NULL;


--
-- Name: movimientos_saldo_favor movimientos_saldo_favor_condominio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientos_saldo_favor
    ADD CONSTRAINT movimientos_saldo_favor_condominio_id_fkey FOREIGN KEY (condominio_id) REFERENCES public.condominios(id) ON DELETE RESTRICT;


--
-- Name: movimientos_saldo_favor movimientos_saldo_favor_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientos_saldo_favor
    ADD CONSTRAINT movimientos_saldo_favor_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES auth.users(id);


--
-- Name: movimientos_saldo_favor movimientos_saldo_favor_movimiento_origen_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientos_saldo_favor
    ADD CONSTRAINT movimientos_saldo_favor_movimiento_origen_id_fkey FOREIGN KEY (movimiento_origen_id) REFERENCES public.movimientos_saldo_favor(id) ON DELETE RESTRICT;


--
-- Name: movimientos_saldo_favor movimientos_saldo_favor_pago_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientos_saldo_favor
    ADD CONSTRAINT movimientos_saldo_favor_pago_id_fkey FOREIGN KEY (pago_id) REFERENCES public.pagos(id) ON DELETE SET NULL;


--
-- Name: movimientos_saldo_favor movimientos_saldo_favor_vivienda_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientos_saldo_favor
    ADD CONSTRAINT movimientos_saldo_favor_vivienda_id_fkey FOREIGN KEY (vivienda_id) REFERENCES public.viviendas(id) ON DELETE RESTRICT;


--
-- Name: notificaciones notificaciones_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: pagos pagos_anulado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_anulado_por_fkey FOREIGN KEY (anulado_por) REFERENCES auth.users(id);


--
-- Name: pagos pagos_cargo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_cargo_id_fkey FOREIGN KEY (cargo_id) REFERENCES public.cargos(id) ON DELETE RESTRICT;


--
-- Name: pagos pagos_confirmado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_confirmado_por_fkey FOREIGN KEY (confirmado_por) REFERENCES auth.users(id);


--
-- Name: pagos pagos_pago_original_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_pago_original_id_fkey FOREIGN KEY (pago_original_id) REFERENCES public.pagos(id);


--
-- Name: pagos pagos_rechazado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_rechazado_por_fkey FOREIGN KEY (rechazado_por) REFERENCES auth.users(id);


--
-- Name: pagos pagos_registrado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos
    ADD CONSTRAINT pagos_registrado_por_fkey FOREIGN KEY (registrado_por) REFERENCES auth.users(id);


--
-- Name: paquetes paquetes_condominio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT paquetes_condominio_id_fkey FOREIGN KEY (condominio_id) REFERENCES public.condominios(id) ON DELETE CASCADE;


--
-- Name: paquetes paquetes_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT paquetes_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: paquetes paquetes_entregado_a_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT paquetes_entregado_a_fkey FOREIGN KEY (entregado_a) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: paquetes paquetes_entregado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT paquetes_entregado_por_fkey FOREIGN KEY (entregado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: paquetes paquetes_recibido_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT paquetes_recibido_por_fkey FOREIGN KEY (recibido_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: paquetes paquetes_servicio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT paquetes_servicio_id_fkey FOREIGN KEY (servicio_id) REFERENCES public.servicios_paqueteria(id) ON DELETE SET NULL;


--
-- Name: paquetes paquetes_vivienda_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paquetes
    ADD CONSTRAINT paquetes_vivienda_id_fkey FOREIGN KEY (vivienda_id) REFERENCES public.viviendas(id) ON DELETE CASCADE;


--
-- Name: plantillas_cargo plantillas_cargo_condominio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plantillas_cargo
    ADD CONSTRAINT plantillas_cargo_condominio_id_fkey FOREIGN KEY (condominio_id) REFERENCES public.condominios(id) ON DELETE RESTRICT;


--
-- Name: plantillas_cargo plantillas_cargo_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plantillas_cargo
    ADD CONSTRAINT plantillas_cargo_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES auth.users(id);


--
-- Name: plantillas_cargo plantillas_cargo_modificado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plantillas_cargo
    ADD CONSTRAINT plantillas_cargo_modificado_por_fkey FOREIGN KEY (modificado_por) REFERENCES auth.users(id);


--
-- Name: plantillas_cargo plantillas_cargo_vivienda_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plantillas_cargo
    ADD CONSTRAINT plantillas_cargo_vivienda_id_fkey FOREIGN KEY (vivienda_id) REFERENCES public.viviendas(id) ON DELETE RESTRICT;


--
-- Name: reservas reservas_aprobador_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT reservas_aprobador_id_fkey FOREIGN KEY (aprobador_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: reservas reservas_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT reservas_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.areas_comunes(id) ON DELETE RESTRICT;


--
-- Name: reservas reservas_condominio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT reservas_condominio_id_fkey FOREIGN KEY (condominio_id) REFERENCES public.condominios(id) ON DELETE CASCADE;


--
-- Name: reservas reservas_solicitante_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT reservas_solicitante_id_fkey FOREIGN KEY (solicitante_id) REFERENCES public.usuarios(id) ON DELETE RESTRICT;


--
-- Name: reservas reservas_titular_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT reservas_titular_id_fkey FOREIGN KEY (titular_id) REFERENCES public.usuarios(id) ON DELETE RESTRICT;


--
-- Name: reservas reservas_vivienda_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT reservas_vivienda_id_fkey FOREIGN KEY (vivienda_id) REFERENCES public.viviendas(id) ON DELETE RESTRICT;


--
-- Name: servicios_paqueteria servicios_paqueteria_condominio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.servicios_paqueteria
    ADD CONSTRAINT servicios_paqueteria_condominio_id_fkey FOREIGN KEY (condominio_id) REFERENCES public.condominios(id) ON DELETE CASCADE;


--
-- Name: servicios_paqueteria servicios_paqueteria_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.servicios_paqueteria
    ADD CONSTRAINT servicios_paqueteria_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: usuarios usuarios_condominio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_condominio_id_fkey FOREIGN KEY (condominio_id) REFERENCES public.condominios(id) ON DELETE RESTRICT;


--
-- Name: usuarios usuarios_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: usuarios usuarios_rol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.roles(id);


--
-- Name: visitas visitas_condominio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visitas
    ADD CONSTRAINT visitas_condominio_id_fkey FOREIGN KEY (condominio_id) REFERENCES public.condominios(id) ON DELETE CASCADE;


--
-- Name: visitas visitas_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visitas
    ADD CONSTRAINT visitas_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: visitas visitas_registrado_entrada_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visitas
    ADD CONSTRAINT visitas_registrado_entrada_por_fkey FOREIGN KEY (registrado_entrada_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: visitas visitas_registrado_salida_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visitas
    ADD CONSTRAINT visitas_registrado_salida_por_fkey FOREIGN KEY (registrado_salida_por) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- Name: visitas visitas_vivienda_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.visitas
    ADD CONSTRAINT visitas_vivienda_id_fkey FOREIGN KEY (vivienda_id) REFERENCES public.viviendas(id) ON DELETE CASCADE;


--
-- Name: vivienda_residente vivienda_residente_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivienda_residente
    ADD CONSTRAINT vivienda_residente_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: vivienda_residente vivienda_residente_vivienda_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivienda_residente
    ADD CONSTRAINT vivienda_residente_vivienda_id_fkey FOREIGN KEY (vivienda_id) REFERENCES public.viviendas(id) ON DELETE CASCADE;


--
-- Name: vivienda_subusuarios vivienda_subusuarios_titular_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivienda_subusuarios
    ADD CONSTRAINT vivienda_subusuarios_titular_id_fkey FOREIGN KEY (titular_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: vivienda_subusuarios vivienda_subusuarios_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivienda_subusuarios
    ADD CONSTRAINT vivienda_subusuarios_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- Name: vivienda_subusuarios vivienda_subusuarios_vivienda_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vivienda_subusuarios
    ADD CONSTRAINT vivienda_subusuarios_vivienda_id_fkey FOREIGN KEY (vivienda_id) REFERENCES public.viviendas(id) ON DELETE CASCADE;


--
-- Name: viviendas viviendas_condominio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.viviendas
    ADD CONSTRAINT viviendas_condominio_id_fkey FOREIGN KEY (condominio_id) REFERENCES public.condominios(id) ON DELETE CASCADE;


--
-- Name: areas_comunes Lectura de areas_comunes; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Lectura de areas_comunes" ON public.areas_comunes FOR SELECT TO authenticated USING ((condominio_id = public.fn_mi_condominio_id()));


--
-- Name: avisos Lectura de avisos del condominio; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Lectura de avisos del condominio" ON public.avisos FOR SELECT TO authenticated USING ((condominio_id = public.fn_mi_condominio_id()));


--
-- Name: condominios Lectura de condominios; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Lectura de condominios" ON public.condominios FOR SELECT TO authenticated USING ((id = public.fn_mi_condominio_id()));


--
-- Name: notificaciones Lectura de notificaciones propias; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Lectura de notificaciones propias" ON public.notificaciones FOR SELECT TO authenticated USING ((usuario_id = ( SELECT auth.uid() AS uid)));


--
-- Name: paquetes Lectura de paquetes; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Lectura de paquetes" ON public.paquetes FOR SELECT TO authenticated USING (((creado_por = ( SELECT auth.uid() AS uid)) OR public.fn_pertenezco_a_vivienda(vivienda_id) OR ((condominio_id = public.fn_mi_condominio_id()) AND (public.fn_mi_rol_id() = ANY (ARRAY[1, 3])))));


--
-- Name: reservas Lectura de reservas; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Lectura de reservas" ON public.reservas FOR SELECT TO authenticated USING (((solicitante_id = ( SELECT auth.uid() AS uid)) OR (titular_id = ( SELECT auth.uid() AS uid)) OR (condominio_id = public.fn_mi_condominio_id())));


--
-- Name: roles Lectura de roles para autenticados; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Lectura de roles para autenticados" ON public.roles FOR SELECT USING (true);


--
-- Name: servicios_paqueteria Lectura de servicios_paqueteria; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Lectura de servicios_paqueteria" ON public.servicios_paqueteria FOR SELECT TO authenticated USING (((es_sistema = true) OR (condominio_id = public.fn_mi_condominio_id())));


--
-- Name: usuarios Lectura de usuarios de su condominio o propio; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Lectura de usuarios de su condominio o propio" ON public.usuarios FOR SELECT TO authenticated USING (((id = ( SELECT auth.uid() AS uid)) OR (condominio_id = public.fn_mi_condominio_id())));


--
-- Name: visitas Lectura de visitas; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Lectura de visitas" ON public.visitas FOR SELECT TO authenticated USING (((creado_por = ( SELECT auth.uid() AS uid)) OR public.fn_pertenezco_a_vivienda(vivienda_id) OR ((condominio_id = public.fn_mi_condominio_id()) AND (public.fn_mi_rol_id() = ANY (ARRAY[1, 3])))));


--
-- Name: vivienda_residente Lectura de vivienda_residente; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Lectura de vivienda_residente" ON public.vivienda_residente FOR SELECT TO authenticated USING (((usuario_id = ( SELECT auth.uid() AS uid)) OR public.fn_pertenezco_a_vivienda(vivienda_id) OR (EXISTS ( SELECT 1
   FROM public.viviendas v
  WHERE ((v.id = vivienda_residente.vivienda_id) AND (v.condominio_id = public.fn_mi_condominio_id()))))));


--
-- Name: vivienda_subusuarios Lectura de vivienda_subusuarios; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Lectura de vivienda_subusuarios" ON public.vivienda_subusuarios FOR SELECT TO authenticated USING (((usuario_id = ( SELECT auth.uid() AS uid)) OR (titular_id = ( SELECT auth.uid() AS uid)) OR public.fn_pertenezco_a_vivienda(vivienda_id) OR (EXISTS ( SELECT 1
   FROM public.viviendas v
  WHERE ((v.id = vivienda_subusuarios.vivienda_id) AND (v.condominio_id = public.fn_mi_condominio_id()))))));


--
-- Name: viviendas Lectura de viviendas; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Lectura de viviendas" ON public.viviendas FOR SELECT TO authenticated USING (((condominio_id = public.fn_mi_condominio_id()) OR public.fn_pertenezco_a_vivienda(id)));


--
-- Name: version Lectura pública de version; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Lectura pública de version" ON public.version FOR SELECT USING (true);


--
-- Name: areas_comunes; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.areas_comunes ENABLE ROW LEVEL SECURITY;

--
-- Name: areas_comunes_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.areas_comunes_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: avisos; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.avisos ENABLE ROW LEVEL SECURITY;

--
-- Name: avisos_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.avisos_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: cargos; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.cargos ENABLE ROW LEVEL SECURITY;

--
-- Name: cargos_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.cargos_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: codigos_condominio; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.codigos_condominio ENABLE ROW LEVEL SECURITY;

--
-- Name: codigos_condominio_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.codigos_condominio_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: codigos_vivienda; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.codigos_vivienda ENABLE ROW LEVEL SECURITY;

--
-- Name: codigos_vivienda_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.codigos_vivienda_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: condominios; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.condominios ENABLE ROW LEVEL SECURITY;

--
-- Name: condominios_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.condominios_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: invitaciones_subusuarios; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.invitaciones_subusuarios ENABLE ROW LEVEL SECURITY;

--
-- Name: invitaciones_subusuarios_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.invitaciones_subusuarios_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: movimientos_saldo_favor; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.movimientos_saldo_favor ENABLE ROW LEVEL SECURITY;

--
-- Name: movimientos_saldo_favor_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.movimientos_saldo_favor_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: notificaciones; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

--
-- Name: notificaciones_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.notificaciones_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: pagos; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.pagos ENABLE ROW LEVEL SECURITY;

--
-- Name: pagos_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.pagos_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: paquetes; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.paquetes ENABLE ROW LEVEL SECURITY;

--
-- Name: paquetes_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.paquetes_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: plantillas_cargo; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.plantillas_cargo ENABLE ROW LEVEL SECURITY;

--
-- Name: plantillas_cargo_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.plantillas_cargo_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: reservas; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.reservas ENABLE ROW LEVEL SECURITY;

--
-- Name: reservas_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.reservas_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: roles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

--
-- Name: roles_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.roles_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: servicios_paqueteria; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.servicios_paqueteria ENABLE ROW LEVEL SECURITY;

--
-- Name: servicios_paqueteria_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.servicios_paqueteria_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

--
-- Name: usuarios_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.usuarios_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: version; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.version ENABLE ROW LEVEL SECURITY;

--
-- Name: version_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.version_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: visitas; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.visitas ENABLE ROW LEVEL SECURITY;

--
-- Name: visitas_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.visitas_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: vivienda_residente; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.vivienda_residente ENABLE ROW LEVEL SECURITY;

--
-- Name: vivienda_residente_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.vivienda_residente_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: vivienda_subusuarios; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.vivienda_subusuarios ENABLE ROW LEVEL SECURITY;

--
-- Name: vivienda_subusuarios_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.vivienda_subusuarios_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: viviendas; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.viviendas ENABLE ROW LEVEL SECURITY;

--
-- Name: viviendas_bitacora; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.viviendas_bitacora ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO anon;
GRANT ALL ON SCHEMA public TO authenticated;
GRANT ALL ON SCHEMA public TO service_role;
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT USAGE ON SCHEMA public TO authenticator;


--
-- Name: FUNCTION _insertar_notificacion_reserva(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text, p_reserva_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public._insertar_notificacion_reserva(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text, p_reserva_id uuid) TO service_role;


--
-- Name: FUNCTION _proyectar_paquete_dto(p_paquete_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public._proyectar_paquete_dto(p_paquete_id uuid) TO service_role;


--
-- Name: FUNCTION _proyectar_visita_dto(p_visita_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public._proyectar_visita_dto(p_visita_id uuid) TO service_role;


--
-- Name: FUNCTION _recalcular_estado_cargo(p_cargo_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public._recalcular_estado_cargo(p_cargo_id uuid) TO service_role;
GRANT ALL ON FUNCTION public._recalcular_estado_cargo(p_cargo_id uuid) TO authenticated;


--
-- Name: FUNCTION actualizar_bloqueo_area(p_actor_id uuid, p_bloqueo_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_motivo text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.actualizar_bloqueo_area(p_actor_id uuid, p_bloqueo_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_motivo text) TO service_role;


--
-- Name: FUNCTION alta_area_comun(p_actor_id uuid, p_condominio_id uuid, p_nombre text, p_descripcion text, p_hora_apertura time without time zone, p_hora_cierre time without time zone); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.alta_area_comun(p_actor_id uuid, p_condominio_id uuid, p_nombre text, p_descripcion text, p_hora_apertura time without time zone, p_hora_cierre time without time zone) TO service_role;


--
-- Name: FUNCTION alta_aviso(p_creado_por uuid, p_titulo text, p_contenido text, p_duracion_dias integer, p_fecha_expiracion timestamp with time zone, p_prioridad text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.alta_aviso(p_creado_por uuid, p_titulo text, p_contenido text, p_duracion_dias integer, p_fecha_expiracion timestamp with time zone, p_prioridad text) TO service_role;


--
-- Name: FUNCTION alta_condominio(p_nombre text, p_direccion text, p_zona_horaria text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.alta_condominio(p_nombre text, p_direccion text, p_zona_horaria text) TO service_role;


--
-- Name: FUNCTION alta_notificacion(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.alta_notificacion(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.alta_notificacion(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text) TO service_role;
GRANT ALL ON FUNCTION public.alta_notificacion(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text) TO authenticated;


--
-- Name: FUNCTION alta_paquete_esperado(p_actor_id uuid, p_vivienda_id integer, p_destinatario_nombre text, p_servicio_id integer, p_servicio_nombre text, p_numero_guia text, p_descripcion text, p_notas text, p_fecha_esperada_desde timestamp with time zone, p_fecha_esperada_hasta timestamp with time zone); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.alta_paquete_esperado(p_actor_id uuid, p_vivienda_id integer, p_destinatario_nombre text, p_servicio_id integer, p_servicio_nombre text, p_numero_guia text, p_descripcion text, p_notas text, p_fecha_esperada_desde timestamp with time zone, p_fecha_esperada_hasta timestamp with time zone) TO service_role;


--
-- Name: FUNCTION alta_servicio_paqueteria(p_condominio_id uuid, p_nombre text, p_icono_url text, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.alta_servicio_paqueteria(p_condominio_id uuid, p_nombre text, p_icono_url text, p_actor_id uuid) TO service_role;


--
-- Name: FUNCTION alta_usuario(p_id uuid, p_email text, p_nombre text, p_apellidos text, p_telefono text, p_rol_id integer, p_condominio_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.alta_usuario(p_id uuid, p_email text, p_nombre text, p_apellidos text, p_telefono text, p_rol_id integer, p_condominio_id uuid) TO service_role;


--
-- Name: FUNCTION alta_visita(p_actor_id uuid, p_vivienda_id integer, p_nombre_visitante character varying, p_apellidos_visitante character varying, p_telefono_visitante character varying, p_motivo character varying, p_num_acompanantes integer, p_vehiculo_placas character varying, p_notas text, p_fecha_llegada_esperada timestamp with time zone, p_horas_vigencia integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.alta_visita(p_actor_id uuid, p_vivienda_id integer, p_nombre_visitante character varying, p_apellidos_visitante character varying, p_telefono_visitante character varying, p_motivo character varying, p_num_acompanantes integer, p_vehiculo_placas character varying, p_notas text, p_fecha_llegada_esperada timestamp with time zone, p_horas_vigencia integer) TO service_role;


--
-- Name: FUNCTION alta_vivienda(p_condominio_id uuid, p_numero_casa text, p_tipo text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.alta_vivienda(p_condominio_id uuid, p_numero_casa text, p_tipo text) TO service_role;


--
-- Name: FUNCTION aprobar_reserva_admin(p_actor_id uuid, p_reserva_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.aprobar_reserva_admin(p_actor_id uuid, p_reserva_id uuid) TO service_role;


--
-- Name: FUNCTION aprobar_reserva_titular(p_actor_id uuid, p_reserva_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.aprobar_reserva_titular(p_actor_id uuid, p_reserva_id uuid) TO service_role;


--
-- Name: FUNCTION asignar_condominio_admin(p_usuario_id uuid, p_condominio_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.asignar_condominio_admin(p_usuario_id uuid, p_condominio_id uuid) TO service_role;


--
-- Name: FUNCTION asignar_residente(p_vivienda_id integer, p_usuario_id uuid, p_es_propietario boolean); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.asignar_residente(p_vivienda_id integer, p_usuario_id uuid, p_es_propietario boolean) TO service_role;


--
-- Name: FUNCTION asignar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.asignar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.asignar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.asignar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) TO authenticated;


--
-- Name: FUNCTION baja_area_comun(p_actor_id uuid, p_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.baja_area_comun(p_actor_id uuid, p_id uuid) TO service_role;


--
-- Name: FUNCTION baja_aviso(p_id uuid, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.baja_aviso(p_id uuid, p_actor_id uuid) TO service_role;


--
-- Name: FUNCTION baja_condominio(p_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.baja_condominio(p_id uuid) TO service_role;


--
-- Name: FUNCTION baja_servicio_paqueteria(p_id integer, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.baja_servicio_paqueteria(p_id integer, p_actor_id uuid) TO service_role;


--
-- Name: FUNCTION baja_subusuario(p_vivienda_id integer, p_usuario_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.baja_subusuario(p_vivienda_id integer, p_usuario_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.baja_subusuario(p_vivienda_id integer, p_usuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.baja_subusuario(p_vivienda_id integer, p_usuario_id uuid) TO authenticated;


--
-- Name: FUNCTION baja_usuario(p_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.baja_usuario(p_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.baja_usuario(p_id uuid) TO authenticated;


--
-- Name: FUNCTION baja_vivienda(p_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.baja_vivienda(p_id integer) TO service_role;


--
-- Name: FUNCTION cambio_area_comun(p_actor_id uuid, p_id uuid, p_nombre text, p_descripcion text, p_hora_apertura time without time zone, p_hora_cierre time without time zone); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.cambio_area_comun(p_actor_id uuid, p_id uuid, p_nombre text, p_descripcion text, p_hora_apertura time without time zone, p_hora_cierre time without time zone) TO service_role;


--
-- Name: FUNCTION cambio_aviso(p_id uuid, p_actor_id uuid, p_titulo text, p_contenido text, p_duracion_dias integer, p_fecha_expiracion timestamp with time zone, p_prioridad text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.cambio_aviso(p_id uuid, p_actor_id uuid, p_titulo text, p_contenido text, p_duracion_dias integer, p_fecha_expiracion timestamp with time zone, p_prioridad text) TO service_role;


--
-- Name: FUNCTION cambio_condominio(p_id uuid, p_nombre text, p_direccion text, p_activo boolean, p_zona_horaria text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.cambio_condominio(p_id uuid, p_nombre text, p_direccion text, p_activo boolean, p_zona_horaria text) TO service_role;


--
-- Name: FUNCTION cambio_paquete_esperado(p_id uuid, p_actor_id uuid, p_destinatario_nombre text, p_servicio_id integer, p_servicio_nombre text, p_numero_guia text, p_descripcion text, p_notas text, p_fecha_esperada_desde timestamp with time zone, p_fecha_esperada_hasta timestamp with time zone); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.cambio_paquete_esperado(p_id uuid, p_actor_id uuid, p_destinatario_nombre text, p_servicio_id integer, p_servicio_nombre text, p_numero_guia text, p_descripcion text, p_notas text, p_fecha_esperada_desde timestamp with time zone, p_fecha_esperada_hasta timestamp with time zone) TO service_role;


--
-- Name: FUNCTION cambio_usuario(p_id uuid, p_nombre text, p_apellidos text, p_telefono text, p_rol_id integer, p_condominio_id uuid, p_debe_cambiar_password boolean); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.cambio_usuario(p_id uuid, p_nombre text, p_apellidos text, p_telefono text, p_rol_id integer, p_condominio_id uuid, p_debe_cambiar_password boolean) TO service_role;
GRANT ALL ON FUNCTION public.cambio_usuario(p_id uuid, p_nombre text, p_apellidos text, p_telefono text, p_rol_id integer, p_condominio_id uuid, p_debe_cambiar_password boolean) TO authenticated;


--
-- Name: FUNCTION cambio_visita(p_id uuid, p_actor_id uuid, p_nombre_visitante character varying, p_apellidos_visitante character varying, p_telefono_visitante character varying, p_motivo character varying, p_num_acompanantes integer, p_vehiculo_placas character varying, p_notas text, p_fecha_llegada_esperada timestamp with time zone, p_horas_vigencia integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.cambio_visita(p_id uuid, p_actor_id uuid, p_nombre_visitante character varying, p_apellidos_visitante character varying, p_telefono_visitante character varying, p_motivo character varying, p_num_acompanantes integer, p_vehiculo_placas character varying, p_notas text, p_fecha_llegada_esperada timestamp with time zone, p_horas_vigencia integer) TO service_role;


--
-- Name: FUNCTION cambio_vivienda(p_id integer, p_numero_casa text, p_tipo text, p_activo boolean); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.cambio_vivienda(p_id integer, p_numero_casa text, p_tipo text, p_activo boolean) TO service_role;


--
-- Name: FUNCTION cancelar_invitacion_subusuario(p_id uuid, p_invitacion_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.cancelar_invitacion_subusuario(p_id uuid, p_invitacion_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.cancelar_invitacion_subusuario(p_id uuid, p_invitacion_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.cancelar_invitacion_subusuario(p_id uuid, p_invitacion_id uuid) TO authenticated;


--
-- Name: FUNCTION cancelar_paquete_esperado(p_id uuid, p_actor_id uuid, p_motivo text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.cancelar_paquete_esperado(p_id uuid, p_actor_id uuid, p_motivo text) TO service_role;


--
-- Name: FUNCTION cancelar_reserva_admin(p_actor_id uuid, p_reserva_id uuid, p_motivo text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.cancelar_reserva_admin(p_actor_id uuid, p_reserva_id uuid, p_motivo text) TO service_role;


--
-- Name: FUNCTION cancelar_reserva_usuario(p_actor_id uuid, p_reserva_id uuid, p_motivo text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.cancelar_reserva_usuario(p_actor_id uuid, p_reserva_id uuid, p_motivo text) TO service_role;


--
-- Name: FUNCTION cancelar_reserva(p_actor_id uuid, p_reserva_id uuid, p_motivo text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.cancelar_reserva(p_actor_id uuid, p_reserva_id uuid, p_motivo text) TO service_role;


--
-- Name: FUNCTION cancelar_visita(p_id uuid, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.cancelar_visita(p_id uuid, p_actor_id uuid) TO service_role;


--
-- Name: FUNCTION confirmar_reserva(p_actor_id uuid, p_reserva_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.confirmar_reserva(p_actor_id uuid, p_reserva_id uuid) TO service_role;


--
-- Name: FUNCTION crear_bloqueo_area(p_actor_id uuid, p_area_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_motivo text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.crear_bloqueo_area(p_actor_id uuid, p_area_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_motivo text) TO service_role;


--
-- Name: FUNCTION crear_notificacion(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.crear_notificacion(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text) TO service_role;


--
-- Name: FUNCTION desasignar_residente(p_vivienda_id integer, p_usuario_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.desasignar_residente(p_vivienda_id integer, p_usuario_id uuid) TO service_role;


--
-- Name: FUNCTION eliminar_bloqueo_area(p_actor_id uuid, p_bloqueo_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.eliminar_bloqueo_area(p_actor_id uuid, p_bloqueo_id uuid) TO service_role;


--
-- Name: FUNCTION entregar_paquete_residente(p_paquete_id uuid, p_entregado_a_nombre text, p_foto_url text, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.entregar_paquete_residente(p_paquete_id uuid, p_entregado_a_nombre text, p_foto_url text, p_actor_id uuid) TO service_role;


--
-- Name: FUNCTION fn_auditoria(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_auditoria() TO service_role;


--
-- Name: FUNCTION fn_generar_codigo_invitacion_subusuario(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_generar_codigo_invitacion_subusuario() TO service_role;
GRANT ALL ON FUNCTION public.fn_generar_codigo_invitacion_subusuario() TO authenticated;


--
-- Name: FUNCTION fn_mi_condominio_id(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_mi_condominio_id() TO service_role;
GRANT ALL ON FUNCTION public.fn_mi_condominio_id() TO authenticated;


--
-- Name: FUNCTION fn_mi_rol_id(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_mi_rol_id() TO service_role;
GRANT ALL ON FUNCTION public.fn_mi_rol_id() TO authenticated;


--
-- Name: FUNCTION fn_pertenezco_a_vivienda(p_vivienda_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_pertenezco_a_vivienda(p_vivienda_id integer) TO service_role;
GRANT ALL ON FUNCTION public.fn_pertenezco_a_vivienda(p_vivienda_id integer) TO authenticated;


--
-- Name: FUNCTION fn_soy_titular_vivienda(p_vivienda_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_soy_titular_vivienda(p_vivienda_id integer) TO service_role;
GRANT ALL ON FUNCTION public.fn_soy_titular_vivienda(p_vivienda_id integer) TO authenticated;


--
-- Name: FUNCTION fn_sync_usuario_app_metadata(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.fn_sync_usuario_app_metadata() TO service_role;


--
-- Name: FUNCTION generar_codigo_condominio(p_condominio_id uuid, p_minutos_vigencia integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.generar_codigo_condominio(p_condominio_id uuid, p_minutos_vigencia integer) TO service_role;


--
-- Name: FUNCTION generar_codigo_vivienda(p_vivienda_id integer, p_minutos_vigencia integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.generar_codigo_vivienda(p_vivienda_id integer, p_minutos_vigencia integer) TO service_role;


--
-- Name: FUNCTION handle_new_user(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.handle_new_user() TO service_role;


--
-- Name: FUNCTION handle_user_metadata_update(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.handle_user_metadata_update() TO service_role;


--
-- Name: TABLE condominios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.condominios TO service_role;
GRANT SELECT ON TABLE public.condominios TO authenticated;


--
-- Name: TABLE invitaciones_subusuarios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.invitaciones_subusuarios TO service_role;


--
-- Name: TABLE usuarios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.usuarios TO service_role;
GRANT SELECT ON TABLE public.usuarios TO authenticated;


--
-- Name: TABLE viviendas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.viviendas TO service_role;
GRANT SELECT ON TABLE public.viviendas TO authenticated;


--
-- Name: TABLE vw_invitaciones_subusuarios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_invitaciones_subusuarios TO service_role;
GRANT SELECT,MAINTAIN ON TABLE public.vw_invitaciones_subusuarios TO authenticated;


--
-- Name: FUNCTION invitar_subusuario(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.invitar_subusuario(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.invitar_subusuario(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) TO service_role;
GRANT ALL ON FUNCTION public.invitar_subusuario(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) TO authenticated;


--
-- Name: FUNCTION invitar_subusuario_por_email(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.invitar_subusuario_por_email(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.invitar_subusuario_por_email(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) TO service_role;
GRANT ALL ON FUNCTION public.invitar_subusuario_por_email(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) TO authenticated;


--
-- Name: FUNCTION liberar_notificacion_push(p_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.liberar_notificacion_push(p_id uuid) TO service_role;


--
-- Name: FUNCTION marcar_notificacion_leida(p_notificacion_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.marcar_notificacion_leida(p_notificacion_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.marcar_notificacion_leida(p_notificacion_id uuid) TO authenticated;


--
-- Name: FUNCTION marcar_notificacion_leida(p_id uuid, p_usuario_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.marcar_notificacion_leida(p_id uuid, p_usuario_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.marcar_notificacion_leida(p_id uuid, p_usuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.marcar_notificacion_leida(p_id uuid, p_usuario_id uuid) TO authenticated;


--
-- Name: FUNCTION marcar_notificacion_push_enviada(p_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.marcar_notificacion_push_enviada(p_id uuid) TO service_role;


--
-- Name: FUNCTION marcar_reserva_no_utilizada(p_actor_id uuid, p_reserva_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.marcar_reserva_no_utilizada(p_actor_id uuid, p_reserva_id uuid) TO service_role;


--
-- Name: FUNCTION marcar_todas_notificaciones_leidas(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.marcar_todas_notificaciones_leidas() TO service_role;
GRANT ALL ON FUNCTION public.marcar_todas_notificaciones_leidas() TO authenticated;


--
-- Name: FUNCTION marcar_todas_notificaciones_leidas(p_usuario_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.marcar_todas_notificaciones_leidas(p_usuario_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.marcar_todas_notificaciones_leidas(p_usuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.marcar_todas_notificaciones_leidas(p_usuario_id uuid) TO authenticated;


--
-- Name: FUNCTION procesar_transiciones_reservas(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.procesar_transiciones_reservas() TO service_role;


--
-- Name: FUNCTION quitar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.quitar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.quitar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.quitar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) TO authenticated;


--
-- Name: FUNCTION reactivar_area_comun(p_actor_id uuid, p_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.reactivar_area_comun(p_actor_id uuid, p_id uuid) TO service_role;


--
-- Name: FUNCTION reactivar_usuario(p_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.reactivar_usuario(p_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.reactivar_usuario(p_id uuid) TO authenticated;


--
-- Name: FUNCTION rechazar_reserva_admin(p_actor_id uuid, p_reserva_id uuid, p_motivo text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.rechazar_reserva_admin(p_actor_id uuid, p_reserva_id uuid, p_motivo text) TO service_role;


--
-- Name: FUNCTION rechazar_reserva_titular(p_actor_id uuid, p_reserva_id uuid, p_motivo text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.rechazar_reserva_titular(p_actor_id uuid, p_reserva_id uuid, p_motivo text) TO service_role;


--
-- Name: FUNCTION recibir_paquete_caseta(p_paquete_id uuid, p_vivienda_id integer, p_destinatario_nombre text, p_servicio_id integer, p_servicio_nombre text, p_numero_guia text, p_descripcion text, p_ubicacion_almacen text, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.recibir_paquete_caseta(p_paquete_id uuid, p_vivienda_id integer, p_destinatario_nombre text, p_servicio_id integer, p_servicio_nombre text, p_numero_guia text, p_descripcion text, p_ubicacion_almacen text, p_actor_id uuid) TO service_role;


--
-- Name: FUNCTION reclamar_notificaciones_push_reservas(p_limite integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.reclamar_notificaciones_push_reservas(p_limite integer) TO service_role;


--
-- Name: FUNCTION redimir_codigo_condominio(p_codigo text, p_usuario_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.redimir_codigo_condominio(p_codigo text, p_usuario_id uuid) TO service_role;


--
-- Name: FUNCTION redimir_codigo_subusuario(p_codigo character varying, p_usuario_id uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.redimir_codigo_subusuario(p_codigo character varying, p_usuario_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.redimir_codigo_subusuario(p_codigo character varying, p_usuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.redimir_codigo_subusuario(p_codigo character varying, p_usuario_id uuid) TO authenticated;


--
-- Name: FUNCTION redimir_codigo_vivienda(p_codigo text, p_usuario_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.redimir_codigo_vivienda(p_codigo text, p_usuario_id uuid) TO service_role;


--
-- Name: FUNCTION registrar_entrada_visita(p_visita_id uuid, p_actor_id uuid, p_vehiculo_placas character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.registrar_entrada_visita(p_visita_id uuid, p_actor_id uuid, p_vehiculo_placas character varying) TO service_role;


--
-- Name: FUNCTION registrar_salida_visita(p_visita_id uuid, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.registrar_salida_visita(p_visita_id uuid, p_actor_id uuid) TO service_role;


--
-- Name: FUNCTION responder_invitacion_subusuario(p_invitacion_id uuid, p_usuario_id uuid, p_respuesta character varying); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.responder_invitacion_subusuario(p_invitacion_id uuid, p_usuario_id uuid, p_respuesta character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION public.responder_invitacion_subusuario(p_invitacion_id uuid, p_usuario_id uuid, p_respuesta character varying) TO service_role;
GRANT ALL ON FUNCTION public.responder_invitacion_subusuario(p_invitacion_id uuid, p_usuario_id uuid, p_respuesta character varying) TO authenticated;


--
-- Name: FUNCTION revocar_subusuario(p_vivienda_id integer, p_subusuario_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.revocar_subusuario(p_vivienda_id integer, p_subusuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.revocar_subusuario(p_vivienda_id integer, p_subusuario_id uuid) TO authenticated;


--
-- Name: FUNCTION rls_auto_enable(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.rls_auto_enable() TO service_role;


--
-- Name: FUNCTION rpc_anular_pago(p_pago_id uuid, p_motivo text, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.rpc_anular_pago(p_pago_id uuid, p_motivo text, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_anular_pago(p_pago_id uuid, p_motivo text, p_actor_id uuid) TO authenticated;


--
-- Name: FUNCTION rpc_aplicar_saldo_favor(p_cargo_id uuid, p_monto numeric, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.rpc_aplicar_saldo_favor(p_cargo_id uuid, p_monto numeric, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_aplicar_saldo_favor(p_cargo_id uuid, p_monto numeric, p_actor_id uuid) TO authenticated;


--
-- Name: FUNCTION rpc_cancelar_cargo(p_cargo_id uuid, p_motivo text, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.rpc_cancelar_cargo(p_cargo_id uuid, p_motivo text, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_cancelar_cargo(p_cargo_id uuid, p_motivo text, p_actor_id uuid) TO authenticated;


--
-- Name: FUNCTION rpc_confirmar_pago(p_pago_id uuid, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.rpc_confirmar_pago(p_pago_id uuid, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_confirmar_pago(p_pago_id uuid, p_actor_id uuid) TO authenticated;


--
-- Name: FUNCTION rpc_depurar_comprobantes_antiguos(p_dias_confirmados integer, p_dias_rechazados integer); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.rpc_depurar_comprobantes_antiguos(p_dias_confirmados integer, p_dias_rechazados integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.rpc_depurar_comprobantes_antiguos(p_dias_confirmados integer, p_dias_rechazados integer) TO service_role;


--
-- Name: FUNCTION rpc_generar_cargos_mensuales(p_periodo date, p_condominio_id uuid, p_creado_por uuid); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.rpc_generar_cargos_mensuales(p_periodo date, p_condominio_id uuid, p_creado_por uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.rpc_generar_cargos_mensuales(p_periodo date, p_condominio_id uuid, p_creado_por uuid) TO service_role;


--
-- Name: FUNCTION rpc_rechazar_pago(p_pago_id uuid, p_motivo text, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.rpc_rechazar_pago(p_pago_id uuid, p_motivo text, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_rechazar_pago(p_pago_id uuid, p_motivo text, p_actor_id uuid) TO authenticated;


--
-- Name: FUNCTION rpc_registrar_pago(p_cargo_id uuid, p_monto numeric, p_fecha_pago date, p_metodo text, p_origen text, p_estado text, p_referencia text, p_banco_origen text, p_comprobante_ruta text, p_comprobante_hash text, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.rpc_registrar_pago(p_cargo_id uuid, p_monto numeric, p_fecha_pago date, p_metodo text, p_origen text, p_estado text, p_referencia text, p_banco_origen text, p_comprobante_ruta text, p_comprobante_hash text, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_registrar_pago(p_cargo_id uuid, p_monto numeric, p_fecha_pago date, p_metodo text, p_origen text, p_estado text, p_referencia text, p_banco_origen text, p_comprobante_ruta text, p_comprobante_hash text, p_actor_id uuid) TO authenticated;


--
-- Name: FUNCTION rpc_revertir_aplicacion_saldo(p_movimiento_id uuid, p_motivo text, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.rpc_revertir_aplicacion_saldo(p_movimiento_id uuid, p_motivo text, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_revertir_aplicacion_saldo(p_movimiento_id uuid, p_motivo text, p_actor_id uuid) TO authenticated;


--
-- Name: FUNCTION solicitar_reserva(p_actor_id uuid, p_area_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.solicitar_reserva(p_actor_id uuid, p_area_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone) TO service_role;


--
-- Name: FUNCTION validar_codigo_visita(p_codigo character varying, p_actor_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.validar_codigo_visita(p_codigo character varying, p_actor_id uuid) TO service_role;


--
-- Name: TABLE areas_comunes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.areas_comunes TO service_role;
GRANT SELECT ON TABLE public.areas_comunes TO authenticated;


--
-- Name: TABLE areas_comunes_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.areas_comunes_bitacora TO service_role;


--
-- Name: SEQUENCE areas_comunes_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.areas_comunes_bitacora_id_seq TO service_role;


--
-- Name: TABLE avisos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.avisos TO service_role;
GRANT SELECT ON TABLE public.avisos TO authenticated;


--
-- Name: TABLE avisos_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.avisos_bitacora TO service_role;


--
-- Name: SEQUENCE avisos_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.avisos_bitacora_id_seq TO service_role;


--
-- Name: TABLE cargos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.cargos TO service_role;


--
-- Name: TABLE cargos_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.cargos_bitacora TO service_role;


--
-- Name: SEQUENCE cargos_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.cargos_bitacora_id_seq TO service_role;


--
-- Name: TABLE codigos_condominio; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.codigos_condominio TO service_role;


--
-- Name: TABLE codigos_condominio_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.codigos_condominio_bitacora TO service_role;


--
-- Name: SEQUENCE codigos_condominio_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.codigos_condominio_bitacora_id_seq TO service_role;


--
-- Name: TABLE codigos_vivienda; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.codigos_vivienda TO service_role;


--
-- Name: TABLE codigos_vivienda_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.codigos_vivienda_bitacora TO service_role;


--
-- Name: SEQUENCE codigos_vivienda_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.codigos_vivienda_bitacora_id_seq TO service_role;


--
-- Name: TABLE condominios_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.condominios_bitacora TO service_role;


--
-- Name: SEQUENCE condominios_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.condominios_bitacora_id_seq TO service_role;


--
-- Name: TABLE invitaciones_subusuarios_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.invitaciones_subusuarios_bitacora TO service_role;


--
-- Name: SEQUENCE invitaciones_subusuarios_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.invitaciones_subusuarios_bitacora_id_seq TO service_role;


--
-- Name: TABLE movimientos_saldo_favor; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.movimientos_saldo_favor TO service_role;


--
-- Name: TABLE movimientos_saldo_favor_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.movimientos_saldo_favor_bitacora TO service_role;


--
-- Name: SEQUENCE movimientos_saldo_favor_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.movimientos_saldo_favor_bitacora_id_seq TO service_role;


--
-- Name: TABLE notificaciones; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.notificaciones TO service_role;
GRANT SELECT ON TABLE public.notificaciones TO authenticated;


--
-- Name: TABLE notificaciones_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.notificaciones_bitacora TO service_role;


--
-- Name: SEQUENCE notificaciones_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.notificaciones_bitacora_id_seq TO service_role;


--
-- Name: TABLE pagos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.pagos TO service_role;


--
-- Name: TABLE pagos_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.pagos_bitacora TO service_role;


--
-- Name: SEQUENCE pagos_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.pagos_bitacora_id_seq TO service_role;


--
-- Name: TABLE paquetes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.paquetes TO service_role;
GRANT SELECT ON TABLE public.paquetes TO authenticated;


--
-- Name: TABLE paquetes_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.paquetes_bitacora TO service_role;


--
-- Name: SEQUENCE paquetes_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.paquetes_bitacora_id_seq TO service_role;


--
-- Name: TABLE plantillas_cargo; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.plantillas_cargo TO service_role;


--
-- Name: TABLE plantillas_cargo_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.plantillas_cargo_bitacora TO service_role;


--
-- Name: SEQUENCE plantillas_cargo_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.plantillas_cargo_bitacora_id_seq TO service_role;


--
-- Name: TABLE reservas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.reservas TO service_role;
GRANT SELECT ON TABLE public.reservas TO authenticated;


--
-- Name: TABLE reservas_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.reservas_bitacora TO service_role;


--
-- Name: SEQUENCE reservas_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.reservas_bitacora_id_seq TO service_role;


--
-- Name: TABLE roles; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.roles TO service_role;
GRANT SELECT ON TABLE public.roles TO anon;
GRANT SELECT ON TABLE public.roles TO authenticated;


--
-- Name: TABLE roles_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.roles_bitacora TO service_role;


--
-- Name: SEQUENCE roles_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.roles_bitacora_id_seq TO service_role;


--
-- Name: TABLE servicios_paqueteria; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.servicios_paqueteria TO service_role;
GRANT SELECT ON TABLE public.servicios_paqueteria TO authenticated;


--
-- Name: TABLE servicios_paqueteria_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.servicios_paqueteria_bitacora TO service_role;


--
-- Name: SEQUENCE servicios_paqueteria_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.servicios_paqueteria_bitacora_id_seq TO service_role;


--
-- Name: SEQUENCE servicios_paqueteria_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.servicios_paqueteria_id_seq TO service_role;


--
-- Name: TABLE usuarios_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.usuarios_bitacora TO service_role;


--
-- Name: SEQUENCE usuarios_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.usuarios_bitacora_id_seq TO service_role;


--
-- Name: TABLE vw_cargos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_cargos TO service_role;
GRANT SELECT,MAINTAIN ON TABLE public.vw_cargos TO authenticated;


--
-- Name: TABLE v_saldo_vivienda; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.v_saldo_vivienda TO service_role;
GRANT SELECT,MAINTAIN ON TABLE public.v_saldo_vivienda TO authenticated;


--
-- Name: TABLE version; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.version TO service_role;
GRANT SELECT ON TABLE public.version TO anon;
GRANT SELECT ON TABLE public.version TO authenticated;


--
-- Name: TABLE version_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.version_bitacora TO service_role;


--
-- Name: SEQUENCE version_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.version_bitacora_id_seq TO service_role;


--
-- Name: SEQUENCE version_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.version_id_seq TO service_role;


--
-- Name: TABLE visitas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.visitas TO service_role;
GRANT SELECT ON TABLE public.visitas TO authenticated;


--
-- Name: TABLE visitas_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.visitas_bitacora TO service_role;


--
-- Name: SEQUENCE visitas_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.visitas_bitacora_id_seq TO service_role;


--
-- Name: TABLE vivienda_residente; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vivienda_residente TO service_role;
GRANT SELECT ON TABLE public.vivienda_residente TO authenticated;


--
-- Name: TABLE vivienda_residente_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vivienda_residente_bitacora TO service_role;


--
-- Name: SEQUENCE vivienda_residente_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.vivienda_residente_bitacora_id_seq TO service_role;


--
-- Name: SEQUENCE vivienda_residente_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.vivienda_residente_id_seq TO service_role;


--
-- Name: TABLE vivienda_subusuarios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vivienda_subusuarios TO service_role;
GRANT SELECT ON TABLE public.vivienda_subusuarios TO authenticated;


--
-- Name: TABLE vivienda_subusuarios_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vivienda_subusuarios_bitacora TO service_role;


--
-- Name: SEQUENCE vivienda_subusuarios_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.vivienda_subusuarios_bitacora_id_seq TO service_role;


--
-- Name: TABLE viviendas_bitacora; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.viviendas_bitacora TO service_role;


--
-- Name: SEQUENCE viviendas_bitacora_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.viviendas_bitacora_id_seq TO service_role;


--
-- Name: SEQUENCE viviendas_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.viviendas_id_seq TO service_role;


--
-- Name: TABLE vw_areas_comunes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_areas_comunes TO service_role;
GRANT SELECT ON TABLE public.vw_areas_comunes TO authenticated;


--
-- Name: TABLE vw_avisos_historico; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_avisos_historico TO service_role;
GRANT SELECT ON TABLE public.vw_avisos_historico TO authenticated;


--
-- Name: TABLE vw_avisos_vigentes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_avisos_vigentes TO service_role;
GRANT SELECT ON TABLE public.vw_avisos_vigentes TO authenticated;


--
-- Name: TABLE vw_calendario_reservas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_calendario_reservas TO service_role;
GRANT SELECT ON TABLE public.vw_calendario_reservas TO authenticated;


--
-- Name: TABLE vw_calendario_reservas_limitado; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_calendario_reservas_limitado TO service_role;
GRANT SELECT ON TABLE public.vw_calendario_reservas_limitado TO authenticated;


--
-- Name: TABLE vw_condominios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_condominios TO service_role;
GRANT SELECT ON TABLE public.vw_condominios TO authenticated;


--
-- Name: TABLE vw_mis_paquetes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_mis_paquetes TO service_role;
GRANT SELECT ON TABLE public.vw_mis_paquetes TO authenticated;


--
-- Name: TABLE vw_mis_visitas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_mis_visitas TO service_role;
GRANT SELECT ON TABLE public.vw_mis_visitas TO authenticated;


--
-- Name: TABLE vw_mis_viviendas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_mis_viviendas TO service_role;
GRANT SELECT ON TABLE public.vw_mis_viviendas TO authenticated;


--
-- Name: TABLE vw_movimientos_saldo_favor; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_movimientos_saldo_favor TO service_role;
GRANT SELECT,MAINTAIN ON TABLE public.vw_movimientos_saldo_favor TO authenticated;


--
-- Name: TABLE vw_no_shows; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_no_shows TO service_role;
GRANT SELECT ON TABLE public.vw_no_shows TO authenticated;


--
-- Name: TABLE vw_notificaciones; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_notificaciones TO service_role;
GRANT SELECT ON TABLE public.vw_notificaciones TO authenticated;


--
-- Name: TABLE vw_pagos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_pagos TO service_role;
GRANT SELECT,MAINTAIN ON TABLE public.vw_pagos TO authenticated;


--
-- Name: TABLE vw_paquetes_caseta; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_paquetes_caseta TO service_role;
GRANT SELECT ON TABLE public.vw_paquetes_caseta TO authenticated;


--
-- Name: TABLE vw_paquetes_historico; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_paquetes_historico TO service_role;
GRANT SELECT ON TABLE public.vw_paquetes_historico TO authenticated;


--
-- Name: TABLE vw_paquetes_residente; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_paquetes_residente TO service_role;
GRANT SELECT ON TABLE public.vw_paquetes_residente TO authenticated;


--
-- Name: TABLE vw_plantillas_cargo; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_plantillas_cargo TO service_role;
GRANT SELECT,MAINTAIN ON TABLE public.vw_plantillas_cargo TO authenticated;


--
-- Name: TABLE vw_reservas_admin; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_reservas_admin TO service_role;
GRANT SELECT ON TABLE public.vw_reservas_admin TO authenticated;


--
-- Name: TABLE vw_reservas_pendientes_titular; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_reservas_pendientes_titular TO service_role;
GRANT SELECT ON TABLE public.vw_reservas_pendientes_titular TO authenticated;


--
-- Name: TABLE vw_reservas_usuario; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_reservas_usuario TO service_role;
GRANT SELECT ON TABLE public.vw_reservas_usuario TO authenticated;


--
-- Name: TABLE vw_residentes_sin_vivienda; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_residentes_sin_vivienda TO service_role;
GRANT SELECT ON TABLE public.vw_residentes_sin_vivienda TO authenticated;


--
-- Name: TABLE vw_servicios_paqueteria; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_servicios_paqueteria TO service_role;
GRANT SELECT ON TABLE public.vw_servicios_paqueteria TO authenticated;


--
-- Name: TABLE vw_subusuarios_vivienda; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_subusuarios_vivienda TO service_role;
GRANT SELECT ON TABLE public.vw_subusuarios_vivienda TO authenticated;


--
-- Name: TABLE vw_usuarios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_usuarios TO service_role;
GRANT SELECT ON TABLE public.vw_usuarios TO authenticated;


--
-- Name: TABLE vw_version; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_version TO service_role;
GRANT SELECT ON TABLE public.vw_version TO anon;
GRANT SELECT ON TABLE public.vw_version TO authenticated;


--
-- Name: TABLE vw_vigilantes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_vigilantes TO service_role;
GRANT SELECT ON TABLE public.vw_vigilantes TO authenticated;


--
-- Name: TABLE vw_visitas_historico; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_visitas_historico TO service_role;
GRANT SELECT ON TABLE public.vw_visitas_historico TO authenticated;


--
-- Name: TABLE vw_visitas_proximas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_visitas_proximas TO service_role;
GRANT SELECT ON TABLE public.vw_visitas_proximas TO authenticated;


--
-- Name: TABLE vw_vivienda_subusuarios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_vivienda_subusuarios TO service_role;
GRANT SELECT ON TABLE public.vw_vivienda_subusuarios TO authenticated;


--
-- Name: TABLE vw_vivienda_usuarios; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_vivienda_usuarios TO service_role;
GRANT SELECT ON TABLE public.vw_vivienda_usuarios TO authenticated;


--
-- Name: TABLE vw_viviendas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_viviendas TO service_role;
GRANT SELECT ON TABLE public.vw_viviendas TO authenticated;


--
-- Name: TABLE vw_viviendas_con_residentes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_viviendas_con_residentes TO service_role;
GRANT SELECT ON TABLE public.vw_viviendas_con_residentes TO authenticated;


--
-- Name: TABLE vw_viviendas_residentes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vw_viviendas_residentes TO service_role;
GRANT SELECT ON TABLE public.vw_viviendas_residentes TO authenticated;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--



-- 2.2 Permisos exactos sin importar los privilegios por defecto del proyecto:
--     se quita todo a anon/authenticated y se vuelven a aplicar solo los GRANT del esquema.
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;
GRANT ALL ON FUNCTION public._insertar_notificacion_reserva(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text, p_reserva_id uuid) TO service_role;
GRANT ALL ON FUNCTION public._proyectar_paquete_dto(p_paquete_id uuid) TO service_role;
GRANT ALL ON FUNCTION public._proyectar_visita_dto(p_visita_id uuid) TO service_role;
GRANT ALL ON FUNCTION public._recalcular_estado_cargo(p_cargo_id uuid) TO service_role;
GRANT ALL ON FUNCTION public._recalcular_estado_cargo(p_cargo_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.actualizar_bloqueo_area(p_actor_id uuid, p_bloqueo_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_motivo text) TO service_role;
GRANT ALL ON FUNCTION public.alta_area_comun(p_actor_id uuid, p_condominio_id uuid, p_nombre text, p_descripcion text, p_hora_apertura time without time zone, p_hora_cierre time without time zone) TO service_role;
GRANT ALL ON FUNCTION public.alta_aviso(p_creado_por uuid, p_titulo text, p_contenido text, p_duracion_dias integer, p_fecha_expiracion timestamp with time zone, p_prioridad text) TO service_role;
GRANT ALL ON FUNCTION public.alta_condominio(p_nombre text, p_direccion text, p_zona_horaria text) TO service_role;
REVOKE ALL ON FUNCTION public.alta_notificacion(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.alta_notificacion(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text) TO service_role;
GRANT ALL ON FUNCTION public.alta_notificacion(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text) TO authenticated;
GRANT ALL ON FUNCTION public.alta_paquete_esperado(p_actor_id uuid, p_vivienda_id integer, p_destinatario_nombre text, p_servicio_id integer, p_servicio_nombre text, p_numero_guia text, p_descripcion text, p_notas text, p_fecha_esperada_desde timestamp with time zone, p_fecha_esperada_hasta timestamp with time zone) TO service_role;
GRANT ALL ON FUNCTION public.alta_servicio_paqueteria(p_condominio_id uuid, p_nombre text, p_icono_url text, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.alta_usuario(p_id uuid, p_email text, p_nombre text, p_apellidos text, p_telefono text, p_rol_id integer, p_condominio_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.alta_visita(p_actor_id uuid, p_vivienda_id integer, p_nombre_visitante character varying, p_apellidos_visitante character varying, p_telefono_visitante character varying, p_motivo character varying, p_num_acompanantes integer, p_vehiculo_placas character varying, p_notas text, p_fecha_llegada_esperada timestamp with time zone, p_horas_vigencia integer) TO service_role;
GRANT ALL ON FUNCTION public.alta_vivienda(p_condominio_id uuid, p_numero_casa text, p_tipo text) TO service_role;
GRANT ALL ON FUNCTION public.aprobar_reserva_admin(p_actor_id uuid, p_reserva_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.aprobar_reserva_titular(p_actor_id uuid, p_reserva_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.asignar_condominio_admin(p_usuario_id uuid, p_condominio_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.asignar_residente(p_vivienda_id integer, p_usuario_id uuid, p_es_propietario boolean) TO service_role;
REVOKE ALL ON FUNCTION public.asignar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.asignar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.asignar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.baja_area_comun(p_actor_id uuid, p_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.baja_aviso(p_id uuid, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.baja_condominio(p_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.baja_servicio_paqueteria(p_id integer, p_actor_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.baja_subusuario(p_vivienda_id integer, p_usuario_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.baja_subusuario(p_vivienda_id integer, p_usuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.baja_subusuario(p_vivienda_id integer, p_usuario_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.baja_usuario(p_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.baja_usuario(p_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.baja_vivienda(p_id integer) TO service_role;
GRANT ALL ON FUNCTION public.cambio_area_comun(p_actor_id uuid, p_id uuid, p_nombre text, p_descripcion text, p_hora_apertura time without time zone, p_hora_cierre time without time zone) TO service_role;
GRANT ALL ON FUNCTION public.cambio_aviso(p_id uuid, p_actor_id uuid, p_titulo text, p_contenido text, p_duracion_dias integer, p_fecha_expiracion timestamp with time zone, p_prioridad text) TO service_role;
GRANT ALL ON FUNCTION public.cambio_condominio(p_id uuid, p_nombre text, p_direccion text, p_activo boolean, p_zona_horaria text) TO service_role;
GRANT ALL ON FUNCTION public.cambio_paquete_esperado(p_id uuid, p_actor_id uuid, p_destinatario_nombre text, p_servicio_id integer, p_servicio_nombre text, p_numero_guia text, p_descripcion text, p_notas text, p_fecha_esperada_desde timestamp with time zone, p_fecha_esperada_hasta timestamp with time zone) TO service_role;
GRANT ALL ON FUNCTION public.cambio_usuario(p_id uuid, p_nombre text, p_apellidos text, p_telefono text, p_rol_id integer, p_condominio_id uuid, p_debe_cambiar_password boolean) TO service_role;
GRANT ALL ON FUNCTION public.cambio_usuario(p_id uuid, p_nombre text, p_apellidos text, p_telefono text, p_rol_id integer, p_condominio_id uuid, p_debe_cambiar_password boolean) TO authenticated;
GRANT ALL ON FUNCTION public.cambio_visita(p_id uuid, p_actor_id uuid, p_nombre_visitante character varying, p_apellidos_visitante character varying, p_telefono_visitante character varying, p_motivo character varying, p_num_acompanantes integer, p_vehiculo_placas character varying, p_notas text, p_fecha_llegada_esperada timestamp with time zone, p_horas_vigencia integer) TO service_role;
GRANT ALL ON FUNCTION public.cambio_vivienda(p_id integer, p_numero_casa text, p_tipo text, p_activo boolean) TO service_role;
REVOKE ALL ON FUNCTION public.cancelar_invitacion_subusuario(p_id uuid, p_invitacion_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.cancelar_invitacion_subusuario(p_id uuid, p_invitacion_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.cancelar_invitacion_subusuario(p_id uuid, p_invitacion_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.cancelar_paquete_esperado(p_id uuid, p_actor_id uuid, p_motivo text) TO service_role;
GRANT ALL ON FUNCTION public.cancelar_reserva_admin(p_actor_id uuid, p_reserva_id uuid, p_motivo text) TO service_role;
GRANT ALL ON FUNCTION public.cancelar_reserva_usuario(p_actor_id uuid, p_reserva_id uuid, p_motivo text) TO service_role;
GRANT ALL ON FUNCTION public.cancelar_visita(p_id uuid, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.confirmar_reserva(p_actor_id uuid, p_reserva_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.crear_bloqueo_area(p_actor_id uuid, p_area_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_motivo text) TO service_role;
GRANT ALL ON FUNCTION public.crear_notificacion(p_usuario_id uuid, p_tipo_evento character varying, p_titulo character varying, p_mensaje text, p_url_redireccion text) TO service_role;
GRANT ALL ON FUNCTION public.desasignar_residente(p_vivienda_id integer, p_usuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.eliminar_bloqueo_area(p_actor_id uuid, p_bloqueo_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.entregar_paquete_residente(p_paquete_id uuid, p_entregado_a_nombre text, p_foto_url text, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.fn_auditoria() TO service_role;
GRANT ALL ON FUNCTION public.fn_generar_codigo_invitacion_subusuario() TO service_role;
GRANT ALL ON FUNCTION public.fn_generar_codigo_invitacion_subusuario() TO authenticated;
GRANT ALL ON FUNCTION public.fn_mi_condominio_id() TO service_role;
GRANT ALL ON FUNCTION public.fn_mi_condominio_id() TO authenticated;
GRANT ALL ON FUNCTION public.fn_mi_rol_id() TO service_role;
GRANT ALL ON FUNCTION public.fn_mi_rol_id() TO authenticated;
GRANT ALL ON FUNCTION public.fn_pertenezco_a_vivienda(p_vivienda_id integer) TO service_role;
GRANT ALL ON FUNCTION public.fn_pertenezco_a_vivienda(p_vivienda_id integer) TO authenticated;
GRANT ALL ON FUNCTION public.fn_soy_titular_vivienda(p_vivienda_id integer) TO service_role;
GRANT ALL ON FUNCTION public.fn_soy_titular_vivienda(p_vivienda_id integer) TO authenticated;
GRANT ALL ON FUNCTION public.fn_sync_usuario_app_metadata() TO service_role;
GRANT ALL ON FUNCTION public.generar_codigo_condominio(p_condominio_id uuid, p_minutos_vigencia integer) TO service_role;
GRANT ALL ON FUNCTION public.generar_codigo_vivienda(p_vivienda_id integer, p_minutos_vigencia integer) TO service_role;
GRANT ALL ON FUNCTION public.handle_new_user() TO service_role;
GRANT ALL ON FUNCTION public.handle_user_metadata_update() TO service_role;
GRANT ALL ON TABLE public.condominios TO service_role;
GRANT SELECT ON TABLE public.condominios TO authenticated;
GRANT ALL ON TABLE public.invitaciones_subusuarios TO service_role;
GRANT ALL ON TABLE public.usuarios TO service_role;
GRANT SELECT ON TABLE public.usuarios TO authenticated;
GRANT ALL ON TABLE public.viviendas TO service_role;
GRANT SELECT ON TABLE public.viviendas TO authenticated;
GRANT ALL ON TABLE public.vw_invitaciones_subusuarios TO service_role;
GRANT SELECT,MAINTAIN ON TABLE public.vw_invitaciones_subusuarios TO authenticated;
REVOKE ALL ON FUNCTION public.invitar_subusuario(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.invitar_subusuario(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) TO service_role;
GRANT ALL ON FUNCTION public.invitar_subusuario(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.invitar_subusuario_por_email(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.invitar_subusuario_por_email(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) TO service_role;
GRANT ALL ON FUNCTION public.invitar_subusuario_por_email(p_vivienda_id integer, p_email character varying, p_parentesco character varying, p_creado_por uuid) TO authenticated;
GRANT ALL ON FUNCTION public.liberar_notificacion_push(p_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.marcar_notificacion_leida(p_notificacion_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.marcar_notificacion_leida(p_notificacion_id uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.marcar_notificacion_leida(p_id uuid, p_usuario_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.marcar_notificacion_leida(p_id uuid, p_usuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.marcar_notificacion_leida(p_id uuid, p_usuario_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.marcar_notificacion_push_enviada(p_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.marcar_reserva_no_utilizada(p_actor_id uuid, p_reserva_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.marcar_todas_notificaciones_leidas() TO service_role;
GRANT ALL ON FUNCTION public.marcar_todas_notificaciones_leidas() TO authenticated;
REVOKE ALL ON FUNCTION public.marcar_todas_notificaciones_leidas(p_usuario_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.marcar_todas_notificaciones_leidas(p_usuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.marcar_todas_notificaciones_leidas(p_usuario_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.procesar_transiciones_reservas() TO service_role;
REVOKE ALL ON FUNCTION public.quitar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.quitar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.quitar_residente_vivienda(p_vivienda_id integer, p_usuario_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.reactivar_area_comun(p_actor_id uuid, p_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.reactivar_usuario(p_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.reactivar_usuario(p_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.rechazar_reserva_admin(p_actor_id uuid, p_reserva_id uuid, p_motivo text) TO service_role;
GRANT ALL ON FUNCTION public.rechazar_reserva_titular(p_actor_id uuid, p_reserva_id uuid, p_motivo text) TO service_role;
GRANT ALL ON FUNCTION public.recibir_paquete_caseta(p_paquete_id uuid, p_vivienda_id integer, p_destinatario_nombre text, p_servicio_id integer, p_servicio_nombre text, p_numero_guia text, p_descripcion text, p_ubicacion_almacen text, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.reclamar_notificaciones_push_reservas(p_limite integer) TO service_role;
GRANT ALL ON FUNCTION public.redimir_codigo_condominio(p_codigo text, p_usuario_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.redimir_codigo_subusuario(p_codigo character varying, p_usuario_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.redimir_codigo_subusuario(p_codigo character varying, p_usuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.redimir_codigo_subusuario(p_codigo character varying, p_usuario_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.redimir_codigo_vivienda(p_codigo text, p_usuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.registrar_entrada_visita(p_visita_id uuid, p_actor_id uuid, p_vehiculo_placas character varying) TO service_role;
GRANT ALL ON FUNCTION public.registrar_salida_visita(p_visita_id uuid, p_actor_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.responder_invitacion_subusuario(p_invitacion_id uuid, p_usuario_id uuid, p_respuesta character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION public.responder_invitacion_subusuario(p_invitacion_id uuid, p_usuario_id uuid, p_respuesta character varying) TO service_role;
GRANT ALL ON FUNCTION public.responder_invitacion_subusuario(p_invitacion_id uuid, p_usuario_id uuid, p_respuesta character varying) TO authenticated;
GRANT ALL ON FUNCTION public.revocar_subusuario(p_vivienda_id integer, p_subusuario_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.revocar_subusuario(p_vivienda_id integer, p_subusuario_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.rls_auto_enable() TO service_role;
GRANT ALL ON FUNCTION public.rpc_anular_pago(p_pago_id uuid, p_motivo text, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_anular_pago(p_pago_id uuid, p_motivo text, p_actor_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.rpc_aplicar_saldo_favor(p_cargo_id uuid, p_monto numeric, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_aplicar_saldo_favor(p_cargo_id uuid, p_monto numeric, p_actor_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.rpc_cancelar_cargo(p_cargo_id uuid, p_motivo text, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_cancelar_cargo(p_cargo_id uuid, p_motivo text, p_actor_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.rpc_confirmar_pago(p_pago_id uuid, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_confirmar_pago(p_pago_id uuid, p_actor_id uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.rpc_depurar_comprobantes_antiguos(p_dias_confirmados integer, p_dias_rechazados integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.rpc_depurar_comprobantes_antiguos(p_dias_confirmados integer, p_dias_rechazados integer) TO service_role;
REVOKE ALL ON FUNCTION public.rpc_generar_cargos_mensuales(p_periodo date, p_condominio_id uuid, p_creado_por uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.rpc_generar_cargos_mensuales(p_periodo date, p_condominio_id uuid, p_creado_por uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_rechazar_pago(p_pago_id uuid, p_motivo text, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_rechazar_pago(p_pago_id uuid, p_motivo text, p_actor_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.rpc_registrar_pago(p_cargo_id uuid, p_monto numeric, p_fecha_pago date, p_metodo text, p_origen text, p_estado text, p_referencia text, p_banco_origen text, p_comprobante_ruta text, p_comprobante_hash text, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_registrar_pago(p_cargo_id uuid, p_monto numeric, p_fecha_pago date, p_metodo text, p_origen text, p_estado text, p_referencia text, p_banco_origen text, p_comprobante_ruta text, p_comprobante_hash text, p_actor_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.rpc_revertir_aplicacion_saldo(p_movimiento_id uuid, p_motivo text, p_actor_id uuid) TO service_role;
GRANT ALL ON FUNCTION public.rpc_revertir_aplicacion_saldo(p_movimiento_id uuid, p_motivo text, p_actor_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.solicitar_reserva(p_actor_id uuid, p_area_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone) TO service_role;
GRANT ALL ON FUNCTION public.validar_codigo_visita(p_codigo character varying, p_actor_id uuid) TO service_role;
GRANT ALL ON TABLE public.areas_comunes TO service_role;
GRANT SELECT ON TABLE public.areas_comunes TO authenticated;
GRANT ALL ON TABLE public.areas_comunes_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.areas_comunes_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.avisos TO service_role;
GRANT SELECT ON TABLE public.avisos TO authenticated;
GRANT ALL ON TABLE public.avisos_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.avisos_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.cargos TO service_role;
GRANT ALL ON TABLE public.cargos_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.cargos_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.codigos_condominio TO service_role;
GRANT ALL ON TABLE public.codigos_condominio_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.codigos_condominio_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.codigos_vivienda TO service_role;
GRANT ALL ON TABLE public.codigos_vivienda_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.codigos_vivienda_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.condominios_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.condominios_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.invitaciones_subusuarios_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.invitaciones_subusuarios_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.movimientos_saldo_favor TO service_role;
GRANT ALL ON TABLE public.movimientos_saldo_favor_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.movimientos_saldo_favor_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.notificaciones TO service_role;
GRANT SELECT ON TABLE public.notificaciones TO authenticated;
GRANT ALL ON TABLE public.notificaciones_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.notificaciones_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.pagos TO service_role;
GRANT ALL ON TABLE public.pagos_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.pagos_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.paquetes TO service_role;
GRANT SELECT ON TABLE public.paquetes TO authenticated;
GRANT ALL ON TABLE public.paquetes_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.paquetes_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.plantillas_cargo TO service_role;
GRANT ALL ON TABLE public.plantillas_cargo_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.plantillas_cargo_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.reservas TO service_role;
GRANT SELECT ON TABLE public.reservas TO authenticated;
GRANT ALL ON TABLE public.reservas_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.reservas_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.roles TO service_role;
GRANT SELECT ON TABLE public.roles TO anon;
GRANT SELECT ON TABLE public.roles TO authenticated;
GRANT ALL ON TABLE public.roles_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.roles_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.servicios_paqueteria TO service_role;
GRANT SELECT ON TABLE public.servicios_paqueteria TO authenticated;
GRANT ALL ON TABLE public.servicios_paqueteria_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.servicios_paqueteria_bitacora_id_seq TO service_role;
GRANT ALL ON SEQUENCE public.servicios_paqueteria_id_seq TO service_role;
GRANT ALL ON TABLE public.usuarios_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.usuarios_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.vw_cargos TO service_role;
GRANT SELECT,MAINTAIN ON TABLE public.vw_cargos TO authenticated;
GRANT ALL ON TABLE public.v_saldo_vivienda TO service_role;
GRANT SELECT,MAINTAIN ON TABLE public.v_saldo_vivienda TO authenticated;
GRANT ALL ON TABLE public.version TO service_role;
GRANT SELECT ON TABLE public.version TO anon;
GRANT SELECT ON TABLE public.version TO authenticated;
GRANT ALL ON TABLE public.version_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.version_bitacora_id_seq TO service_role;
GRANT ALL ON SEQUENCE public.version_id_seq TO service_role;
GRANT ALL ON TABLE public.visitas TO service_role;
GRANT SELECT ON TABLE public.visitas TO authenticated;
GRANT ALL ON TABLE public.visitas_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.visitas_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.vivienda_residente TO service_role;
GRANT SELECT ON TABLE public.vivienda_residente TO authenticated;
GRANT ALL ON TABLE public.vivienda_residente_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.vivienda_residente_bitacora_id_seq TO service_role;
GRANT ALL ON SEQUENCE public.vivienda_residente_id_seq TO service_role;
GRANT ALL ON TABLE public.vivienda_subusuarios TO service_role;
GRANT SELECT ON TABLE public.vivienda_subusuarios TO authenticated;
GRANT ALL ON TABLE public.vivienda_subusuarios_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.vivienda_subusuarios_bitacora_id_seq TO service_role;
GRANT ALL ON TABLE public.viviendas_bitacora TO service_role;
GRANT ALL ON SEQUENCE public.viviendas_bitacora_id_seq TO service_role;
GRANT ALL ON SEQUENCE public.viviendas_id_seq TO service_role;
GRANT ALL ON TABLE public.vw_areas_comunes TO service_role;
GRANT SELECT ON TABLE public.vw_areas_comunes TO authenticated;
GRANT ALL ON TABLE public.vw_avisos_historico TO service_role;
GRANT SELECT ON TABLE public.vw_avisos_historico TO authenticated;
GRANT ALL ON TABLE public.vw_avisos_vigentes TO service_role;
GRANT SELECT ON TABLE public.vw_avisos_vigentes TO authenticated;
GRANT ALL ON TABLE public.vw_calendario_reservas TO service_role;
GRANT SELECT ON TABLE public.vw_calendario_reservas TO authenticated;
GRANT ALL ON TABLE public.vw_calendario_reservas_limitado TO service_role;
GRANT SELECT ON TABLE public.vw_calendario_reservas_limitado TO authenticated;
GRANT ALL ON TABLE public.vw_condominios TO service_role;
GRANT SELECT ON TABLE public.vw_condominios TO authenticated;
GRANT ALL ON TABLE public.vw_mis_paquetes TO service_role;
GRANT SELECT ON TABLE public.vw_mis_paquetes TO authenticated;
GRANT ALL ON TABLE public.vw_mis_visitas TO service_role;
GRANT SELECT ON TABLE public.vw_mis_visitas TO authenticated;
GRANT ALL ON TABLE public.vw_mis_viviendas TO service_role;
GRANT SELECT ON TABLE public.vw_mis_viviendas TO authenticated;
GRANT ALL ON TABLE public.vw_movimientos_saldo_favor TO service_role;
GRANT SELECT,MAINTAIN ON TABLE public.vw_movimientos_saldo_favor TO authenticated;
GRANT ALL ON TABLE public.vw_no_shows TO service_role;
GRANT SELECT ON TABLE public.vw_no_shows TO authenticated;
GRANT ALL ON TABLE public.vw_notificaciones TO service_role;
GRANT SELECT ON TABLE public.vw_notificaciones TO authenticated;
GRANT ALL ON TABLE public.vw_pagos TO service_role;
GRANT SELECT,MAINTAIN ON TABLE public.vw_pagos TO authenticated;
GRANT ALL ON TABLE public.vw_paquetes_caseta TO service_role;
GRANT SELECT ON TABLE public.vw_paquetes_caseta TO authenticated;
GRANT ALL ON TABLE public.vw_paquetes_historico TO service_role;
GRANT SELECT ON TABLE public.vw_paquetes_historico TO authenticated;
GRANT ALL ON TABLE public.vw_paquetes_residente TO service_role;
GRANT SELECT ON TABLE public.vw_paquetes_residente TO authenticated;
GRANT ALL ON TABLE public.vw_plantillas_cargo TO service_role;
GRANT SELECT,MAINTAIN ON TABLE public.vw_plantillas_cargo TO authenticated;
GRANT ALL ON TABLE public.vw_reservas_admin TO service_role;
GRANT SELECT ON TABLE public.vw_reservas_admin TO authenticated;
GRANT ALL ON TABLE public.vw_reservas_pendientes_titular TO service_role;
GRANT SELECT ON TABLE public.vw_reservas_pendientes_titular TO authenticated;
GRANT ALL ON TABLE public.vw_reservas_usuario TO service_role;
GRANT SELECT ON TABLE public.vw_reservas_usuario TO authenticated;
GRANT ALL ON TABLE public.vw_residentes_sin_vivienda TO service_role;
GRANT SELECT ON TABLE public.vw_residentes_sin_vivienda TO authenticated;
GRANT ALL ON TABLE public.vw_servicios_paqueteria TO service_role;
GRANT SELECT ON TABLE public.vw_servicios_paqueteria TO authenticated;
GRANT ALL ON TABLE public.vw_subusuarios_vivienda TO service_role;
GRANT SELECT ON TABLE public.vw_subusuarios_vivienda TO authenticated;
GRANT ALL ON TABLE public.vw_usuarios TO service_role;
GRANT SELECT ON TABLE public.vw_usuarios TO authenticated;
GRANT ALL ON TABLE public.vw_version TO service_role;
GRANT SELECT ON TABLE public.vw_version TO anon;
GRANT SELECT ON TABLE public.vw_version TO authenticated;
GRANT ALL ON TABLE public.vw_vigilantes TO service_role;
GRANT SELECT ON TABLE public.vw_vigilantes TO authenticated;
GRANT ALL ON TABLE public.vw_visitas_historico TO service_role;
GRANT SELECT ON TABLE public.vw_visitas_historico TO authenticated;
GRANT ALL ON TABLE public.vw_visitas_proximas TO service_role;
GRANT SELECT ON TABLE public.vw_visitas_proximas TO authenticated;
GRANT ALL ON TABLE public.vw_vivienda_subusuarios TO service_role;
GRANT SELECT ON TABLE public.vw_vivienda_subusuarios TO authenticated;
GRANT ALL ON TABLE public.vw_vivienda_usuarios TO service_role;
GRANT SELECT ON TABLE public.vw_vivienda_usuarios TO authenticated;
GRANT ALL ON TABLE public.vw_viviendas TO service_role;
GRANT SELECT ON TABLE public.vw_viviendas TO authenticated;
GRANT ALL ON TABLE public.vw_viviendas_con_residentes TO service_role;
GRANT SELECT ON TABLE public.vw_viviendas_con_residentes TO authenticated;
GRANT ALL ON TABLE public.vw_viviendas_residentes TO service_role;
GRANT SELECT ON TABLE public.vw_viviendas_residentes TO authenticated;

-- 2.3 Triggers sobre auth.users
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
CREATE TRIGGER on_auth_user_metadata_updated AFTER UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_user_metadata_update();

-- 2.4 Buckets de storage
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES ('comprobantes', 'comprobantes', 'f', 5242880, '{image/jpeg,image/png,image/webp,application/pdf}') ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, public = EXCLUDED.public, file_size_limit = EXCLUDED.file_size_limit, allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2.5 Politicas de storage
CREATE POLICY comprobantes_admin_insert ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((bucket_id = 'comprobantes'::text) AND (public.fn_mi_rol_id() = 1) AND ((storage.foldername(name))[1] = (public.fn_mi_condominio_id())::text)));
CREATE POLICY comprobantes_admin_select ON storage.objects AS PERMISSIVE FOR SELECT TO authenticated USING (((bucket_id = 'comprobantes'::text) AND (public.fn_mi_rol_id() = 1) AND ((storage.foldername(name))[1] = (public.fn_mi_condominio_id())::text)));
CREATE POLICY comprobantes_residente_insert ON storage.objects AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((bucket_id = 'comprobantes'::text) AND ((storage.foldername(name))[1] = (public.fn_mi_condominio_id())::text) AND (EXISTS ( SELECT 1
   FROM public.vivienda_residente vr
  WHERE ((vr.usuario_id = ( SELECT auth.uid() AS uid)) AND ((vr.vivienda_id)::text = (storage.foldername(objects.name))[2]))))));
CREATE POLICY comprobantes_residente_select ON storage.objects AS PERMISSIVE FOR SELECT TO authenticated USING (((bucket_id = 'comprobantes'::text) AND ((storage.foldername(name))[1] = (public.fn_mi_condominio_id())::text) AND (EXISTS ( SELECT 1
   FROM public.vivienda_residente vr
  WHERE ((vr.usuario_id = ( SELECT auth.uid() AS uid)) AND ((vr.vivienda_id)::text = (storage.foldername(objects.name))[2]))))));

-- 2.6 Event trigger: activa RLS en cada tabla nueva de public
CREATE EVENT TRIGGER ensure_rls ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  EXECUTE FUNCTION public.rls_auto_enable();

-- 2.7 Cron jobs
SELECT cron.schedule('reservas_transiciones_minuto', '* * * * *', 'SELECT public.procesar_transiciones_reservas();');
SELECT cron.schedule('pagos-generar-cargos-mensuales', '5 6 1 * *', 'SELECT public.rpc_generar_cargos_mensuales(date_trunc(''month'', CURRENT_DATE)::DATE, NULL, NULL);');
SELECT cron.schedule('pagos-depurar-comprobantes-antiguos', '0 9 * * *', 'SELECT public.rpc_depurar_comprobantes_antiguos(90, 30);');

COMMIT;
