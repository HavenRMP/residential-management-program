-- ============================================================================
-- 1. VERSIÓN DEL SISTEMA
-- ============================================================================
INSERT INTO public.version (numero_version, updated_at)
SELECT '1.0.0', now()
WHERE NOT EXISTS (SELECT 1 FROM public.version);

-- ============================================================================
-- 2. CATÁLOGO BASE DE ROLES
-- ============================================================================
INSERT INTO public.roles (id, nombre, descripcion) VALUES
  (1, 'Administrador', 'Control total del sistema residencial'),
  (2, 'Residente', 'Acceso a pagos, reservaciones y avisos'),
  (3, 'Vigilancia', 'Control de accesos y registro de visitas'),
  (4, 'Mantenimiento', 'Atención y resolución de reportes e incidencias')
ON CONFLICT (id) DO UPDATE 
SET nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion;

SELECT setval('public.roles_id_seq', (SELECT MAX(id) FROM public.roles));

-- ============================================================================
-- 3. CONDOMINIO MAESTRO (Requerido antes de usuarios y viviendas)
-- ============================================================================
INSERT INTO public.condominios (id, nombre, activo) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Condominio Residencial Principal', true)
ON CONFLICT (id) DO UPDATE 
SET nombre = EXCLUDED.nombre,
    activo = EXCLUDED.activo;

-- ============================================================================
-- 4. USUARIO EN AUTH.USERS (Satisface la llave foránea usuarios_id_fkey)
-- ============================================================================
INSERT INTO auth.users (id, email, raw_user_meta_data, raw_app_meta_data, aud, role)
VALUES (
  '6754a566-e529-40fb-8610-bd136ec77fd5',
  'admin@haven.com',
  '{"nombre": "Admin", "apellidos": "Principal"}'::jsonb,
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  'authenticated',
  'authenticated'
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 5. PERFIL DE USUARIO ADMINISTRADOR
-- ============================================================================
INSERT INTO public.usuarios (id, rol_id, email, nombre, apellidos, telefono, condominio_id)
VALUES (
  '6754a566-e529-40fb-8610-bd136ec77fd5',
  1,
  'admin@haven.com',
  'Admin',
  'Principal',
  '4420000000',
  'a0000000-0000-0000-0000-000000000001'
)
ON CONFLICT (id) DO UPDATE 
SET rol_id = EXCLUDED.rol_id,
    email = EXCLUDED.email,
    nombre = EXCLUDED.nombre,
    apellidos = EXCLUDED.apellidos,
    telefono = EXCLUDED.telefono,
    condominio_id = EXCLUDED.condominio_id;

-- ===========================================================================
-- 6. INSERTAR VIVIENDAS CON VÍNCULO A CONDOMINIO
-- ===========================================================================
INSERT INTO public.viviendas (condominio_id, numero_casa, tipo) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Casa 101', 'Grande'),
  ('a0000000-0000-0000-0000-000000000001', 'Casa 102', 'Mediana'),
  ('a0000000-0000-0000-0000-000000000001', 'Depto 201', 'Chico')
ON CONFLICT (condominio_id, numero_casa) DO NOTHING;

-- ============================================================================
-- 7. ASIGNAR VIVIENDA AL ADMINISTRADOR
-- ============================================================================
INSERT INTO public.vivienda_residente (vivienda_id, usuario_id) VALUES
  (1, '6754a566-e529-40fb-8610-bd136ec77fd5')
ON CONFLICT (vivienda_id, usuario_id) DO NOTHING;
-- ============================================================================
-- 8. AVISOS DE PRUEBA (Vigentes e Históricos)
-- ============================================================================
INSERT INTO public.avisos (
    id,
    condominio_id,
    titulo,
    contenido,
    duracion_dias,
    fecha_expiracion_manual,
    fecha_publicacion,
    activo,
    creado_por,
    creado_en
) VALUES
  -- 1. Vigente estándar (7 días de vigencia por defecto)
  (
    'b0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    'Mantenimiento en alberca y áreas verdes',
    'Se informa que el día viernes las amenidades estarán cerradas por trabajos de limpieza profunda.',
    7,
    NULL,
    timezone('utc'::text, now()),
    true,
    '6754a566-e529-40fb-8610-bd136ec77fd5',
    timezone('utc'::text, now())
  ),

  -- 2. Vigente con fecha manual futura (15 días)
  (
    'b0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000001',
    'Asamblea General Ordinaria',
    'Reunión anual de condóminos en el salón de eventos. Favor de confirmar asistencia y revisar orden del día.',
    NULL,
    timezone('utc'::text, now() + interval '15 days'),
    timezone('utc'::text, now()),
    true,
    '6754a566-e529-40fb-8610-bd136ec77fd5',
    timezone('utc'::text, now())
  ),

  -- 3. Histórico: Expirado naturalmente (Publicado hace 10 días, duró 3)
  (
    'b0000000-0000-0000-0000-000000000003',
    'a0000000-0000-0000-0000-000000000001',
    'Corte temporal de suministro de agua',
    'Corte programado por reparación de tubería general en el sector poniente.',
    3,
    NULL,
    timezone('utc'::text, now() - interval '10 days'),
    true,
    '6754a566-e529-40fb-8610-bd136ec77fd5',
    timezone('utc'::text, now() - interval '10 days')
  ),

  -- 4. Histórico: Eliminado lógicamente (activo = false)
  (
    'b0000000-0000-0000-0000-000000000004',
    'a0000000-0000-0000-0000-000000000001',
    'Aviso cancelado por error tipográfico',
    'Este comunicado fue revocado administrativamente tras detectarse un error en los horarios.',
    5,
    NULL,
    timezone('utc'::text, now() - interval '2 days'),
    false,
    '6754a566-e529-40fb-8610-bd136ec77fd5',
    timezone('utc'::text, now() - interval '2 days')
  )
ON CONFLICT (id) DO UPDATE 
SET titulo = EXCLUDED.titulo,
    contenido = EXCLUDED.contenido,
    duracion_dias = EXCLUDED.duracion_dias,
    fecha_expiracion_manual = EXCLUDED.fecha_expiracion_manual,
    activo = EXCLUDED.activo;
    -- ============================================================================
-- 8. USUARIO VIGILANCIA Y RESIDENTE DE EJEMPLO (Pruebas de Caseta)
-- ============================================================================

-- A. Login de Supabase (auth.users)
INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
) VALUES 
  -- Vigilante
  (
    '00000000-0000-0000-0000-000000000000',
    'c0000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'vigilante@haven.com',
    crypt('Password123!', gen_salt('bf')),
    timezone('utc'::text, now()),
    '{"provider":"email","providers":["email"]}',
    '{"nombre":"Vigilante","apellidos":"Caseta"}',
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  ),
  -- Residente de prueba para Casa 101
  (
    '00000000-0000-0000-0000-000000000000',
    'e0000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'residente.prueba@haven.com',
    crypt('Password123!', gen_salt('bf')),
    timezone('utc'::text, now()),
    '{"provider":"email","providers":["email"]}',
    '{"nombre":"Carlos","apellidos":"Gómez"}',
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  )
ON CONFLICT (id) DO NOTHING;

