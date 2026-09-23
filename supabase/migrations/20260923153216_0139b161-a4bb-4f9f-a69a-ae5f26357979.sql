CREATE TYPE public.app_role AS ENUM ('student', 'staff', 'admin');
CREATE TYPE public.complaint_status AS ENUM ('submitted', 'assigned', 'in_progress', 'resolved', 'verified', 'closed');

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY,
  email text NOT NULL,
  display_name text NOT NULL DEFAULT 'Campus User',
  phone text,
  department text,
  avatar_url text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  role public.app_role NOT NULL DEFAULT 'student',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;

CREATE POLICY profiles_read ON public.profiles FOR SELECT TO authenticated USING (id = auth.uid() OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY profiles_insert ON public.profiles FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
CREATE POLICY profiles_update ON public.profiles FOR UPDATE TO authenticated USING (id = auth.uid() OR public.has_role(auth.uid(), 'admin')) WITH CHECK (id = auth.uid() OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY roles_read ON public.user_roles FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE CHECK (char_length(name) BETWEEN 2 AND 80),
  description text CHECK (description IS NULL OR char_length(description) <= 300),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.categories TO authenticated;
GRANT ALL ON public.categories TO service_role;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY categories_read ON public.categories FOR SELECT TO authenticated USING (true);
CREATE POLICY categories_admin_insert ON public.categories FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY categories_admin_update ON public.categories FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY categories_admin_delete ON public.categories FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.priorities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE CHECK (char_length(name) BETWEEN 2 AND 40),
  level smallint NOT NULL UNIQUE CHECK (level BETWEEN 1 AND 5),
  response_hours integer NOT NULL CHECK (response_hours BETWEEN 1 AND 720),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.priorities TO authenticated;
GRANT ALL ON public.priorities TO service_role;
ALTER TABLE public.priorities ENABLE ROW LEVEL SECURITY;
CREATE POLICY priorities_read ON public.priorities FOR SELECT TO authenticated USING (true);
CREATE POLICY priorities_admin_insert ON public.priorities FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY priorities_admin_update ON public.priorities FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY priorities_admin_delete ON public.priorities FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'admin'));

CREATE SEQUENCE public.complaint_number_seq START 1001;
GRANT USAGE ON SEQUENCE public.complaint_number_seq TO authenticated, service_role;

CREATE TABLE public.complaints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_number text NOT NULL UNIQUE DEFAULT ('CMP-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.complaint_number_seq')::text, 5, '0')),
  student_id uuid NOT NULL,
  category_id uuid NOT NULL REFERENCES public.categories(id),
  priority_id uuid NOT NULL REFERENCES public.priorities(id),
  title text NOT NULL CHECK (char_length(title) BETWEEN 5 AND 160),
  description text NOT NULL CHECK (char_length(description) BETWEEN 10 AND 3000),
  location text NOT NULL CHECK (char_length(location) BETWEEN 2 AND 200),
  image_path text,
  status public.complaint_status NOT NULL DEFAULT 'submitted',
  resolution_notes text CHECK (resolution_notes IS NULL OR char_length(resolution_notes) <= 3000),
  resolved_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.complaints TO authenticated;
GRANT ALL ON public.complaints TO service_role;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id uuid NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
  staff_id uuid NOT NULL,
  assigned_by uuid NOT NULL,
  note text CHECK (note IS NULL OR char_length(note) <= 500),
  is_current boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.assignments TO authenticated;
GRANT ALL ON public.assignments TO service_role;
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id uuid NOT NULL REFERENCES public.complaints(id) ON DELETE CASCADE,
  status public.complaint_status NOT NULL,
  changed_by uuid NOT NULL,
  note text CHECK (note IS NULL OR char_length(note) <= 1000),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT ON public.status_history TO authenticated;
