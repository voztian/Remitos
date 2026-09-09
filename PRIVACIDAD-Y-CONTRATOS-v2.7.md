# Privacidad y acuerdo de piloto — GoRemitos v2.7

Este documento es una lista de preparación técnica y comercial. No es un
contrato listo para firmar ni reemplaza el análisis profesional de la actividad,
mercadería, recorrido o jurisdicción de cada cliente.

## Alcance que el cliente debe aceptar

- La empresa cliente emite el remito original mediante su propio sistema y
  conserva la responsabilidad sobre numeración, contenido y requisitos que le
  correspondan.
- GoRemitos custodia una copia, organiza la entrega, registra hitos y genera una
  constancia digital; no emite Remito R, factura, carta de porte, COT ni otro
  comprobante fiscal o sectorial.
- La constancia y la firma capturada son evidencia electrónica del circuito. No
  se presentan como firma digital certificada ni garantizan por sí solas el
  cumplimiento documental del traslado.
- El seguimiento de v2.7 informa estados y horarios. No incluye GPS continuo,
  optimización de rutas ni ETA automática.
- Si un traslado exige documentación física o digital específica, la empresa
  debe proporcionarla al chofer además de usar GoRemitos.

El detalle funcional está en `ALCANCE-ETAPA-1-v2.7.md`.

## Decisiones que debe documentar cada empresa

- razón social, CUIT, domicilio y contacto para privacidad;
- finalidad y necesidad de documento, firma, DNI, fotos y teléfono;
- información que recibirá el receptor y tratamiento de una negativa;
- personas y roles autorizados;
- plazo concreto de conservación y procedimiento de supresión/bloqueo;
- requisitos de traslado según mercadería, origen, destino y jurisdicción;
- tratamiento de reclamos, devoluciones, faltantes e incidentes;
- canal alternativo ante caída de internet, energía o plataforma.

La aplicación exige datos identificatorios y una política de conservación, pero
no decide esas cuestiones por la empresa.

## Acuerdo entre GoRemitos y el cliente

El documento contractual del piloto debería definir, como mínimo:

- cliente como emisor del remito y responsable de los datos;
- GoRemitos como prestador/encargado técnico y límites de la etapa 1;
- finalidades e instrucciones permitidas;
- confidencialidad, usuarios, altas, bajas y revisión de administradores;
- medidas de seguridad y prohibición de compartir cuentas;
- subencargados: Supabase, Vercel, Google y Cloudflare cuando corresponda;
- transferencias y ubicación de tratamiento;
- plan utilizado, disponibilidad ofrecida y exclusiones del piloto;
- copia de base y ambos buckets, recuperación y responsables;
- notificación y cooperación ante incidentes;
- asistencia con derechos de titulares;
- conservación, exportación, devolución y eliminación al finalizar;
- propiedad del documento y de las evidencias;
- soporte, cambios de versión y salida del servicio;
- prohibición de cargar información ajena a una entrega o que no sea necesaria.

Si se usa Supabase Free, el acuerdo debe decir claramente que el proyecto puede
pausarse por inactividad y que la continuidad depende también de respaldos
externos. La modalidad elegida no altera la responsabilidad del cliente sobre
el remito original.

## Enlace de seguimiento

El enlace funciona como un enlace portador: quien lo recibe puede ver empresa,
número, fecha, estado y horarios, sin iniciar sesión. El cliente debe:

- compartirlo sólo con participantes de la entrega;
- evitar publicarlo en redes o canales abiertos;
- avisar si fue enviado a una persona equivocada;
- entender que en esta versión no existe revocación individual del enlace.

No se exponen por ese canal cliente, domicilio, teléfono, chofer, mercadería,
documento, receptor, DNI, firma, fotos, hashes ni IDs internos.

## Aviso al receptor

Antes de capturar nombre, DNI, firma o fotografías, el receptor debe poder
conocer en lenguaje claro:

- la empresa responsable y cómo contactarla;
- los datos solicitados y la finalidad;
- cuáles son necesarios para documentar la entrega;
- destinatarios/proveedores y tratamiento fuera de Argentina;
- plazo de conservación;
- cómo ejercer acceso, rectificación, actualización o supresión.

La interfaz muestra el aviso y exige una confirmación. La empresa debe validar
que el texto coincida con su operación real y capacitar a quien entrega.
Esa casilla documenta que la información fue brindada; no sustituye por sí
sola la base legal que corresponda ni prueba un consentimiento libre. El
acuerdo del piloto debe definir la base aplicable y qué hacer si la persona se
niega a aportar un dato o una evidencia opcional.

## Antes de iniciar el piloto

- [ ] Cliente y GoRemitos aprobaron por escrito el alcance de etapa 1.
- [ ] Se verificó qué documento debe acompañar cada tipo de mercadería.
- [ ] Se completaron los datos legales y la conservación en la aplicación.
- [ ] Se revisó el aviso de privacidad con los datos reales.
- [ ] Se habilitaron únicamente usuarios nominados y roles necesarios.
- [ ] Se probó la baja inmediata de un usuario.
- [ ] Se ejecutó `PRUEBAS-PILOTO-v2.7.md` sin fallas críticas.
- [ ] Se restauraron la base, `documentos-remito` y `evidencias` en prueba.
- [ ] Choferes conocen la contingencia física y el canal de incidentes.
- [ ] Se definió quién responde reclamos y solicitudes de datos.

## Referencias oficiales para revisión profesional

- Ley 25.326, texto actualizado:
  https://www.argentina.gob.ar/normativa/nacional/ley-25326-64790/actualizacion
- AAIP, protección de datos personales:
  https://www.argentina.gob.ar/aaip/datospersonales
- Derechos de titulares:
  https://www.argentina.gob.ar/aaip/datospersonales/derechos

## Aprobaciones del piloto

Responsable de GoRemitos: __________________  Fecha: __________

Responsable del cliente: ___________________  Fecha: __________

Revisión profesional, si corresponde: ______  Fecha: __________

Alcance/mercadería/provincias: ____________________________________________

Modalidad: ☐ Pro  ☐ Free controlado     RPO: ______     RTO: ______

Estado: ☐ Aprobado para piloto  ☐ Pendiente  ☐ Rechazado
