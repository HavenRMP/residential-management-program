-- ==============================================================================
-- Archivo: supabase/seed.sql
-- Proyecto: HAVEN
-- Descripción: Archivo maestro de datos semilla con credenciales operativas,
--              integridad referencial completa y cobertura para todos los módulos.
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==============================================================================
-- 1. VERSIÓN DEL SISTEMA
-- ==============================================================================
INSERT INTO public.version (numero_version, updated_at)
SELECT '1.0.0', now()
WHERE NOT EXISTS (SELECT 1 FROM public.version);

-- ==============================================================================
-- 2. CATÁLOGO BASE DE ROLES
-- ==============================================================================
INSERT INTO public.roles (id, nombre, descripcion) VALUES
  (1, 'Administrador', 'Control total del sistema residencial'),
  (2, 'Residente', 'Acceso a pagos, reservaciones y avisos'),
  (3, 'Vigilancia', 'Control de accesos y registro de visitas'),
  (4, 'Mantenimiento', 'Atención y resolución de reportes e incidencias')
ON CONFLICT (id) DO UPDATE 
SET nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion;

SELECT setval('public.roles_id_seq', (SELECT MAX(id) FROM public.roles));

-- ==============================================================================
-- 3. CONDOMINIO MAESTRO
-- ==============================================================================
INSERT INTO public.condominios (id, nombre, zona_horaria, activo) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Condominio Residencial Principal', 'America/Mexico_City', true)
ON CONFLICT (id) DO UPDATE 
SET nombre = EXCLUDED.nombre,
    zona_horaria = EXCLUDED.zona_horaria,
    activo = EXCLUDED.activo;

-- ==============================================================================
-- 4. VIVIENDAS BASE
-- ==============================================================================
INSERT INTO public.viviendas (condominio_id, numero_casa, tipo, activo) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Casa 101', 'Grande', true),
  ('a0000000-0000-0000-0000-000000000001', 'Casa 102', 'Mediana', true),
  ('a0000000-0000-0000-0000-000000000001', 'Depto 201', 'Chico', true)
ON CONFLICT (condominio_id, numero_casa) DO NOTHING;

-- ==============================================================================
-- 5. CUENTAS DE AUTENTICACIÓN (auth.users)
-- ==============================================================================
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
  -- 1. Administrador (Contraseña: AdminPassword1)
  (
    '00000000-0000-0000-0000-000000000000',
    '6754a566-e529-40fb-8610-bd136ec77fd5',
    'authenticated',
    'authenticated',
    'admin@haven.com',
    crypt('AdminPassword1', gen_salt('bf')),
    timezone('utc'::text, now()),
    '{"provider":"email","providers":["email"]}',
    '{"nombre":"Admin","apellidos":"Principal"}',
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  ),
  -- 2. Vigilante de Caseta (Contraseña: Password123!)
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
  -- 3. Residente Titular (Contraseña: Password123!)
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
  ),
  -- 4. Sub-usuario Activo (Contraseña: Password123!)
  (
    '00000000-0000-0000-0000-000000000000',
    'c0000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'subusuario.activo@haven.com',
    crypt('Password123!', gen_salt('bf')),
    timezone('utc'::text, now()),
    '{"provider":"email","providers":["email"]}',
    '{"nombre":"Carlos Jr","apellidos":"Gómez"}',
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  ),
  -- 5. Familiar Invitado Pendiente (Contraseña: Password123!)
  (
    '00000000-0000-0000-0000-000000000000',
    'c0000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'invitado.pendiente@haven.com',
    crypt('Password123!', gen_salt('bf')),
    timezone('utc'::text, now()),
    '{"provider":"email","providers":["email"]}',
    '{"nombre":"Mariana","apellidos":"Familiar Invitado"}',
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  ),
  -- 6. Personal de Mantenimiento (Contraseña: Password123!)
  (
    '00000000-0000-0000-0000-000000000000',
    'c0000000-0000-0000-0000-000000000004',
    'authenticated',
    'authenticated',
    'mantenimiento@haven.com',
    crypt('Password123!', gen_salt('bf')),
    timezone('utc'::text, now()),
    '{"provider":"email","providers":["email"]}',
    '{"nombre":"Técnico","apellidos":"Mantenimiento"}',
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  )
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- 6. PERFILES DE USUARIO (public.usuarios)
-- ==============================================================================
INSERT INTO public.usuarios (id, rol_id, email, nombre, apellidos, telefono, condominio_id, activo, debe_cambiar_password)
VALUES 
  ('6754a566-e529-40fb-8610-bd136ec77fd5', 1, 'admin@haven.com', 'Admin', 'Principal', '4420000000', 'a0000000-0000-0000-0000-000000000001', true, false),
  ('c0000000-0000-0000-0000-000000000001', 3, 'vigilante@haven.com', 'Vigilante', 'Caseta', '4423000001', 'a0000000-0000-0000-0000-000000000001', true, false),
  ('e0000000-0000-0000-0000-000000000001', 2, 'residente.prueba@haven.com', 'Carlos', 'Gómez', '4423000002', 'a0000000-0000-0000-0000-000000000001', true, false),
  ('c0000000-0000-0000-0000-000000000003', 2, 'subusuario.activo@haven.com', 'Carlos Jr', 'Gómez', '4421112233', 'a0000000-0000-0000-0000-000000000001', true, false),
  ('c0000000-0000-0000-0000-000000000002', 2, 'invitado.pendiente@haven.com', 'Mariana', 'Familiar Invitado', '4424445566', 'a0000000-0000-0000-0000-000000000001', true, false),
  ('c0000000-0000-0000-0000-000000000004', 4, 'mantenimiento@haven.com', 'Técnico', 'Mantenimiento', '4429998877', 'a0000000-0000-0000-0000-000000000001', true, false)
