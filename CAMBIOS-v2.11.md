# GoRemitos 2.11 — revisión de experiencia y consistencia

- Una caída temporal al consultar el modo conserva los campos, archivo, firma y fotos. El guardado se pausa hasta verificar de nuevo; ya no se interpreta un fallo de red como modo desactivado.
- Cada escritura vuelve a comprobar el estado. La creación y el respaldo manual comunican a la base el modo esperado, validado dentro de la misma transacción que guarda.
- Navegar fuera de un formulario con cambios pide confirmación. Durante el guardado se evita salir.
- El chofer consulta sus pendientes por separado del historial y puede cargar más. Una entrega anterior a los primeros 100 registros ya no desaparece.
- La búsqueda y los filtros consultan todo el historial con paginación. La consulta se conserva al cargar más resultados y los términos se escapan como valores.
- Los remitos abiertos mediante un enlace interno se consultan directamente, aunque no estén en la primera página.
- Después de guardar o cerrar se recarga el registro concreto, incluyendo constancia y evidencias.
- Una entrega con faltantes o daños no puede cerrarse como conforme. Un rechazo total no puede declarar mercadería recibida. La base también protege estas reglas para pestañas antiguas.
- El servidor valida el dígito verificador del CUIT para habilitar operación real.
- Los teléfonos argentinos con prefijo local 15 se normalizan; los incompletos no abren un destinatario incorrecto en WhatsApp.
- El generador PDF permite reintentar si falla la carga de su biblioteca.
- El inicio del viaje bloquea la navegación mientras guarda y recupera el botón si falla la conexión. El cierre actualiza el estado de la cabecera y lleva a la constancia; si la escritura ya fue confirmada pero falla la recarga, informa que quedó guardada y evita ofrecer un segundo cierre.
- Los campos de receptor conservan sus etiquetas accesibles al abrir la entrega. El PDF mide los valores con su fuente final y reduce saltos de página innecesarios.
- La publicación usa una lista explícita de archivos. No expone migraciones, documentación, pruebas ni la aplicación vieja.
- Pruebas de funciones, DOM y PostgreSQL en memoria con datos ficticios. Banco visual separado disponible solamente en deployments de preview.

No se introducen emisión fiscal, geolocalización, envíos automáticos ni guardado sin conexión.

## Ajustes 2.11.1 — prueba en producción

- La creación confirmada libera la navegación aunque falle la consulta posterior. Avisa que el remito ya se guardó y evita presentar el mismo formulario como pendiente de guardar.
- Los archivos vacíos tienen un mensaje específico, separado del límite de 10 MB.
- Los horarios se muestran expresamente en formato de 24 horas, conservando la zona horaria del dispositivo.
