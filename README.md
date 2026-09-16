# GoRemitos v2.10 — prueba interna completa

Esta versión permite probar el circuito persistente con las tres cuentas reales de la empresa —Administrador, Oficina y Chofer— sin confundir la prueba con una entrega operativa.

## Circuito de prueba

1. El administrador activa **Modo de prueba interna** en Usuarios.
2. Oficina carga un remito externo ficticio, mercadería y chofer.
3. El chofer inicia el viaje, revisa los ítems y cierra la recepción con datos y firma ficticios.
4. Administración u oficina revisan trazabilidad, seguimiento y PDF.
5. Todas las vistas muestran **PRUEBA** y el PDF dice que no corresponde a una entrega real.
6. Con las pruebas cerradas o eliminadas, el administrador desactiva el modo.

Durante este modo se bloquean los avisos por WhatsApp a destinatarios. No uses nombres, domicilios, teléfonos, DNI, firmas, fotos ni documentos reales.

La simulación local de v2.9 continúa disponible como recorrido rápido sin escribir nada. El nuevo modo v2.10 sí guarda los datos ficticios para probar permisos, Storage, cambios de cuenta y cierre del circuito.

## Instalación sobre v2.9.1

El orden evita una ventana de incompatibilidad:

1. En Supabase, ejecutar completo `supabase-migration-v2.10.sql`.
2. Publicar todos los archivos de este paquete en la raíz del repositorio de GitHub.
3. Esperar que Vercel muestre **Ready / Production / Current**.
4. En Supabase, ejecutar `supabase-verificacion-v2.10.sql`.
5. Confirmar que todos los controles sean `true` y que la consulta de anomalías devuelva cero filas.

No vuelvas a ejecutar migraciones anteriores y no ejecutes `supabase-finalizar-v2.7.sql` nuevamente.

## Separación y seguridad

- La marca `es_prueba` se asigna en Supabase y es inmutable; el navegador no puede decidirla ni quitarla.
- No se puede activar el modo si existen entregas reales pendientes.
- No se puede desactivar mientras queden pruebas pendientes.
- El bypass de preparación se habilita únicamente dentro de cada RPC v2.10 y durante esa transacción.
- El modo no habilita altas de clientes, configuración de plataforma ni operación real.
- Documentos y evidencias conservan las restricciones de empresa, rol, ruta, tipo, tamaño y frecuencia.
- El seguimiento público sigue sin mostrar domicilio, teléfono, mercadería, documento, receptor, DNI, firma, fotos ni hashes.
- Las pruebas se identifican en listados, detalle, seguimiento y constancia PDF.

## Alcance del producto

GoRemitos sigue siendo una plataforma de seguimiento y constancia digital asociada a un remito emitido por la empresa:

- No genera Remito R, CAI/CAE ni numeración fiscal.
- No reemplaza el documento que la empresa debe emitir.
- Custodia una copia privada, registra el viaje y produce evidencia de entrega.

Para operar con datos reales siguen siendo obligatorios los datos legales de la empresa y la preparación técnica prevista en v2.7.

## Archivos v2.10

- `index.html`: aplicación adaptable para PC y celular.
- `supabase-migration-v2.10.sql`: actualización transaccional sin borrado de datos.
- `supabase-verificacion-v2.10.sql`: controles posteriores y consulta de anomalías.
- `CAMBIOS-v2.10.md`: detalle funcional y técnico.
- `PRUEBAS-MODO-INTERNO-v2.10.md`: recorrido de aceptación con tres roles.
- `tests/verificar-paquete.mjs`: validación integral del paquete.

Las migraciones y guías anteriores permanecen incluidas por trazabilidad y para instalaciones nuevas.