ON CONFLICT (id) DO UPDATE 
SET rol_id = EXCLUDED.rol_id,
    email = EXCLUDED.email,
    nombre = EXCLUDED.nombre,
    apellidos = EXCLUDED.apellidos,
    telefono = EXCLUDED.telefono,
    condominio_id = EXCLUDED.condominio_id,
    activo = EXCLUDED.activo,
    debe_cambiar_password = EXCLUDED.debe_cambiar_password;

-- ==============================================================================
-- 7. ASIGNACIONES DE RESIDENCIA
-- ==============================================================================
DO $$
DECLARE
    v_casa_101_id INTEGER;
BEGIN
    SELECT id INTO v_casa_101_id FROM public.viviendas WHERE numero_casa = 'Casa 101' LIMIT 1;

    IF v_casa_101_id IS NOT NULL THEN
        -- Titular asignado a Casa 101
        INSERT INTO public.vivienda_residente (vivienda_id, usuario_id)
        VALUES (v_casa_101_id, 'e0000000-0000-0000-0000-000000000001')
        ON CONFLICT (vivienda_id, usuario_id) DO NOTHING;

        -- Sub-usuario activo asignado a Casa 101
        INSERT INTO public.vivienda_subusuarios (vivienda_id, usuario_id, titular_id, parentesco, activo)
        VALUES (v_casa_101_id, 'c0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000001', 'Hijo', true)
        ON CONFLICT (vivienda_id, usuario_id) DO UPDATE
        SET activo = true, parentesco = EXCLUDED.parentesco;

        -- Invitación pendiente de prueba con vigencia de 24 horas
        INSERT INTO public.invitaciones_subusuarios (
            id, vivienda_id, creado_por, email_invitado, codigo_invitacion,
            estado, usuario_id, parentesco, expira_en
        ) VALUES (
            'd0000000-0000-0000-0000-000000000001',
            v_casa_101_id,
            'e0000000-0000-0000-0000-000000000001',
            'invitado.pendiente@haven.com',
            'HAVEN24K',
            'pendiente',
            'c0000000-0000-0000-0000-000000000002',
            'Hermana',
            timezone('utc'::text, now()) + INTERVAL '24 hours'
        ) ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;

