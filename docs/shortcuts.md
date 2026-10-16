# Atajos de captura

Cómo configurar los dos atajos que alimentan Gastario ([`SPEC.md` Fase 2](../SPEC.md#fase-2--captura-app-intents)). Se basan en las automatizaciones que ya existen y escriben los CSVs viejos.

> **Transición (2–3 semanas).** Los atajos siguen escribiendo el CSV viejo **en paralelo**. El `Append to Text File` va **antes** de la acción de Gastario: si Gastario falla, el atajo se detiene y la fila del CSV ya quedó escrita ([`INTENT.md`, Respaldo](../INTENT.md#respaldo)). Los Append se quitan en la Fase 7, después de comparar conteos.

Antes de empezar, abre Gastario una vez después de instalarla para que Atajos vea sus acciones.

## Tarjeta (Apple Pay)

Automatización personal **Transaction** (Wallet): *When Any Card is tapped*, ejecutar inmediatamente, sin confirmar.

```
Current Location
Append to Text File          ← la acción actual del CSV viejo, sin cambios
Log Card Transaction
    Merchant     → Merchant (de la transacción)
    Amount       → Amount
    Card or Pass → Card or Pass
    City         → City (de Current Location)
    Latitude     → Latitude
    Longitude    → Longitude
```

- Si no hay ubicación, deja City, Latitude y Longitude vacíos: el movimiento se guarda igual (AC-10).
- El trigger corre con el **tap**, no con la aprobación: un pago rechazado también crea un movimiento y se borra a mano.

## Yappy (correo)

Automatización personal **Email**: *When I get an email* **sin filtro de remitente** (cualquier remitente), ejecutar inmediatamente y con **"Notificar al ejecutar" desactivado**: el atajo corre con cada correo que llega y el `If` decide cuáles son de Yappy.

```
Repeat with each item in Email
    If Repeat Item → Sender is notificaciones@yappy.com.pa
        Append to Text File      ← la acción actual del CSV viejo, sin cambios
        Log Yappy Email
            Content → Repeat Item → Content
    End If
End Repeat
```

- **El `If` es el único filtro.** `Email` trae **todos** los correos que llegaron en ese lote. Visto en dispositivo:
  - Con el filtro de remitente en el trigger, si el **primer** correo del lote no es de Yappy el atajo no corre y el Yappy que viene después se pierde. Por eso el trigger no filtra.
  - Sin el `If`, un correo de otro remitente que llega junto con el de Yappy (por ejemplo, el recibo del comercio) entra como movimiento `failed`.
- Si `Sender` incluye el nombre ("Yappy <notificaciones@…>"), usa *contains* con la dirección completa.
- La salida del trigger es `Email`, **no** `Shortcut Input`.
- `Content` entrega el cuerpo en **HTML o texto plano**, según el correo; Gastario lo guarda tal cual y acepta ambos al parsear.
- El `If` filtra solo por remitente: también entran los correos de Yappy Comercial de la cuenta del negocio, que se registran como ingresos ([`INTENT.md`, Decisiones](../INTENT.md#decisiones)).
- Correr el atajo dos veces sobre el mismo correo no duplica: se deduplica por confirmación + dirección.

## Verificación (gate de la Fase 2)

1. Paga algo con Apple Pay **sin abrir Gastario**. Ábrela después: el movimiento está en la lista.
2. Recibe o envía un Yappy: aparece. Si el comercio manda además su recibo por correo, ese recibo **no** aparece, y el Yappy entra aunque el recibo llegue primero.
3. En Atajos, corre la automatización de correo a mano dos veces sobre el mismo correo: un solo movimiento.
4. El CSV viejo tiene las filas nuevas.
5. Cierra Gastario desde el switcher y repite 1: el intent corre igual con la app terminada.
