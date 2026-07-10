# RentalMngr — instrucciones de proyecto

App de gestión de alquileres. Swift 6 + SwiftUI + Supabase. Targets: iPhone, iPad y
**Mac Catalyst** (binario nativo `arm64-maccatalyst`).

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
- **Tarjetas consistentes** (foto y sin-foto idénticas), pulsables en toda su área, con cursor de puntero.
- **Hojas modales siempre cerrables** en Mac (botón Done/Cerrar; no hay swipe-to-dismiss).

## Build / run (Mac Catalyst)

```
xcodebuild build -project RentalMngr.xcodeproj -scheme RentalMngr \
  -destination 'platform=macOS,variant=Mac Catalyst,name=My Mac' \
  -derivedDataPath /Volumes/SSDani/Xcode_DerivedData_Cat
open /Volumes/SSDani/Xcode_DerivedData_Cat/Build/Products/Debug-maccatalyst/RentalMngr.app
```

(Usar `-project` con ruta absoluta: las tareas en background pueden arrancar fuera del repo.)

## Convenciones

- SwiftUI sobre UIKit. `@Observable` (no `ObservableObject`). `@MainActor` en ViewModels. Swift 6 strict concurrency.
- Tests con Swift Testing (no XCTest).
- Sesión Catalyst: el storage de auth usa `UserDefaultsLocalStorage` (el Keychain del SDK
  falla en Catalyst). Ver `Core/Services/SupabaseService.swift`.
- Commits solo cuando se pidan explícitamente.
