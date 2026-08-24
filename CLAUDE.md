# RentalMngr — instrucciones de proyecto

App de gestión de alquileres **por habitaciones** (y, desde ago-2026, también de
viviendas enteras). Swift 6 + SwiftUI + Supabase. Targets: iPhone, iPad y
**Mac Catalyst** (binario nativo `arm64-maccatalyst`).

## Producción: leer antes de tocar la base de datos

**No hay staging.** Un único proyecto de Supabase, plan Free (sin backups
automáticos), con dos años de datos reales y PII de inquilinos.

**[docs/SQL_RULES.md](docs/SQL_RULES.md) es de lectura obligatoria** antes de
escribir una sola línea de SQL. Resumen:

- Claude tiene la base en **solo lectura** (MCP con `--read-only`). Escribe la
  migración en `supabase/migrations/` y **la ejecuta el usuario**. Esa
  separación es deliberada.
- Nada de `DROP`, `TRUNCATE`, ni `DELETE`/`UPDATE` sin `WHERE`.
- Antes de borrar cualquier cosa importante, **preguntar otra vez**.

## Diseño (OBLIGATORIO leer antes de tocar UI)

Antes de crear o modificar cualquier vista, aplica la guía de diseño Mac/iPad:
**[docs/MAC_DESIGN.md](docs/MAC_DESIGN.md)**. No improvises layouts; sigue su escala,
gutters, tarjetas, estados y reglas de macOS HIG. Usa su checklist (§9) antes de dar
una pantalla por buena.

Principios no negociables:
- **iPhone intacto.** Las mejoras de pantalla grande van bajo `horizontalSizeClass == .regular`;
  lo cosmético de ventana/Catalyst bajo `#if targetEnvironment(macCatalyst)`.
- **Un único gutter por pantalla** (regular 20 / compact 16): hero, headers, grids y listas alineados.
- **Llenar el ancho** con rejillas multi-columna adaptativas; nunca columna estrecha con huecos
  ni contenido estirado a una sola columna.
- **Tarjetas consistentes en rejilla** (iPad/Mac): foto y sin-foto con el mismo alto, o la
  cuadrícula queda dentada. En iPhone van en columna, así que una tarjeta sin foto **sí** se
  encoge para no desperdiciar espacio.
- **Hojas modales siempre cerrables** en Mac (botón Done/Cerrar; no hay swipe-to-dismiss).

## Build / run

```
# Mac Catalyst
xcodebuild build -project RentalMngr.xcodeproj -scheme RentalMngr \
  -destination 'platform=macOS,variant=Mac Catalyst,name=My Mac' \
  -derivedDataPath /Volumes/SSDani/Xcode_DerivedData_Cat
open /Volumes/SSDani/Xcode_DerivedData_Cat/Build/Products/Debug-maccatalyst/RentalMngr.app

# iOS (usar 'generic/platform=iOS': con -destination 'id=…' xcodebuild se cuelga
# esperando al dispositivo)
xcodebuild build -project RentalMngr.xcodeproj -scheme RentalMngr \
  -destination 'generic/platform=iOS' -derivedDataPath /Volumes/SSDani/Xcode_DerivedData_iOS \
  -allowProvisioningUpdates
xcrun devicectl device install app --device <UDID> \
  /Volumes/SSDani/Xcode_DerivedData_iOS/Build/Products/Debug-iphoneos/RentalMngr.app
```

(Usar `-project` con ruta absoluta: las tareas en background pueden arrancar fuera del repo.)

**Compila SIEMPRE las dos plataformas.** El código bajo `#if !targetEnvironment(macCatalyst)`
no lo ve el build de Catalyst: un `import` que falte solo aparece en el de iOS.

## Convenciones

- SwiftUI sobre UIKit. `@Observable` (no `ObservableObject`). `@MainActor` en ViewModels. Swift 6 strict concurrency.
- Tests con Swift Testing (no XCTest).
- Sesión Catalyst: el storage de auth usa `UserDefaults`. El Keychain del SDK falla
  ahí (`errSecMissingEntitlement`) y, al fallar el guardado, las peticiones salían
  **sin token**: con RLS activa eso son cero filas y una app que parece vacía.
  Ver `Core/Services/SupabaseService.swift`.
- Commits solo cuando se pidan explícitamente.

## Trampas que ya nos han mordido

- **Dinero**: parsear con el locale del dispositivo lee `"600,50"` como `60050` en un
  iPhone en inglés. Todo importe entra por `Decimal.fromUserInput`, nunca por
  `Decimal(string:)`. Cubierto por tests.
- **Errores en silencio**: un `try?` o un `catch` que solo loguea hace que un fallo de
  RLS parezca "no hay datos". Todo error de usuario acaba en `safeUserMessage` y en una
  alerta visible.
- **Límites de plan**: se aplican con triggers en la base. En Swift solo la UI que
  enseña el paywall antes; ahí son decorativos.
- **Fotos**: los buckets no tienen transformación de imagen (es de plan Pro). Cada foto
  sube con una miniatura hermana `thumb_` (~50 KB) y las listas piden esa. Las URLs se
  firman **por lotes** al abrir la pantalla, no una a una.
- **Enums del servidor**: decodificar sin caso de reserva hace que **una** fila
  desconocida tire la lista entera.
