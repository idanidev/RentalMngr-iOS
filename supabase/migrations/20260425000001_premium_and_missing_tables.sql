-- =====================================================================
-- RentalMngr — Premium tier + missing cross-platform tables
-- Date: 2026-04-25
-- Apply via Supabase SQL Editor or `supabase db push`.
-- Idempotent: safe to re-run.
-- =====================================================================

-- ─── 1. contract_variables (custom user variables for contract templates) ───

CREATE TABLE IF NOT EXISTS contract_variables (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    label TEXT NOT NULL,
    default_value TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, name)
);

ALTER TABLE contract_variables ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own contract_variables" ON contract_variables;
CREATE POLICY "Users manage own contract_variables"
    ON contract_variables FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ─── 2. landlord_profiles (one row per user, owner data for contracts) ───

CREATE TABLE IF NOT EXISTS landlord_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL DEFAULT '',
    dni TEXT NOT NULL DEFAULT '',
    address TEXT NOT NULL DEFAULT '',
    email TEXT NOT NULL DEFAULT '',
    phone TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE landlord_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own landlord_profile" ON landlord_profiles;
CREATE POLICY "Users manage own landlord_profile"
    ON landlord_profiles FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ─── 3. notifications + notification_settings ───

CREATE TABLE IF NOT EXISTS notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN (
        'contract_expiring', 'contract_expired', 'weekly_report',
        'invitation', 'expense', 'income', 'room_change'
    )),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    metadata JSONB,
    read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON notifications(user_id, read, created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own notifications" ON notifications;
CREATE POLICY "Users manage own notifications"
    ON notifications FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);


CREATE TABLE IF NOT EXISTS notification_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    contract_alert_days INTEGER[] NOT NULL DEFAULT ARRAY[30, 15, 7, 1],
    enable_contract_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    enable_weekly_report BOOLEAN NOT NULL DEFAULT TRUE,
    enable_invitation_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    enable_expense_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    enable_income_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    enable_room_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE notification_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own notification_settings" ON notification_settings;
CREATE POLICY "Users manage own notification_settings"
    ON notification_settings FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ─── 4. PREMIUM TIER — user_subscriptions ───

