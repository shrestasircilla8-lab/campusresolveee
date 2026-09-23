CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;
GRANT USAGE ON SCHEMA private TO authenticated, service_role;

ALTER FUNCTION public.has_role(uuid, public.app_role) SET SCHEMA private;
ALTER FUNCTION public.can_view_complaint(uuid, uuid) SET SCHEMA private;
ALTER FUNCTION public.handle_new_user() SET SCHEMA private;
ALTER FUNCTION public.log_and_notify_complaint() SET SCHEMA private;
ALTER FUNCTION public.handle_assignment() SET SCHEMA private;
ALTER FUNCTION public.handle_feedback() SET SCHEMA private;

REVOKE ALL ON FUNCTION private.has_role(uuid, public.app_role) FROM PUBLIC;
REVOKE ALL ON FUNCTION private.can_view_complaint(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.has_role(uuid, public.app_role) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.can_view_complaint(uuid, uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION private.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.log_and_notify_complaint() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.handle_assignment() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.handle_feedback() FROM PUBLIC, anon, authenticated;