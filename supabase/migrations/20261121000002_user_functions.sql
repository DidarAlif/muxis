-- ============================================================================
-- MUXIS POSTGRESQL MIGRATION 20261121000002
-- User Account Functions & Security RPCs
-- ============================================================================

-- Function to allow an authenticated user to permanently delete their own account
-- Executes with SECURITY DEFINER to permit removing the auth.users record.
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    calling_user_id UUID;
BEGIN
    calling_user_id := auth.uid();
    IF calling_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: No active user session';
    END IF;

    -- 1. Explicitly purge custom profile (foreign keys will CASCADE to devices, playlists, favorites, etc.)
    DELETE FROM public.profiles WHERE id = calling_user_id;

    -- 2. Purge auth.users record
    DELETE FROM auth.users WHERE id = calling_user_id;
END;
$$;

-- Grant execution permissions only to authenticated users
REVOKE EXECUTE ON FUNCTION public.delete_user_account() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;

-- Comment for PostgREST schema reflection
COMMENT ON FUNCTION public.delete_user_account() IS 'Permanently deletes the calling authenticated user and all associated cloud data in compliance with GDPR/CCPA.';
