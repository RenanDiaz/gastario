# GastarioCore

Modelos SwiftData (`Movement`, `Attachment`), el store en el App Group y la lógica de presentación que se puede probar sin UI. Depende de `GastarioParsing` y reexporta sus tipos (`Direction`, `ParseStatus`, `ParseIssue`…).

Usa SwiftData, así que solo compila en plataformas Apple ([`SPEC.md` §3](../../SPEC.md#entorno-y-verificación)):

```bash
swift test --package-path Packages/GastarioCore
```
