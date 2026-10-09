-- Tiempo real para inquilinos, habitaciones y propiedades (RepoMind #27)
--
-- La app escucha cambios en tiempo real sobre tenants, rooms y properties, pero
-- esas tablas no estaban en la publicación supabase_realtime: solo lo estaban
-- income, inventory_items y utility_charges. Las escuchas existían y nunca
-- recibían nada. Consecuencias:
--
--   - Si Álvaro renueva un contrato en su móvil, tú no lo ves hasta refrescar.
--   - Una propiedad recién compartida no aparece hasta refrescar.
--
-- Lo que cambias TÚ ya se ve al momento sin esto: la app avisa a sus propias
-- pantallas (AppState.tenantDataRevision). Esto es para los cambios que hace
-- otra persona o tu otro dispositivo.
--
-- QUÉ HACE AL APLICARSE: añade tres tablas a la publicación. No crea, modifica
-- ni borra ninguna fila. Se puede ejecutar más de una vez.
--
-- PRIVACIDAD: el tiempo real respeta la RLS. Cada usuario solo recibe cambios
-- de filas que ya puede leer, igual que en una consulta normal.
--
-- COSTE: el plan gratuito incluye 2 millones de mensajes al mes. Con el uso de
-- esta app no se acerca.
--
-- Vuelta atrás, si hiciera falta:
--   alter publication supabase_realtime drop table public.tenants;
--   alter publication supabase_realtime drop table public.rooms;
--   alter publication supabase_realtime drop table public.properties;

do $$
declare
    tabla text;
begin
    foreach tabla in array array['tenants', 'rooms', 'properties'] loop
        if not exists (
            select 1 from pg_publication_tables
            where pubname = 'supabase_realtime'
              and schemaname = 'public'
              and tablename = tabla
        ) then
            execute format('alter publication supabase_realtime add table public.%I', tabla);
        end if;
    end loop;
end $$;
