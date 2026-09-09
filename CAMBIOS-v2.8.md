# Cambios de GoRemitos v2.8

## Escritorio

- La aplicación deja de estar limitada a una columna de 560 px cuando se usa en una computadora.
- Desde 900 px de ancho utiliza un menú lateral persistente con iconos y nombres visibles.
- **Nuevo remito** se muestra como una acción principal clara en el menú lateral.
- El encabezado separa la identidad de la empresa de los controles de sesión, perfil y tema.
- El dashboard distribuye indicadores y actividad reciente en paneles independientes.
- La lista de remitos usa un panel ancho con búsqueda, filtros y filas más legibles.
- Usuarios separa la configuración y autorización de la lista de miembros.
- El formulario de programación aprovecha el ancho sin producir líneas excesivamente largas.

## Celular y tablet

- Por debajo de 900 px se conserva la navegación inferior y el diseño compacto de v2.7.
- El mismo HTML cambia de distribución automáticamente; no existen dos aplicaciones distintas.
- La orientación de la aplicación instalada deja de estar bloqueada en vertical.

## Compatibilidad y seguridad

- No cambia el esquema de Supabase, las funciones RPC ni las políticas RLS.
- No se requiere ejecutar ninguna migración SQL.
- Se mantienen Google OAuth, autorizaciones por email, remitos, evidencias, firmas, trazabilidad y seguimiento público.
- Los errores incluyen la versión 2.8 en su contexto para facilitar el diagnóstico sin modificar la base.
