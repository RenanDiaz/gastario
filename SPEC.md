# SPEC.md — Gastario, plan de implementación por fases (v1 y v2)

`INTENT.md` define **qué** se construye y **por qué**. Este documento define **cómo** y **en qué orden**. Si hay conflicto, gana `INTENT.md`, salvo en los puntos marcados como **Cambio propuesto** (sección 2), que deben confirmarse antes de la fase que los usa.

## 1. Cómo usar este documento

- Cada fase es una unidad de trabajo cerrada para un agente de código: tiene objetivo, alcance, entregables, criterios y un **gate de salida**. No se abre una fase sin cerrar el gate de la anterior.
- Una fase = una rama = un PR. La rama es `phase-N-<slug>` o, si la crea una sesión de Claude Code en la nube, `claude/<slug>`; CI corre en ambas. El PR enlaza la sección de la fase y marca el checklist del gate.
- `AC-n` referencia el criterio de aceptación `n` de `INTENT.md`.
- Las verificaciones marcadas 📱 requieren dispositivo físico y las hace la persona, no el agente. El agente deja listo todo lo que se puede verificar con `swift test` o en simulador.
- Prioridad de orden: primero lo que **protege la captura** (principio 1), después lo que la hace útil, al final lo que es accesorio (adjuntos).

## 2. Cambios propuestos a INTENT.md

Huecos encontrados al convertir el intent en fases. Cada uno tiene una decisión por defecto; si no se objeta, se implementa así. **C1–C9 confirmados** (Q4).

