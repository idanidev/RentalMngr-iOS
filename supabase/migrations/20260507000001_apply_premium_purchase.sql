-- =====================================================================
-- RentalMngr — apply_premium_purchase RPC
-- Date: 2026-05-07
-- Allows authenticated users to record their own premium purchase from StoreKit.
-- Idempotent.
--
-- ⚠️ v1 implementation: client-trusted. Acceptable for launch but production
-- should validate Apple receipts via App Store Server Notifications V2 in an
-- Edge Function and bypass this RPC.
-- =====================================================================

CREATE OR REPLACE FUNCTION apply_premium_purchase(
    p_transaction_id TEXT,
    p_expires_at TIMESTAMPTZ,
    p_provider TEXT DEFAULT 'apple'
)
RETURNS VOID AS $$
DECLARE
    uid UUID := auth.uid();
BEGIN
    IF uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    -- Don't downgrade admins. Otherwise upsert as premium.
    INSERT INTO user_subscriptions (
        user_id, tier, expires_at, provider, provider_id, auto_renew, updated_at
    )
    VALUES (uid, 'premium', p_expires_at, p_provider, p_transaction_id, TRUE, NOW())
    ON CONFLICT (user_id) DO UPDATE
        SET tier = CASE
                WHEN user_subscriptions.tier = 'admin' THEN user_subscriptions.tier
                ELSE 'premium'::subscription_tier
            END,
            expires_at = CASE
                WHEN user_subscriptions.tier = 'admin' THEN user_subscriptions.expires_at
                ELSE EXCLUDED.expires_at
            END,
            provider = CASE
                WHEN user_subscriptions.tier = 'admin' THEN user_subscriptions.provider
                ELSE EXCLUDED.provider
            END,
            provider_id = CASE
                WHEN user_subscriptions.tier = 'admin' THEN user_subscriptions.provider_id
                ELSE EXCLUDED.provider_id
            END,
            auto_renew = CASE
                WHEN user_subscriptions.tier = 'admin' THEN user_subscriptions.auto_renew
                ELSE EXCLUDED.auto_renew
            END,
            updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Allow authenticated role to call it
GRANT EXECUTE ON FUNCTION apply_premium_purchase(TEXT, TIMESTAMPTZ, TEXT) TO authenticated;
