DROP TRIGGER complaint_lifecycle ON public.complaints;

CREATE OR REPLACE FUNCTION private.log_new_complaint() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE actor uuid := auth.uid();
BEGIN
  INSERT INTO public.status_history (complaint_id, status, changed_by, note) VALUES (NEW.id, NEW.status, COALESCE(actor, NEW.student_id), 'Complaint submitted');
  INSERT INTO public.notifications (user_id, complaint_id, title, message) VALUES (NEW.student_id, NEW.id, 'Complaint submitted', NEW.ticket_number || ' was submitted successfully.');
  INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, details) VALUES (COALESCE(actor, NEW.student_id), 'complaint.created', 'complaint', NEW.id, jsonb_build_object('ticket', NEW.ticket_number));
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.log_new_complaint() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER complaint_created AFTER INSERT ON public.complaints FOR EACH ROW EXECUTE FUNCTION private.log_new_complaint();

CREATE OR REPLACE FUNCTION private.log_complaint_update() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE actor uuid := auth.uid();
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF actor = NEW.student_id AND NOT (OLD.status = 'resolved' AND NEW.status = 'verified') THEN RAISE EXCEPTION 'Students may only verify resolved complaints'; END IF;
    IF private.has_role(actor, 'staff') AND NOT EXISTS (SELECT 1 FROM public.assignments a WHERE a.complaint_id = NEW.id AND a.staff_id = actor AND a.is_current) THEN RAISE EXCEPTION 'Staff member is not assigned to this complaint'; END IF;
    IF private.has_role(actor, 'staff') AND NOT ((OLD.status = 'assigned' AND NEW.status = 'in_progress') OR (OLD.status = 'in_progress' AND NEW.status = 'resolved')) THEN RAISE EXCEPTION 'Invalid staff status transition'; END IF;
    IF NOT private.has_role(actor, 'admin') AND actor <> NEW.student_id AND NOT private.has_role(actor, 'staff') THEN RAISE EXCEPTION 'Not authorized'; END IF;
    NEW.resolved_at := CASE WHEN NEW.status = 'resolved' THEN now() ELSE OLD.resolved_at END;
    NEW.closed_at := CASE WHEN NEW.status = 'closed' THEN now() ELSE OLD.closed_at END;
    INSERT INTO public.status_history (complaint_id, status, changed_by, note) VALUES (NEW.id, NEW.status, actor, NEW.resolution_notes);
    INSERT INTO public.notifications (user_id, complaint_id, title, message) VALUES (NEW.student_id, NEW.id, 'Status updated', NEW.ticket_number || ' is now ' || replace(initcap(NEW.status::text), '_', ' ') || '.');
    INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, details) VALUES (actor, 'complaint.status_changed', 'complaint', NEW.id, jsonb_build_object('from', OLD.status, 'to', NEW.status));
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.log_complaint_update() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER complaint_updated BEFORE UPDATE ON public.complaints FOR EACH ROW EXECUTE FUNCTION private.log_complaint_update();