# Gastario

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/marca/lockup-gastario-oscuro.svg">
  <img src="docs/marca/lockup-gastario.svg" alt="Gastario" height="64">
</picture>

App iOS que registra cada pago con Apple Pay y cada Yappy, y permite anotar en qué fue cada movimiento respondiendo desde la notificación.

> **Documentos del proyecto.** El qué y el porqué están en [`INTENT.md`](INTENT.md); el cómo y el orden, en [`SPEC.md`](SPEC.md). Este README solo explica cómo compilar y verificar. Si contradice al spec, gana el spec.

## Estado

| Fase | Estado |
|---|---|
| 0. Fundación | Cerrada |
| 1. Parsers | Cerrada |
| 2. Captura ([`docs/shortcuts.md`](docs/shortcuts.md)) | Implementada. 📱 Verificado: una compra con Apple Pay quedó guardada con monto, comercio, tarjeta y ubicación. Faltan el resto de las verificaciones 📱 del gate |
| 3. Notificaciones | Implementada. 📱 Verificado: AC-8 (responder con la app cerrada guarda la nota). Falta: AC-1 con un pago, AC-7/12, que un duplicado no notifique y tocar la notificación (C15) |
| 4. Revisión y edición | Implementada. Fixtures comparados con un cuerpo crudo real. 📱 Verificado: borrar. Falta: AC-9, AC-13, AC-14, AC-18 |
| 5. Exportar y respaldo (iCloud Drive) | Implementada. 📱 Verificado: AC-11 ("Exportar ahora" abre en Numbers). Falta: AC-21 (auto-export, requiere cuenta pagada) y export fallido |
| 6. Adjuntos (foto, PDF, link, QR de factura) | Implementada. 📱 Verificado: QR, PDF, foto y borrar un adjunto. Falta: AC-19 (PDF de 5 MB tras reabrir), AC-15 completo y captura durante el flujo de adjuntar |
| 7. Transición | En curso: período en paralelo. Herramienta de comparación lista ([cómo usarla](#transición-fase-7)) |
| 8. Tipo y categoría (v2) | Especificada ([`SPEC.md`](SPEC.md#fase-8--tipo-y-categoría)). Sigue después de la Fase 7 o en paralelo |
| 9. Reglas y sugerencias (v2) | Especificada. Bloqueada por Q6 |
| 10. Dividir movimientos (v2) | Especificada |

Pregunta abierta: [Q6](SPEC.md#5-preguntas-abiertas-bloquean-la-fase-indicada) (contrapartes reales de tarjeta, bloquea la Fase 9). Detalle de cada fase en el [mapa de fases](SPEC.md#mapa-de-fases).

## Requisitos

| | Versión |
|---|---|
| Mac de build | Xcode 26 o posterior (Swift 6) |
| App | iOS 26+ (iPhone); deployment target en [`SPEC.md` §2, C12](SPEC.md#2-cambios-propuestos-a-intentmd) |
| Cuenta de Apple | Developer pagada: iCloud Documents no está disponible con una cuenta gratis, y la firma gratis vence a los 7 días |
| Herramientas | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) |

## Primeros pasos

```bash
# 1. Team ID para firmar (archivo local, fuera de git)
cp Configs/Local.xcconfig.example Configs/Local.xcconfig
#    edita DEVELOPMENT_TEAM con tu Team ID

# 2. Generar el proyecto
xcodegen generate
open Gastario.xcodeproj
```

Con el Team ID puesto y firma automática, Xcode registra el App Group `group.com.renandiaz.Gastario` la primera vez que compilas en el iPhone. En la consola de Xcode, el arranque imprime la ruta del store: debe contener `Shared/AppGroup`.

Lo mismo pasa con el contenedor de iCloud `iCloud.com.renandiaz.Gastario`, que usa el respaldo. **Con un equipo personal (cuenta gratis)** Xcode no puede firmar: "Personal development teams … do not support the iCloud capability". Mientras tanto, descomenta `GASTARIO_ENTITLEMENTS` en tu `Configs/Local.xcconfig` (ver `Local.xcconfig.example`): la app firma sin iCloud, el respaldo automático queda deshabilitado y "Exportar ahora" sigue ofreciendo el CSV para compartir. Si la carpeta "Gastario" no aparece en Archivos → iCloud Drive después del primer export, sube `CURRENT_PROJECT_VERSION` en `Configs/Base.xcconfig` y reinstala: iOS solo vuelve a leer `NSUbiquitousContainers` cuando cambia el número de build.

Vuelve a correr `xcodegen generate` cada vez que agregues o quites archivos o cambies `project.yml`.

## Transición (Fase 7)

Al final del período en paralelo, compara el export de Gastario con los dos CSVs viejos ([`SPEC.md`, Fase 7](SPEC.md#fase-7--transición-operativa)). En la Mac:

```bash
swift run --package-path Tools/TransitionReport transition-report \
  --gastario Gastario.csv --tarjeta pagos_con_tarjeta.csv --yappy yappy_each.csv \
  --desde 2026-10-16 > /tmp/comparacion.md
```

- `Gastario.csv` sale de "Exportar ahora" en Ajustes. Los otros dos son los CSVs que escriben los atajos viejos.
- `--desde` es el **primer día completo** en paralelo. Sin `--desde`, empieza el primer día con capturas en Gastario, y lo que el CSV viejo tenga ese día antes de instalar sale como perdido. `--hasta` es opcional.
- Exporta al final del día: lo que entre en los CSVs viejos después del export sale como perdido en Gastario.
- La salida es Markdown: conteos y sumas por día, discrepancias fila por fila con una pista de clase y las filas del CSV viejo de Yappy que no son movimientos. Va a `docs/transition-report.md`, completando la columna *Clase*.
- Los CSVs tienen datos personales: no los subas al repo.

## Verificación

```bash
scripts/verify.sh
```

Es lo mismo que corre CI (GitHub Actions, en cada push a `main`, `claude/**` y `phase-*`, y en cada PR):

| Job | Runner | Qué verifica |
|---|---|---|
| `linux` | `swift:6.4.1-noble` | `GastarioParsing` solo importa `Foundation`; `swift test` de `GastarioParsing` y de `Tools/TransitionReport` |
| `macos` | `macos-26` | Lo anterior + `swift test` de `GastarioCore` + build de la app en Debug y Release, sin firmar |

Si falta `project.yml` o alguno de los paquetes, `verify.sh` falla: no omite nada.

### Sesiones de Claude Code en la nube

[`.claude/hooks/session-start.sh`](.claude/hooks/session-start.sh) instala Swift para Linux al iniciar la sesión, así el agente puede correr `verify.sh` (la parte de Linux). Necesita que la política de red del environment permita `download.swift.org`; si no, avisa y la sesión sigue sin Swift.

## Estructura

```
gastario/
├── INTENT.md, SPEC.md       # qué y por qué / cómo y en qué orden
├── project.yml              # XcodeGen: fuente de verdad del proyecto
├── Configs/                 # xcconfig y entitlements (con y sin iCloud); Local.xcconfig fuera de git
├── Gastario/                # target iOS
│   ├── Assets.xcassets/     # ícono de la app (clara, oscura, tintada)
│   ├── App/                 # arranque, AppDelegate, contenedor SwiftData en el App Group
│   ├── Intents/             # App Intents de captura (tarjeta y Yappy)
│   ├── Notifications/       # notificaciones con respuesta
│   ├── Movements/           # lista, detalle, edición y entrada manual
│   ├── Export/              # respaldo semanal del CSV en iCloud Drive
│   ├── Attachments/         # adjuntos: foto, PDF, link y QR
│   ├── Settings/
│   └── Debug/
├── Packages/
│   ├── GastarioParsing/     # parsers puros, solo Foundation, probados también en Linux
│   └── GastarioCore/        # SwiftData y servicios, solo plataformas Apple
├── Tools/
│   └── TransitionReport/    # Fase 7: compara el export con los CSVs viejos (Mac y Linux)
├── docs/
│   ├── shortcuts.md         # cómo configurar los atajos de captura
│   └── marca/               # ícono y lockup en SVG, capas para Icon Composer
├── scripts/verify.sh
├── .github/workflows/ci.yml # jobs linux y macos
└── .claude/                 # hook de inicio para sesiones en la nube
```

Detalle en [`SPEC.md` §3](SPEC.md#3-arquitectura-y-convenciones-aplican-a-todas-las-fases).
