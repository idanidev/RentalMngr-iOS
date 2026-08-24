-- =====================================================================
-- RentalMngr — Monetización: escalada cerrada, compra endurecida, unidades
-- Fecha: 2026-08-21
--
-- Reemplaza a 20260507000001_apply_premium_purchase.sql (nunca aplicada):
-- mantiene su lógica de no degradar admins y le añade las comprobaciones
-- que faltaban. No borra datos.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. CERRAR ESCALADA DE PRIVILEGIOS
--    grant_admin/revoke_admin no comprueban quién llama y estaban abiertas
--    al rol `anon`: con la clave pública de la app, cualquiera se hacía
--    premium con un curl. Se siguen pudiendo usar desde el editor SQL.
-- ---------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.grant_admin(user_email text) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.revoke_admin(user_email text) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.create_notification(p_user_id uuid, p_type text, p_title text, p_message text, p_property_id uuid, p_metadata jsonb) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_user_by_email(user_email text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.is_premium(uid uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_unread_notifications_count(p_user_id uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_property_users(p_property_id uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.generate_monthly_income() FROM anon;
REVOKE EXECUTE ON FUNCTION public.create_default_notification_settings() FROM anon;
REVOKE EXECUTE ON FUNCTION public.create_free_subscription_for_user() FROM anon;
REVOKE EXECUTE ON FUNCTION public.enforce_free_tier_property_limit() FROM anon;
REVOKE EXECUTE ON FUNCTION public.enforce_free_tier_room_limit() FROM anon;

-- ---------------------------------------------------------------------
-- 2. COMPRA PREMIUM
--    La app llama a esta función al comprar. HOY NO EXISTE en producción:
--    Apple cobra, la llamada falla y el usuario se queda en `free`.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.applied_purchases (
    transaction_id TEXT PRIMARY KEY,
    user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    expires_at     TIMESTAMPTZ,
    applied_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.applied_purchases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS applied_purchases_select_own ON public.applied_purchases;
CREATE POLICY applied_purchases_select_own ON public.applied_purchases
    FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.apply_premium_purchase(
    p_transaction_id TEXT,
    p_expires_at     TIMESTAMPTZ,
    p_provider       TEXT DEFAULT 'apple'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    uid     UUID := auth.uid();
    v_owner UUID;
BEGIN
    -- El usuario sale de la sesión, nunca de un parámetro.
    IF uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    -- Sin esto, un cliente manipulado pide premium hasta el año 3000.
    IF p_expires_at IS NULL OR p_expires_at <= NOW() THEN
        RAISE EXCEPTION 'expired_transaction';
    END IF;
    IF p_expires_at > NOW() + INTERVAL '2 years' THEN
        RAISE EXCEPTION 'implausible_expiry';
    END IF;

    -- Una transacción de Apple solo puede activar UNA cuenta.
    SELECT user_id INTO v_owner FROM applied_purchases WHERE transaction_id = p_transaction_id;
    IF v_owner IS NOT NULL AND v_owner <> uid THEN
        RAISE EXCEPTION 'transaction_already_used';
    END IF;

    INSERT INTO applied_purchases (transaction_id, user_id, expires_at)
    VALUES (p_transaction_id, uid, p_expires_at)
    ON CONFLICT (transaction_id) DO UPDATE
        SET expires_at = EXCLUDED.expires_at, applied_at = NOW();

    -- No degradar admins (heredado de la migración de mayo).
    INSERT INTO user_subscriptions (
        user_id, tier, expires_at, provider, provider_id, auto_renew, updated_at
    )
    VALUES (uid, 'premium', p_expires_at, COALESCE(p_provider, 'apple'), p_transaction_id, TRUE, NOW())
    ON CONFLICT (user_id) DO UPDATE
        SET tier = CASE WHEN user_subscriptions.tier = 'admin'
                        THEN user_subscriptions.tier ELSE 'premium'::subscription_tier END,
            expires_at = CASE WHEN user_subscriptions.tier = 'admin'
                        THEN user_subscriptions.expires_at ELSE EXCLUDED.expires_at END,
            provider = CASE WHEN user_subscriptions.tier = 'admin'
                        THEN user_subscriptions.provider ELSE EXCLUDED.provider END,
            provider_id = CASE WHEN user_subscriptions.tier = 'admin'
                        THEN user_subscriptions.provider_id ELSE EXCLUDED.provider_id END,
            auto_renew = CASE WHEN user_subscriptions.tier = 'admin'
                        THEN user_subscriptions.auto_renew ELSE EXCLUDED.auto_renew END,
            updated_at = NOW();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.apply_premium_purchase(TEXT, TIMESTAMPTZ, TEXT) FROM anon;
GRANT  EXECUTE ON FUNCTION public.apply_premium_purchase(TEXT, TIMESTAMPTZ, TEXT) TO authenticated;

-- ---------------------------------------------------------------------
-- 3. UNIDADES GESTIONADAS — una casa marcada como única cuenta 1 unidad
--    aunque tenga 5 habitaciones. Plan gratis: 3 unidades.
--    Es MÁS generoso que el límite actual (1 propiedad / 2 habitaciones),
--    así que ningún usuario existente pierde nada.
-- ---------------------------------------------------------------------
ALTER TABLE public.properties
    ADD COLUMN IF NOT EXISTS is_single_unit BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.properties.is_single_unit IS
    'true = se alquila entera (1 unidad); false = por habitaciones (cada habitación es 1 unidad)';

CREATE OR REPLACE FUNCTION public.managed_units(uid UUID)
RETURNS INTEGER LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
    SELECT
      (SELECT COUNT(*) FROM properties p
         WHERE p.owner_id = uid AND p.is_single_unit)
    + (SELECT COUNT(*) FROM rooms r JOIN properties p ON p.id = r.property_id
         WHERE p.owner_id = uid AND NOT p.is_single_unit);
$$;
REVOKE EXECUTE ON FUNCTION public.managed_units(UUID) FROM anon;
GRANT  EXECUTE ON FUNCTION public.managed_units(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.enforce_free_tier_property_limit()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
    IF is_premium(NEW.owner_id) THEN RETURN NEW; END IF;

    -- Tope de propiedades: evita crear propiedades vacías sin fin.
    IF (SELECT COUNT(*) FROM properties WHERE owner_id = NEW.owner_id) >= 3 THEN
        RAISE EXCEPTION 'free_tier_unit_limit_reached'
            USING HINT = 'Upgrade to premium for unlimited properties';
    END IF;

    -- Una casa entera consume 1 unidad ya al crearse.
    IF NEW.is_single_unit AND managed_units(NEW.owner_id) >= 3 THEN
        RAISE EXCEPTION 'free_tier_unit_limit_reached'
            USING HINT = 'Upgrade to premium for unlimited units';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_free_tier_room_limit()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
    v_owner  UUID;
    v_single BOOLEAN;
BEGIN
    SELECT owner_id, is_single_unit INTO v_owner, v_single
        FROM properties WHERE id = NEW.property_id;

    IF is_premium(v_owner) THEN RETURN NEW; END IF;

    -- En una casa alquilada entera, las habitaciones son organización
    -- interna: no consumen unidades.
    IF v_single THEN RETURN NEW; END IF;

    IF managed_units(v_owner) >= 3 THEN
        RAISE EXCEPTION 'free_tier_unit_limit_reached'
            USING HINT = 'Upgrade to premium for unlimited units';
    END IF;

    RETURN NEW;
END;
$$;
