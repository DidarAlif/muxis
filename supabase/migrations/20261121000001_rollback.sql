-- ============================================================================
-- MUXIS (PRISMATIC AURA) SCHEMA ROLLBACK
-- Migration Version: 20261121000001_rollback.sql
-- Description: Reverses 20261121000001_initial_schema.sql safely
-- ============================================================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.delete_user_account();

DROP TABLE IF EXISTS public.sync_metadata CASCADE;
DROP TABLE IF EXISTS public.user_settings CASCADE;
DROP TABLE IF EXISTS public.listening_history CASCADE;
DROP TABLE IF EXISTS public.favorites CASCADE;
DROP TABLE IF EXISTS public.playlist_tracks CASCADE;
DROP TABLE IF EXISTS public.playlists CASCADE;
DROP TABLE IF EXISTS public.user_devices CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

DROP FUNCTION IF EXISTS set_updated_at();
