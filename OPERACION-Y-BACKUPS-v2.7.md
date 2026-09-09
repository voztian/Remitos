# Operación, backups e incidentes — GoRemitos v2.7

## Regla principal

GoRemitos tiene tres piezas que deben poder recuperarse juntas:

1. **Base de datos:** empresas, usuarios, remitos, ítems, estados, hashes y trazabilidad.
2. **Storage `documentos-remito`:** PDF o imagen del remito original.
3. **Storage `evidencias`:** firmas y fotografías de entrega.

Un backup de Postgres conserva las referencias y metadatos de Storage, pero no
recupera los archivos borrados de los buckets. Una copia que abarque sólo la
base está incompleta.

Referencia oficial: https://supabase.com/docs/guides/platform/backups

## Antes de habilitar un cliente

- Definir un responsable titular y un reemplazo para Supabase, Storage,
  Vercel/GitHub, Google OAuth, Turnstile, privacidad e incidentes.
- Activar MFA y guardar los códigos de recuperación fuera del equipo habitual.
- Establecer el objetivo de pérdida máxima de datos (RPO) y el tiempo máximo de
  recuperación (RTO). Para el piloto se recomienda RPO de 24 horas o menor.
- Generar una copia externa reciente de la base y de ambos buckets.
- Restaurar la copia en un entorno de prueba, nunca sobre producción.
- Abrir al menos un remito y una evidencia restaurados y comparar sus hashes.
- Registrar fecha, resultado, responsable y ubicación protegida del respaldo.

No marques en la aplicación **Backup de base verificado** ni **Backup externo
de Storage verificado** hasta completar una restauración real de prueba.

## Responsables

| Tarea | Titular | Reemplazo | Canal de emergencia |
|---|---|---|---|
| Supabase y base | __________ | __________ | __________ |
| Ambos buckets de Storage | __________ | __________ | __________ |
| Vercel y GitHub | __________ | __________ | __________ |
| Google OAuth y Turnstile | __________ | __________ | __________ |
| Privacidad y solicitudes de titulares | __________ | __________ | __________ |
| Incidentes y soporte | __________ | __________ | __________ |

No concentres las cuentas de recuperación y todas las credenciales en una sola
persona. La `service_role` sólo puede existir en un equipo o servicio confiable;
nunca debe copiarse al HTML, al repositorio público, a un chat ni a un teléfono
de chofer.

## Rutina diaria durante el piloto

1. Verificar Supabase **Healthy** y Vercel **Ready**.
2. Revisar **Usuarios > Errores recientes**.
3. Comprobar entregas que lleven demasiado tiempo **En camino**.
4. Confirmar que no haya usuarios o administradores inesperados.
5. Verificar que se completó la copia programada según el RPO acordado.
6. Registrar cualquier interrupción, aunque se haya resuelto sola.

Si se usa Supabase Free, revisar además que el proyecto no esté pausado antes
de iniciar la jornada. Free no debe presentarse al cliente como una modalidad
de continuidad garantizada.

## Rutina semanal

1. Confirmar fecha, tamaño y estado de la última copia de base.
2. Inventariar por separado `documentos-remito` y `evidencias`.
3. Comparar la cantidad de objetos respaldados con la cantidad informada por
   producción y revisar diferencias.
4. Restaurar en un bucket de prueba un documento y una evidencia elegidos al
   azar; comparar SHA-256 con los registros.
5. Revisar usuarios activos, roles, empresas y autorizaciones pendientes.
6. Probar Google, recuperación de contraseña, cámara, firma, PDF y seguimiento
   desde un dispositivo distinto.

La siguiente consulta es sólo informativa y puede ejecutarse con el rol
`postgres` en SQL Editor para inventariar Storage sin mostrar el contenido:

```sql
select bucket_id,
       count(*) as objetos,
       coalesce(sum(nullif(metadata->>'size','')::bigint),0) as bytes
from storage.objects
where bucket_id in ('documentos-remito','evidencias')
group by bucket_id
order by bucket_id;
```

## Rutina mensual

1. Restaurar base y ambos buckets en un proyecto aislado.
2. Probar el ingreso de un administrador y un chofer de prueba.
3. Recorrer un circuito completo: programar, iniciar, cerrar y descargar la
   constancia.
4. Medir y registrar el tiempo real de recuperación.
5. Revisar accesos de Supabase, Vercel, GitHub, Google Cloud y Cloudflare.
6. Aplicar la política de conservación de cada cliente a producción y a las
   copias; documentar toda eliminación.
7. Revisar documentos huérfanos producidos por una pestaña cerrada o una caída
   entre la subida y el guardado.

La consulta siguiente sólo enumera documentos con más de 24 horas que no están
vinculados a ningún remito. Primero comprobá que no exista una carga o incidente
en revisión, respaldalos si corresponde y eliminá únicamente esos objetos desde
el panel o la API oficial de Storage. **No ejecutes `delete` directamente sobre
`storage.objects`**, porque eso puede dejar el archivo físico desincronizado.

```sql
select o.name,o.created_at,
       coalesce(nullif(o.metadata->>'size','')::bigint,0) as bytes
from storage.objects o
left join public.remitos r on r.documento_url=o.name
where o.bucket_id='documentos-remito'
  and r.id is null
  and o.created_at<now()-interval '24 hours'
order by o.created_at;
```

## Requisitos de la copia externa

- Cifrado durante la transferencia y en reposo.
- Acceso restringido, MFA y registro de operaciones.
- Conservación de ruta, bytes, fecha, tamaño y SHA-256 de cada objeto.
- Versionado o protección contra borrado accidental/ransomware.
- Retención documentada y coherente con cada cliente.
- Restauración probada, no sólo una tarea que informa “éxito”.

El repositorio de GitHub conserva el código, pero no reemplaza el backup de
Supabase. Una copia de Storage tampoco reemplaza la base que vincula cada
archivo con su entrega.

## Caída de Internet, Supabase o energía

GoRemitos v2.7 no promete trabajo offline. Ante una caída:

1. No recargar ni cerrar una pestaña que contenga un formulario aún no enviado.
2. Usar el procedimiento físico acordado por la empresa y conservar el remito
   firmado.
3. No enviar DNI, firma o fotos por chats personales.
4. Al recuperar conexión, usar **Manual** para cargar la foto autorizada del
   documento físico.
5. Registrar hora, entregas afectadas y responsable de la regularización.

## Incidente de seguridad o integridad

1. Suspender nuevas operaciones sin borrar ni modificar evidencia.
2. Registrar hora, alcance, cuentas, empresas y sistemas afectados.
3. Revocar sesiones o credenciales comprometidas desde los servicios oficiales.
4. Preservar logs, hashes, objetos y copias en una ubicación controlada.
5. Evaluar por separado el impacto de cada cliente y cada titular de datos.
6. Escalar al responsable de privacidad y obtener asesoramiento profesional
   para las comunicaciones u obligaciones aplicables.
7. Restaurar primero en un entorno aislado, verificar y recién después reabrir.

## Cambios y reversión

Cada publicación debe dejar registrado:

- commit y deployment de Vercel;
- versión y SHA-256 del ZIP;
- resultado de `supabase-verificacion-v2.7.sql`;
- copia previa de base y ambos buckets;
- responsables y hora de inicio/fin;
- pruebas de aceptación ejecutadas.

La reversión incluida no borra datos y sólo reactiva la web v2.6 cuando no hay
entregas en camino. Nunca ejecutes `supabase-reversion-emergencia-v2.7.sql` con
viajes activos ni como reemplazo de un backup.
