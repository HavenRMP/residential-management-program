-- ==============================================================================
-- HAVEN - Paso 1 de 3: tirar la base
-- ------------------------------------------------------------------------------
-- Borra cron jobs, event trigger de RLS, triggers sobre auth.users, politicas de
-- storage, todos los objetos del esquema public y todas las cuentas de auth.
-- Se puede ejecutar aunque la base ya este vacia.
--
-- No se borran los archivos ya subidos a storage (Supabase no permite borrarlos
-- por SQL); para vaciarlos usar el dashboard o la API de Storage.
--
-- Orden de ejecucion: 01_tirar.sql -> 02_recrear.sql -> 03_seed.sql
-- Cada archivo corre en su propia transaccion: si algo falla, ese paso no se aplica.
-- Ejecutar desde el SQL Editor de Supabase o con:
--   psql "<connection string session pooler>" -v ON_ERROR_STOP=1 -f supabase/reset/<archivo>
-- ==============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 1.1 Cron jobs
SELECT cron.unschedule(jobid) FROM cron.job;

-- 1.2 Event trigger que activa RLS automaticamente
DROP EVENT TRIGGER IF EXISTS ensure_rls;

-- 1.3 Triggers sobre auth.users que apuntan a funciones de public
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_metadata_updated ON auth.users;

-- 1.4 Politicas de storage
DROP POLICY IF EXISTS comprobantes_admin_insert ON storage.objects;
DROP POLICY IF EXISTS comprobantes_admin_select ON storage.objects;
DROP POLICY IF EXISTS comprobantes_residente_insert ON storage.objects;
DROP POLICY IF EXISTS comprobantes_residente_select ON storage.objects;

-- 1.5 Todos los objetos del esquema public (menos los de extensiones)
DO $$
DECLARE
  v_obj text;
BEGIN
  FOREACH v_obj IN ARRAY ARRAY(
    SELECT format('DROP %s IF EXISTS %I.%I CASCADE',
                  CASE c.relkind WHEN 'm' THEN 'MATERIALIZED VIEW' ELSE 'VIEW' END,
                  n.nspname, c.relname)
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind IN ('v', 'm')
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype = 'e')
    UNION ALL
    SELECT format('DROP TABLE IF EXISTS %I.%I CASCADE', n.nspname, c.relname)
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p', 'f')
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype = 'e')
  ) LOOP
    EXECUTE v_obj;
  END LOOP;

  FOREACH v_obj IN ARRAY ARRAY(
    SELECT format('DROP SEQUENCE IF EXISTS %I.%I CASCADE', n.nspname, c.relname)
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'S'
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = c.oid AND d.deptype = 'e')
    UNION ALL
    SELECT format('DROP %s IF EXISTS %I.%I(%s) CASCADE',
                  CASE p.prokind WHEN 'a' THEN 'AGGREGATE' WHEN 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END,
                  n.nspname, p.proname, pg_get_function_identity_arguments(p.oid))
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
  ) LOOP
    EXECUTE v_obj;
  END LOOP;

  FOREACH v_obj IN ARRAY ARRAY(
    SELECT format('DROP %s IF EXISTS %I.%I CASCADE',
                  CASE t.typtype WHEN 'd' THEN 'DOMAIN' ELSE 'TYPE' END,
                  n.nspname, t.typname)
    FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public' AND t.typtype IN ('e', 'd', 'c', 'r')
      AND (t.typrelid = 0 OR (SELECT c.relkind FROM pg_class c WHERE c.oid = t.typrelid) = 'c')
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = t.oid AND d.deptype = 'e')
  ) LOOP
    EXECUTE v_obj;
  END LOOP;
END
$$;

-- 1.6 Cuentas de autenticacion (en cascada: identities, sesiones, tokens)
DELETE FROM auth.users;

COMMIT;
