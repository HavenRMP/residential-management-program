# Reporte de Auditoría y Actualización de Base de Datos (HAVEN)

## 1. Resolución de Bugs en Producción

### 1.1. Corrección en Edición de Avisos (Caso 2)

* **Problema:** La función `cambio_aviso` fallaba por una referencia errónea a la tabla `condominio` (en singular) y enviaba avisos vencidos al historial involuntariamente por recalcular la fecha de vigencia de forma estricta.
* **Solución Técnica:** Se ajustó la consulta de retorno para utilizar `condominios` (plural). Se modificó la lógica condicional del cálculo de vigencia para que, si no se envían explícitamente nuevos parámetros de tiempo, la fecha original de expiración permanezca intacta.

### 1.2. Corrección en Asignación de Residentes (Caso 5)

* **Problema:** La función `asignar_residente_vivienda` no actualizaba el `condominio_id` del usuario en la tabla `usuarios`, dejándolo sin acceso a las consultas de su complejo.
* **Solución Técnica:** Se agregó un comando UPDATE en el Stored Procedure para actualizar automáticamente la columna `condominio_id` del usuario al momento de vincularlo a una vivienda. Adicionalmente, se ejecutó un script de actualización retroactiva masiva para reparar a los residentes huérfanos preexistentes.

---

## 2. Contratos de Integración y Nuevas Estructuras

Todas las entidades nuevas cumplen estrictamente con la arquitectura de HAVEN: revocación de permisos directos a tablas físicas, creación de tablas de bitácora (`_bitacora`), configuración de triggers `fn_auditoria()` para acciones CUD, y encapsulamiento mediante vistas y funciones (`SECURITY DEFINER`).

### 2.1. Entidad: Avisos (Actualización de Prioridad - Caso 1)

**Estructura de Tabla Modificada:**

* Se agregó la columna `prioridad` (`VARCHAR(20) NOT NULL DEFAULT 'informativo'`).
* Se aplicó un constraint `CHECK` para restringir valores a: `'informativo'`, `'urgente'`, `'mantenimiento'`, `'evento'`.

#### Vistas de Consulta

* **`vw_avisos_vigentes`** y **`vw_avisos_historico`**
* `id`: UUID
* `condominio_id`: UUID
* `condominio_nombre`: VARCHAR(150)
* `titulo`: VARCHAR(200)
* `contenido`: TEXT
* `prioridad`: VARCHAR(20) *(NUEVO)*
* `duracion_dias`: INTEGER
* `fecha_expiracion_manual`: TIMESTAMPTZ
* `fecha_publicacion`: TIMESTAMPTZ
* `fecha_expiracion`: TIMESTAMPTZ
* `activo`: BOOLEAN
* `estado`: VARCHAR *(Solo presente en vw_avisos_historico)*
* `creado_por`: UUID
* `creado_por_nombre`: TEXT
* `creado_en`: TIMESTAMPTZ



#### Stored Procedures (RPC)

* **`alta_aviso`**
* Parámetros:
* `p_creado_por`: UUID (Obligatorio)
* `p_titulo`: VARCHAR(200) (Obligatorio)
* `p_contenido`: TEXT (Obligatorio)
* `p_duracion_dias`: INTEGER (Opcional, default 7)
* `p_fecha_expiracion`: TIMESTAMPTZ (Opcional, default NULL)
* `p_prioridad`: VARCHAR(20) (Opcional, default 'informativo')


* Retorna: Registro completo de `vw_avisos_vigentes`.


* **`cambio_aviso`**
* Parámetros:
* `p_id`: UUID (Obligatorio)
* `p_actor_id`: UUID (Obligatorio)
* `p_titulo`: VARCHAR(200) (Opcional)
* `p_contenido`: TEXT (Opcional)
* `p_duracion_dias`: INTEGER (Opcional)
* `p_fecha_expiracion`: TIMESTAMPTZ (Opcional)
* `p_prioridad`: VARCHAR(20) (Opcional)


* Retorna: Registro actualizado de `vw_avisos_vigentes`.



---

### 2.2. Entidad: Notificaciones Internas (Caso 4)

**Estructura de Tabla Base:**

* Tabla `notificaciones` con llaves foráneas a `usuarios` (en cascada). Cuenta con un índice parcial optimizado para conteo rápido y campanas de alertas (`WHERE leida = false`).

#### Vista de Consulta

* **`vw_notificaciones`** (Lectura GET)
* `id`: UUID
* `usuario_id`: UUID
* `usuario_nombre`: TEXT
* `usuario_email`: VARCHAR(255)
* `tipo_evento`: VARCHAR(50)
* `titulo`: VARCHAR(150)
* `mensaje`: TEXT
* `url_redireccion`: TEXT
* `leida`: BOOLEAN
* `creado_en`: TIMESTAMPTZ



#### Stored Procedures (RPC)

