BEGIN;

SELECT plan(14);

-- Firmas (tipos) y tipo de retorno de las RPC que consume Visitas.Api

SELECT has_function('public', 'alta_visita',
    ARRAY['uuid', 'integer', 'character varying', 'character varying', 'character varying', 'character varying', 'integer', 'character varying', 'text', 'timestamp with time zone', 'integer'],
    'alta_visita debe existir con la firma que usa Visitas.Api');
SELECT function_returns('public', 'alta_visita',
    ARRAY['uuid', 'integer', 'character varying', 'character varying', 'character varying', 'character varying', 'integer', 'character varying', 'text', 'timestamp with time zone', 'integer'],
    'jsonb', 'alta_visita debe retornar jsonb (VisitaDto)');

SELECT has_function('public', 'cambio_visita',
    ARRAY['uuid', 'uuid', 'character varying', 'character varying', 'character varying', 'character varying', 'integer', 'character varying', 'text', 'timestamp with time zone', 'integer'],
    'cambio_visita debe existir con la firma que usa Visitas.Api');
SELECT function_returns('public', 'cambio_visita',
    ARRAY['uuid', 'uuid', 'character varying', 'character varying', 'character varying', 'character varying', 'integer', 'character varying', 'text', 'timestamp with time zone', 'integer'],
    'boolean', 'cambio_visita debe retornar boolean');

SELECT has_function('public', 'cancelar_visita', ARRAY['uuid', 'uuid'], 'cancelar_visita(uuid, uuid) debe existir');
SELECT function_returns('public', 'cancelar_visita', ARRAY['uuid', 'uuid'], 'boolean', 'cancelar_visita debe retornar boolean');

SELECT has_function('public', 'validar_codigo_visita', ARRAY['character varying', 'uuid'], 'validar_codigo_visita(varchar, uuid) debe existir');
SELECT function_returns('public', 'validar_codigo_visita', ARRAY['character varying', 'uuid'], 'jsonb', 'validar_codigo_visita debe retornar jsonb');

SELECT has_function('public', 'registrar_entrada_visita', ARRAY['uuid', 'uuid', 'character varying'], 'registrar_entrada_visita(uuid, uuid, varchar) debe existir');
SELECT function_returns('public', 'registrar_entrada_visita', ARRAY['uuid', 'uuid', 'character varying'], 'jsonb', 'registrar_entrada_visita debe retornar jsonb');

SELECT has_function('public', 'registrar_salida_visita', ARRAY['uuid', 'uuid'], 'registrar_salida_visita(uuid, uuid) debe existir');
SELECT function_returns('public', 'registrar_salida_visita', ARRAY['uuid', 'uuid'], 'jsonb', 'registrar_salida_visita debe retornar jsonb');

-- PostgREST resuelve la función por NOMBRE de parámetro; has_function solo valida tipos

SELECT is(
    (SELECT proargnames FROM pg_proc WHERE oid = 'public.alta_visita(uuid, integer, character varying, character varying, character varying, character varying, integer, character varying, text, timestamp with time zone, integer)'::regprocedure),
    ARRAY['p_actor_id', 'p_vivienda_id', 'p_nombre_visitante', 'p_apellidos_visitante', 'p_telefono_visitante', 'p_motivo', 'p_num_acompanantes', 'p_vehiculo_placas', 'p_notas', 'p_fecha_llegada_esperada', 'p_horas_vigencia']::text[],
    'alta_visita debe usar los nombres de parámetros que envía Visitas.Api');

SELECT is(
    (SELECT proargnames FROM pg_proc WHERE oid = 'public.cambio_visita(uuid, uuid, character varying, character varying, character varying, character varying, integer, character varying, text, timestamp with time zone, integer)'::regprocedure),
    ARRAY['p_id', 'p_actor_id', 'p_nombre_visitante', 'p_apellidos_visitante', 'p_telefono_visitante', 'p_motivo', 'p_num_acompanantes', 'p_vehiculo_placas', 'p_notas', 'p_fecha_llegada_esperada', 'p_horas_vigencia']::text[],
    'cambio_visita debe usar los nombres de parámetros que envía Visitas.Api');

SELECT * FROM finish();

ROLLBACK;
