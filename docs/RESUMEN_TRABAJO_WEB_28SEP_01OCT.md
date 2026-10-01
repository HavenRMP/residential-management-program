# Resumen del trabajo en la web (28 sep – 1 oct 2026)

Cobertura: solo `web/` (Angular 19, standalone + signals, Tailwind, SweetAlert2). Todo se probó contra los servicios reales (Render + Supabase) con cuentas de prueba de cada rol, en el condominio **Maderas**.

## 1. En una página

- **Visitas** quedó completa de punta a punta: el residente programa, edita, cancela y comparte el código (copiar, QR, compartir, imprimir); la caseta valida el código y **registra la entrada automáticamente**; el administrador y el vigilante consultan el historial.
- **Caseta del vigilante** ahora tiene tres pestañas (**Próximas 24 h**, **Programadas**, **Historial**), un **Directorio** de personas con casa y teléfono, y los avisos del condominio en solo lectura.
- **Administrador**: el directorio de viviendas muestra si cada casa está **ocupada o disponible**, con filtro; el dashboard lleva al detalle de cada vivienda; las tarjetas de resumen son enlaces.
- **Sub-usuarios**: invitación por correo con validación, banner de invitaciones pendientes y manejo de invitaciones obsoletas sin mostrar errores técnicos.
- **Diseño**: residente, vigilante y administrador aprovechan todo el ancho de la pantalla.
- **Calidad**: 244 pruebas unitarias pasando y una verificación de punta a punta de 31 chequeos con las tres cuentas reales, todos en verde (ver sección 5).

## 2. Qué se hizo por módulo

