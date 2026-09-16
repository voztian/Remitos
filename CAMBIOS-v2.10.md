# GoRemitos v2.10

## Resultado

La empresa puede activar un modo de prueba interna para recorrer el circuito completo sin presentar esa actividad como operación real.

## Cambios

- El administrador de la empresa activa o desactiva el modo desde **Usuarios**.
- Oficina puede adjuntar un remito externo ficticio y asignarlo a un chofer.
- El chofer puede iniciar el viaje, revisar ítems, registrar receptor y firma, y cerrar la prueba.
- Los registros se marcan en el servidor como `PRUEBA`; el navegador no puede elegir ni quitar esa clasificación.
- Las pruebas se identifican en listados, detalles, seguimiento público y PDF.
- Los avisos por WhatsApp al destinatario se bloquean durante una prueba.
- No se puede activar el modo si hay entregas reales pendientes ni desactivarlo si quedan pruebas pendientes.
- La excepción de preparación se limita a cada transacción v2.10 y no habilita altas de clientes ni otras funciones de plataforma.

## Instalación

1. Ejecutar `supabase-migration-v2.10.sql` en Supabase.
2. Publicar los archivos web.
3. Ejecutar `supabase-verificacion-v2.10.sql`; todos los controles deben devolver `true` y la segunda consulta, cero filas.

No hay que volver a ejecutar migraciones anteriores.