* **`alta_notificacion`**
* Parámetros:
* `p_usuario_id`: UUID (Obligatorio)
* `p_tipo_evento`: VARCHAR(50) (Obligatorio)
* `p_titulo`: VARCHAR(150) (Obligatorio)
* `p_mensaje`: TEXT (Obligatorio)
* `p_url_redireccion`: TEXT (Opcional)


* Retorna: Registro creado de `vw_notificaciones`.


* **`marcar_notificacion_leida`**
* Parámetros:
* `p_id`: UUID (Obligatorio)
* `p_usuario_id`: UUID (Obligatorio)


* Retorna: BOOLEAN (`true` si la notificación fue marcada como leída).


* **`marcar_todas_notificaciones_leidas`**
* Parámetros:
* `p_usuario_id`: UUID (Obligatorio)


* Retorna: INTEGER (Cantidad total de notificaciones que pasaron a estado leído).



---

### 2.3. Entidad: Sub-usuarios e Invitaciones (Caso 3)

**Estructura de Tablas Base:**

* `vivienda_subusuarios`: Relación consolidada y definitiva de residentes secundarios.
* `codigos_subusuario`: Almacén temporal de invitaciones con vigencia estricta de 24 horas e índice parcial único para evitar colisiones de códigos alfanuméricos simultáneos activos.

#### Vistas de Consulta

* **`vw_vivienda_subusuarios`** (Residentes secundarios registrados)
* `id`: UUID
* `vivienda_id`: INTEGER
* `numero_casa`: VARCHAR(50)
* `condominio_id`: UUID
* `condominio_nombre`: VARCHAR(150)
* `usuario_id`: UUID
* `usuario_nombre`: TEXT
* `usuario_email`: VARCHAR(255)
* `usuario_telefono`: VARCHAR(20)
* `parentesco`: VARCHAR(50)
* `activo`: BOOLEAN
* `creado_en`: TIMESTAMPTZ


* **`vw_codigos_subusuario`** (Invitaciones generadas y su estatus)
* `id`: UUID
* `vivienda_id`: INTEGER
* `numero_casa`: VARCHAR(50)
* `condominio_id`: UUID
* `codigo`: VARCHAR(6)
* `parentesco`: VARCHAR(50)
* `expira_en`: TIMESTAMPTZ
* `activo`: BOOLEAN
* `es_vigente`: BOOLEAN (Campo calculado: activo = true, usado_por IS NULL, expira_en > now)
* `usado_por`: UUID
* `usado_por_nombre`: TEXT
* `usado_en`: TIMESTAMPTZ
* `creado_por`: UUID
* `creado_por_nombre`: TEXT
* `creado_en`: TIMESTAMPTZ



#### Stored Procedures (RPC)

* **`generar_codigo_subusuario`**
* *Regla de Negocio:* Máximo estricto de 2 sub-usuarios por vivienda, calculando perfiles activos sumados a invitaciones vigentes.
* Parámetros:
* `p_vivienda_id`: INTEGER (Obligatorio)
* `p_parentesco`: VARCHAR(50) (Obligatorio)
* `p_creado_por`: UUID (Obligatorio)


* Retorna: Registro creado de `vw_codigos_subusuario`.


* **`cancelar_codigo_subusuario`** (Desactivación manual para liberar cupo)
* Parámetros:
* `p_id`: UUID (Obligatorio)


* Retorna: BOOLEAN (`true` si desactivó el código).


* **`redimir_codigo_subusuario`**
* *Regla de Negocio:* Valida existencia, caducidad, auto-asigna el `condominio_id` al usuario y lo inserta definitivamente en `vivienda_subusuarios`.
* Parámetros:
* `p_codigo`: VARCHAR(6) (Obligatorio)
* `p_usuario_id`: UUID (Obligatorio)


* Retorna: Registro consolidado de `vw_vivienda_subusuarios`.


* **`baja_subusuario`** (Baja lógica del acceso secundario)
* Parámetros:
* `p_vivienda_id`: INTEGER (Obligatorio)
* `p_usuario_id`: UUID (Obligatorio)


* Retorna: BOOLEAN (`true` si desactivó el perfil).



#### Matriz de Errores SQL (Sub-usuarios)

| Código SQL | Causa de Negocio | HTTP Status Recomendado |
| --- | --- | --- |
| `SU001` | Límite máximo de 2 sub-usuarios alcanzado en la vivienda. | 409 Conflict |
| `SU002` | El usuario ya es el residente titular de esta vivienda. | 409 Conflict |
| `CD001` | El código de invitación no existe. | 404 Not Found |
| `CD002` | El código ya fue utilizado. | 409 Conflict |
| `CD003` | El código ha caducado (pasaron 24h) o fue cancelado manualmente. | 410 Gone / 400 Bad Request |
| `CD004` | El usuario ya se encuentra vinculado a un condominio diferente. | 409 Conflict |
