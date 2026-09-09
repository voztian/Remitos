# Pruebas de aceptación — GoRemitos v2.7

No habilites clientes reales hasta completar esta lista con datos ficticios. Registrá fecha, navegador, usuario y resultado de cada prueba.

## A. Instalación

- [ ] `supabase-migration-v2.7.sql` termina sin error.
- [ ] Vercel muestra v2.7 como `Ready` antes de ejecutar `supabase-finalizar-v2.7.sql`.
- [ ] `supabase-finalizar-v2.7.sql` termina sin error.
- [ ] Todos los controles de `supabase-verificacion-v2.7.sql` dicen `true`.
- [ ] La consulta de anomalías devuelve cero filas.
- [ ] Vercel muestra el deployment como `Ready`.
- [ ] `VERSION.txt` y la aplicación muestran 2.7.0.
- [ ] Una recarga forzada no vuelve a mostrar v2.6.
- [ ] En **Preparación para el piloto** está elegida la modalidad real: Pro o piloto controlado en Free, nunca una declaración falsa.
- [ ] Si se eligió Free, se ensayó una restauración externa de base y Storage antes de usar datos reales.
- [ ] El procedimiento de reversión se leyó y no se ejecuta si hay viajes en curso.

## B. Roles y aislamiento

- [ ] Administrador puede programar, editar y eliminar una entrega no iniciada.
- [ ] Oficina puede programar y editar, pero no eliminar.
- [ ] Chofer sólo ve remitos asignados a su usuario.
- [ ] Chofer no puede ver documentos de otro chofer.
- [ ] Un usuario de otra empresa no puede leer remitos, documentos ni evidencias.
- [ ] Usuario eliminado pierde acceso y sus entregas programadas quedan sin chofer.
- [ ] No se puede eliminar ni cambiar de rol a un chofer con una entrega en camino.
- [ ] Después de cerrar ese viaje, el administrador sí puede eliminarlo o cambiarle el rol.

## C. Documento original

- [ ] Alta sin archivo es rechazada.
- [ ] PDF válido menor de 10 MB se guarda.
- [ ] JPG, PNG y WebP válidos se guardan.
- [ ] Archivo mayor de 10 MB es rechazado antes de subir.
- [ ] TXT, DOCX, SVG o ejecutable renombrado son rechazados.
- [ ] Los archivos de prueba provienen de un origen confiable; no se presenta esta validación como antivirus.
- [ ] Documento puede abrirse y descargarse por administrador, oficina y chofer asignado.
- [ ] Abrir, descargar y generar la constancia vuelven a verificar el SHA-256 del documento.
- [ ] Documento no abre en una ventana incógnita usando sólo su URL de Storage vencida.
- [ ] La descarga coincide con el hash registrado.
- [ ] Reemplazar el documento antes de la salida conserva el nuevo y limpia el anterior.
- [ ] El mismo objeto no puede vincularse a dos remitos.

## D. Estados y bloqueo

- [ ] Al crear, la entrega aparece como **Programado**.
- [ ] Antes de iniciar no aparece el formulario de firma.
- [ ] **Iniciar viaje** pide confirmación.
- [ ] Después de iniciar aparece **En camino** con la hora correcta.
- [ ] Después de iniciar, administrador/oficina ya no pueden editar.
- [ ] Después de iniciar, administrador ya no puede eliminar.
- [ ] Una baja y un inicio simultáneos nunca dejan el viaje asignado a un usuario inactivo.
- [ ] Tocar dos veces o repetir la llamada no duplica el evento de inicio.
- [ ] No puede cerrarse una entrega sin inicio registrado.

## E. Seguimiento público

- [ ] El enlace abre en incógnito sin iniciar sesión.
- [ ] Muestra empresa, número, fecha, estado y horarios.
- [ ] No muestra cliente, domicilio, contacto, teléfono, chofer, ítems ni cantidades.
- [ ] No permite abrir o descargar el remito original.
- [ ] No muestra receptor, DNI, firma, fotos, hashes ni IDs internos.
- [ ] Un token modificado muestra “Entrega no encontrada”.
- [ ] Un valor que no es UUID muestra “Enlace inválido”.
- [ ] Cambia de Programado a En camino y luego a Entregado sin cambiar el enlace.
- [ ] QR y compartir producen exactamente el mismo enlace.

## F. Cierre de entrega

- [ ] No permite continuar hasta revisar todos los ítems.
- [ ] Conforme exige receptor, DNI, confirmación de información y firma.
- [ ] Disconforme registra cantidades, observaciones y fotos opcionales.
- [ ] Rechazo exige motivo y no guarda firma de conformidad.
- [ ] Una caída durante la subida no cierra parcialmente y limpia archivos huérfanos recientes.
- [ ] El cierre genera hash y snapshot.
- [ ] El snapshot contiene hash/metadata del documento original y hora de salida.
- [ ] Una constancia cerrada no se puede modificar ni borrar.
- [ ] El PDF se titula como constancia, no como remito fiscal.
- [ ] El PDF verifica todas las evidencias antes de generarse.

## G. Contingencia

- [ ] Sin conexión, iniciar y guardar quedan bloqueados con un mensaje claro.
- [ ] El formulario abierto conserva lo escrito mientras no se recargue la pestaña.
- [ ] El chofer conoce el procedimiento en papel si no hay conexión.
- [ ] Al recuperar señal puede cargar la foto del remito firmado en **Manual**.
- [ ] La evidencia manual no puede reutilizarse.

## H. Autenticación y privacidad heredadas

- [ ] Google permite elegir la cuenta y sólo acepta emails autorizados.
- [ ] Email/contraseña exige confirmación y CAPTCHA cuando está habilitado.
- [ ] Recuperar contraseña pide el email y vuelve al dominio productivo.
- [ ] El nombre del usuario aparece correctamente y puede actualizarse.
- [ ] El aviso de privacidad corresponde a v2.7.
- [ ] Los datos legales y de conservación de la empresa están completos.
- [ ] El enlace público se comparte sólo con personas involucradas.

## I. Operación

- [ ] SMTP propio probado.
- [ ] OAuth productivo probado con al menos dos cuentas.
- [ ] CAPTCHA probado en alta, ingreso y recuperación.
- [ ] Exportación/restauración de base ensayada.
- [ ] Copia de documentos y evidencias ensayada.
- [ ] El inventario y la restauración abarcan por separado `documentos-remito` y `evidencias`, según `OPERACION-Y-BACKUPS-v2.7.md`.
- [ ] Existe responsable para incidentes y soporte.
- [ ] Existe procedimiento para baja, rectificación y supresión de datos.
- [ ] Se acordó con el cliente que GoRemitos no emite el remito original.
- [ ] Cliente y GoRemitos completaron el alcance y las aprobaciones de `PRIVACIDAD-Y-CONTRATOS-v2.7.md`.

## Criterio de aprobación

El piloto sólo se aprueba si no hay fallas en aislamiento, documento original, inicio de viaje, cierre, inmutabilidad o privacidad pública. Una falla en esos grupos bloquea la salida aunque el resto funcione.