### Visitas (residente)
- Programar, editar y cancelar visitas; el formulario bloquea una llegada cuya vigencia ya terminó y solo envía los campos que cambiaron al editar. (#808, #856)
- Compartir el código de acceso: copiar, código QR, menú nativo de compartir e imprimir. (#810, #856)
- Una visita programada cuyo día ya pasó sin que llegara el visitante se muestra **Expirada** y ya no se puede editar, cancelar ni mostrar su código, aunque el backend tarde en marcarla. (#881)

### Caseta (vigilante y administrador)
- **Próximas 24 h**: visitas por atender en una ventana móvil de 24 horas más las que están en curso. Usa `GET /api/visitas/proximas`; el endpoint anterior `/hoy` fue eliminado por el backend. (#808, #920)
- **Validar código = dar entrada.** Si el código es de una visita programada se registra la entrada de inmediato con las placas que ya indicó el residente. Si la visita no está por atender se explica con el nombre del visitante en lugar de dejar la tarjeta vacía. (#880, #922)
- **Programadas**: visitas que llegan después de las próximas 24 h, la más próxima primero, solo de consulta. (#881)
- **Historial**: solo visitas que ya pasaron (Finalizada, Cancelada, Expirada), con paginación y filtro por estado. (#864, #881)
- Detalle de cada visita en caseta (#810), captura de placas al dar ingreso (#861) y la sección "a quién avisar en la casa" con los residentes de esa casa (#862).
- Avisos del condominio en solo lectura, con prioridad y conteo de urgentes. (#862)

### Directorio de personas (vigilante)
- Vistas **Caseta** y **Directorio** para no saturar la pantalla. Cada fila muestra persona, casa y teléfono; hay búsqueda por casa, nombre o teléfono. (#862, #864)
- Sin botones de llamar ni copiar: el teléfono es un enlace `tel:` que se toca para llamar desde un celular o tableta. (#880)

### Administrador
- Directorio de viviendas con columna **Ocupación** (Ocupada con número de residentes, o Disponible) y filtro Todas / Ocupadas / Disponibles. La ocupación sale de `GET /api/viviendas/con-residentes`; mientras carga se ve un marcador y, si falla, un guion: nunca afirma "Disponible" sin saberlo. (#916)
- Cada fila de "Estado de viviendas" del dashboard abre el detalle en el directorio mediante `?vivienda=ID`. (#916)
- Tarjetas de resumen del panel clickeables. (#857)
- Directorio de vigilantes conectado al backend: alta, baja y reactivación, y mensaje claro cuando una cuenta fue dada de baja al iniciar sesión. (#708, #779, #861)

### Sub-usuarios (residente)
- Invitación por correo con el nuevo contrato del backend, validación de formato del correo y banner de invitaciones pendientes en el portal. (#764, #810, #812)
- Si una invitación ya fue respondida o cancelada, la pantalla refresca las listas y avisa con un mensaje claro. Cualquier error técnico del backend (JSON de Supabase) se oculta. (#866)

### Avisos y notificaciones
- La prioridad de un aviso se refleja correctamente en el badge. (#763)
- La notificación de un aviso urgente lleva al aviso, ya no al login; la campana de notificaciones aparece también en el topbar de escritorio del administrador y la ruta `/visitas/:id` funciona. (#778, #809)

### Login y diseño general
- Skeleton en el login en lugar del texto "Cargando". (#812)
- Residente, vigilante y administrador usan todo el ancho; en pantallas grandes el portal del residente muestra vivienda y avisos en dos columnas, y las visitas y sub-usuarios se reparten en columnas. En móvil no cambia (verificado a 390 px, sin desbordes). (#916, #921)

## 3. Decisiones que conviene recordar

| Decisión | Motivo |
|---|---|
| "Vencida" se define por el **fin de la vigencia**, no por el día calendario | Es el mismo criterio con el que el backend marca `expirada`. Una visita con llegada ayer pero vigencia todavía abierta sigue siendo editable. |
| "Programadas" empieza **después** de la ventana de 24 h | Evita repetir en dos pestañas lo que el backend ya devuelve en `/proximas`. |
| El historial no tiene "Todos los estados" | Mezclaba visitas activas con las pasadas, y el filtro `estado` del backend solo acepta un valor. |
| La ocupación del directorio sale de `/api/viviendas/con-residentes` | Una sola consulta paginada en lugar de una por vivienda. |
| Se resuelve en el frontend lo que el backend contesta incompleto | Evita que una respuesta vacía pise datos buenos de la lista (`fusionarSinVacios`) y que respuestas lentas pisen a las recientes. |

## 4. Problemas encontrados en backend y BD

### Resueltos
- Vistas sin columnas que el frontend necesitaba; 502 al filtrar por vivienda; `alta_visita` con parámetros opcionales (VI008); `cancelar_invitacion` con `p_id` en lugar de `p_invitacion_id`; error 500 al editar una visita.
- El vigilante recibía 403 en `GET /api/visitas/historico`: ya tiene permiso.

### Abiertos (para el equipo de backend)
1. **`GET /api/visitas/proximas` ya no busca por número de casa** en `busqueda` (antes lo hacía el RPC `buscar_visitas_hoy`). El identificador de casa es texto alfanumérico (16-B, A-204), así que debe ser coincidencia de texto. Corrección sugerida: agregar `numero_casa.ilike.{b}` al `or=(...)` de `GetVisitasProximasAsync`; la vista ya expone la columna. Cuando se despliegue, el placeholder de la caseta pasa a "Nombre, casa, placas o código…".
2. **`GET /api/visitas/codigo/{codigo}` devuelve `estado` vacío** y `vigenciaHasta` en `0001-01-01`. La web ya lo completa con la lista de próximas, pero debería devolver los valores reales como el resto de endpoints de visitas.
3. **Responder dos veces una invitación (SU004)** devuelve el JSON crudo de Supabase en `error`. La web lo oculta, pero conviene un mensaje legible desde el origen.
4. **`estado` del histórico solo acepta un valor** (con varios usa el primero; con comas responde 400). Si aceptara varios o hubiera un filtro de "ya pasadas", el historial podría tener un "Todas" sin mezclar activas.
5. **Proceso**: el cambio de `/hoy` a `/proximas` llegó sin aviso previo y dejó la caseta rota en producción hasta que se detectó. Conviene anunciar los cambios de rutas antes de desplegarlos.

## 5. Verificación

Se ejecutó sobre la rama del PR #922 (que incluye todo lo anterior), con el frontend local apuntando a los servicios reales y las cuentas de administrador, residente y vigilante. Resultado: **31 de 31 chequeos en verde**.

- **Administrador (11):** enlace del dashboard al detalle, etiquetas Ocupada/Disponible, apertura y cierre del detalle con `?vivienda=`, columna y filtros de ocupación, ancho de la tabla, historial de visitas.
- **Residente (6):** avisos en columna derecha, visitas vencidas sin editar ni cancelar, vigentes con Editar y Cancelar, dos columnas, programar visita con código, sub-usuarios sin JSON técnico.
- **Vigilante (14):** pestañas, ver la visita recién programada, validar código con entrada automática y limpieza del campo, registrar salida, Programadas, Historial (solo estados pasados, sin error de permiso, con la visita finalizada), Directorio con enlaces `tel:` y sin botones, ancho completo.

**La verificación encontró un fallo real** que las pruebas unitarias no habían detectado: la validación del código devolvía `estado` vacío y el registro automático no actuaba. Se corrigió en el PR #922 y se volvió a verificar.

**Alcance y límites**
- La cuenta de administrador de prueba solo tiene una vivienda, así que el estado "Disponible" y el filtro de disponibles se comprobaron sin datos reales (devuelven cero filas, sin error).
- No se reprodujo el caso SU004 de una invitación obsoleta contra el backend real; está cubierto con pruebas unitarias.
- No se probó la app móvil (Flutter) ni la web en un navegador distinto a Chromium.
- El registro automático de entrada y la salida usaron una visita de prueba que quedó finalizada en Maderas.

## 6. Pendientes

- Mergear el PR #922 y repetir el recorrido sobre `main`.
- Cuando backend despliegue la búsqueda por casa: cambiar el placeholder de la caseta y verificarlo.
- Opcionales sin pedir: tarjeta "Estado del Sistema" en el panel del administrador, cerrar con comentario los issues de GitHub ya resueltos, notificaciones push en web (requiere Firebase y soporte del backend).
- Siguiente sprint: paquetería, reservas y pagos.

## Anexo: pull requests

| PR | Cambio |
|---|---|
| #763 | Badge de prioridad de avisos |
| #764 | Sub-usuarios: invitación por correo (nuevo contrato) |
| #778 | Notificación de aviso urgente ya no manda al login |
| #779 | Alta de vigilantes conectada al backend |
| #808 | Visitas: residente, caseta e histórico |
| #809 | Ruta `/visitas/:id` y campana en el topbar del administrador |
| #810 | Compartir código, búsqueda reactiva, detalle en caseta, validación de correo |
| #812 | Banner de invitaciones de sub-usuario y skeleton en el login |
| #856 | QR del código, ajustes de fecha, viviendas e histórico |
| #857 | Tarjetas de resumen del panel clickeables |
| #861 | Vigilantes con el backend, placas en caseta y mensaje de baja |
| #862 | Directorio de casas y avisos de solo lectura en caseta |
| #864 | Directorio de personas, vistas Caseta/Directorio e historial |
| #866 | Sub-usuarios: refrescar listas y ocultar errores técnicos |
| #880 | Entrada automática al validar código y directorio sin botones de contacto |
| #881 | Pestaña Programadas, historial solo de pasadas y visitas vencidas sin edición |
| #916 | Ocupación en el directorio de viviendas, enlace desde el dashboard y ancho completo |
| #920 | Caseta usa `/api/visitas/proximas` |
| #921 | Residente y vigilante a todo el ancho |
| #922 | Validación del código con estado vacío (abierto) |
