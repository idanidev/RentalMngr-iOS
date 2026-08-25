-- =====================================================================
-- RentalMngr — delete_account
-- Fecha: 2026-08-25
--
-- La app llama a este RPC desde AuthService.deleteAccount(), pero la
-- función NO EXISTE en la base: borrar cuenta falla siempre. Apple exige
-- el borrado (Guideline 5.1.1 v) y el revisor lo prueba, así que sin esto
-- hay rechazo seguro.
--
-- El fichero original (20260221_delete_account_rpc.sql) se perdió, así que
-- esta versión se ha escrito leyendo el grafo real de claves foráneas.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Por qué basta con borrar el usuario:
--
-- TODO cuelga de auth.users con ON DELETE CASCADE — properties,
-- property_access, user_subscriptions, notifications,
-- notification_settings, device_tokens, landlord_profiles,
-- contract_variables, contract_templates, invitations, expenses,
-- house_rules, reminders, shared_expenses y applied_purchases.
--
-- Y properties arrastra a su vez rooms, tenants, income, utility_charges,
-- documents, property_utilities, inventory_items y expense_splits.
--
-- Postgres se encarga del resto en una sola transacción.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_account()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    uid UUID := auth.uid();
BEGIN
    -- El usuario sale de la sesión, nunca de un parámetro: así nadie puede
    -- borrar la cuenta de otro.
    IF uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    DELETE FROM auth.users WHERE id = uid;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.delete_account() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.delete_account() TO authenticated;

-- =====================================================================
-- DOS COSAS QUE ESTO NO HACE, dichas claramente
--
-- 1. NO borra las fotos del bucket. Los ficheros de storage no se pueden
--    tocar desde SQL (storage.objects es de supabase_storage_admin), así
--    que las fotos de las habitaciones quedarían huérfanas. Para cumplir
--    de verdad con RGPD la app debe borrarlas ANTES de llamar a este RPC.
--
-- 2. Si el usuario había creado gastos o normas en propiedades de OTRA
--    persona, esas filas se borran también, porque su clave foránea a
--    auth.users ya venía con CASCADE de antes. No lo introduce esta
--    migración, pero conviene saberlo.
-- =====================================================================
