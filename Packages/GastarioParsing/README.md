# GastarioParsing

Parsers puros de Gastario: texto de entrada → campos de un movimiento. Solo importa `Foundation` y se prueba en macOS y Linux ([`SPEC.md` Fase 1](../../SPEC.md#fase-1--parsers-puros)).

```bash
swift test --package-path Packages/GastarioParsing
```

Los fixtures de Yappy están en `Tests/GastarioParsingTests/Fixtures/Yappy/`. Son cuerpos reales con los datos personales reemplazados (nombres, teléfonos, confirmaciones). Los derivados sintéticos llevan `SYNTHETIC` en el nombre del test.
