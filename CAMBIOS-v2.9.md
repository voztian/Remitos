# Cambios de GoRemitos v2.9

## Prueba interna segura

- Agrega un recorrido guiado con datos ficticios: Programado, En camino, Recepción y Cerrado.
- La prueba vive sólo en memoria durante la pestaña actual.
- No crea remitos, no consulta ni modifica tablas, no sube documentos o evidencias y no genera enlaces públicos.
- La pantalla mantiene una señal visible de simulación en todo momento.

## Preparación operativa más clara

- El dashboard separa los faltantes legales de la habilitación técnica.
- Un administrador de empresa ya no recibe un botón engañoso para controles reservados al responsable de plataforma.
- Nuevo remito muestra los bloqueos antes de que la persona complete el formulario.
- Si no existen choferes activos, el selector lo informa y ofrece un acceso directo a Usuarios.
- Usuarios muestra cuántos choferes activos hay o qué acción falta.

## Calidad de datos

- El CUIT argentino se valida con dígito verificador, además de exigir 11 dígitos.

## Instalación

Es una actualización exclusivamente web. No requiere ejecutar SQL ni modificar Supabase.
