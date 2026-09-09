# Operación, backups e incidentes — GoRemitos v2.6

## Regla principal

La base de datos y las evidencias son dos respaldos distintos. Un backup de
Postgres conserva los registros y metadatos, pero no recupera fotos ni firmas
borradas del bucket `evidencias`.

Referencia oficial:
https://supabase.com/docs/guides/platform/backups

## Responsables a definir

| Tarea | Responsable | Reemplazo | Canal |
|---|---|---|---|
| Supabase y base | __________ | __________ | __________ |
| Storage y evidencias | __________ | __________ | __________ |
| Vercel/GitHub | __________ | __________ | __________ |
| Google OAuth/Cloudflare Turnstile | __________ | __________ | __________ |
| Privacidad y clientes | __________ | __________ | __________ |
| Incidentes | __________ | __________ | __________ |

No concentres todas las credenciales en una sola cuenta personal. Activá MFA en
Google, Supabase, Vercel, GitHub y Cloudflare, y guardá códigos de recuperación fuera del
equipo de trabajo.

## Rutina diaria

1. Verificar Supabase **Healthy** y Vercel **Ready**.
2. Revisar **Usuarios > Errores recientes**.
3. Confirmar que no haya remitos pendientes sin chofer por una baja o cambio de
   rol.
4. Confirmar que la aplicación no muestre la barra de Realtime desconectado.
5. Registrar incidentes, aunque se hayan resuelto solos.

## Rutina semanal

1. Confirmar la fecha del último backup de DB.
2. Confirmar la fecha del último backup externo del bucket `evidencias`.
3. Comparar cantidad de objetos respaldados y tamaño total.
4. Restaurar al menos una evidencia de prueba y validar su SHA-256.
5. Revisar usuarios activos, administradores y altas pendientes.
6. Verificar que ningún cliente haya quedado sin administrador.
7. Actualizar navegador de un dispositivo de prueba y repetir Google, cámara,
   firma y PDF.

## Rutina mensual

1. Hacer una restauración completa en un proyecto de prueba, nunca sobre
   producción sólo para ensayar.
2. Medir cuánto tiempo lleva recuperar DB, Storage, Auth y configuración.
3. Revisar roles de GitHub, Vercel, Supabase, Google Cloud y Cloudflare; rotar
   secretos sólo con una sesión de administración de respaldo abierta.
4. Revisar contratos, subencargados y política de conservación de cada cliente.
5. Borrar respaldos vencidos conforme a la política definida; documentar la
   eliminación.
6. Revisar actualizaciones de dependencias y repetir las pruebas P0/P1.

## Respaldo de Storage

Elegí una solución que cumpla estas condiciones:

- usa credenciales de servidor sólo en un equipo o servicio confiable;
- nunca copia `service_role` al HTML, GitHub público ni WhatsApp;
- cifra el respaldo en tránsito y en reposo;
- conserva ruta, tamaño, fecha y SHA-256 de cada objeto;
- tiene retención y acceso limitado;
- permite restaurar a un bucket de prueba;
- registra quién ejecutó y verificó cada copia.

No marques **Backup externo de Storage verificado** hasta completar una
restauración real de prueba.

## Caída de Internet o Supabase

GoRemitos v2.6 no promete modo offline. Si el chofer pierde señal:

1. No recargues ni cierres la pestaña si ya completó el formulario.
2. Conservá el remito físico y registrá fecha, hora, receptor, conformidad y
   observación según el procedimiento de la empresa.
3. No fotografíes ni envíes DNI o firmas por chats personales.
4. Cuando vuelva la conexión, cargá el respaldo mediante **Remito manual** con
   una foto autorizada del documento físico.
5. Informá el incidente para correlacionarlo con la constancia.

## Incidente de seguridad

Ante acceso indebido, filtración, borrado, malware o credenciales expuestas:

1. Detené nuevas operaciones sin destruir evidencia.
2. Registrá hora, alcance, cuentas, empresas y sistemas afectados.
3. Revocá sesiones y credenciales comprometidas; no edites la evidencia
   original.
4. Preservá logs, hashes, backups y capturas en un repositorio controlado.
5. Evaluá impacto por cliente y por titular de datos.
6. Avisá al responsable de privacidad y obtené asesoramiento profesional sobre
   comunicaciones y obligaciones aplicables.
7. Restaurá en entorno aislado, verificá integridad y recién después reabrí.
8. Documentá causa, corrección y prevención.

## Cambio y rollback

Cada publicación debe guardar:

- commit y deployment de Vercel;
- versión y checksum del ZIP;
- resultado de la verificación SQL;
- backup previo de DB y Storage;
- responsable y hora de inicio/fin;
- pruebas ejecutadas.

Si falla la web pero la migración v2.6 terminó, no vuelvas a habilitar los RPC
antiguos. Corregí o restaurá el frontend v2.6 compatible. El rollback de base
debe planificarse desde un backup y no improvisarse con comandos destructivos.
