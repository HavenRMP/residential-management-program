-- ==============================================================================
-- Archivo: supabase/migrations/20261015183000_fix_security_linter_warns.sql
-- Proyecto: HAVEN
-- Descripción: Corrección de advertencias del Database Linter de Supabase:
--              fijar search_path inmutable, revocar accesos públicos anónimos
--              en funciones SECURITY DEFINER y vistas, y asegurar privilegios por defecto.
-- ==============================================================================

-- ==============================================================================
-- 1. FIJAR SEARCH_PATH EN FUNCIONES MUTABLES (Lint 0011)
-- ==============================================================================
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT p.oid::regprocedure AS func_signature
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN (
              'fn_generar_codigo_6',
              'fn_calcular_expiracion_aviso',
              'fn_generar_codigo_visita',
              'actualizar_bloqueo_area'
          )
    LOOP
        EXECUTE format('ALTER FUNCTION %s SET search_path = public;', r.func_signature);
    END LOOP;
END;
$$;

-- ==============================================================================
-- 2. REVOCAR EJECUCIÓN PÚBLICA EN FUNCIONES SECURITY DEFINER (Lints 0028 y 0029)
-- ==============================================================================
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT p.oid::regprocedure AS func_signature
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prosecdef = true -- Solo funciones SECURITY DEFINER
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC;', r.func_signature);
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM anon;', r.func_signature);
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role;', r.func_signature);
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO postgres;', r.func_signature);
    END LOOP;
END;
$$;

-- ==============================================================================
-- 3. REVOCAR ACCESO PÚBLICO (ANON) EN TODAS LAS VISTAS DEL ESQUEMA PUBLIC
-- ==============================================================================
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT table_name
        FROM information_schema.views
        WHERE table_schema = 'public'
          AND table_name LIKE 'vw_%'
    LOOP
        EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC;', r.table_name);
        EXECUTE format('REVOKE ALL ON public.%I FROM anon;', r.table_name);
        EXECUTE format('GRANT SELECT ON public.%I TO service_role;', r.table_name);
    END LOOP;
END;
$$;

-- ==============================================================================
-- 4. EVITAR QUE FUTURAS FUNCIONES SE EXPONGAN POR DEFECTO
-- ==============================================================================
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO postgres;

NOTIFY pgrst, 'reload schema';