ALTER TABLE public.assignments ADD CONSTRAINT assignments_staff_profile_fkey FOREIGN KEY (staff_id) REFERENCES public.profiles(id);
ALTER TABLE public.assignments ADD CONSTRAINT assignments_assigner_profile_fkey FOREIGN KEY (assigned_by) REFERENCES public.profiles(id);
ALTER TABLE public.status_history ADD CONSTRAINT status_history_changer_profile_fkey FOREIGN KEY (changed_by) REFERENCES public.profiles(id);

CREATE POLICY profiles_active_staff_read ON public.profiles FOR SELECT TO authenticated USING (is_active AND private.has_role(id, 'staff'));

CREATE OR REPLACE FUNCTION private.log_complaint_update() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE actor uuid := auth.uid();
BEGIN
  IF NEW.student_id IS DISTINCT FROM OLD.student_id OR NEW.category_id IS DISTINCT FROM OLD.category_id OR NEW.priority_id IS DISTINCT FROM OLD.priority_id OR NEW.title IS DISTINCT FROM OLD.title OR NEW.description IS DISTINCT FROM OLD.description OR NEW.location IS DISTINCT FROM OLD.location OR NEW.image_path IS DISTINCT FROM OLD.image_path THEN
    IF actor IS NOT NULL THEN RAISE EXCEPTION 'Submitted complaint details and ownership cannot be changed'; END IF;
  END IF;
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF actor = NEW.student_id AND NOT (OLD.status = 'resolved' AND NEW.status = 'verified') THEN RAISE EXCEPTION 'Students may only verify resolved complaints'; END IF;
    IF private.has_role(actor, 'staff') AND NOT EXISTS (SELECT 1 FROM public.assignments a WHERE a.complaint_id = NEW.id AND a.staff_id = actor AND a.is_current) THEN RAISE EXCEPTION 'Staff member is not assigned to this complaint'; END IF;
    IF private.has_role(actor, 'staff') AND NOT ((OLD.status = 'assigned' AND NEW.status = 'in_progress') OR (OLD.status = 'in_progress' AND NEW.status = 'resolved')) THEN RAISE EXCEPTION 'Invalid staff status transition'; END IF;
    IF actor IS NOT NULL AND NOT private.has_role(actor, 'admin') AND actor <> NEW.student_id AND NOT private.has_role(actor, 'staff') THEN RAISE EXCEPTION 'Not authorized'; END IF;
    NEW.resolved_at := CASE WHEN NEW.status = 'resolved' THEN now() ELSE OLD.resolved_at END;
    NEW.closed_at := CASE WHEN NEW.status = 'closed' THEN now() ELSE OLD.closed_at END;
    INSERT INTO public.status_history (complaint_id, status, changed_by, note) VALUES (NEW.id, NEW.status, COALESCE(actor, NEW.student_id), NEW.resolution_notes);
    INSERT INTO public.notifications (user_id, complaint_id, title, message) VALUES (NEW.student_id, NEW.id, 'Status updated', NEW.ticket_number || ' is now ' || replace(initcap(NEW.status::text), '_', ' ') || '.');
    INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, details) VALUES (COALESCE(actor, NEW.student_id), 'complaint.status_changed', 'complaint', NEW.id, jsonb_build_object('from', OLD.status, 'to', NEW.status));
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.log_complaint_update() FROM PUBLIC, anon, authenticated;