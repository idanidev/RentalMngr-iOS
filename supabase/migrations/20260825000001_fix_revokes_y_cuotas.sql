-- =====================================================================
-- RentalMngr — Corrección: revocar de PUBLIC y cuotas sin tocar storage
-- Fecha: 2026-08-25
--
-- SUSTITUYE a 20260821000002_cuotas_servidor.sql, que falla entero con
-- "42501: must be owner of table objects": storage.objects pertenece a
-- supabase_storage_admin y desde el editor SQL no se pueden crear ni
-- triggers ni índices sobre esa tabla.
--
-- Y corrige un fallo de 20260821000001: los REVOKE quitaban el permiso a
-- `anon`, pero las funciones lo tienen concedido a PUBLIC, así que `anon`
-- seguía pudiendo ejecutarlas. Verificado: has_function_privilege('anon',
-- 'grant_admin(text)') devolvía true DESPUÉS de aplicar aquella migración.
--
-- No borra datos.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. CERRAR DE VERDAD LA ESCALADA DE PRIVILEGIOS
--    Hay que revocar de PUBLIC; si no, todos los roles lo heredan.
-- ---------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.grant_admin(user_email text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.revoke_admin(user_email text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.create_notification(p_user_id uuid, p_type text, p_title text, p_message text, p_property_id uuid, p_metadata jsonb) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.create_default_notification_settings() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.create_free_subscription_for_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.enforce_free_tier_property_limit() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.enforce_free_tier_room_limit() FROM PUBLIC, anon, authenticated;

-- Estas SÍ las usa la app, pero solo con sesión iniciada.
REVOKE EXECUTE ON FUNCTION public.get_user_by_email(user_email text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_user_by_email(user_email text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.generate_monthly_income() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.generate_monthly_income() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.is_premium(uid uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_unread_notifications_count(p_user_id uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_property_users(p_property_id uuid) FROM PUBLIC, anon;

-- La de compra: solo usuarios con sesión.
REVOKE EXECUTE ON FUNCTION public.apply_premium_purchase(text, timestamptz, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.apply_premium_purchase(text, timestamptz, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.managed_units(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.managed_units(uuid) TO authenticated;

-- ---------------------------------------------------------------------
-- 2. CUOTA DE DOCUMENTOS (5 gratis / 300 premium)
--    public.documents sí es tuya, así que aquí el trigger funciona.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_document_quota()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
    v_owner UUID;
    v_count INTEGER;
    v_max   INTEGER;
BEGIN
    SELECT owner_id INTO v_owner FROM properties WHERE id = NEW.property_id;
    IF v_owner IS NULL THEN RETURN NEW; END IF;

    v_max := CASE WHEN is_premium(v_owner) THEN 300 ELSE 5 END;

    SELECT COUNT(*) INTO v_count
      FROM documents d JOIN properties p ON p.id = d.property_id
     WHERE p.owner_id = v_owner;

    IF v_count >= v_max THEN
        RAISE EXCEPTION 'document_quota_reached'
            USING HINT = 'Upgrade to premium for more documents';
    END IF;

    RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.enforce_document_quota() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_enforce_document_quota ON public.documents;
CREATE TRIGGER trg_enforce_document_quota
    BEFORE INSERT ON public.documents
    FOR EACH ROW EXECUTE FUNCTION public.enforce_document_quota();

-- ---------------------------------------------------------------------
-- 3. CUOTA DE FOTOS, por la puerta que sí controlamos
--
--    No se puede vigilar storage.objects, pero una foto solo cuenta cuando
--    la app la registra en `rooms.photos`. Ese UPDATE sí pasa por una tabla
--    nuestra, así que el límite se aplica ahí.
--
--    Límite: 25 fotos en gratis, 400 en premium (por propietario).
--
--    Efecto secundario conocido: el fichero ya está en el bucket cuando el
--    UPDATE se rechaza, así que queda un huérfano. Es un residuo pequeño y
--    preferible a no tener límite; la app muestra el error.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_photo_quota()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
    v_owner  UUID;
    v_before INTEGER;
    v_after  INTEGER;
    v_total  INTEGER;
    v_max    INTEGER;
BEGIN
    v_before := COALESCE(jsonb_array_length(OLD.photos), 0);
    v_after  := COALESCE(jsonb_array_length(NEW.photos), 0);

    -- Solo interesa cuando se añaden fotos.
    IF v_after <= v_before THEN RETURN NEW; END IF;

    SELECT owner_id INTO v_owner FROM properties WHERE id = NEW.property_id;
    IF v_owner IS NULL THEN RETURN NEW; END IF;

    v_max := CASE WHEN is_premium(v_owner) THEN 400 ELSE 25 END;

    SELECT COALESCE(SUM(COALESCE(jsonb_array_length(r.photos), 0)), 0) INTO v_total
      FROM rooms r JOIN properties p ON p.id = r.property_id
     WHERE p.owner_id = v_owner AND r.id <> NEW.id;

    IF v_total + v_after > v_max THEN
        RAISE EXCEPTION 'photo_quota_reached'
            USING HINT = 'Upgrade to premium for more photos';
    END IF;

    RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.enforce_photo_quota() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_enforce_photo_quota ON public.rooms;
CREATE TRIGGER trg_enforce_photo_quota
    BEFORE UPDATE OF photos ON public.rooms
    FOR EACH ROW EXECUTE FUNCTION public.enforce_photo_quota();

-- =====================================================================
-- NOTA sobre el bucket privado
--
-- Las políticas de storage NO se tocan desde aquí: hay que usar
-- Dashboard -> Storage -> Policies, que se conecta con el rol dueño.
-- Además sigue pendiente confirmar si la webapp lee las fotos por URL
-- pública; si es así, hacer el bucket privado le rompe las imágenes.
-- =====================================================================
