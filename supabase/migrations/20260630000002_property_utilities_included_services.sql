-- Community fees "what's included" list.
-- Stores which services a flat community-fees charge covers (e.g. {"Luz","Agua"}).
-- Run this in the Supabase SQL editor (or via the CLI). NOT executed automatically.

alter table public.property_utilities
    add column if not exists included_services text[];
