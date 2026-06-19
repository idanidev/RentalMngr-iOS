# Mac Catalyst — estado y plan (para retomar en sesión nueva)

## Estado actual
- ✅ **Mac Catalyst habilitado** en el target (`SUPPORTS_MACCATALYST = YES`,
  `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO` en `RentalMngr.xcodeproj/project.pbxproj`).
- ✅ **Compila y arranca** como app Mac nativa (binario arm64 maccatalyst).
- ✅ `MainTabView` ya usa `.tabViewStyle(.sidebarAdaptable)` → en Mac sale sidebar.

## Bug a resolver (PRIORIDAD)
En Mac, tras hacer login correctamente, **`fetchProperties()` devuelve vacío** →
la app cree que el usuario es nuevo y muestra el wizard "Crea tu primera propiedad".
Además **no recuerda la sesión** entre lanzamientos (pide login cada vez).

### Diagnóstico
La sesión de auth **no se propaga a las consultas** en Catalyst:
- Las queries REST van sin el token → RLS de Supabase devuelve 0 filas → "sin propiedades".
- La sesión no persiste en el Keychain de Catalyst → no recuerda la cuenta.

### Causa probable
SDK `supabase-swift` usa `KeychainLocalStorage` por defecto. En Mac Catalyst el
Keychain requiere el **entitlement Keychain Sharing** (o un `keychain-access-group`
válido); sin él, guardar/leer la sesión falla silenciosamente.

### Plan de fix (orden)
1. **Añadir Keychain Sharing** al target (entitlements):
   - Crear/editar `RentalMngr.entitlements` con
     `keychain-access-groups` = `$(AppIdentifierPrefix)idanidev.RentalMngr`
   - Referenciarlo con `CODE_SIGN_ENTITLEMENTS` en el pbxproj (ambas configs).
2. **Network client entitlement** (Catalyst es sandbox):
   - `com.apple.security.network.client = YES` (si no está, las peticiones salientes fallan;
     aunque el login funcionó, confirmarlo).
3. Si el Keychain sigue dando guerra, **configurar storage custom** del SDK:
   - Pasar `auth: .init(storage: <UserDefaultsLocalStorage>)` en `SupabaseService.swift`
     para Catalyst (`#if targetEnvironment(macCatalyst)`).
4. Rebuild Catalyst, login, verificar que **carga propiedades** y **recuerda sesión**
   al relanzar.

### Comandos útiles
```bash
cd /Volumes/SSDani/XcodeWorkspace/RentalMngr-iOS/RentalMngr
# Build Catalyst
xcodebuild build -scheme RentalMngr \
  -destination 'platform=macOS,variant=Mac Catalyst,name=My Mac' \
  -derivedDataPath /Volumes/SSDani/Xcode_DerivedData_Cat
# Lanzar
open /Volumes/SSDani/Xcode_DerivedData_Cat/Build/Products/Debug-maccatalyst/RentalMngr.app
```

## Después del fix
- Hacer la UI "mega responsive": `minWidth/minHeight` de ventana, limitar ancho máximo
  de formularios/listas en ventanas anchas, revisar el sidebar en Mac.
- Probar: escáner de documentos (VisionKit no hay cámara en Mac → debe ocultarse,
  ya protegido con `isSupported`), háptica (no-op en Mac).
