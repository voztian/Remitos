# Validación de GoRemitos 2.11 — 28 de septiembre de 2026

## Proyecto real

- Supabase reactivado después de una pausa; volvió a mostrar estado Healthy.
- Migración 2.11 aplicada en una transacción, sin modificar entregas existentes.
- Seis controles de funciones y permisos correctos. Comprobación adicional: ninguna entrega con cierre incoherente.
- Confirmación de correo activada para nuevas cuentas; Google permanece habilitado.

## Pruebas aisladas

`npm test` cubre sintaxis, reglas de negocio, preservación de formularios ante fallos, etiquetas, búsqueda paginada, pendientes antiguos, estados en caché, navegación durante el inicio y recuperación después de un cierre confirmado. La cadena SQL completa corre en PostgreSQL en memoria con roles y empresas ficticias; comprueba permisos, aislamiento, documentos privados, modo esperado, estados y cierres inmutables.

## Navegador de preview

Se recorrió Oficina → remito externo ficticio → asignación → Chofer → apertura del documento → inicio de viaje → entrega parcial con firma → cierre → descarga de PDF. También se simuló un fallo al consultar el modo y se verificó que el archivo y los datos cargados se conservaran. Se comprobó que un faltante impida cerrar conforme. El PDF descargado contiene cantidades, observaciones, receptor, firma y huellas.

El banco visual usa respuestas simuladas y datos ficticios. No escribe entregas ni envía comunicaciones en el proyecto real. El recorrido visual se ejecutó en escritorio y con un área de 390 px; no sustituye una prueba física en el teléfono.

## Límites para el piloto

- Falta una entrega completa con las cuentas reales de oficina y chofer y con Storage de producción.
- No se verificaron SMTP, CAPTCHA ni una restauración de respaldos. La pantalla del proyecto no mostraba respaldos automáticos disponibles.
- La configuración operativa y los datos reales de cada empresa deben estar completos antes de desactivar el modo de prueba. No se completaron con datos inventados.
- Guardar requiere conexión. No se incorporaron emisión fiscal, envíos automáticos ni seguimiento GPS.
- Las pruebas aisladas no certifican el comportamiento de concurrencia del servicio alojado ni sustituyen un análisis de archivos del lado servidor.
