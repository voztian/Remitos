# Cambios de GoRemitos v2.7

## Circuito operativo

- El alta pasó de “crear un remito” a **programar una entrega con remito externo**.
- El PDF o imagen del remito original es obligatorio para altas nuevas.
- Se incorporó el estado derivado **Programado**.
- El estado **En camino** comienza únicamente cuando el chofer toca **Iniciar viaje**.
- Una entrega iniciada ya no puede editarse ni eliminarse.
- El inicio se registra con usuario y hora en la trazabilidad.
- La baja o el cambio de rol de un chofer queda bloqueado mientras tenga una
  entrega en camino. Las operaciones concurrentes se serializan por empresa.

## Documento original

- Bucket privado independiente `documentos-remito`.
- Formatos permitidos: PDF, JPG, PNG y WebP.
- Límite: 10 MB.
- SHA-256 calculado antes de la subida.
- Metadata, tamaño y tipo verificados por el backend.
- Prevención de reutilización del mismo objeto en dos remitos.
- Vista, descarga y uso de compartir nativo para usuarios autorizados.
- El snapshot final incluye la metadata y el hash del documento.

## Seguimiento del destinatario

- Nuevo enlace `#seguimiento=<token>` que no requiere una cuenta y no entrega el token al hosting.
- Estados visibles: Programado, En camino, Entregado, Entregado con observaciones o Rechazado.
- Actualización automática cada 30 segundos mientras la pestaña está visible.
- QR y opción de compartir desde el alta y el detalle.
- Mensajes de WhatsApp con enlace de seguimiento.
- El RPC público omite domicilio, teléfono, contacto, mercadería, documento, usuarios, receptor, DNI, firma, fotos y hashes.

## Dashboard y navegación

- Contadores separados para Programados, En camino y Entregados.
- Filtros nuevos por etapa real del viaje.
- Detalle con línea temporal, hora de salida y documento original.
- Terminología aclarada: el PDF final es una constancia de seguimiento y entrega, no un remito fiscal.

## Backend y seguridad

- Nuevas columnas `documento_*`, `salida_at` y `salida_por`.
- Nuevos RPC `guardar_remito_v27`, `marcar_en_camino_v27`, `confirmar_entrega_v27`, `resumen_remitos_v27`, `obtener_seguimiento_publico_v27` y `eliminar_remito_pendiente_v27`.
- Se revocan los RPC v2.6 que permitirían guardar o cerrar sin aplicar las reglas nuevas.
- Las políticas de Storage aíslan empresa, rol y chofer asignado.
- La limpieza sólo alcanza documentos que ya no estén vinculados.
- El seguimiento público usa una consulta de campos mínimos por token UUID aleatorio.
- Pro deja de ser un bloqueo técnico: se puede elegir un piloto controlado en Free, con aceptación explícita del riesgo y backups externos obligatorios.
- Los errores de cliente quedan identificados como versión 2.7 para facilitar el diagnóstico durante el piloto.
- La actualización se separa en migración, deployment y finalización para no cortar la web v2.6 durante la publicación.
- Se incluye una reversión de emergencia no destructiva, bloqueada cuando existen viajes en curso.

## Compatibilidad

- No se borran datos ni usuarios de v2.6.
- Las constancias cerradas anteriores siguen visibles.
- Los pendientes creados antes de v2.7 aparecen como Programados sin documento y deben editarse para adjuntarlo antes de iniciar.
- El respaldo Manual continúa usando el cierre verificado de v2.6.
