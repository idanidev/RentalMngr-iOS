# RentalMngr — App Store Release Checklist

## 0. Estado actual del código

- StoreKit 2 integrado (`Core/Services/PurchaseManager.swift`).
- Producto IAP esperado: **`idanidev.RentalMngr.premium.monthly`** — debe coincidir EXACTO en App Store Connect.
- Backend: Supabase migration `20260507000001_apply_premium_purchase.sql` — ejecutar antes de release.
- Local testing: `RentalMngrPremium.storekit` (Edit Scheme → Run → Options → StoreKit Configuration).

## 1. Apple Developer Program

- Cuenta activa (99 USD/año).
- Team ID disponible en developer.apple.com → Membership.

## 2. Identificadores y certificados

1. **App ID** → Certificates, Identifiers & Profiles → Identifiers → `+`:
   - Bundle ID: `idanidev.RentalMngr` (ya en el `.xcodeproj`)
   - Capabilities: Push Notifications (futuro), In-App Purchase, Sign in with Apple (si aplica)
2. **Distribution certificate** (Apple Distribution).
3. **Provisioning profile** App Store para `idanidev.RentalMngr`.

Si Xcode tiene "Automatically manage signing" → todo lo anterior se genera solo.

## 3. App Store Connect — crear app

1. App Store Connect → My Apps → `+` New App.
2. Datos:
   - Name: **RentalMngr**
   - Primary language: **Spanish (Spain)**
   - Bundle ID: `idanidev.RentalMngr`
   - SKU: `rentalmngr-ios` (libre)
   - User Access: Full
3. App Information:
   - Category: Business / Finance
   - Content rights: confirma derechos
   - Age rating: 4+

## 4. Crear producto IAP — CRÍTICO

App Store Connect → tu app → **Subscriptions** (sidebar) → New Subscription Group:

- Group: `RentalMngr Premium`
- Subscription:
  - Reference Name: `Premium Monthly`
  - **Product ID: `idanidev.RentalMngr.premium.monthly`** (EXACTO — el código lo busca por este id)
  - Subscription Duration: 1 Month
  - Price: 5,99 € (Tier 6 en España)
  - Localizations es-ES:
    - Display Name: `Premium Mensual`
    - Description: `Acceso ilimitado a propiedades, habitaciones, contratos PDF y todas las funciones avanzadas.`
  - Review Information: pantalla del paywall (screenshot) + notas
- Submit subscription for review (junto con la build).

## 5. App Privacy

App Store Connect → App Privacy:
- Data collected:
  - Email Address (Account, linked to identity)
  - Name (Account, linked to identity)
  - User Content: Photos (linked, app functionality)
  - Identifiers: User ID (linked, app functionality, analytics)
- **Privacy Policy URL: obligatoria.** Sirve un HTML público (GitHub Pages o un .md en Supabase Storage). Ejemplo mínimo:
  - Qué se recoge (email, perfil, datos de propiedad/inquilinos)
  - Procesador (Supabase, Apple para pagos)
  - Retención y borrado (botón Delete Account ya implementado)
  - Contacto: idanideveloper@gmail.com

## 6. Pricing & Availability

- Free (la app es gratis; el premium es IAP).
- Disponibilidad: España + resto.

## 7. Screenshots requeridos

Mínimo 1 set por tamaño:
- iPhone 6.9" (15/16/17 Pro Max) — 1320 × 2868
- iPhone 6.5" (XS Max) — 1242 × 2688
- iPhone 5.5" (8 Plus) — 1242 × 2208 (requerido por Apple)
- iPad 12.9" (Pro 6th gen) — 2048 × 2732

5 screenshots por tamaño. Recomendado:
1. Dashboard
2. Lista propiedades
3. Detalle propiedad (habitaciones)
4. Inquilinos / contrato
5. Paywall premium

Generación: simulador iPhone → toma capturas (`Cmd+S`) y redimensiona, o usa el script Python que mencionaste.

## 8. Build y archive

```bash
cd /Volumes/SSDani/XcodeWorkspace/RentalMngr-iOS/RentalMngr

# 1. Asegúrate que el scheme está configurado para Release
# 2. Bumpea version + build en RentalMngr.xcodeproj
#    Marketing Version: 1.0.0
#    Current Project Version: 1

# 3. Archive
xcodebuild -scheme RentalMngr \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath ./build/RentalMngr.xcarchive \
  clean archive
```

## 9. Subir build con API Key (.p8)

Necesitas:
- `AuthKey_XXXXXXXX.p8` (la que tienes en Downloads)
- Issuer ID (App Store Connect → Users and Access → Keys → arriba)
- Key ID (mismo lugar)

```bash
# Mover la key a la ubicación esperada por altool/notarytool
mkdir -p ~/.appstoreconnect/private_keys
cp ~/Downloads/AuthKey_XXXXXXXX.p8 ~/.appstoreconnect/private_keys/

# Exportar IPA desde el archive
xcodebuild -exportArchive \
  -archivePath ./build/RentalMngr.xcarchive \
  -exportOptionsPlist ./ExportOptions.plist \
  -exportPath ./build/ipa

# Upload con xcrun altool
xcrun altool --upload-app \
  --type ios \
  --file ./build/ipa/RentalMngr.ipa \
  --apiKey XXXXXXXX \
  --apiIssuer YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY
```

## 10. Submit for review

App Store Connect → App → 1.0 Prepare for Submission:
- Selecciona la build subida
- Promotional Text, Description, Keywords (es-ES)
- Support URL
- Marketing URL (opcional)
- Demo account credentials (si los reviewers necesitan login para probar)
- Notes for Review: explica que premium se prueba con sandbox tester
- Click **Submit for Review**

## 11. Sandbox testing antes de submit

App Store Connect → Users and Access → Sandbox Testers → crear usuario.
En iPhone real: Settings → App Store → Sandbox Account → login con ese usuario.
Abre RentalMngr → Settings → Hazte Premium → compra con sandbox (no cobra).
Verifica:
- StoreKit purchase succeeds
- Supabase `user_subscriptions.tier = 'premium'` y `expires_at` se actualiza
- App refresca tier sin re-login

## 12. Después del review (1–2 días)

Aprobada → manual release o automatic.
Rechazos comunes:
- Privacy policy URL muerta o sin contenido
- Screenshots no representativos
- IAP description vaga
- Falta restoration purchases (ya implementado en paywall)

---

## TODO post-launch (importante)

- **Receipt validation server-side**: hoy `apply_premium_purchase` confía en el cliente. Implementar Apple App Store Server Notifications V2 → Edge Function que valida con Apple y actualiza `user_subscriptions`. Bloquear el RPC actual cuando esté listo.
- **App Store Server API**: para gestionar refunds, status, etc.
- **Política de privacidad legal real** (consulta lawyer/genera con plantilla GDPR).