| # | Hueco | Decisión por defecto | Fase |
|---|---|---|---|
| C1 | La regla "si un `partial` resuelve los campos faltantes pasa a `ok`" necesita saber **qué** faltó. No se puede derivar de los datos (una fecha fallida es indistinguible de una captura sin fecha). | Agregar `parseIssues: Set<ParseIssue>` a `Movement`. `ParseIssue` = `amount`, `counterparty`, `occurredAt`, `confirmation`, `direction`. El parser la llena; editar un campo quita su issue; `parseIssues.isEmpty` → `ok`. También alimenta el texto de la notificación de tarjeta `partial` ("no pude leer el monto / el comercio"). | 0 |
| C2 | `editedFields: Set<String>` acepta cualquier string. | Tiparlo como `Set<EditableField>` con casos `amount`, `counterparty`, `occurredAt`, persistido como strings. | 0 |
| C3 | Un Yappy `failed` sin `confirmation` no se puede deduplicar. Si Shortcuts reintenta, habrá duplicados. | Aceptado para v1. Se documenta en la vista de detalle con un aviso cuando `confirmation == nil`. Se borra a mano. | 2 |
| C4 | El respaldo necesita estado (`lastExportAt`, último intento fallido) y no se dice dónde vive. | `UserDefaults(suiteName: "group.<bundle-id>")`. No va en SwiftData: el export no debe depender del store que respalda. | 5 |
| C5 | No se define nombre de archivo ni retención del CSV. | `Gastario-YYYY-MM-DD-HHmm.csv` en `<ubiquity>/Documents/`. Se conservan todos; ~52 archivos pequeños al año. | 5 |
| C6 | Formato de fechas en CSV no definido. | ISO 8601 con offset de Panamá (`2026-10-04T08:31:00-05:00`). Numbers lo reconoce. Sin BOM. | 5 |
| C7 | Un QR que no contenga URL no cabe en `kind: link`. | Se rechaza con mensaje "El QR no contiene un link". Los QR de factura electrónica de la DGI son URLs; si aparece un caso real distinto, se amplía en v1.1. | 6 |
| C8 | Imágenes sin límite inflan el almacenamiento externo. | Fotos se guardan como JPEG calidad 0.8, lado mayor máximo 2048 px. PDFs sin tocar. | 6 |
| C9 | El resumen mensual no dice qué mes ni qué zona horaria. | Mes calendario actual en `America/Panama`. Neto = entradas − salidas. Incluye todos los `parseStatus`. | 4 |
| C10 | Los correos reales muestran formatos que el intent no listaba: `Content` llega en HTML, existe "Pagaste por Yappy / Pagado a" y llegan correos de Yappy Comercial. | **Confirmado e incorporado a `INTENT.md`.** El parser convierte HTML a texto sin WebKit; "Pagaste" → `outflow`; Yappy Comercial → `inflow`. | 1 |
| C12 | **Confirmado e incorporado a `INTENT.md`.** `INTENT.md` decía iOS 27, pero los runners de GitHub (`macos-26`) solo traen Xcode 26.x con SDK de iOS 26.5; con deployment target 27 el job `macos` no puede compilar la app. Ninguna API que pide el intent es exclusiva de iOS 27. | Deployment target **iOS 26.0**, compilado con Xcode 26.x en CI. La app corre igual en iOS 27 y se puede compilar localmente con Xcode 27. Se sube a 27 cuando GitHub ofrezca Xcode 27. | 0 |
| C13 | **Confirmado e incorporado a `INTENT.md`.** `INTENT.md` no definía el texto de la notificación para una tarjeta `failed` (el parser lanzó) ni para un Yappy `partial` sin contraparte, ni los títulos. | Tarjeta `failed`: "No pude leer un pago con tarjeta, revísalo en la app." Sin contraparte: la pregunta sin el "en …" ("¿En qué gastaste $49.06?"). Títulos: "Gasto", "Ingreso", "Revisar movimiento". | 3 |
| C14 | **Confirmado e incorporado a `INTENT.md`.** Abrir un link adjunto con `Link` lo manda a Safari: cada factura deja una pestaña abierta. | Los links adjuntos abren dentro de la app con `SFSafariViewController`, presentado a pantalla completa. El link a Maps del detalle no cambia. | 6 |
| C15 | **Confirmado e incorporado a `INTENT.md`.** `INTENT.md` no decía qué pasa al tocar la notificación (no "Responder"): el delegate la ignoraba. | Tocar la notificación abre el detalle del movimiento y el editor con el cursor en la nota. El delegate deja el ID en `NotificationRouter`; la lista navega (cerrando lo que esté abierto) y el detalle abre el editor. | 3 |
| C16 | **Confirmado e incorporado a `INTENT.md`.** `INTENT.md` dejaba las categorías para v2, "derivadas de ~2 meses de notas". Ya existe la fuente real: los topes del presupuesto. Y clasificar solo por categoría no distingue pasamanos, préstamos ni reembolsos. | Sección [v2 — Clasificación](INTENT.md#v2--clasificación): `kind` (8 tipos) aparte de la categoría, reglas por comercio con sugerencia en la notificación y división en partes. Fases 8–10. | 8–10 |
| C17 | **Confirmado e incorporado a `INTENT.md`.** En la Fase 7 aparecieron pagos que el atajo le pasó a Gastario (la fila está en el CSV viejo) y que no están en el store. `INTENT.md` no pide ningún rastro fuera de SwiftData, así que no hay forma de saber si el intent no corrió, si murió antes de guardar o si el movimiento se borró después. | Bitácora de captura: un archivo JSON Lines en el App Group, escrito sin SwiftData, con una línea por paso de cada invocación de los intents y por cada borrado desde la UI. Se ve y se comparte desde Ajustes. Detalle en la [Fase 7a](#fase-7a--bitácora-de-captura). | 7a |
| C18 | **Confirmado e incorporado a `INTENT.md`.** Con la cuenta gratis (Personal Team) el perfil de aprovisionamiento vence a los 7 días. Vencido, iOS no abre la app ni para correr los intents: el atajo de tarjeta escribe el Append del CSV viejo y falla al llamar a Gastario. Así se perdió M/S Betty el 22/10 ([Fase 7](#fase-7--transición-operativa)). `INTENT.md` no prevé ningún aviso, y la bitácora (C17) no lo ve porque el proceso ni arranca. Viola el principio 1 sin dejar rastro. | Leer `ExpirationDate` de `embedded.mobileprovision` dentro del bundle. Ajustes muestra "La app vence el …", en rojo con menos de 48 h, y con menos de 48 h la lista también muestra un aviso arriba. Notificación local 24 h antes, reprogramada cada vez que se abre la app. Sin ese archivo (App Store, TestFlight, simulador) no se muestra ni se programa nada. Detalle en la [Fase 7b](#fase-7b--aviso-de-vencimiento-de-la-firma). | 7b |
| C11 | Un pago de la cuenta personal al propio negocio llega dos veces con la misma `confirmation`; deduplicar solo por `confirmation` pierde uno. | **Confirmado e incorporado a `INTENT.md`.** Clave de deduplicación = `confirmation` + `direction`. | 2 |

## 3. Arquitectura y convenciones (aplican a todas las fases)

### Estructura del repo

```
project.yml                   ← XcodeGen: targets, capabilities y entitlements. El
                                 .xcodeproj se genera y no se versiona
Configs/                      ← Base.xcconfig; Local.xcconfig (Team ID) fuera de git
Gastario/                     ← target iOS: UI, App Intents, Notificaciones, Adjuntos, Ajustes
Packages/
  GastarioParsing/            ← SOLO Foundation. Parsers puros. Testeable en macOS y Linux.
  GastarioCore/               ← Modelos SwiftData, CaptureService, ReparseService, CSVExporter,
                                 BackupPolicy. Depende de GastarioParsing. Testeable en macOS.
scripts/verify.sh             ← lo mismo que corre CI
```

Por qué XcodeGen y no un `.xcodeproj` versionado: un agente en la nube no tiene Xcode. Con `project.yml` puede agregar el App Group (Fase 0), iCloud Documents (Fase 5) o el target de la Share Extension (v1.1) editando YAML legible; con un `pbxproj` versionado tendría que editarlo a mano. El costo es instalar XcodeGen y correr `xcodegen generate` después de agregar archivos.

Por qué dos paquetes y no uno: un agente que corre en la nube (Linux) puede desarrollar y probar `GastarioParsing` completo sin Xcode. `GastarioCore` necesita SwiftData, que solo existe en plataformas Apple; se trabaja con Claude Code local en la Mac. El target de app no tiene lógica probable por unidad: todo lo que se pueda probar vive en los paquetes.

### Entorno y verificación

- `scripts/verify.sh` es la única definición de "verde". En macOS corre ambos paquetes y compila la app en Debug y Release sin firmar; en Linux corre solo `GastarioParsing`.
- CI tiene dos jobs: `linux` (imagen `swift`) y `macos` (Xcode 26.x, SDK de iOS 26). Un PR no se mergea con ninguno en rojo.
- `GastarioParsing` solo importa `Foundation`; `verify.sh` falla si importa otra cosa.
- Las sesiones de Claude Code en la nube instalan Swift para Linux con `.claude/hooks/session-start.sh`. Ahí se desarrolla y prueba `GastarioParsing`; lo que depende de SwiftData o UIKit se escribe en la nube pero lo verifica el job `macos`.

### Reglas

- Swift 6, concurrencia estricta. Swift Testing (`@Test`), no XCTest, salvo en UI tests si llegan a existir.
- Las suites de prueba que crean containers o modelos de SwiftData son `@MainActor`. Swift Testing corre las suites en paralelo, y SwiftData usado desde varios hilos a la vez tumbó el proceso de pruebas en CI (señal 11, de forma intermitente).
- Montos siempre `Decimal`. Prohibido `Double` para dinero. `Decimal(string:locale:)` con `en_US_POSIX`.
- Enums persistidos con `String` raw value.
- Toda zona horaria explícita: `TimeZone(identifier: "America/Panama")!`. Nunca `.current` en lógica de parseo o agrupación.
- Inyección por protocolo para los efectos laterales del pipeline de captura (`MovementNotifier`, `BackupTrigger`). Las fases tempranas usan implementaciones no-op; las fases posteriores las reemplazan sin tocar el pipeline.
- Ningún intent lanza error a Shortcuts por un fallo de parseo. Solo lanza si el store es inaccesible (el Append del CSV viejo ya habrá corrido).
- Definition of done por fase: compila sin warnings nuevos, `swift test` verde en ambos paquetes, `README.md` al día (ver `CLAUDE.md`, "Antes de abrir un PR"), checklist del gate marcado en el PR.

### Mapa de fases

| Fase | Nombre | Resultado observable | AC cubiertos | Depende de |
|---|---|---|---|---|
| 0 | Fundación | App vacía con store en App Group y lista de solo lectura | — | — |
| 1 | Parsers | `swift test` verde con fixtures reales | 2, 3, 4, 7, 16 (unitarios) | — |
| 2 | Captura | Toco la tarjeta o llega un Yappy → aparece en la lista | 1, 5, 6, 10, 12 | 0, 1 |
| 3 | Notificaciones | Llega la pregunta y respondo sin abrir la app | 1, 7, 8, 9, 12 | 2 |
| 4 | Revisión y edición | Filtros, detalle editable, re-parseo, entrada manual, borrar | 9, 13, 14, 15, 17, 18 | 3 |
| 5 | Exportar y respaldo | CSV en iCloud Drive sin abrir la app | 11, 21 | 2, 4 |
| 6 | Adjuntos | Foto, PDF, link y QR por movimiento | 15, 19, 20 | 4 |
| 7 | Transición | Shortcuts viejos retirados con evidencia | — | 3 + 2–3 semanas |
| 7a | Bitácora de captura | Una captura perdida dice en qué paso murió o si se borró | — | 2 |
| 7b | Aviso de vencimiento de la firma | Ajustes dice cuándo vence la app; con menos de 48 h la lista avisa, y llega una notificación 24 h antes | — | 3 |
| 8 | Tipo y categoría (v2) | Clasifico a mano; resumen y CSV respetan el `kind` | 22, 23, 24, 25, 31 (parcial) | 4, 5 |
| 9 | Reglas y sugerencias (v2) | La segunda compra en un comercio se clasifica con un toque desde la notificación | 26, 27, 28 | 3, 8 |
| 10 | Dividir movimientos (v2) | Un movimiento repartido en partes con su propia clasificación | 25, 29, 30, 31 | 8 |
| S1 | Spike: correos de factura | Censo de correos reales, fixtures y decisión go/no-go | — | 2 (atajo de correo activo) |
| 11 | Facturas por correo (v1.1) | Llega la factura por correo → queda asignada al movimiento | AC-F1…F9 (propuestos) | 6, 8, S1 |

Las fases 0 y 1 pueden correr en paralelo (dos agentes, dos ramas). La Fase 1 es dueña de `Packages/GastarioParsing`; la Fase 0 no lo crea.

El spike S1 no lleva código de la app y conviene **arrancarlo ya**, en paralelo con la Fase 7: es recolección de correos reales durante 2–3 semanas. La Fase 11 depende de la Fase 8 solo por el esquema versionado (`SchemaMigrationPlan`); no necesita las reglas ni la división.

---

## Fase 0 — Fundación

**Objetivo.** Proyecto compilable en dispositivo con el store de SwiftData en el App Group desde el primer commit, modelos completos y una lista mínima para ver datos.

**Alcance.**
- `project.yml` (XcodeGen) con bundle id y capability **App Groups** (`group.<bundle-id>`). iCloud Documents se habilita en Fase 5 (es solo un toggle, no una migración).
- Paquete `GastarioCore`, que depende de `GastarioParsing` (lo crea la Fase 1; si la Fase 0 empieza antes de mergearla, se basa en su rama).
- Modelos `Movement` y `Attachment` según `INTENT.md` + C1 + C2. Relación `attachments` con `deleteRule: .cascade`. **Sin** `@Attribute(.unique)` en `confirmation`.
- `GastarioStore.makeContainer(inMemory: Bool) -> ModelContainer`. En disco apunta a `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`. Falla en voz alta (`fatalError` con mensaje) si el App Group no está disponible: es un error de configuración, no de runtime.
- `MovementListView` de solo lectura con `@Query`, agrupada por día en `America/Panama`, orden `occurredAt` descendente. Muestra contraparte, monto con signo, ícono de fuente, badges "sin nota" y "requiere revisión".
- `#if DEBUG`: menú para insertar movimientos de muestra y para borrar todo.

**Fuera de alcance.** Cualquier edición, intents, notificaciones.

**Entregables.**
- `Packages/GastarioCore/Sources/GastarioCore/Models/{Movement,Attachment,Enums}.swift`
- `Packages/GastarioCore/Sources/GastarioCore/Store/GastarioStore.swift`
- `Gastario/App/GastarioApp.swift`, `Gastario/Movements/MovementListView.swift`
- `project.yml` con la capability App Groups. Desde la Fase 5 las capabilities viven en `Configs/Gastario.entitlements` (versionado) y `Configs/Base.xcconfig` elige el archivo.
- README corto en cada paquete: cómo correr `swift test`.
- `scripts/verify.sh` sin la tolerancia a partes faltantes: si un paquete o `project.yml` no existe, falla.

**Pruebas automáticas.**
- Insertar y leer un `Movement` en container en memoria.
- Borrar un `Movement` con dos `Attachment` → cero attachments restantes (cascade).
- `editedFields` y `parseIssues` sobreviven un ciclo guardar/leer.

**Gate de salida.**
- [ ] `swift test` verde en ambos paquetes.
- [ ] 📱 La app abre en el dispositivo. El log de arranque (categoría `app`) imprime la URL del store y contiene `Shared/AppGroup`, la ruta de los App Groups en iOS. (`Group Containers` es la ruta en macOS.)
- [ ] 📱 Insertar muestras desde el menú DEBUG, cerrar la app desde el switcher, reabrir → siguen ahí.

**Riesgos.** ~~Verificar contra el SDK de iOS 27 que SwiftData acepte `Set<ParseIssue>` y `Set<EditableField>` como atributos Codable sin transformer; si no, persistir como `[String]`.~~ **Resuelto:** enums y conjuntos se persisten como `String` / `[String]` con accesores tipados. Evita el riesgo y permite predicados sobre `parseStatusRaw` en la Fase 4.

---

## Fase 1 — Parsers puros

**Objetivo.** Todo el parseo como funciones puras sobre texto, con fixtures reales, sin tocar SwiftData ni UI. Es la parte que más valor da por hora de agente y la que `INTENT.md` identifica como frágil hoy.

**Alcance.** Paquete `GastarioParsing`:
- `TextNormalizer.normalize(_:)`: U+00A0 y U+202F → espacio; `\r\n` → `\n`.
- `AmountParser.parse(_:) -> Decimal?`: regex `\d[\d,]*(?:\.\d+)?`, quitar comas, `Decimal(string:locale:)` POSIX. Devuelve `nil` para vacío o no parseable; `0` para `"$0.00"`.
- `CardInputParser.parse(CardRawInputs) -> ParsedCard`: aplica `AmountParser`; monto `nil` o `0` → issue `amount` y `amount = 0`; merchant vacío o solo espacios → issue `counterparty`.
- `YappyDateParser.parse(_:) -> Date?`: regex día/mes/año/hora/minuto/`a|p`; mapa `ene…dic` + `sept`; `DateComponents` con `America/Panama`. Sin `DateFormatter`.
- `YappyEmailParser.parse(_:) -> ParsedYappy`: dirección, monto, contraparte, mensaje, confirmación, fecha, según la tabla de `INTENT.md`. Reglas de estado:
  - `failed`: no se pudo determinar dirección **o** monto.
  - `partial`: dirección y monto presentes, pero falta alguno de contraparte, confirmación o fecha. Cada faltante va a `parseIssues`.
  - `ok`: todo presente. `yappyMessage` vacío **no** es un issue.
- Tipos de salida (`ParsedCard`, `ParsedYappy`, `ParseStatus`, `ParseIssue`, `Direction`) viven aquí y `GastarioCore` los reexporta o mapea.

**Fixtures.** `Tests/GastarioParsingTests/Fixtures/Yappy/`:
- HTML tal como lo entrega `Content`: `sent-with-message.html`, `sent-without-message.html`, `received.html`.
- `paid-merchant-content.txt`: "Pagaste" real tal como llegó al intent (texto plano), desde la vista de cuerpo crudo. Coincide línea por línea con `paid-merchant-with-message.txt`.
- Texto plano copiado de Mail (todavía sin HTML de estos tipos): `sent-as-text.txt`, `paid-merchant.txt`, `paid-merchant-with-message.txt`, `commercial-received.txt`, `commercial-online-purchase.txt`.
- Sintéticos derivados de un real: `amount-with-comma.html`, variantes de fecha `date-narrow-nbsp.html` (U+202F) y `date-plain.html`. La variante U+00A0 es la de los fixtures reales.
- `unexpected-format.txt` (cuerpo que no es de Yappy).
- Los datos personales (nombres, teléfonos, confirmaciones, números de pedido, negocio) se reemplazan conservando el formato.

Los cuerpos deben ser **reales**, copiados desde Mail (seleccionar todo el cuerpo → copiar). Cuando exista la vista de cuerpo crudo (Fase 4), se comparan contra lo que llega al intent y se reemplazan si difieren. Hasta recibir los reales, el agente trabaja con fixtures sintéticos marcados `// SYNTHETIC` en el nombre del test; el gate no se cierra con sintéticos.

**Pruebas automáticas.** Un test por fixture y por fila de la tabla de montos de `INTENT.md` (`$3.80`, `$1,250.00`, `B/.3.80`, `USD 3.80`, `""`, `"$0.00"`). Cubren AC-2, AC-3, AC-4, AC-16 y la mitad de parseo de AC-7 y AC-12.

**Gate de salida.**
- [ ] `swift test` verde en `GastarioParsing` en macOS **y** en Linux (jobs `macos` y `linux` de CI).
- [ ] Al menos 3 fixtures de Yappy son reales (enviado con mensaje, sin mensaje, recibido).
- [ ] Ningún test marcado `SYNTHETIC` para los casos que ya tienen fixture real.

---

## Fase 2 — Captura (App Intents)

**Objetivo.** Los dos App Intents guardan en el store, en segundo plano, siguiendo el orden obligatorio, con deduplicación. Al cerrar esta fase se activan los Shortcuts nuevos **en paralelo** con los CSVs viejos (empieza el reloj de la Fase 7).

**Alcance.**
- `GastarioCore/Capture/CaptureService`:
  - `captureCard(_ inputs: CardRawInputs, capturedAt: Date = .now) async -> CaptureOutcome`
  - `captureYappy(content: String, capturedAt: Date = .now) async -> CaptureOutcome`
  - `CaptureOutcome` = `.created(Movement.ID)` | `.duplicate(existing: Movement.ID)`.
  - Orden interno: (1) insertar `Movement` con crudo y `parseStatus = failed` provisional, guardar; (2) parsear; (3) actualizar campos, `parseStatus`, `parseIssues`; (4) guardar; (5) `notifier.notify(movementID)`; (6) `backup.runIfDue()`. Los pasos 5 y 6 reciben protocolos; en esta fase son no-op.
  - Dedup Yappy por `confirmation` + `direction` (C11), **después** de los pasos 1–3: la confirmación sale del parser, y parsear antes de guardar el crudo perdería la captura si el parser falla (principio 2). Si existe otro movimiento con la misma clave → se borra el recién insertado y se devuelve `.duplicate`, sin tocar el existente y sin notificar. Sin `confirmation` o sin `direction` no hay dedup (C3).
  - El parser se inyecta (`CaptureParser`) para poder probar con uno que lanza.
  - `@MainActor`: las capturas del proceso se serializan, así dos correos iguales simultáneos no pasan ambos la dedup.
  - `rawInputs` = JSON de `CardRawInputs` (Codable) tal como llegó.
- `Gastario/Intents/LogCardMovementIntent.swift`, `LogYappyEmailIntent.swift`:
  - Títulos "Log Card Transaction" y "Log Yappy Email".
  - Modo background con `supportedModes = .background` (iOS 26+; verificado: compila con Xcode 26.6).
  - Usan un único container por proceso (compartido con la app) y llaman a `CaptureService`. Devuelven `.result()` siempre que el store responda, también en `.duplicate` y en `failed`.
  - Todos los parámetros son opcionales: uno requerido que llega vacío hace que Atajos pregunte, y en segundo plano eso detiene la captura (principio 1). `nil` se guarda como `""`.
- Instrucciones para configurar los dos atajos en `docs/shortcuts.md`, copiadas de `INTENT.md`, con el `Append to Text File` **antes** del intent.

**Fuera de alcance.** Notificaciones, export, UI.

**Pruebas automáticas** (container en memoria, `MovementNotifier` espía):
- Tarjeta completa → `card`/`outflow`, monto `Decimal`, `ok`, notifier llamado una vez. (AC-1 sin la notificación)
- Tarjeta con `Amount = "0"` o `Merchant = ""` → `partial`, issues correctos, se guarda. (AC-12)
- Tarjeta sin ciudad ni coordenadas → se guarda con nulos. (AC-10)
- Mismo correo dos veces, el primero con `note` → un `Movement`, `note` intacta, notifier llamado una vez. (AC-6)
- Dos correos distintos → dos movimientos. (AC-5)
- Misma `confirmation` con dirección opuesta (pago al propio negocio por Yappy Comercial) → dos movimientos. (C11)
- Cuerpo inesperado → `failed`, `rawContent` guardado, notifier llamado. (AC-7)
- El `Movement` existe en el store **antes** de que termine el parseo (inyectar un parser que lance; el movimiento queda `failed` con crudo). Principio 2.

**Gate de salida.**
- [ ] Tests anteriores verdes.
- [ ] 📱 Ambos atajos configurados según `docs/shortcuts.md`. Pagar con Apple Pay → el movimiento aparece en la lista sin abrir la app durante el pago.
- [ ] 📱 Recibir un Yappy → aparece. Correr el atajo de email dos veces sobre el mismo correo → un solo movimiento.
- [ ] 📱 El CSV viejo sigue recibiendo filas (el Append va antes del intent).
- [ ] 📱 Un correo de otro remitente que llega junto con un Yappy no crea movimiento (`If` del remitente dentro del `Repeat`).
- [ ] 📱 Un Yappy que llega **después** de otro correo en el mismo lote sí entra (el trigger no filtra por remitente).

**Riesgos.** El trigger de Wallet puede entregar `Merchant` vacío o `Amount = 0`; los formatos reales de `Amount` deben agregarse a los fixtures de Fase 1 en cuanto se observen. Verificar que el intent corre con la app terminada desde el switcher.

---

## Fase 3 — Notificaciones

**Objetivo.** Cada captura dispara la pregunta y la respuesta se guarda sin abrir la app, incluso con la app terminada. Es el momento en que Gastario reemplaza funcionalmente a los Shortcuts viejos.

**Alcance.**
- `Gastario/Notifications/NotificationService`: pedir permiso en el primer arranque; registrar categoría `MOVEMENT_QUESTION` con `UNTextInputNotificationAction(identifier: "REPLY", title: "Responder")`, **sin** `.foreground`. Implementa `MovementNotifier`.
- `GastarioCore/Notifications/NotificationText.build(for: Movement) -> (title, body)`: textos de `INTENT.md`. Para tarjeta `partial` usa `parseIssues` para elegir "el monto", "el comercio" o "el monto ni el comercio". Montos con `.currency(code: "USD")` y locale `en_US` → `$3.80`.
- Identificador de la notificación = `movement.id.uuidString`.
- `Gastario/App/AppDelegate` vía `@UIApplicationDelegateAdaptor`. En `didFinishLaunchingWithOptions`: crear el `ModelContainer` compartido (propiedad del AppDelegate, no de la escena SwiftUI) y asignar `UNUserNotificationCenter.current().delegate`. Motivo: al responder con la app terminada, iOS lanza el proceso y llama a `didReceive` sin que ninguna vista exista.
- `GastarioCore/Notifications/NoteReplyHandler.handle(movementID:text:)`: busca, asigna `note` y `notedAt`, guarda. El `completionHandler` del delegate se llama **después** del `await` de este método.
- Movimientos `manual` no notifican (el `CaptureService` no participa en la entrada manual; se cubre en Fase 4).
- Reemplazar el no-op de Fase 2 por `NotificationService`.
- Swift 6: los métodos del delegate son `nonisolated` y solo pasan valores `Sendable` al `MainActor`; permiso y programación usan las APIs `async` desde funciones `nonisolated` (un completion handler creado en el `MainActor` y llamado desde otro hilo falla la verificación de aislamiento).
- `didReceive` usa la forma con completion handler, no la `async`, y llama el completion desde el `MainActor`. Con la forma `async`, el thunk del compilador lo llama desde el executor genérico; para la acción por defecto UIKit responde en `-[UIApplication _updateSnapshotAndStateRestorationWithAction:windowScene:]`, que exige el hilo principal, y la app muere con `NSInternalInconsistencyException` al abrirse desde la notificación (C15). "Responder" no pasa por ahí, por eso AC-8 funcionaba.
- El detalle de solo lectura muestra `note` y `notedAt`, para verificar AC-8 en el dispositivo.

**Pruebas automáticas.**
- `NotificationText` para los 6 casos: salida, entrada, tarjeta sin monto, sin comercio, sin ambos, Yappy `failed`. Más los de C13 y un monto con coma.
- `NotificationText` recibe valores simples (con una sobrecarga para `Movement`), así se prueba también fuera de SwiftData.
- `NoteReplyHandler` con container en memoria: guarda `note` y `notedAt`; con un ID inexistente no lanza.

**Gate de salida.**
- [ ] 📱 AC-1 completo: pago → notificación con el texto correcto.
- [x] 📱 AC-8: dejar la notificación varias horas, matar la app desde el switcher, responder desde el Centro de Notificaciones → abrir la app → `note` y `notedAt` guardados.
- [ ] 📱 AC-7 y AC-12: llegan las notificaciones de revisión / completar.
- [ ] 📱 Dedup: un correo repetido no genera segunda notificación (AC-6).
- [ ] 📱 C15: tocar la notificación, con la app cerrada y con la app abierta en otra pantalla, abre el detalle del movimiento con el teclado en la nota. Para probarlo sin capturar nada: Debug → "Notificación de prueba en 5 s" programa la notificación del movimiento más reciente.

**Riesgos.** Si `didReceive` llega antes de que el container esté listo, la respuesta se pierde: por eso el container se crea síncronamente en `didFinishLaunching`. Medir que no exceda el tiempo de arranque en frío.

---

## Fase 4 — Revisión y edición

**Objetivo.** Todo lo que permite confiar en los datos: ver qué falló, corregirlo, re-parsear, agregar lo que la automatización no capturó y borrar lo que sobra.

**Alcance.**
- **Filtros** en la lista: "Todos", "Sin nota" (`note == nil`), "Requiere revisión" (`parseStatus != ok`; en el control segmentado dice "Revisar"). Cuenta en cada filtro. Se filtra en memoria sobre el `@Query`: el volumen personal no justifica predicados dinámicos.
- **Detalle** (`MovementDetailView`):
  - Todos los campos. Link a Maps si hay coordenadas. Aviso si es Yappy sin `confirmation` (C3).
  - Sección **Cuerpo crudo** para Yappy, con botón "Copiar" (para alimentar fixtures). Para tarjeta, `rawInputs` formateado. **Adelantado:** una versión de solo lectura (campos, hora de captura con segundos y cuerpo crudo) entró después de la Fase 2 para diagnosticar capturas reales; la Fase 4 la vuelve editable.
  - Edición en una hoja ("Editar") que solo aplica los campos que cambiaron, vía `GastarioCore/Editing/MovementEditor`. Montos con el mismo `AmountParser` de la captura.
  - Edición de `amount`, `counterparty`, `occurredAt`. Cada edición agrega el campo a `editedFields` y quita su `ParseIssue`. Si `parseIssues` queda vacío y el estado era `partial` → `ok`. Un `failed` **no** cambia por edición: solo por re-parseo (su crudo no se entendió; editar a mano no lo valida).
  - `note` editable; al guardar asigna `notedAt` si estaba vacío.
  - Botón "Re-parsear" en `card`/`yappy`.
- `GastarioCore/Reparse/ReparseService`:
  - `reparse(_ movement:)`: vuelve a correr el parser sobre `rawInputs`/`rawContent`, escribe solo los campos **no** incluidos en `editedFields`, recalcula `parseStatus` y `parseIssues` (un campo editado nunca cuenta como issue). No toca `note`, `notedAt`, `attachments`. Ignora `manual`.
  - `reparseAll()`: solo `parseStatus != ok`. Devuelve conteo de cambiados.
- **Entrada manual** (`+`): monto, dirección, contraparte, fecha (default ahora), nota opcional. Crea `source = manual`, `parseStatus = ok`, sin pasar por `CaptureService` → sin notificación.
- **Borrar**: swipe con `confirmationDialog`. Cascade borra adjuntos. También retira la notificación entregada del movimiento, para que no quede una pregunta sobre algo que ya no existe.
- **Resumen del mes** como cabecera de la lista (C9).
- **Ajustes** (esqueleto): "Re-parsear todo" con resultado "N movimientos actualizados". Fase 5 agrega las filas de export.

**Pruebas automáticas.**
- `ReparseService`: crudo bueno + campos corruptos → restaura, conserva `note`, `attachments` y `editedFields`. (AC-17, AC-18)
- `reparseAll` ignora `ok` y `manual`.
- Resolución `partial → ok` al editar el último campo faltante; `failed` no cambia por edición. (AC-13)
- Resumen mensual con movimientos en el límite de mes en `America/Panama` (23:30 del día 30 en UTC cae en el mes siguiente; en Panamá no).

**Gate de salida.**
- [ ] Tests verdes.
- [ ] 📱 AC-9: borrar una notificación sin responder → el movimiento está en "Sin nota".
- [ ] 📱 AC-13, AC-14, AC-18 en dispositivo.
- [ ] 📱 AC-15 parcial: borrar un movimiento desaparece de la lista (adjuntos reales se verifican en Fase 6).
- [x] Fixtures de Fase 1 comparados con el cuerpo crudo real capturado; reemplazados si difieren. ("Pagaste" real coincide con el fixture de Mail; agregado como `paid-merchant-content.txt`.)

---

## Fase 5 — Exportar y respaldo

**Objetivo.** Nunca depender del dispositivo como única copia. El CSV completo se escribe a iCloud Drive cada 7+ días, aunque la app no se abra.

**Alcance.**
- Capability **iCloud Documents** (ubiquity container `iCloud.com.renandiaz.Gastario`, no CloudKit), en `Configs/Gastario.entitlements`. Los equipos personales (cuenta gratis) no admiten iCloud: `Configs/Local.xcconfig` puede elegir `Configs/Gastario-SinICloud.entitlements` (sin respaldo automático; el error queda en Ajustes y la captura no se ve afectada). `NSUbiquitousContainers` en Info.plist con `NSUbiquitousContainerIsDocumentScopePublic = true` para que la carpeta aparezca en Files. Como es un diccionario, XcodeGen genera `Gastario/Info.plist` desde `project.yml` (no se versiona), con las versiones enlazadas a `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`.
- `GastarioCore/Export/CSVExporter.export(_ rows: [CSVRow]) -> Data` (filas con valores simples, más `CSVRow(movement)`; se prueba también fuera de SwiftData). Fin de línea CRLF (RFC 4180). Montos con dos decimales y punto: columnas exactas de `INTENT.md`, montos con signo (`outflow` negativo), fechas según C6, escape RFC 4180 (comillas dobles, saltos de línea dentro de `note`), `attachmentCount` = `attachments.count`. Sin BOM.
- `GastarioCore/Export/BackupPolicy`: `isDue(lastExportAt:now:)` → 7 días. Estado en `UserDefaults` del App Group (C4): `lastExportAt`, `lastExportAttemptAt`, `lastExportError`.
- `Gastario/Export/BackupService`: implementa `BackupTrigger`. Obtiene `FileManager.url(forUbiquityContainerIdentifier: nil)` **fuera del main actor** (puede bloquear), escribe en `Documents/` con el nombre de C5. Cualquier error se registra en `lastExportError` y **nunca** se propaga al intent.
- Puntos de evaluación: paso 6 del `CaptureService` (reemplaza el no-op) y `scenePhase == .active` al abrir la app.
- Ajustes: fecha del último export, último error si lo hay, "Exportar ahora" (fuerza el export a iCloud **y** ofrece `ShareLink` del mismo archivo, que se escribe también en el directorio temporal: se puede compartir aunque iCloud falle).
- `#if DEBUG`: botón "Simular 8 días sin export" que retrocede `lastExportAt`.

**Pruebas automáticas.**
- Golden test de `CSVExporter` con 3 movimientos (uno con coma y comillas en `note`, uno `inflow`, uno sin ubicación).
- `BackupPolicy.isDue` en los bordes: 6d23h → no; 7d → sí; nunca exportado → sí.
- ~~`CaptureService` con un `BackupTrigger` que lanza → la captura igual termina `.created`.~~ Garantizado por tipo: `BackupTrigger.runIfDue()` no es `throws`, así que no puede propagar un error a la captura.
- `BackupState` en un `UserDefaults` de prueba: un fallo no mueve `lastExportAt`; un éxito limpia el error.
- Nombre de archivo de C5 en hora de Panamá.

**Gate de salida.**
- [ ] Tests verdes.
- [x] 📱 AC-11: "Exportar ahora" → el archivo abre en Numbers, una fila por movimiento, montos con signo, fechas legibles.
- [ ] 📱 AC-21: "Simular 8 días", matar la app, hacer un pago → aparece el CSV nuevo en Files → iCloud Drive → Gastario, sin abrir la app.
- [ ] 📱 Un export fallido (modo avión + iCloud deshabilitado) no impide la captura ni la notificación.

**Riesgos.** El ubiquity container puede tardar en estar disponible tras la primera activación de iCloud Documents; el primer export puede fallar y reintentarse en la siguiente captura. Eso es comportamiento esperado, no bug.

---

## Fase 6 — Adjuntos

**Objetivo.** Documentar cada movimiento con foto, PDF o link, sin tocar el camino de captura (principio 4).

**Alcance.**
- `Gastario/Attachments/AttachmentService` (app target, necesita UIKit/PhotosUI):
  - Foto: `PhotosPicker` y cámara (`UIImagePickerController` envuelto). Guardar según C8.
  - PDF: `.fileImporter(allowedContentTypes: [.pdf])`, leer dentro de `startAccessingSecurityScopedResource`, copiar `Data`.
  - Link: `TextField` validado (`URL` con esquema `http`/`https`).
  - QR: `DataScannerViewController` con `.barcode(symbologies: [.qr])`; si el payload es URL → `kind = link`; si no → error (C7).
  - Ver: `QLPreviewController` sobre un archivo temporal escrito desde `data`; links dentro de la app con `SFSafariViewController` (C14).
- Sección de adjuntos en el detalle: lista, agregar, borrar individual.
- `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` en Info.plist.

**Pruebas automáticas.** Validación de links (acepta `https://dgi-fep.mef.gob.pa/...`, rechaza `javascript:`, texto plano, `ftp://`). Redimensionado de imagen respeta el máximo. El resto es UI y se verifica en dispositivo.

**Notas de implementación.**
- La lógica probable vive en `GastarioCore/Attachments`: `AttachmentRules` (links; el QR es estricto, un link escrito a mano sin esquema se completa con `https://`) e `ImageCompressor` (ImageIO, aplica la orientación EXIF y nunca agranda una imagen chica).
- La compresión corre fuera del main actor.
- La vista previa usa `.quickLookPreview` de SwiftUI sobre un archivo temporal.

**Gate de salida.**
- [ ] 📱 AC-19: PDF de 5 MB, cerrar y abrir → sigue ahí y abre en Quick Look. Verificar que el store `.sqlite` no creció 5 MB (externalStorage).
- [ ] 📱 AC-20: QR de una factura electrónica real → `link` que abre dentro de la app, sin pestaña nueva en Safari (C14).
- [ ] 📱 AC-15 completo: borrar un movimiento con 3 adjuntos → desaparecen los archivos externos.
- [ ] 📱 Una captura durante el flujo de adjuntar no se pierde ni se afecta.

---

## Fase 7 — Transición (operativa)

**Objetivo.** Retirar los Shortcuts viejos con evidencia de que Gastario no pierde capturas.

**Procedimiento.**
1. Empieza al cerrar la Fase 3 (desde ahí Gastario es funcional). Duración: 2–3 semanas de uso normal.
2. Al final: "Exportar ahora" en Gastario y comparar contra los dos CSVs viejos con `Tools/TransitionReport` ([README](README.md#transición-fase-7)). Da **conteos y sumas por día** y empareja fila por fila: Yappy por confirmación, tarjeta por monto y hora del atajo (±5 min). La app no cambia: es una herramienta de línea de comandos que reutiliza `GastarioParsing`.
3. Cada discrepancia se clasifica: (a) duplicado en Gastario sin `confirmation` (C3), (b) pago rechazado capturado por el tap, (c) captura perdida en Gastario, (d) captura perdida en el CSV viejo. La herramienta sugiere una clase; la decide la persona.
   - Un pago rechazado (b) aparece en los dos lados, porque el CSV viejo y Gastario corren en el mismo atajo: no sale como discrepancia. Se busca a mano contra el estado de cuenta.
   - Un Yappy que el atajo nunca vio (como el que se perdió por el filtro del trigger, ver [`docs/shortcuts.md`](docs/shortcuts.md#yappy-correo)) falta **en los dos lados** y la comparación no lo detecta. Por eso, además: buscar en Mail los correos de `notificaciones@yappy.com.pa` del período y comparar su cantidad con las filas de Yappy en Gastario. Si falta en los dos, cuenta como (c).
4. Cualquier (c) bloquea el retiro: se investiga con la [bitácora de captura](#fase-7a--bitácora-de-captura), se corrige, y se extiende el período una semana.
   - **Primera comparación (28/10, desde el 16/10):** 13 de 15 pagos con tarjeta coinciden. Faltan en Gastario dos que el CSV viejo sí tiene, ninguno borrado a mano: (c).
     - 22/10 18:02, M/S Betty, $3.10. Causa probable: el perfil de firma de la cuenta gratis vence a los 7 días y la app deja de abrir, también para el intent. El atajo escribe el Append y falla en Gastario. Mientras se firme con cuenta gratis, hay que reinstalar antes del vencimiento; en la bitácora este caso se ve como "ningún `received`". Mitigación: el aviso de vencimiento de la [Fase 7b](#fase-7b--aviso-de-vencimiento-de-la-firma) (C18).
     - 18/10 15:40, con comercio, monto y tarjeta vacíos. Sin explicar: es el caso para el que existe la Fase 7a.
     - Además, el 25/10 (Rey David, $18.78, pagado con el iPhone) falta en los dos lados y se registró a mano: el atajo no corrió o se detuvo antes del Append. La bitácora no lo ve. Sospechosa: `Current Location`, la primera acción del atajo, que lo detiene si falla.
5. Con cero (c): quitar el `Append to Text File` de ambos atajos. Archivar los CSVs viejos como insumo para la importación de v1.1.

**Gate de salida.**
- [ ] Tabla de comparación en `docs/transition-report.md` (salida de `Tools/TransitionReport`) con los conteos y la clasificación de cada discrepancia.
- [ ] Conteo de correos de Yappy en Mail del período igual al de Gastario.
- [ ] Appends retirados.
- [ ] Decisión registrada sobre v1.1: importar CSVs, Share Extension, y qué formatos reales de `Amount` aparecieron.

---

## Fase 7a — Bitácora de captura

**Objetivo.** Que una captura perdida deje evidencia de dónde murió (C17). Hoy, si el atajo llamó a Gastario y el movimiento no está, no hay forma de saber si el intent no corrió, si el proceso murió antes de guardar, si el store lanzó o si el movimiento se borró después. La bitácora no arregla nada: da el dato para arreglar la causa real. Bloquea el cierre de la Fase 7, porque sin ella una (c) no se puede investigar.

**Por qué fuera de SwiftData.** Si el problema está en abrir o escribir el store, una bitácora en el store muere con él. Es el mismo argumento de C4.

**Alcance.**
- **Archivo.** `<App Group>/Logs/capture-YYYY-MM.jsonl`, con el mes en `America/Panama`. Una línea JSON por evento, con las claves ordenadas. Se conservan el mes actual y los dos anteriores, y lo más viejo se borra al abrir la app. Tamaño esperado: < 1 MB al mes.
- **Escritura.** `CaptureLog` en `GastarioCore/Diagnostics/`, solo con Foundation. Cada evento se escribe completo de inmediato (abrir en modo append, una sola escritura, `synchronize()`, cerrar): si iOS mata el proceso, lo escrito antes ya está en disco. **La bitácora nunca hace fallar ni retrasa una captura:** sus errores se tragan y solo van a OSLog (principio 1).
- **Campos comunes.** `t` (ISO 8601 con milisegundos y offset de Panamá), `pid`, `ev` (el evento) e `inv` (UUID de la invocación; no lo llevan `process` ni `deleted`).
- **Eventos.**

| `ev` | Quién lo escribe | Cuándo | Campos propios |
|---|---|---|---|
| `process` | `CaptureLog` | En la primera escritura de cada proceso | `version`, `build` |
| `received` | El intent | Primera línea de `perform()`, **antes** de tocar `SharedModelContainer` (su inicialización perezosa es sospechosa) | `src`. Tarjeta: los 6 parámetros tal como llegaron, con `null` distinto de `""`. Yappy: `contentLength` y `contentSHA256` (el correo sigue en Mail y el cuerpo crudo ya va al store) |
| `rawSaved` | `CaptureService`, vía observador | Después del `save()` del paso 1 | `movementID` |
| `saved` | `CaptureService`, vía observador | Después del paso 4, o después de borrar un duplicado | `movementID`, `outcome` (`created` o `duplicate` con `existing`), `parseStatus`, `parseIssues` |
| `error` | El intent | En un `catch` alrededor de la captura, antes de relanzar | `message`, `type` |
| `done` | El intent | Justo antes de `return .result()` | — |
| `deleted` | La app | Al borrar un movimiento: swipe en la lista y "Borrar todo" del menú Debug | `movementID`, `src`, `amount`, `counterparty`, `capturedAt`, `from` (`list` o `debug`) |

- **Observador.** El protocolo `CaptureObserver` (`rawSaved(id:)`, `saved(id:outcome:status:issues:)`) se inyecta en `CaptureService` como `MovementNotifier`, con `NoopCaptureObserver` por defecto. El intent crea uno por invocación, con su `inv`. El pipeline no cambia de orden, solo avisa.
- **Lectura.** `CaptureLogReader` agrupa los eventos por `inv` y clasifica cada invocación según la tabla de interpretación (abajo). Es una función pura sobre las líneas; una línea que no se puede leer se cuenta y se salta.
- **Ajustes → "Bitácora de captura".** Muestra cuántas invocaciones hubo en los últimos 30 días y cuántas no terminaron en `done`. Las que no terminaron se listan con hora, fuente, comercio y monto crudos, y el último evento que alcanzaron. Abajo, los borrados del mismo período. Botón **"Compartir bitácora"** (`ShareLink` con los `.jsonl`), para pasarlos al agente igual que los CSVs.

**Interpretación** (para una fila que está en el CSV viejo y no en Gastario).

| Lo que dice la bitácora | Dónde murió |
|---|---|
| Ningún `received` cerca de esa hora | El intent no se invocó: Atajos falló al llamar la acción después del Append |
| `received`, sin `rawSaved` ni `error` | El proceso murió antes del primer guardado: abriendo el store o porque iOS lo mató |
| `received` + `error` | El store lanzó. El mensaje dice qué pasó |
| `rawSaved`, sin `saved` | Murió entre el parseo y el segundo guardado. El crudo **debería** estar en el store como `failed`; si no está, el primer guardado no fue durable |
| `saved`, sin `done` | Murió notificando o respaldando. El movimiento existe |
| `done` + `deleted` del mismo `movementID` | Se borró a mano |
| `done`, sin `deleted` | Desapareció del store después de guardarse: bug grave, se investiga aparte |

Un `pid` distinto entre dos eventos de la misma invocación no debería pasar. Si pasa, iOS relanzó el proceso a mitad de la captura.

**Fuera de alcance.**
- Arreglar la causa: eso sale de la evidencia, en su propio PR.
- Lo que pasa en Atajos antes de llamar al intent: la bitácora no lo ve. Un pago que falta en los dos lados sigue saliendo de la comparación del paso 3 de la Fase 7.
- Registrar notificaciones y respuestas.
- Que `Tools/TransitionReport` lea la bitácora. Se agrega si cruzarla a mano resulta lento.

**Entregables.**
- `Packages/GastarioCore/Sources/GastarioCore/Diagnostics/{CaptureLog,CaptureLogEvent,CaptureLogEvent+Movement,CaptureLogReader,CaptureObserver}.swift`
- `CaptureService`: parámetro `observer` en `init` y las dos llamadas. Nada más cambia.
- `LogCardMovementIntent` y `LogYappyEmailIntent`: `received`, `error` y `done`, y el observador.
- `MovementListView.delete` y `DebugMenu`: `deleted`.
- `GastarioApp`: la retención al abrir.
- `SettingsView`: la sección "Bitácora de captura".

**Pruebas automáticas** (`GastarioCore`, macOS).
- Escribir varios eventos produce una línea JSON válida por evento, y `process` va una sola vez por instancia.
- El archivo del mes sigue `America/Panama`: el 31/10 a las 23:30 de Panamá (1/11 en UTC) va a `capture-2026-10.jsonl`.
- Una ruta en la que no se puede escribir no lanza.
- Tarjeta con `merchant` en `nil` y `amount` en `""`: la línea conserva la diferencia.
- `CaptureService` con un observador espía: `rawSaved` antes que `saved`, con el mismo ID. Un Yappy duplicado da `saved` con `outcome = duplicate` y el ID existente.
- `CaptureLogReader`: un caso por fila de la tabla de interpretación, y una línea corrupta que se salta sin perder las demás.
- Retención: con archivos de 4 meses, quedan los 3 más recientes y no se toca nada que no sea `capture-*.jsonl`.

**Gate de salida.**
- [ ] `scripts/verify.sh` verde en el job `macos`.
- [ ] 📱 Pagar con Apple Pay sin abrir la app → en Ajustes la invocación aparece completa. En el archivo compartido están `received`, `rawSaved`, `saved` y `done` con el mismo `inv`.
- [ ] 📱 Recibir un Yappy y correr el atajo otra vez sobre el mismo correo → dos invocaciones completas, la segunda con `outcome = duplicate`.
- [ ] 📱 Borrar un movimiento desde la lista → aparece en "Borrados".
- [ ] 📱 "Compartir bitácora" entrega los `.jsonl`.
- [ ] Desde aquí, cada (c) de la Fase 7 se anota en `docs/transition-report.md` con la fila de la tabla de interpretación que le corresponde.

---

## Fase 7b — Aviso de vencimiento de la firma

**Objetivo.** Avisar antes de que venza la firma de la app, para reinstalarla desde Xcode a tiempo (C18). No evita el vencimiento ni reinstala sola: da el aviso que hoy no existe. Deja de hacer falta con una cuenta Developer pagada, cuyo perfil dura un año. Para entonces la sección casi nunca se pondrá en rojo, y puede quedarse.

**Por qué no basta la bitácora.** Con el perfil vencido el proceso no arranca: no hay `received` ni nada que escribir (Fase 7a, "Ningún `received`"). El único momento útil para avisar es **antes**.

**Alcance.**
- **Lectura del perfil.** `ProvisioningProfile.expirationDate(fromProfile: Data) -> Date?` en `GastarioCore/Signing/`, solo con Foundation. `embedded.mobileprovision` es un plist XML envuelto en una firma CMS (DER). Se toman los bytes desde `<?xml` hasta el primer `</plist>` que le sigue, ambos incluidos, se leen con `PropertyListSerialization` y se toma `ExpirationDate`. No se valida la firma CMS: el dato es solo informativo. Cualquier falla devuelve `nil`, sin lanzar.
- **Dónde está.** La app lo busca con `Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision")`. En App Store y TestFlight el archivo no existe, y en el simulador tampoco. Sin archivo, o si no se puede leer, no se muestra ni se programa nada.
- **Decisión.** `SigningExpiry(expiresAt:)`:
  - `isUrgent(now:)`: faltan **menos de 48 h** (incluye ya vencida, aunque en ese caso la app no abre).
  - `reminderDate(now:)`: `expiresAt − 24 h` si todavía está en el futuro; si no, `nil`.
  - Textos en `America/Panama` y `es_PA`: Ajustes, "La app vence el {fecha y hora}". Notificación, título "Gastario vence mañana" y cuerpo "La firma vence el {fecha y hora}. Reinstálala desde Xcode para no perder capturas."
- **Ajustes → "Firma".** Es la primera sección, porque es la única que avisa de una pérdida futura. Muestra "La app vence el …", en rojo si `isUrgent`. Pie: "Con una cuenta gratis la app vence 7 días después de instalarla desde Xcode. Vencida no abre, y los atajos no pueden guardar capturas." Sin perfil, la sección no aparece.
- **Aviso en la lista.** Con `isUrgent`, la lista muestra arriba del resumen del mes una fila en rojo: "La app vence el …" y, debajo, "Reinstálala desde Xcode para no perder capturas." Tocarla abre Ajustes. Ajustes solo se ve si se abre; la lista se ve siempre.
- **Notificación.** Identificador fijo `signing-expiry`, sin categoría (no lleva "Responder"). Cada vez que la app pasa a `active` se borra la pendiente con ese identificador y, si `reminderDate` no es `nil`, se programa otra con `UNTimeIntervalNotificationTrigger`. Al tocarla, la app abre sin más: el delegate ya ignora identificadores que no son UUID.
- **Debug.** En builds `DEBUG`, el botón "Simular vencimiento mañana" muestra la sección y el aviso de la lista con una fecha de vencimiento 24 h adelante (en rojo) y programa la notificación con ese texto para 10 s después. Así se verifica sin esperar 6 días.

**Casos límite** (decisiones por defecto).
- Al abrir faltan menos de 24 h: ya pasó la hora del aviso y no se programa. La lista y Ajustes están en rojo.
- Se reinstala desde Xcode y no se abre la app: la notificación anterior sigue programada y llega con la fecha vieja. Se corrige la próxima vez que se abre la app. Se acepta.
- Sin permiso de notificaciones: solo queda Ajustes.

**Fuera de alcance.**
- Renovar o reinstalar sin Xcode.
- Reprogramar desde los intents: los intents no deben hacer nada que no sea capturar.
- Registrar el vencimiento en la bitácora.

**Entregables.**
- `Packages/GastarioCore/Sources/GastarioCore/Signing/{ProvisioningProfile,SigningExpiry}.swift`
- `Gastario/Settings/SigningExpirySection.swift`: la sección de Ajustes, el botón de Debug y el aviso de la lista.
- `Gastario/Notifications/SigningExpiryReminder.swift`: leer el perfil del bundle y (re)programar la notificación.
- `GastarioApp`: reprogramar al pasar a `active`.
- `SettingsView`: la sección. `MovementListView`: el aviso.

**Pruebas automáticas** (`GastarioCore`, macOS).
- Perfil sintético (bytes binarios, el plist y más bytes binarios) → la fecha exacta de `ExpirationDate`.
- Sin `<?xml`, sin `</plist>`, `ExpirationDate` ausente o de otro tipo, datos vacíos → `nil`.
- `isUrgent`: 47 h 59 min → sí; 48 h → no; vencida → sí.
- `reminderDate`: con 3 días → vencimiento − 24 h; con 23 h → `nil`.
- Textos: la fecha y la hora salen en Panamá aunque en UTC sea otro día.

**Gate de salida.**
- [ ] `scripts/verify.sh` verde en el job `macos`.
- [ ] 📱 Instalar desde Xcode con la cuenta gratis → Ajustes muestra "La app vence el …" con la misma fecha que el perfil en Xcode (Signing & Capabilities, ⓘ del perfil).
- [ ] 📱 "Simular vencimiento mañana" (Debug) → la sección y el aviso de la lista en rojo; tocar el aviso abre Ajustes; y 10 s después llega la notificación, también con la app en segundo plano.
- [ ] 📱 En el ciclo real siguiente, la notificación llega 24 h antes del vencimiento.

---

## Fase 8 — Tipo y categoría

**Objetivo.** Clasificar cada movimiento con `kind` y categoría a mano, ver lo que falta clasificar y tener totales y CSV que respeten la clasificación ([`INTENT.md`, v2](INTENT.md#v2--clasificación)).

**Alcance.**
- `GastarioCore`: enums `MovementKind`, `ExpenseCategory`, `FixedCategory` (o un `Category` con su `kind`) y `TransportSubcategory`, con `String` raw value. Cada categoría sabe si es "fuera del presupuesto". `MovementKind.allowed(for: Direction)`.
- **Esquema versionado.** `SchemaV1` (el modelo actual, congelado) y `SchemaV2` (agrega `kind`, `category`, `subcategory` opcionales a `Movement`), con `SchemaMigrationPlan` de etapa liviana. Solo se agregan atributos opcionales: nada se renombra ni se borra.
- `MovementEditor.classify(_:kind:category:subcategory:)`: valida dirección y categoría obligatoria; lanza un error tipado que el editor muestra. Nunca se usa en el camino de captura.
- `ParseApplier`/`ReparseService` no tocan los campos nuevos.
- Resumen del mes: salidas = `expense` + `fixed_expense` + `debt_payment` + por clasificar `outflow`; entradas = `income` + por clasificar `inflow`. Los demás `kind` no suman.
- Lista: filtro "Por clasificar" con su cuenta; badge en la fila.
- Editor: sección "Clasificación" con `kind` filtrado por `direction`, categoría y subcategoría (solo Transporte). "Guardar" deshabilitado si falta la categoría obligatoria.
- CSV: `id` como primera columna, más `kind`, `category`, `subcategory` y `splitGroupId` (vacío hasta la Fase 10). `Tools/TransitionReport` lee por nombre de columna: verificar que sigue leyendo el export nuevo.

**Pruebas automáticas.**
- Migración: un store creado con `SchemaV1` en disco (con nota y adjunto) abre con `SchemaV2`, conserva todo y queda con `kind == nil`. (AC-22)
- `classify` rechaza `expense` sin categoría, `income` en un `outflow` y `expense` en un `inflow`. (AC-23, AC-24)
- Resumen mensual con un movimiento de cada `kind` y uno por clasificar. (AC-25)
- Re-parsear un movimiento clasificado conserva la clasificación.
- CSV golden con `id` y las columnas nuevas. (AC-31, parcial)

**Gate de salida.**
- [ ] Tests verdes.
- [ ] 📱 Actualizar la app sobre los datos reales: abre, no falta ningún movimiento y todos aparecen en "Por clasificar". (AC-22)
- [ ] 📱 Clasificar un gasto, un pasamanos y un ingreso; el resumen cambia como corresponde.
- [ ] 📱 "Exportar ahora" abre en Numbers con las columnas nuevas.

---

## Fase 9 — Reglas y sugerencias

**Objetivo.** Que la mayoría de los movimientos se clasifique con un toque, desde la notificación.

**Alcance.**
- `GastarioParsing/CounterpartyNormalizer`: función pura (solo `Foundation`), probada en Linux con contrapartes reales (Q6).
- `ClassificationRule` en `SchemaV3` (entidad nueva, migración liviana). Unicidad por fetch explícito de `counterpartyKey`, no `@Attribute(.unique)`.
- `GastarioCore/Classification/SuggestionService`:
  - Tarjeta: regla por `counterpartyKey`. Clasificar un movimiento de tarjeta (en el editor, con "Aplicar" o desde la notificación) crea o actualiza la regla.
  - Yappy: sin reglas; sugiere si las últimas 3 clasificaciones de esa contraparte en Yappy coinciden.
- Notificaciones: una `UNNotificationCategory` por combinación de `kind` y categoría, con "Responder" y "✓ <etiqueta>", ninguna con `.foreground`. Se registran todas en `didFinishLaunching`. `NotificationService` busca la sugerencia al programar; si falla o no hay, usa `MOVEMENT_QUESTION` como hoy.
- `AppDelegate`: la acción de sugerencia clasifica vía `MovementEditor.classify` y guarda antes de retornar (mismo patrón que la respuesta, C15 y AC-8).
- Detalle: sugerencia con "Aplicar" cuando el movimiento no tiene `kind`.

**Pruebas automáticas.**
- `CounterpartyNormalizer` con los casos de Q6.
- Regla: clasificar dos veces el mismo comercio distinto → gana la última.
- Sugerencia de tarjeta presente pero el movimiento sigue sin `kind`. (AC-26)
- Yappy: 2 iguales → sin sugerencia; 3 iguales → sugerencia; 3 con una distinta → sin sugerencia. (AC-28)
- Identificador de categoría ↔ (`kind`, categoría) ida y vuelta para todas las combinaciones.

**Gate de salida.**
- [ ] Tests verdes.
- [ ] 📱 AC-26: segunda compra en el mismo comercio llega con el botón de sugerencia.
- [ ] 📱 AC-27: tocar la sugerencia con la app cerrada desde el switcher clasifica sin abrir la app.
- [ ] 📱 "Responder" sigue guardando la nota en una notificación con sugerencia (AC-8).

---

## Fase 10 — Dividir movimientos

**Objetivo.** Repartir un movimiento entre varios `kind`/categorías sin tocar su crudo.

**Alcance.**
- `Allocation` en `SchemaV4` con `deleteRule: .cascade` desde `Movement`.
- `MovementEditor.split(_:into:)`: rechaza si la suma ≠ `amount` o si alguna parte no es válida para la `direction`; al dividir, limpia `kind`/`category` del movimiento. Quitar la división vuelve al estado por clasificar.
- `needsReview` incluye "las partes no suman el monto" (además de `parseStatus != ok`).
- Resumen y filtro "Por clasificar" suman y miran por parte.
- CSV: una fila por parte con su `id`, su monto con signo y `splitGroupId`.
- `Tools/TransitionReport`: si la Fase 7 sigue abierta, agrupar por `splitGroupId` para no contar dos veces un movimiento dividido.
- UI: "Dividir" en el detalle, con el restante por asignar visible.

**Pruebas automáticas.**
- Suma ≠ monto → error; suma exacta con `Decimal` (sin errores de redondeo). (AC-29)
- Re-parseo que cambia el monto → partes intactas y `needsReview`. (AC-30)
- Resumen con un movimiento dividido en `expense` y `reimbursable`. (AC-25)
- CSV golden con un movimiento dividido en 2 filas. (AC-31)
- Borrar un movimiento dividido borra sus partes.

**Gate de salida.**
- [ ] Tests verdes.
- [ ] 📱 Dividir una compra real en dos partes; el resumen y el CSV la reflejan.

---

## Spike S1 — Correos de factura electrónica

**Objetivo.** Saber con correos reales cómo llegan las facturas electrónicas, para decidir si Gastario las puede atrapar con el atajo de correo que ya existe y asignarlas a un movimiento ([`INTENT.md`, v1.1](INTENT.md#v11--facturas-por-correo-candidato)). Es investigación: el entregable es un documento con fixtures y una decisión.

**Punto de partida (ya verificado).**
- El atajo de Yappy corre con **cada** correo, sin filtro en el trigger, y filtra con un `If` dentro del `Repeat` ([`docs/shortcuts.md`](docs/shortcuts.md#yappy-correo)). No hace falta otro trigger: basta una rama `Otherwise`.
- Ya llegó un recibo de comercio junto con un Yappy. Hoy el `If` lo descarta.
- `Content` entrega HTML o texto plano. `HTMLText` (Fase 1) ya convierte HTML a texto sin WebKit.

**Procedimiento** (la persona instala el atajo y copia los correos; el agente analiza).
1. **Inventario retroactivo.** En Mail, buscar `factura`, `CUFE`, `CAFE`, `comprobante`, `dgi-fep` en los últimos 3 meses. Por correo: remitente, dominio, asunto, si lo envía el comercio o un PAC, adjuntos (PDF, XML, ninguno) y si el cuerpo trae total, CUFE, RUC, fecha y link de la DGI.
2. **Censo en el atajo existente**, 2–3 semanas. Va en un **segundo** `Repeat`, después del de Yappy, para que un fallo del diagnóstico nunca impida registrar un Yappy del mismo lote (principio 1):
   ```
   Repeat with each item in Email            ← el de Yappy, sin cambios
      …
   End Repeat
   Repeat with each item in Email            ← diagnóstico, se quita al cerrar S1
      If Repeat Item → Sender does not contain notificaciones@yappy.com.pa
         Append to Text File  iCloud Drive/Gastario-Spike/censo.txt
            "<Date Received> | <Sender> | <Subject> | <Attachments o 'n/a'>"
         If Subject or Content contains factura / CUFE / dgi-fep
            Append to Text File  iCloud Drive/Gastario-Spike/facturas-<fecha>.txt
               "=== <Sender> | <Subject>\n<Content>"
         End If
      End If
   End Repeat
   ```
   - El censo (remitente y asunto de **todo** correo) mide los falsos negativos del filtro por palabras: una factura que no dice "factura" aparece en el censo y no en `facturas-*.txt`.
   - Los archivos quedan en iCloud Drive, nunca en el repo.
   - El trigger no cambia: sigue sin filtro y con "Notificar al ejecutar" desactivado.
3. **Cruce con movimientos.** Para cada factura, buscar el movimiento en Gastario y anotar la diferencia de monto, la de tiempo entre el pago y el correo, y si el nombre de Wallet/Yappy se parece al emisor.

**Preguntas que cierra.**

| # | Pregunta | Impacto en la Fase 11 |
|---|---|---|
| S1.1 | ¿Qué remitentes envían facturas? ¿Pocos PACs o uno por comercio? | Si el detector puede usar remitentes conocidos o depende solo de palabras |
| S1.2 | ¿Qué palabras o patrones distinguen una factura de una promoción? | Reglas de `InvoiceEmailDetector` y su tasa de falsos negativos (contra el censo) |
| S1.3 | ¿`Content` trae CUFE, total, RUC, fecha y link de la DGI en texto? | Si no, el parseo depende del adjunto (S1.4) |
| S1.4 | ¿El `Email` de Atajos expone los adjuntos y se pueden pasar como archivo a un intent? | Si no, el PDF/XML solo entra por la Share Extension de v1.1 |
| S1.5 | ¿El total de la factura coincide con lo cobrado? Propina, pago dividido, consumo parcial | Si el monto exacto falla seguido, casi todo queda como sugerencia |
| S1.6 | Retraso entre el pago y el correo (mediana y máximo) | Ventana de candidatos del matcher |
| S1.7 | ¿El emisor se parece al `counterparty` de Wallet? | Desempate en el matcher; cruza con Q6 (`CounterpartyNormalizer`) |
| S1.8 | ¿Llega la misma factura dos veces, o factura + nota de crédito? | Dedup por CUFE y manejo de notas de crédito |
| S1.9 | ¿Cuántos correos no-Yappy llegan al día? | Costo de invocar el intent con cada uno (ver Fase 11, riesgos) |

**Entregables.**
- `docs/spikes/invoice-emails.md`: inventario (remitentes por dominio, sin direcciones personales), respuestas S1.1–S1.9 y decisión **go / go reducido / no-go**.
- `Packages/GastarioParsing/Tests/GastarioParsingTests/Fixtures/Invoice/`: al menos 5 cuerpos reales de emisores distintos, tal como los recibió el atajo, y 3 no-facturas que mencionan "factura" (promociones, estados de cuenta). Datos personales reemplazados conservando el formato, como en los fixtures de Yappy.

**Criterio de decisión.**
- **Go:** en ≥ 70 % de las facturas recolectadas el cuerpo trae total y CUFE (o el link de la DGI con CUFE), y el detector por palabras no pierde ninguna del censo.
- **Go reducido:** los datos solo vienen en el adjunto y Atajos no lo expone → la Fase 11 se monta sobre la Share Extension de v1.1 (compartir el correo desde Mail), sin captura automática.
- **No-go:** remitentes y formatos demasiado dispersos o solo PDF escaneado. Queda el adjunto manual de la Fase 6.

**Gate de salida.**
- [ ] 📱 Censo corriendo ≥ 2 semanas.
- [ ] Inventario con ≥ 15 facturas de ≥ 5 emisores.
- [ ] Fixtures commiteados y anonimizados.
- [ ] Respuestas y decisión en `docs/spikes/invoice-emails.md`.
- [ ] 📱 Segundo `Repeat` de diagnóstico retirado del atajo.

---

## Fase 11 — Facturas por correo (v1.1, sujeta a S1)

> Hipótesis previa al spike. Lo que S1 contradiga se corrige aquí antes de abrir la fase.

**Objetivo.** Una factura que llega por correo se captura sola, se parsea y queda asignada al movimiento que corresponde, o como sugerencia si no hay certeza. `CaptureService`, `LogCardMovementIntent` y `LogYappyEmailIntent` no cambian (principio 4).

**Alcance.**
- **`GastarioParsing`** (solo `Foundation`, se prueba en Linux):
  - `InvoiceEmailDetector.isCandidate(sender:subject:text:) -> Bool`: generoso a propósito (palabras de S1.2 y remitentes de S1.1). Un falso positivo termina como `failed` en la bandeja; un falso negativo se pierde, por eso se audita (ver "Correos ignorados").
  - `InvoiceEmailParser.parse(sender:subject:content:) -> ParsedInvoice`: `HTMLText` + `TextNormalizer` + `AmountParser`, reglas sacadas de los fixtures de S1. `failed` si no hay ni total ni CUFE; `partial` si falta alguno de emisor, fecha o link.
  - `InvoiceMatcher.candidates(for:among:) -> [MatchCandidate]`: función pura sobre valores simples (monto, fecha, dirección, si ya tiene factura), no sobre `Movement`, para probarla en Linux. Hipótesis (ajustar con S1.5–S1.7):
    - Solo `outflow` de cualquier `source`, sin factura confirmada, con `occurredAt` en `[issuedAt − 2 h, issuedAt + 72 h]` (o `capturedAt` de la factura si no hay `issuedAt`).
    - **Fuerte:** monto exacto. **Débil:** total ≤ monto ≤ total × 1.20 (propina).
    - Auto-asignar solo con **exactamente un** candidato fuerte que ninguna otra factura no bloqueada reclame. Todo lo demás → `suggested`.
    - El emisor solo ordena, no decide.
- **`GastarioCore`**:
  - `Invoice` en el siguiente `SchemaVn` libre (migración liviana; si las Fases 9–10 ya se cerraron, `SchemaV5`):

    | Campo | Tipo | Notas |
    |---|---|---|
    | `id` | UUID | |
    | `rawContent`, `sender`, `subject` | String? | Tal como llegaron |
    | `capturedAt` | Date | |
    | `cufe` | String? | Dedup por fetch explícito, sin `.unique` (misma razón que `confirmation`) |
    | `issuerName`, `issuerRUC` | String? | |
    | `total` | Decimal? | |
    | `issuedAt` | Date? | `America/Panama` |
    | `dgiURL` | URL? | Validado con `AttachmentRules.link` |
    | `parseStatusRaw`, `parseIssuesRaw` | | Mismo patrón que `Movement` |
    | `matchStatusRaw` | String | `unmatched` \| `suggested` \| `autoLinked` \| `confirmed` \| `dismissed` |
    | `matchLocked` | Bool | `true` al confirmar, desasignar o descartar a mano (principio 3) |
    | `movement` | `Movement?` | `deleteRule: .nullify`: borrar el movimiento devuelve la factura a la bandeja |

    `Movement` gana la inversa `invoices` (factura + nota de crédito pueden ser dos).
  - `InvoiceCaptureService`, aparte de `CaptureService` y con su mismo patrón: (1) insertar con crudo y `failed` provisional, guardar; (2–3) parsear y aplicar; dedup por `cufe` **después** de parsear, borrando el recién insertado (como C11); (4) guardar; (5) asignar con `InvoiceMatcher` y guardar; (6) `backup.runIfDue()`. Sin notificación en v1.1. Un fallo del matcher deja la factura `unmatched`, nunca pierde la captura.
  - `InvoiceRematcher.run()`: re-evalúa las `unmatched`/`suggested` no bloqueadas. Corre al volver la app a `.active` (el mismo punto que el respaldo) y desde Ajustes. Cubre la factura que llegó antes que el movimiento o el movimiento manual creado después.
  - CSV: columna `invoiceCUFE` (la del primer `confirmed`/`autoLinked`), después de las de la Fase 8. Golden test actualizado; `Tools/TransitionReport` lee por nombre y no se ve afectado.
- **App**:
  - `LogInvoiceEmailIntent` ("Log Invoice Email"): parámetros `sender`, `subject`, `content`, todos opcionales (regla de la Fase 2). Si `InvoiceEmailDetector` dice que no es factura → **no guarda nada** y registra en "Correos ignorados". Devuelve `.result()` siempre que el store responda.
  - **Correos ignorados:** los últimos 200 (fecha, remitente, asunto; sin cuerpo) en `UserDefaults` del App Group, visibles en Ajustes. Sirve para encontrar facturas que el detector se perdió y alimentar fixtures.
  - Bandeja "Facturas sin asignar" (`unmatched` + `suggested`, y `failed` de parseo) con contador en la lista. Cada sugerencia: confirmar, elegir otro movimiento o descartar.
  - Detalle del movimiento: facturas asignadas dentro de la sección de adjuntos; el link de la DGI abre con `SafariView` (C14); botón "Desasignar". Una factura asignada **no** se copia como `Attachment`: vive en `Invoice` para poder desasignarla sin perder nada.
- **Atajo** (`docs/shortcuts.md`), rama nueva en el `If` existente:
  ```
  Repeat with each item in Email
     If Repeat Item → Sender is notificaciones@yappy.com.pa
        …                                    ← sin cambios
     Otherwise
        Log Invoice Email (Sender, Subject, Content)
     End If
  End Repeat
  ```

**Fuera de alcance.** Leer el PDF o el XML (depende de S1.4; con go reducido entra con la Share Extension). Notificar facturas. Usar el RUC como clave de `ClassificationRule` (más estable que el `counterparty` de Wallet; candidato después de la Fase 9).

**Criterios de aceptación propuestos** (pasan a `INTENT.md` cuando S1 dé go):

| # | Criterio |
|---|---|
| AC-F1 | Factura con total igual a un único pago de salida en la ventana → `autoLinked` a ese movimiento. |
| AC-F2 | Dos pagos del mismo monto en la ventana → `suggested` con ambos; no se asigna sola. |
| AC-F3 | Factura sin movimiento que calce → `unmatched`. Creo después el movimiento a mano y vuelvo a la app → pasa a `autoLinked` o `suggested`. |
| AC-F4 | Mismo CUFE dos veces → una sola factura. |
| AC-F5 | Factura que no parsea → se guarda con `rawContent` y `failed`, visible en la bandeja. |
| AC-F6 | Desasigno una factura auto-asignada → el rematcher no la vuelve a asignar. |
| AC-F7 | Borro un movimiento con factura → la factura vuelve a la bandeja. |
| AC-F8 | Pago con propina (monto > total, ≤ 20 %) → sugerencia, no auto-asignación. |
| AC-F9 | Un correo que no es factura no deja nada en el store y aparece en "Correos ignorados". Un Yappy del mismo lote entra igual. |

**Pruebas automáticas.**
- Linux: `InvoiceEmailDetector` con los fixtures de S1 (facturas y no-facturas); `InvoiceEmailParser` por fixture; `InvoiceMatcher` con tabla: exacto único, exacto duplicado, propina, fuera de ventana, `inflow` ignorado, movimiento con factura confirmada ignorado, otra factura reclamando el mismo movimiento.
- macOS (`@MainActor`): `InvoiceCaptureService` con container en memoria: crudo guardado antes de parsear (parser que lanza), dedup por CUFE, matcher que lanza → `unmatched`; `InvoiceRematcher` respeta `matchLocked`; borrar un movimiento deja la factura con `movement == nil`; migración desde el esquema anterior con datos.

**Gate de salida.**
- [ ] Tests verdes.
- [ ] Diff vacío en `CaptureService`, `LogCardMovementIntent` y `LogYappyEmailIntent`.
- [ ] 📱 Una compra real con factura por correo queda asignada sin abrir la app.
- [ ] 📱 AC-F2, AC-F6, AC-F7 y AC-F9 en el dispositivo.
- [ ] 📱 Una semana sin facturas perdidas: cada factura del inventario de Mail del período está en Gastario o en "Correos ignorados" (y entonces se corrige el detector).

**Riesgos.**
- **Costo de correr el intent con cada correo** (S1.9): lanza el proceso en segundo plano por cada correo no-Yappy. Si en el dispositivo se nota en batería o en retraso del Yappy, se agrega un prefiltro por asunto en el atajo, aceptando que esa parte del filtro vuelve a Atajos.
- Totales con ITBMS, redondeos o cargo por servicio pueden romper el "monto exacto"; S1.5 lo mide antes de fijar la regla.

---

## 4. Trazabilidad AC → Fase

| AC | Descripción corta | Prueba automática | Verificación 📱 |
|---|---|---|---|
| 1 | Captura de tarjeta + notificación | F2 | F3 |
| 2 | Montos con formato | F1 | — |
| 3 | Yappy enviado completo | F1 | F2 |
| 4 | Yappy sin mensaje | F1 | — |
| 5 | Dos correos a la vez | F2 | F2 |
| 6 | Duplicado, nota intacta | F2 | F3 |
| 7 | Parseo fallido | F1, F2 | F3 |
| 8 | Responder después, app terminada | F3 (handler) | F3 |
| 9 | Sin nota tras descartar | — | F4 |
| 10 | Sin ubicación | F2 | — |
| 11 | Exportar abre en Numbers | F5 (golden) | F5 |
| 12 | Tarjeta con datos vacíos | F1, F2 | F3 |
| 13 | Resolver parcial | F4 | F4 |
| 14 | Entrada manual | — | F4 |
| 15 | Borrar con adjuntos | F0 (cascade) | F4, F6 |
| 16 | Fecha con NBSP | F1 | — |
| 17 | Re-parsear todo | F4 | — |
| 18 | Edición protegida | F4 | F4 |
| 19 | Adjunto persistente | — | F6 |
| 20 | QR de factura | F6 (validación) | F6 |
| 21 | Auto-export sin abrir la app | F5 (policy) | F5 |
| 22 | Por clasificar | F8 (migración) | F8 |
| 23 | Gasto sin categoría | F8 | — |
| 24 | Tipo y dirección | F8 | — |
| 25 | Totales por `kind` | F8, F10 | F8 |
| 26 | Sugerencia, nunca silenciosa | F9 | F9 |
| 27 | Clasificar desde la notificación | — | F9 |
| 28 | Yappy sin regla | F9 | — |
| 29 | División que no suma | F10 | — |
| 30 | Re-parseo con división | F10 | — |
| 31 | Export v2 | F8, F10 (golden) | F8, F10 |

## 5. Preguntas abiertas (bloquean la fase indicada)

| # | Pregunta | Bloquea |
|---|---|---|
| Q1 | ~~Bundle id y Team ID para el App Group y el ubiquity container.~~ **Resuelta:** `com.renandiaz.Gastario`, App Group `group.com.renandiaz.Gastario`. El Team ID va en `Configs/Local.xcconfig`, fuera de git. | F0 |
| Q2 | ~~Tres cuerpos reales de correo Yappy (enviado con mensaje, sin mensaje, recibido), copiados desde Mail.~~ **Resuelta:** recibidos en HTML (lo que entrega `Content`), más pago a comercio y Yappy Comercial en texto. Ver C10. | Gate F1 |
| Q3 | ~~Formato exacto del `Amount` que entrega el trigger de Wallet hoy (revisar el CSV viejo: ¿`3.80`, `$3.80`, `B/.3.80`?).~~ **Resuelta:** `$46.55` (con `$` y punto decimal), visto en "Datos recibidos" de una compra real con Apple Pay. `AmountParser` ya lo cubría; queda una prueba con ese formato. | F1 (fixtures), F2 |
| Q4 | ~~Confirmar C1–C9 o indicar cuáles cambian.~~ **Resuelta:** confirmados. | F0 (C1, C2), F5, F6 |
| Q5 | ~~¿La lista muestra montos de `partial` con `amount = 0` como `$0.00` o como "—"?~~ **Resuelta:** "—" con el badge de revisión. | F0 |
| Q6 | Entre 5 y 10 `counterparty` crudos de tarjeta, tal como llegan (con prefijos, sucursales, mayúsculas), para fijar las reglas de `CounterpartyNormalizer`. | F9 |
| Q7 | ¿Las facturas llegan a una cuenta de correo configurada en Mail del iPhone? El trigger solo ve esas cuentas. | S1 |
| Q8 | ¿Se acepta que una factura se asigne sola sin avisar (AC-F1)? Default: sí, solo con candidato único y monto exacto; se puede desasignar. | F11 |
