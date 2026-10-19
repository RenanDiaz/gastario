# Spike S1 — Correos de factura electrónica

Bitácora del spike ([`SPEC.md`, Spike S1](../../SPEC.md#spike-s1--correos-de-factura-electrónica)). Se llena a medida que llegan los datos; al final queda la decisión que abre (o no) la [Fase 11](../../SPEC.md#fase-11--facturas-por-correo-v11-sujeta-a-s1).

> **Datos personales.** Aquí van dominios, conteos y patrones, nunca direcciones de correo personales, cédulas, nombres de personas ni montos asociados a una persona. Los archivos del censo (`Gastario-Spike/` en iCloud Drive) **no** se suben al repo.

## Estado

| Paso | Estado | Notas |
|---|---|---|
| Q7: las facturas llegan a una cuenta configurada en Mail del iPhone | Pendiente | Si alguna llega a una cuenta que no está en Mail, el atajo no la ve |
| 1. Inventario retroactivo (Mail, últimos 3 meses) | Pendiente | |
| 2. Censo en el atajo ([`docs/shortcuts.md`](../shortcuts.md#diagnóstico-de-facturas-spike-s1-temporal)) | Pendiente | Inicio: — · Fin previsto: inicio + 14 días |
| 3. Cruce con movimientos de Gastario | Pendiente | |
| Fixtures en `Packages/GastarioParsing/Tests/GastarioParsingTests/Fixtures/Invoice/` | Pendiente | ≥ 5 facturas de emisores distintos y 3 no-facturas |
| Decisión | Pendiente | |
| 📱 Segundo `Repeat` retirado del atajo | Pendiente | |

## 1. Inventario retroactivo

En Mail del iPhone o de la Mac, buscar por separado: `factura`, `factura electrónica`, `CUFE`, `CAFE`, `comprobante`, `dgi-fep`. Una fila por **emisor** (no por correo).

| Dominio del remitente | ¿Comercio o PAC? | Comercio(s) | Correos | Asunto típico | Adjuntos | Total en el cuerpo | CUFE en el cuerpo | RUC | Fecha | Link DGI |
|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | PDF / XML / ninguno | sí / no | sí / no | sí / no | sí / no | sí / no |

## 2. Censo

Resumen de `censo.txt` y `facturas-*.txt` al cerrar el período.

- Días con censo: —
- Correos no-Yappy por día (mediana / máximo): — (S1.9)
- Facturas en `facturas-*.txt`: —
- Facturas que **solo** aparecen en `censo.txt` (el filtro por palabras se las perdió): — → listar el asunto típico de cada una

## 3. Cruce con movimientos

Una fila por factura. Montos y horas, sin datos personales.

| Emisor (dominio) | Total factura | Monto del movimiento | Diferencia | `source` | Pago → correo (min) | ¿Emisor ≈ `counterparty`? |
|---|---|---|---|---|---|---|
| | | | | card / yappy / manual | | sí / no / parcial |

## Respuestas

| # | Pregunta | Respuesta |
|---|---|---|
| S1.1 | ¿Qué remitentes envían facturas? ¿Pocos PACs o uno por comercio? | |
| S1.2 | ¿Qué palabras o patrones distinguen una factura de una promoción? | |
| S1.3 | ¿`Content` trae CUFE, total, RUC, fecha y link de la DGI en texto? | |
| S1.4 | ¿El `Email` de Atajos expone los adjuntos y se pueden pasar a un intent? | |
| S1.5 | ¿El total de la factura coincide con lo cobrado? | |
| S1.6 | Retraso pago → correo (mediana y máximo) | |
| S1.7 | ¿El emisor se parece al `counterparty` de Wallet? | |
| S1.8 | ¿Llega la misma factura dos veces, o factura + nota de crédito? | |
| S1.9 | ¿Cuántos correos no-Yappy llegan al día? | |

## Decisión

**Pendiente.** Una de: go / go reducido / no-go, con el criterio de [`SPEC.md`](../../SPEC.md#spike-s1--correos-de-factura-electrónica) y lo que cambia en la Fase 11 (ventana del matcher, tolerancia de propina, reglas del detector).
