import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { AuthScreen } from "@/components/campus/auth-screen";

export const Route = createFileRoute("/")({
  head: () => ({ meta: [
    { title: "Campus Resolve — Complaint Management" },
    { name: "description", content: "Report, track, and resolve campus complaints with clear ownership and status updates." },
    { property: "og:title", content: "Campus Resolve" },
    { property: "og:description", content: "A transparent campus complaint management system." },
    { property: "og:type", content: "website" },
    { name: "twitter:card", content: "summary_large_image" },
  ] }),
  component: Index,
});

function Index() {
  const navigate = useNavigate();
  const [ready, setReady] = useState(false);
  useEffect(() => { void supabase.auth.getUser().then(({ data }) => {
    if (data.user) void navigate({ to: "/dashboard", replace: true });
    else setReady(true);
  }); }, [navigate]);
  return ready ? <AuthScreen /> : <div className="loading-screen">Checking your session…</div>;
}
