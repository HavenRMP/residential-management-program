-- ==============================================================================
-- HAVEN - Parche: contrato de las RPC de visitas con Visitas.Api
-- ------------------------------------------------------------------------------
-- Corrige en la base viva, sin tirarla, lo que 02_recrear.sql ya trae corregido:
--   * alta_visita   : recibe p_fecha_llegada_esperada (antes p_fecha_llegada) y
--                     lanza VI009 (vivienda) y VI002 (sin permiso).
--   * cambio_visita : recibe p_fecha_llegada_esperada, retorna boolean y lanza
--                     VI001 (no existe) y VI002 (sin permiso).
--   * cancelar_visita, validar_codigo_visita, registrar_entrada_visita y
--     registrar_salida_visita: códigos de error alineados con RpcErrorMapper.
--
-- Solo toca esas 6 funciones (no borra tablas, vistas ni datos).
-- Es seguro correrlo más de una vez.
-- Ejecutar desde el SQL Editor de Supabase o con:
--   psql "<connection string>" -v ON_ERROR_STOP=1 -f supabase/reset/parches/20261111_visitas_contrato_api.sql
-- ==============================================================================

BEGIN;

-- 1. Firmas que cambian de nombre de parámetro o de tipo de retorno: hay que
--    borrarlas antes de recrearlas. También se borran las versiones de la
--    migración original por si quedaron en la base (evita sobrecargas ambiguas).
DROP FUNCTION IF EXISTS public.alta_visita(uuid, integer, character varying, character varying, character varying, character varying, integer, character varying, text, timestamp with time zone, integer);
DROP FUNCTION IF EXISTS public.alta_visita(uuid, integer, character varying, character varying, character varying, character varying, integer, character varying, character varying, timestamp with time zone, integer);
DROP FUNCTION IF EXISTS public.cambio_visita(uuid, uuid, character varying, character varying, character varying, character varying, integer, character varying, text, timestamp with time zone, integer);
DROP FUNCTION IF EXISTS public.cambio_visita(uuid, uuid, character varying, character varying, character varying, character varying, integer, character varying, character varying, timestamp with time zone, integer);
DROP FUNCTION IF EXISTS public.validar_codigo_visita(character varying);
DROP FUNCTION IF EXISTS public.registrar_entrada_visita(uuid, uuid);

-- 2. alta_visita
CREATE OR REPLACE FUNCTION public.alta_visita(p_actor_id uuid, p_vivienda_id integer, p_nombre_visitante character varying, p_apellidos_visitante character varying, p_telefono_visitante character varying, p_motivo character varying, p_num_acompanantes integer, p_vehiculo_placas character varying, p_notas text, p_fecha_llegada_esperada timestamp with time zone, p_horas_vigencia integer DEFAULT 24) RETURNS jsonb
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
GRANT ALL ON FUNCTION public.alta_visita(p_actor_id uuid, p_vivienda_id integer, p_nombre_visitante character varying, p_apellidos_visitante character varying, p_telefono_visitante character varying, p_motivo character varying, p_num_acompanantes integer, p_vehiculo_placas character varying, p_notas text, p_fecha_llegada_esperada timestamp with time zone, p_horas_vigencia integer) TO service_role;

-- 3. cambio_visita
CREATE OR REPLACE FUNCTION public.cambio_visita(p_id uuid, p_actor_id uuid, p_nombre_visitante character varying DEFAULT NULL::character varying, p_apellidos_visitante character varying DEFAULT NULL::character varying, p_telefono_visitante character varying DEFAULT NULL::character varying, p_motivo character varying DEFAULT NULL::character varying, p_num_acompanantes integer DEFAULT NULL::integer, p_vehiculo_placas character varying DEFAULT NULL::character varying, p_notas text DEFAULT NULL::text, p_fecha_llegada_esperada timestamp with time zone DEFAULT NULL::timestamp with time zone, p_horas_vigencia integer DEFAULT NULL::integer) RETURNS boolean
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
GRANT ALL ON FUNCTION public.cambio_visita(p_id uuid, p_actor_id uuid, p_nombre_visitante character varying, p_apellidos_visitante character varying, p_telefono_visitante character varying, p_motivo character varying, p_num_acompanantes integer, p_vehiculo_placas character varying, p_notas text, p_fecha_llegada_esperada timestamp with time zone, p_horas_vigencia integer) TO service_role;

-- 4. cancelar_visita
CREATE OR REPLACE FUNCTION public.cancelar_visita(p_id uuid, p_actor_id uuid) RETURNS boolean
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
GRANT ALL ON FUNCTION public.cancelar_visita(p_id uuid, p_actor_id uuid) TO service_role;

-- 5. validar_codigo_visita
CREATE OR REPLACE FUNCTION public.validar_codigo_visita(p_codigo character varying, p_actor_id uuid) RETURNS jsonb
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
GRANT ALL ON FUNCTION public.validar_codigo_visita(p_codigo character varying, p_actor_id uuid) TO service_role;

-- 6. registrar_entrada_visita
CREATE OR REPLACE FUNCTION public.registrar_entrada_visita(p_visita_id uuid, p_actor_id uuid, p_vehiculo_placas character varying DEFAULT NULL::character varying) RETURNS jsonb
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
GRANT ALL ON FUNCTION public.registrar_entrada_visita(p_visita_id uuid, p_actor_id uuid, p_vehiculo_placas character varying) TO service_role;

-- 7. registrar_salida_visita
CREATE OR REPLACE FUNCTION public.registrar_salida_visita(p_visita_id uuid, p_actor_id uuid) RETURNS jsonb
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
GRANT ALL ON FUNCTION public.registrar_salida_visita(p_visita_id uuid, p_actor_id uuid) TO service_role;

COMMIT;

-- Recarga el caché de esquema de PostgREST para que vea las firmas nuevas.
NOTIFY pgrst, 'reload schema';