GRANT ALL ON public.status_history TO service_role;
ALTER TABLE public.status_history ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id uuid NOT NULL UNIQUE REFERENCES public.complaints(id) ON DELETE CASCADE,
  student_id uuid NOT NULL,
  rating smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment text CHECK (comment IS NULL OR char_length(comment) <= 1000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.feedback TO authenticated;
GRANT ALL ON public.feedback TO service_role;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  complaint_id uuid REFERENCES public.complaints(id) ON DELETE CASCADE,
  title text NOT NULL CHECK (char_length(title) BETWEEN 2 AND 120),
  message text NOT NULL CHECK (char_length(message) BETWEEN 2 AND 500),
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, UPDATE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.audit_logs TO authenticated;
GRANT ALL ON public.audit_logs TO service_role;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.can_view_complaint(_complaint_id uuid, _user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.complaints c
    WHERE c.id = _complaint_id AND (
      c.student_id = _user_id OR public.has_role(_user_id, 'admin') OR EXISTS (
        SELECT 1 FROM public.assignments a WHERE a.complaint_id = c.id AND a.staff_id = _user_id AND a.is_current
      )
    )
  )
$$;
GRANT EXECUTE ON FUNCTION public.can_view_complaint(uuid, uuid) TO authenticated;

CREATE POLICY complaints_read ON public.complaints FOR SELECT TO authenticated USING (student_id = auth.uid() OR public.has_role(auth.uid(), 'admin') OR EXISTS (SELECT 1 FROM public.assignments a WHERE a.complaint_id = id AND a.staff_id = auth.uid() AND a.is_current));
CREATE POLICY complaints_student_insert ON public.complaints FOR INSERT TO authenticated WITH CHECK (student_id = auth.uid() AND public.has_role(auth.uid(), 'student'));
CREATE POLICY complaints_update ON public.complaints FOR UPDATE TO authenticated USING (student_id = auth.uid() OR public.has_role(auth.uid(), 'admin') OR EXISTS (SELECT 1 FROM public.assignments a WHERE a.complaint_id = id AND a.staff_id = auth.uid() AND a.is_current)) WITH CHECK (student_id = student_id);

CREATE POLICY assignments_read ON public.assignments FOR SELECT TO authenticated USING (staff_id = auth.uid() OR public.has_role(auth.uid(), 'admin') OR EXISTS (SELECT 1 FROM public.complaints c WHERE c.id = complaint_id AND c.student_id = auth.uid()));
CREATE POLICY assignments_admin_insert ON public.assignments FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'admin'));
CREATE POLICY assignments_admin_update ON public.assignments FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY history_read ON public.status_history FOR SELECT TO authenticated USING (public.can_view_complaint(complaint_id, auth.uid()));
CREATE POLICY history_insert ON public.status_history FOR INSERT TO authenticated WITH CHECK (changed_by = auth.uid() AND public.can_view_complaint(complaint_id, auth.uid()));

CREATE POLICY feedback_read ON public.feedback FOR SELECT TO authenticated USING (student_id = auth.uid() OR public.has_role(auth.uid(), 'admin') OR public.can_view_complaint(complaint_id, auth.uid()));
CREATE POLICY feedback_insert ON public.feedback FOR INSERT TO authenticated WITH CHECK (student_id = auth.uid() AND EXISTS (SELECT 1 FROM public.complaints c WHERE c.id = complaint_id AND c.student_id = auth.uid() AND c.status = 'verified'));
CREATE POLICY feedback_update ON public.feedback FOR UPDATE TO authenticated USING (student_id = auth.uid()) WITH CHECK (student_id = auth.uid());

CREATE POLICY notifications_read ON public.notifications FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY notifications_update ON public.notifications FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY audit_admin_read ON public.audit_logs FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

CREATE OR REPLACE FUNCTION public.touch_updated_at() RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END $$;
CREATE TRIGGER profiles_touch BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER categories_touch BEFORE UPDATE ON public.categories FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER priorities_touch BEFORE UPDATE ON public.priorities FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER complaints_touch BEFORE UPDATE ON public.complaints FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER feedback_touch BEFORE UPDATE ON public.feedback FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name) VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)));
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'student');
  RETURN NEW;
END $$;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.log_and_notify_complaint() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE actor uuid := auth.uid();
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.status_history (complaint_id, status, changed_by, note) VALUES (NEW.id, NEW.status, COALESCE(actor, NEW.student_id), 'Complaint submitted');
    INSERT INTO public.notifications (user_id, complaint_id, title, message) VALUES (NEW.student_id, NEW.id, 'Complaint submitted', NEW.ticket_number || ' was submitted successfully.');
    INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, details) VALUES (COALESCE(actor, NEW.student_id), 'complaint.created', 'complaint', NEW.id, jsonb_build_object('ticket', NEW.ticket_number));
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    IF actor = NEW.student_id AND NOT (OLD.status = 'resolved' AND NEW.status = 'verified') THEN RAISE EXCEPTION 'Students may only verify resolved complaints'; END IF;
    IF public.has_role(actor, 'staff') AND NOT EXISTS (SELECT 1 FROM public.assignments a WHERE a.complaint_id = NEW.id AND a.staff_id = actor AND a.is_current) THEN RAISE EXCEPTION 'Staff member is not assigned to this complaint'; END IF;
    IF public.has_role(actor, 'staff') AND NOT ((OLD.status = 'assigned' AND NEW.status = 'in_progress') OR (OLD.status = 'in_progress' AND NEW.status = 'resolved')) THEN RAISE EXCEPTION 'Invalid staff status transition'; END IF;
    IF NOT public.has_role(actor, 'admin') AND actor <> NEW.student_id AND NOT public.has_role(actor, 'staff') THEN RAISE EXCEPTION 'Not authorized'; END IF;
    NEW.resolved_at := CASE WHEN NEW.status = 'resolved' THEN now() ELSE OLD.resolved_at END;
    NEW.closed_at := CASE WHEN NEW.status = 'closed' THEN now() ELSE OLD.closed_at END;
    INSERT INTO public.status_history (complaint_id, status, changed_by, note) VALUES (NEW.id, NEW.status, actor, NEW.resolution_notes);
    INSERT INTO public.notifications (user_id, complaint_id, title, message) VALUES (NEW.student_id, NEW.id, 'Status updated', NEW.ticket_number || ' is now ' || replace(initcap(NEW.status::text), '_', ' ') || '.');
    INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, details) VALUES (actor, 'complaint.status_changed', 'complaint', NEW.id, jsonb_build_object('from', OLD.status, 'to', NEW.status));
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER complaint_lifecycle BEFORE INSERT OR UPDATE ON public.complaints FOR EACH ROW EXECUTE FUNCTION public.log_and_notify_complaint();

