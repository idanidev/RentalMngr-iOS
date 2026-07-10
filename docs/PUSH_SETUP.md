# Push remoto (APNs) — pasos manuales

El código de la app ya está listo (AppDelegate, `PushManager`, `DeviceTokenService`,
registro de token y wiring). Falta lo que **solo tú** puedes hacer en tu cuenta de
Apple y en Supabase. Sigue el orden.

## 0. Aceptar el Program License Agreement
El build con la capability falló con `PLA Update available`. Entra en
<https://developer.apple.com/account> → acepta el acuerdo pendiente. Sin esto Xcode no
puede crear perfiles con Push.

## 1. Activar la capability en Xcode
1. Abre `RentalMngr.xcodeproj` → target **RentalMngr** → pestaña **Signing & Capabilities**.
2. **+ Capability** → **Push Notifications**.
3. **+ Capability** → **Background Modes** → marca **Remote notifications**.
4. Xcode añadirá `CODE_SIGN_ENTITLEMENTS` (apuntando al `RentalMngr/RentalMngr.entitlements`
   que ya está creado) y el `UIBackgroundModes`, y registrará el App ID con Push.
   - Ya está el archivo `RentalMngr/RentalMngr.entitlements` con `aps-environment = development`.
   - Si Xcode crea uno nuevo, deja solo uno.

## 2. Crear la APNs Auth Key (.p8)
1. <https://developer.apple.com/account/resources/authkeys/list> → **+**.
2. Marca **Apple Push Notifications service (APNs)** → Continue → Register.
3. Descarga el `.p8` (¡solo se descarga una vez!) y apunta el **Key ID**.
4. Team ID = `AXK73U74AC`. Bundle ID = `idanidev.RentalMngr`.

## 3. Migración de BD
Ejecuta `supabase/migrations/20260630000001_device_tokens.sql` en el SQL editor de
Supabase (o `supabase db push`). Crea la tabla `device_tokens` con RLS por usuario.

## 4. Desplegar la Edge Function
```bash
supabase functions deploy send-push --no-verify-jwt

supabase secrets set \
  APNS_KEY_ID=XXXXXXXXXX \
  APNS_TEAM_ID=AXK73U74AC \
  APNS_BUNDLE_ID=idanidev.RentalMngr \
  APNS_HOST=api.sandbox.push.apple.com \
  APNS_PRIVATE_KEY="$(cat AuthKey_XXXXXXXXXX.p8)"
```
- `APNS_HOST`: `api.sandbox.push.apple.com` para builds de desarrollo (Xcode/dispositivo
  con perfil dev). Para TestFlight/App Store usa `api.push.apple.com` y cambia el
  entitlement a `aps-environment = production` (o deja que Xcode lo gestione en release).

## 5. Disparar el push (webhook)
Dashboard → **Database** → **Webhooks** → **Create**:
- Tabla `notifications`, evento **Insert**.
- Tipo **Supabase Edge Functions** → `send-push`.

Así, cada fila nueva en `notifications` (que ya genera tu backend/realtime) manda push a
los dispositivos del `user_id`. El payload del webhook llega como `record` y la función usa
`record.user_id`, `record.title`, `record.message`.

## 6. Probar
- Compila e instala en el iPhone (perfil dev). Al conceder permiso, la app registra el
  token y lo guarda en `device_tokens`.
- Inserta una notificación de prueba para tu `user_id` o llama directo:
```bash
curl -X POST 'https://<PROJECT>.supabase.co/functions/v1/send-push' \
  -H 'Authorization: Bearer <ANON_O_SERVICE_KEY>' \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"<TU_UUID>","title":"Hola","body":"Push de prueba"}'
```

## Notas
- En el simulador no hay APNs real; prueba en dispositivo físico.
- Mac Catalyst usa APNs propio; el token se guarda con `platform = maccatalyst`.
- Tokens muertos (410 / BadDeviceToken / Unregistered) se borran solos en la función.
- El borrado de token al cerrar sesión existe (`PushManager.clearOnSignOut()`) pero aún no
  está cableado a `signOut()`; dímelo si quieres que lo conecte.