-- B. Perfiles en tabla pública (public.usuarios)
INSERT INTO public.usuarios (id, rol_id, email, nombre, apellidos, telefono, condominio_id, activo)
VALUES 
  -- Vigilante (rol_id = 3)
  (
    'c0000000-0000-0000-0000-000000000001',
    3,
    'vigilante@haven.com',
    'Vigilante',
    'Caseta',
    '4423000001',
    'a0000000-0000-0000-0000-000000000001',
    true
  ),
  -- Residente (rol_id = 2)
  (
    'e0000000-0000-0000-0000-000000000001',
    2,
    'residente.prueba@haven.com',
    'Carlos',
    'Gómez',
    '4423000002',
    'a0000000-0000-0000-0000-000000000001',
    true
  )
ON CONFLICT (id) DO UPDATE 
SET rol_id = EXCLUDED.rol_id,
    email = EXCLUDED.email,
    nombre = EXCLUDED.nombre,
    apellidos = EXCLUDED.apellidos,
    telefono = EXCLUDED.telefono,
    condominio_id = EXCLUDED.condominio_id,
    activo = EXCLUDED.activo;

-- C. Asignar residente de prueba a Casa 101 (id = 1)
-- Nota: Casa 102 (id = 2) permanece intencionalmente sin asignaciones.
INSERT INTO public.vivienda_residente (vivienda_id, usuario_id) VALUES
  (1, 'e0000000-0000-0000-0000-000000000001')
ON CONFLICT (vivienda_id, usuario_id) DO NOTHING;-- ==============================================================================
-- SEED: MÓDULO DE VISITAS (DATOS DE PRUEBA)
-- ==============================================================================
DO $$
DECLARE
    v_residente_id UUID;
    v_vigilante_id UUID;
    v_vivienda_id INTEGER;
