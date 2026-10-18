# Marca

Ícono "Renglón": una página con la primera línea escrita. Es lo que hace la app: cada pago queda anotado en una línea.

## Paleta

| Color | Hex | Uso |
|---|---|---|
| Azul tinta | `#3B5B8A` | Fondo (clara); renglón escrito (oscura) |
| Papel | `#F2F0E9` | Página |
| Tinta | `#1B2A44` | Renglón escrito (clara); texto del lockup |
| Fondo oscuro | `#14181F` | Fondo (oscura) |

## Archivos

| Archivo | Para qué |
|---|---|
| `clara.svg`, `oscura.svg`, `tintada.svg` | Ícono completo, 1024×1024, por apariencia |
| `capas-clara/`, `capas-oscura/` | Capas para Icon Composer: `0-fondo` (Background), `1-pagina`, `2-trazos` |
| `lockup-gastario.svg`, `lockup-gastario-oscuro.svg` | Ícono + nombre, para el README |

La app usa los PNG de [`Gastario/Assets.xcassets/AppIcon.appiconset`](../../Gastario/Assets.xcassets/AppIcon.appiconset), exportados desde estos SVG, en RGB y sin canal alfa (App Store rechaza íconos con alfa). Si cambia un SVG, vuelve a exportar su PNG.

## Pendiente

- **Icon Composer.** Con las capas se puede armar un `.icon` de iOS 26 para que el sistema aplique el vidrio por capa. Se hace en la Mac; luego el `.icon` reemplaza al `AppIcon.appiconset` (`ASSETCATALOG_COMPILER_APPICON_NAME` en `project.yml` toma el nombre del archivo).
- **Lockup.** El texto usa DM Sans sin incrustar; donde no está instalada, se ve con la fuente del sistema. Para fijarla, convierte el texto a trazos.