DO $$ BEGIN
    CREATE TYPE subscription_tier AS ENUM ('free', 'premium', 'admin');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS user_subscriptions (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    tier subscription_tier NOT NULL DEFAULT 'free',
    -- NULL means lifetime (admin), or "no current subscription" for free
    expires_at TIMESTAMPTZ,
    -- 'apple', 'google', 'revenuecat', 'manual' (admin grants)
    provider TEXT,
    -- Provider's subscription ID (Stripe sub_xxx, RevenueCat entitlement, etc.)
    provider_id TEXT,
    -- Auto-renew status from store
    auto_renew BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;

-- Users see only their own subscription
DROP POLICY IF EXISTS "Users read own subscription" ON user_subscriptions;
CREATE POLICY "Users read own subscription"
    ON user_subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- Inserts/updates restricted to service_role (webhook from RevenueCat) or trigger.
-- Users themselves CANNOT modify their tier from the client.
DROP POLICY IF EXISTS "Service role manages subscriptions" ON user_subscriptions;
CREATE POLICY "Service role manages subscriptions"
    ON user_subscriptions FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Auto-create free row on signup
CREATE OR REPLACE FUNCTION create_free_subscription_for_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_subscriptions (user_id, tier)
    VALUES (NEW.id, 'free')
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_create_free_subscription ON auth.users;
CREATE TRIGGER trg_create_free_subscription
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION create_free_subscription_for_user();

-- ─── 5. is_premium() helper — single source of truth for entitlement ───
-- Returns TRUE if user is admin (forever) OR premium with valid expires_at.
-- Use in RLS policies to gate INSERTs (e.g. property limit for free users).

CREATE OR REPLACE FUNCTION is_premium(uid UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_subscriptions
        WHERE user_id = uid
          AND (
              tier = 'admin'
              OR (tier = 'premium' AND (expires_at IS NULL OR expires_at > NOW()))
          )
    );
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- ─── 6. Free-tier hard limits enforced server-side via triggers ───
-- Free user: max 1 property, max 2 rooms total across all properties.

CREATE OR REPLACE FUNCTION enforce_free_tier_property_limit()
RETURNS TRIGGER AS $$
DECLARE
    current_count INTEGER;
BEGIN
    IF is_premium(NEW.owner_id) THEN
        RETURN NEW;
    END IF;
    SELECT COUNT(*) INTO current_count
        FROM properties WHERE owner_id = NEW.owner_id;
    IF current_count >= 1 THEN
        RAISE EXCEPTION 'free_tier_property_limit_reached'
            USING HINT = 'Upgrade to premium for unlimited properties';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_enforce_property_limit ON properties;
CREATE TRIGGER trg_enforce_property_limit
    BEFORE INSERT ON properties
    FOR EACH ROW EXECUTE FUNCTION enforce_free_tier_property_limit();


CREATE OR REPLACE FUNCTION enforce_free_tier_room_limit()
RETURNS TRIGGER AS $$
DECLARE
    owner UUID;
    current_count INTEGER;
BEGIN
    SELECT owner_id INTO owner FROM properties WHERE id = NEW.property_id;
    IF is_premium(owner) THEN
        RETURN NEW;
    END IF;
    SELECT COUNT(*) INTO current_count
        FROM rooms r
        JOIN properties p ON p.id = r.property_id
        WHERE p.owner_id = owner;
    IF current_count >= 2 THEN
        RAISE EXCEPTION 'free_tier_room_limit_reached'
            USING HINT = 'Upgrade to premium for unlimited rooms';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_enforce_room_limit ON rooms;
CREATE TRIGGER trg_enforce_room_limit
    BEFORE INSERT ON rooms
    FOR EACH ROW EXECUTE FUNCTION enforce_free_tier_room_limit();

-- ─── 7. Admin grant helper (you run this from SQL editor to make a user admin) ───
-- Usage:
--   SELECT grant_admin('email@example.com');
--   SELECT revoke_admin('email@example.com');

CREATE OR REPLACE FUNCTION grant_admin(user_email TEXT)
RETURNS VOID AS $$
DECLARE
    uid UUID;
BEGIN
    SELECT id INTO uid FROM auth.users WHERE email = user_email;
    IF uid IS NULL THEN
        RAISE EXCEPTION 'user_not_found: %', user_email;
    END IF;
    INSERT INTO user_subscriptions (user_id, tier, expires_at, provider, provider_id)
    VALUES (uid, 'admin', NULL, 'manual', 'admin_grant')
    ON CONFLICT (user_id)
    DO UPDATE SET tier = 'admin', expires_at = NULL,
                  provider = 'manual', provider_id = 'admin_grant',
                  updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION revoke_admin(user_email TEXT)
RETURNS VOID AS $$
DECLARE
    uid UUID;
BEGIN
    SELECT id INTO uid FROM auth.users WHERE email = user_email;
    IF uid IS NULL THEN
        RAISE EXCEPTION 'user_not_found: %', user_email;
    END IF;
    UPDATE user_subscriptions
        SET tier = 'free', expires_at = NULL,
            provider = NULL, provider_id = NULL, updated_at = NOW()
        WHERE user_id = uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── 8. Backfill: existing users get a free row ───

INSERT INTO user_subscriptions (user_id, tier)
SELECT id, 'free' FROM auth.users
ON CONFLICT (user_id) DO NOTHING;

-- ─── DONE ───
-- Next steps after running:
--   1. SELECT grant_admin('idanideveloper@gmail.com');  -- make yourself admin
--   2. Wire RevenueCat webhook to Supabase Edge Function that updates user_subscriptions
--   3. Verify gates: try inserting 2nd property as free user — should error "free_tier_property_limit_reached"
