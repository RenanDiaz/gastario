# CLAUDE.md

## Idioma

El idioma del proyecto es el español:

- documentación (`INTENT.md`, `SPEC.md`, `README.md`, este archivo);
- comentarios y doc comments del código;
- scripts y CI: comentarios y mensajes;
- mensajes de commit, nombres de rama, títulos y descripciones de PR, y checklists.

Los identificadores (tipos, funciones, variables) van en inglés, como ya los define `INTENT.md` (`Movement`, `parseStatus`, `CaptureService`).

## Documentos

- `INTENT.md` manda sobre `SPEC.md`, y `SPEC.md` manda sobre el código y `README.md`. Excepción: los **Cambios propuestos** de `SPEC.md` §2, una vez confirmados.
- `README.md` explica cómo compilar, instalar, usar y verificar. No copia el spec: enlaza a sus secciones.
- Una fase = un PR. El PR enlaza la sección de la fase y marca el checklist del gate. Las verificaciones 📱 las hace la persona: déjalas sin marcar y lista qué falta probar.

## Antes de abrir un PR

Todo PR (de fase o no) revisa `README.md` y actualiza en el mismo PR lo que su cambio dejó desactualizado:

- **Estado** (fases cerradas, en curso y qué sigue; preguntas y cambios propuestos pendientes);
- **Requisitos** (iOS, Xcode, Swift);
- **Primeros pasos**, si cambió la instalación o la configuración local;
- **Verificación**, si `scripts/verify.sh` o CI hacen algo nuevo;
- **Estructura**, si se agregaron o movieron carpetas o paquetes;
- los enlaces a secciones del spec (`SPEC.md#…`), si se renumeraron o renombraron.

La descripción del PR dice qué cambió en el README o, si nada, "README: sin cambios".

## Proyecto y verificación

- El `.xcodeproj` **no se versiona**: se genera con `xcodegen generate` desde `project.yml`. Targets, capabilities (App Groups, iCloud) y entitlements se cambian en `project.yml`, nunca en el `pbxproj`.
- Antes de hacer push, corre `scripts/verify.sh`. Es lo mismo que corre CI.
- **En la nube (Linux)** solo existe Swift para Linux: `verify.sh` prueba `GastarioParsing` y nada más. `GastarioCore` (SwiftData) y la app solo se verifican en macOS; para eso está el job `macos` de CI. No declares verde lo que no pudiste correr: di qué verificó Linux y qué queda para CI.
- `GastarioParsing` solo importa `Foundation`. `verify.sh` lo hace cumplir.
