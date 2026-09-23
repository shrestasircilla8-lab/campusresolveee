# Campus Complaint Management System

## Build scope
- Create a responsive application with secure email/password and Google sign-in.
- Add full user profiles and three roles: Student, Staff, and Admin.
- Build role-specific dashboards and navigation while preserving the workflow in the supplied requirements.

## Student workflow
- Create complaints with category, priority, location, description, and an optional image.
- View and filter personal complaints, open complaint details, and track every status from Submitted to Closed.
- Receive live notifications for assignments and status changes.
- Verify resolved work, request reopening when needed, and submit feedback with a rating and comment.

## Staff workflow
- View only assigned complaints.
- Start work, add resolution notes, and move work through In Progress and Resolved.
- See assignment and status history.

## Admin workflow
- Review all complaints, filter/search them, assign or reassign staff, and manage users.
- Create, edit, enable, and disable categories and priority options.
- View operational reports by category, status, priority, and staff.
- Review a complete audit log of important actions.

## Data and security
- Store profiles, roles, complaints, assignments, status history, feedback, notifications, categories, priorities, and audit records in Lovable Cloud.
- Enforce role-based access in the database so users cannot bypass the interface.
- Use private image storage with owner/admin access rules.
- Enable live updates for complaints and notifications.
- Add validated inputs, safe file restrictions, timestamps, and indexes.

## Demo data and accounts
- Seed categories, priorities, sample complaints, notifications, history, feedback, and reporting data.
- Provide demo Student, Staff, and Admin sign-ins in the app.
- Seeded demo accounts will use clearly labeled non-production credentials.

## Design
- Create a focused campus service interface using navy, green, amber, and neutral semantic colors.
- Use compact navigation, clear status indicators, accessible forms, and mobile-friendly tables/cards.
- Treat the uploaded image as a requirements reference only, not an embedded image.

## Verification
- Test sign-in and role routing for all three demo accounts.
- Exercise complaint creation, image upload, assignment, status updates, verification, feedback, filters, CRUD management, reports, notifications, and audit history.
- Check desktop and mobile layouts, then run database security and application health checks.
