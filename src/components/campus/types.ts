export type Role = "student" | "staff" | "admin";
export type Status = "submitted" | "assigned" | "in_progress" | "resolved" | "verified" | "closed";
export interface Profile { id: string; email: string; display_name: string; department: string | null; is_active: boolean }
export interface Lookup { id: string; name: string; is_active: boolean; description?: string | null; level?: number; response_hours?: number }
export interface Complaint { id: string; ticket_number: string; student_id: string; category_id: string; priority_id: string; title: string; description: string; location: string; image_path: string | null; status: Status; resolution_notes: string | null; created_at: string; categories?: { name: string } | null; priorities?: { name: string; level: number } | null; assignments?: Array<{ staff_id: string; is_current: boolean; profiles?: { display_name: string } | null }> }
export interface Notice { id: string; title: string; message: string; complaint_id: string | null; is_read: boolean; created_at: string }
export interface History { id: string; status: Status; note: string | null; created_at: string; changed_by: string }
export const statusOrder: Status[] = ["submitted", "assigned", "in_progress", "resolved", "verified", "closed"];
export const statusLabel: Record<Status, string> = { submitted: "Submitted", assigned: "Assigned", in_progress: "In progress", resolved: "Resolved", verified: "Verified", closed: "Closed" };