BEGIN
    -- Obtener referencias dinámicas existentes en el entorno
    SELECT usuario_id, vivienda_id 
    INTO v_residente_id, v_vivienda_id 
    FROM public.vivienda_residente 
    LIMIT 1;

    -- Si no hay vinculación en vivienda_residente, tomar registros directos
    IF v_residente_id IS NULL THEN
        SELECT id INTO v_residente_id FROM public.usuarios WHERE rol_id = 2 LIMIT 1;
        SELECT id INTO v_vivienda_id FROM public.viviendas WHERE activo = true LIMIT 1;
    END IF;

    -- Obtener vigilante o administrador para auditoría de caseta
    SELECT id INTO v_vigilante_id FROM public.usuarios WHERE rol_id = 3 LIMIT 1;
    IF v_vigilante_id IS NULL THEN
        SELECT id INTO v_vigilante_id FROM public.usuarios WHERE rol_id = 1 LIMIT 1;
    END IF;

    IF v_residente_id IS NOT NULL AND v_vivienda_id IS NOT NULL THEN
        -- 1. Visita Programada (Vigente para el día de hoy, lista para validar en caseta)
        INSERT INTO public.visitas (
            id, vivienda_id, creado_por, nombre_visitante, apellidos_visitante,
            telefono_visitante, motivo, num_acompanantes, vehiculo_placas,
            notas, fecha_llegada_esperada, horas_vigencia, estado,
            codigo_acceso, codigo_usado
        )
        VALUES (
            'e0000000-0000-0000-0000-000000000001',
            v_vivienda_id,
            v_residente_id,
            'Carlos',
            'Mendoza Ruiz',
            '5512345678',
            'familiar',
            2,
            'ABC-1234',
            'Reunión familiar en jardín',
            now() + interval '2 hours',
            12,
            'programada',
            'VIS789',
            false
        )
        ON CONFLICT (id) DO NOTHING;

        -- 2. Visita En Curso (Ingreso validado y actualmente dentro del residencial)
        INSERT INTO public.visitas (
            id, vivienda_id, creado_por, nombre_visitante, apellidos_visitante,
            telefono_visitante, motivo, num_acompanantes, vehiculo_placas,
            notas, fecha_llegada_esperada, horas_vigencia, estado,
            codigo_acceso, codigo_usado, hora_entrada, registrado_entrada_por
        )
        VALUES (
            'e0000000-0000-0000-0000-000000000002',
            v_vivienda_id,
            v_residente_id,
            'Sofía',
            'Hernández Lara',
            '5598765432',
            'personal',
            0,
            'XYZ-9876',
            'Visita corta',
            now() - interval '1 hour',
            12,
            'en_curso',
            'VIS456',
            true,
            now() - interval '30 minutes',
            v_vigilante_id
        )
        ON CONFLICT (id) DO NOTHING;

        -- 3. Visita Finalizada (Registro completado con hora de entrada y salida)
        INSERT INTO public.visitas (
            id, vivienda_id, creado_por, nombre_visitante, apellidos_visitante,
            telefono_visitante, motivo, num_acompanantes, vehiculo_placas,
            notas, fecha_llegada_esperada, horas_vigencia, estado,
            codigo_acceso, codigo_usado, hora_entrada, registrado_entrada_por,
            hora_salida, registrado_salida_por
        )
        VALUES (
            'e0000000-0000-0000-0000-000000000003',
            v_vivienda_id,
            v_residente_id,
            'Roberto',
            'Gómez Bolaños',
            '5544332211',
            'proveedor',
            1,
            'PRV-1122',
            'Mantenimiento de climas',
            now() - interval '1 day',
            8,
            'finalizada',
            'VIS123',
            true,
            now() - interval '24 hours',
            v_vigilante_id,
            now() - interval '22 hours',
            v_vigilante_id
        )
        ON CONFLICT (id) DO NOTHING;

        -- 4. Visita Cancelada (Cancelada antes del arribo)
        INSERT INTO public.visitas (
            id, vivienda_id, creado_por, nombre_visitante, apellidos_visitante,
            telefono_visitante, motivo, num_acompanantes, vehiculo_placas,
            notas, fecha_llegada_esperada, horas_vigencia, estado,
            codigo_acceso, codigo_usado
        )
        VALUES (
            'e0000000-0000-0000-0000-000000000004',
            v_vivienda_id,
            v_residente_id,
            'Mariana',
            'Torres Garza',
            '5566778899',
            'paqueteria',
            0,
            NULL,
            'Cancelado por reprogramación de entrega',
            now() - interval '5 hours',
            6,
            'cancelada',
            'VIS999',
            false
        )
        ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;
