# Alcance de la primera etapa

## Objetivo

Digitalizar el circuito logístico sin asumir todavía la emisión legal o fiscal del remito:

`remito emitido por el cliente → carga en GoRemitos → asignación → viaje → recepción → constancia y archivo`

## Responsabilidad de cada parte

### Empresa usuaria

- Emite el remito con el sistema y requisitos que correspondan a su actividad.
- Verifica numeración, datos comerciales, fiscales y de transporte cuando sean exigibles.
- Define los usuarios autorizados, el plazo de conservación y las instrucciones al chofer.
- Informa al receptor sobre el tratamiento de sus datos.

### GoRemitos

- Custodia una copia privada del documento entregado por la empresa.
- Registra asignación, inicio de viaje, resultado y eventos de auditoría.
- Permite capturar firma electrónica y evidencias de la entrega.
- Genera una constancia digital vinculada mediante hashes.
- Brinda un seguimiento público mínimo mediante un enlace compartido por la empresa.

## Fuera de alcance en v2.7

- Emisión de Remito R u otros comprobantes reglamentados.
- CAI, CAE, puntos de venta, numeración fiscal e integración con ARCA.
- Carta de porte, COT u otros regímenes sectoriales/provinciales.
- Validación automática de que el documento subido cumple las obligaciones de cada mercadería o jurisdicción.
- Firma digital certificada.
- Optimización de rutas, GPS continuo y cálculo automático de ETA.
- Sincronización offline.
- Lectura automática/OCR de los ítems del PDF.

## Criterio para avanzar a una segunda etapa

No sumar emisión propia hasta validar con clientes reales:

- volumen de entregas;
- tipos de remito que ya utilizan;
- provincias y actividades involucradas;
- necesidad real de numeración/impresión/integración fiscal;
- responsables contables o legales que deban aprobar el circuito;
- integraciones con ERP, facturación o ruteo.

Esta separación evita prometer que una constancia logística de GoRemitos reemplaza un documento que, según el caso, deba cumplir requisitos especiales.