CREATE OR REPLACE FUNCTION public.handle_assignment() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE ticket text; owner_id uuid;
BEGIN
  UPDATE public.assignments SET is_current = false WHERE complaint_id = NEW.complaint_id AND id <> NEW.id AND is_current;
  UPDATE public.complaints SET status = 'assigned' WHERE id = NEW.complaint_id AND status = 'submitted';
  SELECT ticket_number, student_id INTO ticket, owner_id FROM public.complaints WHERE id = NEW.complaint_id;
  INSERT INTO public.notifications (user_id, complaint_id, title, message) VALUES (NEW.staff_id, NEW.complaint_id, 'New assignment', ticket || ' has been assigned to you.'), (owner_id, NEW.complaint_id, 'Staff assigned', 'A staff member has been assigned to ' || ticket || '.');
  INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, details) VALUES (NEW.assigned_by, 'complaint.assigned', 'complaint', NEW.complaint_id, jsonb_build_object('staff_id', NEW.staff_id));
  RETURN NEW;
END $$;
CREATE TRIGGER assignment_created AFTER INSERT ON public.assignments FOR EACH ROW EXECUTE FUNCTION public.handle_assignment();

CREATE OR REPLACE FUNCTION public.handle_feedback() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.complaints SET status = 'closed', closed_at = now() WHERE id = NEW.complaint_id AND status = 'verified';
  INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, details) VALUES (NEW.student_id, 'feedback.created', 'complaint', NEW.complaint_id, jsonb_build_object('rating', NEW.rating));
  RETURN NEW;
END $$;
CREATE TRIGGER feedback_created AFTER INSERT ON public.feedback FOR EACH ROW EXECUTE FUNCTION public.handle_feedback();

CREATE INDEX complaints_student_idx ON public.complaints(student_id, created_at DESC);
CREATE INDEX complaints_status_idx ON public.complaints(status, created_at DESC);
CREATE INDEX assignments_staff_idx ON public.assignments(staff_id, is_current);
CREATE INDEX history_complaint_idx ON public.status_history(complaint_id, created_at);
CREATE INDEX notifications_user_idx ON public.notifications(user_id, is_read, created_at DESC);
CREATE INDEX audit_created_idx ON public.audit_logs(created_at DESC);

INSERT INTO public.categories (id, name, description) VALUES
('10000000-0000-0000-0000-000000000001', 'Electrical', 'Power, lighting and electrical equipment'),
('10000000-0000-0000-0000-000000000002', 'Facilities', 'Buildings, furniture and maintenance'),
('10000000-0000-0000-0000-000000000003', 'IT & Wi-Fi', 'Internet, systems and campus technology'),
('10000000-0000-0000-0000-000000000004', 'Cleanliness', 'Cleaning, waste and sanitation'),
('10000000-0000-0000-0000-000000000005', 'Canteen', 'Food service and dining facilities'),
('10000000-0000-0000-0000-000000000006', 'Safety', 'Campus safety and security concerns');
INSERT INTO public.priorities (id, name, level, response_hours) VALUES
('20000000-0000-0000-0000-000000000001', 'Low', 1, 168),
('20000000-0000-0000-0000-000000000002', 'Medium', 2, 72),
('20000000-0000-0000-0000-000000000003', 'High', 3, 24),
('20000000-0000-0000-0000-000000000004', 'Urgent', 4, 4);

CREATE POLICY complaint_images_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'complaint-images' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY complaint_images_read ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'complaint-images' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.has_role(auth.uid(), 'admin') OR EXISTS (SELECT 1 FROM public.complaints c JOIN public.assignments a ON a.complaint_id = c.id WHERE c.image_path = name AND a.staff_id = auth.uid() AND a.is_current)));
CREATE POLICY complaint_images_delete ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'complaint-images' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.has_role(auth.uid(), 'admin')));

ALTER PUBLICATION supabase_realtime ADD TABLE public.complaints;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;