-- ==============================================================================
-- 8. AVISOS DE PRUEBA
-- ==============================================================================
INSERT INTO public.avisos (
    id, condominio_id, titulo, contenido, prioridad,
    duracion_dias, fecha_expiracion_manual, fecha_publicacion,
    activo, creado_por, creado_en
) VALUES
  (
    'b0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    'Mantenimiento en alberca y áreas verdes',
    'Se informa que el día viernes las amenidades estarán cerradas por trabajos de limpieza profunda.',
    'mantenimiento',
    7,
    NULL,
    timezone('utc'::text, now()),
    true,
    '6754a566-e529-40fb-8610-bd136ec77fd5',
    timezone('utc'::text, now())
  ),
  (
    'b0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000001',
    'Asamblea General Ordinaria',
    'Reunión anual de condóminos en el salón de eventos. Favor de confirmar asistencia y revisar orden del día.',
    'evento',
    NULL,
    timezone('utc'::text, now() + interval '15 days'),
    timezone('utc'::text, now()),
    true,
    '6754a566-e529-40fb-8610-bd136ec77fd5',
    timezone('utc'::text, now())
  ),
  (
    'b0000000-0000-0000-0000-000000000003',
    'a0000000-0000-0000-0000-000000000001',
    'Corte temporal de suministro de agua',
    'Corte programado por reparación de tubería general en el sector poniente.',
    'urgente',
    3,
    NULL,
    timezone('utc'::text, now() - interval '10 days'),
    true,
    '6754a566-e529-40fb-8610-bd136ec77fd5',
    timezone('utc'::text, now() - interval '10 days')
  ),
  (
    'b0000000-0000-0000-0000-000000000004',
    'a0000000-0000-0000-0000-000000000001',
    'Aviso cancelado por error tipográfico',
    'Este comunicado fue revocado administrativamente tras detectarse un error en los horarios.',
    'informativo',
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
    prioridad = EXCLUDED.prioridad,
    activo = EXCLUDED.activo;

-- ==============================================================================
-- 9. VISITAS DE PRUEBA
-- ==============================================================================
DO $$
DECLARE
    v_vivienda_id INTEGER;
BEGIN
    SELECT id INTO v_vivienda_id FROM public.viviendas WHERE numero_casa = 'Casa 101' LIMIT 1;

    IF v_vivienda_id IS NOT NULL THEN
        INSERT INTO public.visitas (
            id, vivienda_id, creado_por, nombre_visitante, apellidos_visitante,
            telefono_visitante, motivo, num_acompanantes, vehiculo_placas,
            notas, fecha_llegada_esperada, horas_vigencia, estado,
            codigo_acceso, codigo_usado, hora_entrada, registrado_entrada_por,
            hora_salida, registrado_salida_por
        ) VALUES 
          -- 1. Programada (Vigente en ventana móvil de 24h)
          (
            'e0000000-0000-0000-0000-000000000001',
            v_vivienda_id,
            'e0000000-0000-0000-0000-000000000001',
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
            false,
            NULL,
            NULL,
            NULL,
            NULL
          ),
          -- 2. En curso (Ingresó a caseta)
          (
            'e0000000-0000-0000-0000-000000000002',
            v_vivienda_id,
            'e0000000-0000-0000-0000-000000000001',
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
            'c0000000-0000-0000-0000-000000000001',
            NULL,
            NULL
          ),
          -- 3. Finalizada
          (
            'e0000000-0000-0000-0000-000000000003',
            v_vivienda_id,
            'e0000000-0000-0000-0000-000000000001',
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
            'c0000000-0000-0000-0000-000000000001',
            now() - interval '22 hours',
            'c0000000-0000-0000-0000-000000000001'
          ),
          -- 4. Cancelada
          (
            'e0000000-0000-0000-0000-000000000004',
            v_vivienda_id,
            'e0000000-0000-0000-0000-000000000001',
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
            false,
            NULL,
            NULL,
            NULL,
            NULL
          )
        ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;

-- ==============================================================================
-- 10. PAQUETERÍA
-- ==============================================================================
DO $$
DECLARE
    v_vivienda_id INTEGER;
BEGIN
    SELECT id INTO v_vivienda_id FROM public.viviendas WHERE numero_casa = 'Casa 101' LIMIT 1;

    IF v_vivienda_id IS NOT NULL THEN
        INSERT INTO public.paquetes (
            id, condominio_id, vivienda_id, destinatario_id, destinatario_nombre,
            empresa_reparto, codigo_rastreo, descripcion, estado, fecha_esperada,
            fecha_recepcion, recibido_por, fecha_entrega, entregado_por, entregado_a,
            entregado_a_nombre, cierre_motivo, notas, creado_por
        ) VALUES 
          -- 1. Paquete esperado (Pre-registrado por residente)
          (
            'fa000000-0000-0000-0000-000000000001',
            'a0000000-0000-0000-0000-000000000001',
            v_vivienda_id,
            'e0000000-0000-0000-0000-000000000001',
            'Carlos Gómez',
            'Amazon',
            'MX-98234-AMZ',
            'Caja mediana con accesorios de cómputo',
            'esperado',
            (timezone('America/Mexico_City', now()))::date,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            'Dejar en caseta si no me encuentro',
            'e0000000-0000-0000-0000-000000000001'
          ),
          -- 2. Paquete recibido en caseta (En custodia física)
          (
            'fa000000-0000-0000-0000-000000000002',
            'a0000000-0000-0000-0000-000000000001',
            v_vivienda_id,
            'e0000000-0000-0000-0000-000000000001',
            'Carlos Gómez',
            'Mercado Libre',
            'ML-445892-PAQ',
            'Sobre acolchado amarillo',
            'recibido',
            NULL,
            timezone('utc'::text, now() - interval '3 hours'),
            'c0000000-0000-0000-0000-000000000001',
            NULL,
            NULL,
            NULL,
            NULL,
            NULL,
            'Recibido en buen estado en guardia matutina',
            'c0000000-0000-0000-0000-000000000001'
          ),
          -- 3. Paquete entregado (Histórico)
          (
            'fa000000-0000-0000-0000-000000000003',
            'a0000000-0000-0000-0000-000000000001',
            v_vivienda_id,
            'e0000000-0000-0000-0000-000000000001',
            'Carlos Gómez',
            'DHL',
            'DHL-88190-EXP',
            'Paquete de documentos',
            'entregado',
            NULL,
            timezone('utc'::text, now() - interval '2 days'),
            'c0000000-0000-0000-0000-000000000001',
            timezone('utc'::text, now() - interval '1 day'),
            'c0000000-0000-0000-0000-000000000001',
            'e0000000-0000-0000-0000-000000000001',
            'Carlos Gómez',
            'Entregado a residente titular',
            NULL,
            'c0000000-0000-0000-0000-000000000001'
          )
        ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;

-- ==============================================================================
-- 11. ÁREAS COMUNES Y RESERVAS
-- ==============================================================================
INSERT INTO public.areas_comunes (
    id, condominio_id, nombre, descripcion, hora_apertura, hora_cierre, activo
) VALUES 
  (
    'fb000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    'Salón de Eventos Principal',
    'Salón climatizado con mesas, sillas y cocina de servicio. Capacidad para 60 personas.',
    '09:00:00',
    '23:00:00',
    true
  ),
  (
    'fb000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000001',
    'Alberca y Palapa',
    'Área húmeda con asador integrado y mobiliario exterior.',
    '08:00:00',
    '21:00:00',
    true
  ),
  (
    'fb000000-0000-0000-0000-000000000003',
    'a0000000-0000-0000-0000-000000000001',
    'Cancha de Pádel',
    'Cancha iluminada con césped sintético y cristal templado.',
    '07:00:00',
    '22:00:00',
    true
  )
ON CONFLICT (id) DO UPDATE 
SET nombre = EXCLUDED.nombre,
    hora_apertura = EXCLUDED.hora_apertura,
    hora_cierre = EXCLUDED.hora_cierre,
    activo = EXCLUDED.activo;

DO $$
DECLARE
    v_vivienda_id INTEGER;
BEGIN
    SELECT id INTO v_vivienda_id FROM public.viviendas WHERE numero_casa = 'Casa 101' LIMIT 1;

    IF v_vivienda_id IS NOT NULL THEN
        INSERT INTO public.reservas (
            id, condominio_id, area_id, tipo, estado, inicio, fin,
            titular_id, vivienda_id, solicitante_id, aprobador_id, motivo, confirmada_en
        ) VALUES 
          -- 1. Reserva confirmada para Casa 101 en Salón de Eventos (dentro de 10 días)
          (
            'fc000000-0000-0000-0000-000000000001',
            'a0000000-0000-0000-0000-000000000001',
            'fb000000-0000-0000-0000-000000000001',
            'RESERVA',
            'APROBADA',
            date_trunc('day', now() + interval '10 days') + interval '16 hours',
            date_trunc('day', now() + interval '10 days') + interval '21 hours',
            'e0000000-0000-0000-0000-000000000001',
            v_vivienda_id,
            'e0000000-0000-0000-0000-000000000001',
            '6754a566-e529-40fb-8610-bd136ec77fd5',
            'Festejo de cumpleaños familiar',
            timezone('utc'::text, now())
          ),
          -- 2. Bloqueo administrativo por mantenimiento en Alberca (dentro de 5 días)
          (
            'fc000000-0000-0000-0000-000000000002',
            'a0000000-0000-0000-0000-000000000001',
            'fb000000-0000-0000-0000-000000000002',
            'BLOQUEO',
            'APROBADA',
            date_trunc('day', now() + interval '5 days') + interval '8 hours',
            date_trunc('day', now() + interval '5 days') + interval '14 hours',
            NULL,
            NULL,
            '6754a566-e529-40fb-8610-bd136ec77fd5',
            '6754a566-e529-40fb-8610-bd136ec77fd5',
            'Mantenimiento preventivo de bombas y cambio de filtros',
            timezone('utc'::text, now())
          )
        ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;

-- ==============================================================================
-- 12. PLANTILLAS DE CARGO Y CARGOS
-- ==============================================================================
DO $$
DECLARE
    v_vivienda_id INTEGER;
BEGIN
    SELECT id INTO v_vivienda_id FROM public.viviendas WHERE numero_casa = 'Casa 101' LIMIT 1;

    IF v_vivienda_id IS NOT NULL THEN
        -- Plantilla de cuota ordinaria activa
        INSERT INTO public.plantillas_cargo (
            id, condominio_id, vivienda_id, tipo, concepto, monto, dia_vencimiento,
            vigencia_inicio, responsable_pago, activa, creado_por
        ) VALUES (
            'fd000000-0000-0000-0000-000000000001',
            'a0000000-0000-0000-0000-000000000001',
            v_vivienda_id,
            'Mantenimiento',
            'Cuota Ordinaria de Mantenimiento',
            1500.00,
            10,
            '2026-01-01',
            'Residente',
            true,
            '6754a566-e529-40fb-8610-bd136ec77fd5'
        ) ON CONFLICT (vivienda_id, tipo, concepto) WHERE activa = true DO UPDATE 
        SET monto = EXCLUDED.monto,
            dia_vencimiento = EXCLUDED.dia_vencimiento;

        -- Cargo 1: Mes anterior (Pagado)
        INSERT INTO public.cargos (
            id, condominio_id, vivienda_id, plantilla_id, tipo, concepto, monto,
            periodo, fecha_vencimiento, estado, responsable_pago, creado_por
        ) VALUES (
            'fe000000-0000-0000-0000-000000000001',
            'a0000000-0000-0000-0000-000000000001',
            v_vivienda_id,
            'fd000000-0000-0000-0000-000000000001',
            'Mantenimiento',
            'Cuota Ordinaria de Mantenimiento',
            1500.00,
            (date_trunc('month', now() - interval '1 month'))::date,
            ((date_trunc('month', now() - interval '1 month'))::date + 9),
            'Pagado',
            'Residente',
            '6754a566-e529-40fb-8610-bd136ec77fd5'
        ) ON CONFLICT (plantilla_id, periodo) DO NOTHING;

        -- Cargo 2: Mes actual (Pendiente)
        INSERT INTO public.cargos (
            id, condominio_id, vivienda_id, plantilla_id, tipo, concepto, monto,
            periodo, fecha_vencimiento, estado, responsable_pago, creado_por
        ) VALUES (
            'fe000000-0000-0000-0000-000000000002',
            'a0000000-0000-0000-0000-000000000001',
            v_vivienda_id,
            'fd000000-0000-0000-0000-000000000001',
            'Mantenimiento',
            'Cuota Ordinaria de Mantenimiento',
            1500.00,
            (date_trunc('month', now()))::date,
            ((date_trunc('month', now()))::date + 9),
            'Pendiente',
            'Residente',
            '6754a566-e529-40fb-8610-bd136ec77fd5'
        ) ON CONFLICT (plantilla_id, periodo) DO NOTHING;
    END IF;
END $$;

-- ==============================================================================
-- 13. PAGOS Y COMPROBANTES
-- ==============================================================================
INSERT INTO public.pagos (
    id, cargo_id, monto, monto_cubierto, monto_excedente, fecha_pago, metodo,
    referencia, banco_origen, estado, origen, comprobante_ruta, comprobante_hash,
    es_reversa, registrado_por, confirmado_por, confirmado_en
) VALUES (
    'ff000000-0000-0000-0000-000000000001',
    'fe000000-0000-0000-0000-000000000001',
    1500.00,
    1500.00,
    0.00,
    ((date_trunc('month', now() - interval '1 month'))::date + 5),
    'Transferencia',
    'SPEI-9988112233',
    'BBVA Bancomer',
    'Confirmado',
    'Inquilino',
    'comprobantes/casa-101/pago_mantenimiento_anterior.pdf',
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    false,
    'e0000000-0000-0000-0000-000000000001',
    '6754a566-e529-40fb-8610-bd136ec77fd5',
    timezone('utc'::text, now() - interval '25 days')
) ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- 14. SALDO A FAVOR Y MOVIMIENTOS CONTABLES
-- ==============================================================================
DO $$
DECLARE
    v_vivienda_id INTEGER;
BEGIN
    SELECT id INTO v_vivienda_id FROM public.viviendas WHERE numero_casa = 'Casa 101' LIMIT 1;

    IF v_vivienda_id IS NOT NULL THEN
        INSERT INTO public.movimientos_saldo_favor (
            id, condominio_id, vivienda_id, tipo, monto, pago_id, cargo_id, motivo, creado_por
        ) VALUES (
            'fa100000-0000-0000-0000-000000000001',
            'a0000000-0000-0000-0000-000000000001',
            v_vivienda_id,
            'Abono',
            200.00,
            NULL,
            NULL,
            'Saldo inicial transferido por administración',
            '6754a566-e529-40fb-8610-bd136ec77fd5'
        ) ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;