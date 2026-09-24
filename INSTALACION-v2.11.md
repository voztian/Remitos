# Actualizar de 2.10 a 2.11

1. Conservar el commit anterior de GitHub y comprobar el respaldo habitual de base y Storage.
2. Ejecutar completo `supabase-migration-v2.11.sql` en el proyecto correcto. Es una transacción compatible con la interfaz 2.10 y no altera registros existentes.
3. Ejecutar `supabase-verificacion-v2.11.sql`: los seis controles deben ser `true`. La segunda consulta informa incoherencias heredadas; no las modifica.
4. Publicar la rama verificada en `main`. Vercel ejecuta `node scripts/build-static.mjs` y sirve exclusivamente `dist`.
5. Comprobar que Vercel esté Ready, el HTML publicado coincida con el commit y las rutas de SQL, pruebas, QA y la versión vieja devuelvan 404.
6. Probar Oficina → asignación → Chofer → salida → recepción → constancia con datos ficticios.

La interfaz 2.11 requiere los dos RPC nuevos. No publicarla antes de aplicar la migración.

## Reversión

Si fuera necesario, volver a desplegar el commit anterior de la interfaz. Las funciones 2.10 se conservan. La validación de coherencia del cierre permanece activa; no requiere borrar datos ni revertir el esquema.

## Antes de trabajar con clientes

- Completar los datos reales de responsable, contacto y empresa; no usar datos inventados para desbloquear la operación.
- Habilitar la confirmación de correo en Supabase, verificar SMTP y probar el acceso previsto.
- Configurar y probar CAPTCHA para los formularios que lo usan.
- Comprobar respaldos de base y de los dos buckets privados, y una restauración.
- Definir contingencia sin conexión: esta versión requiere internet para guardar. Descargar el remito original antes del viaje permite conservar una copia fuera de la app.

La prueba de PostgreSQL en memoria no valida las credenciales, el SMTP, la configuración actual del proyecto ni el servicio de archivos de producción. La prueba visual de preview usa respuestas simuladas y documentos ficticios; no sustituye una entrega completa autenticada en el proyecto real.
