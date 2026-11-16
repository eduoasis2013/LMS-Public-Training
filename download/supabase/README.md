# Edu Oasis LMS — Supabase Database Setup

Database schema for the Edu Oasis LMS (PRD v1.3): Latihan Awam NON-HRD & HRD
Claimable (e-TRiS / HRD Corp). Scope: course catalog, trainer data, users &
roles (admin), participant registration, payment-proof verification.
**Invoicing is intentionally out of scope** (handled by e-boss).

> **No credentials live in this repo.** This file contains only the schema,
> RLS policies, and seed data. Never commit the project URL, publishable key,
> or connection string.

## 1. Apply the schema (Supabase Dashboard — no local tooling needed)

1. Open the project: <https://supabase.com/dashboard/project/ehmkapncaoupgunzoxba>
2. Left sidebar → **SQL Editor** → **+ New query**.
3. Open [`schema.sql`](./schema.sql), copy the **entire** file, paste into the editor.
4. Click **Run** (Ctrl+Enter). It is idempotent — safe to re-run.
5. Open [`verify.sql`](./verify.sql), paste, **Run**. Every query should return
   rows (`table_count = 18`, 6 categories, 6 published courses, 3 instructors,
   4 sessions, `rls_on = true` for every table).

This creates:

| Area | Tables |
|---|---|
| Identity | `profiles` (extends `auth.users`, auto-created on signup via trigger) |
| Employers | `employers` |
| Catalog | `course_categories`, `courses`, `instructors`, `sessions` |
| Registration | `enrollments`, `payment_proofs` |
| HRD / e-TRiS | `hrd_requests`, `claim_cases` |
| Outcomes | `certificates`, `feedback_responses`, `feedback_reports` |
| Trainers | `trainer_documents`, `trainer_bank_accounts` |
| System | `app_settings`, `audit_logs`, `pdpa_consents` |

…plus 6 enum types, helper functions (`is_staff()`, `is_admin()`,
`current_role()`), indexes, and **Row Level Security** policies on every table.

## 2. Create the Super Admin

1. Dashboard → **Authentication** → **Users** → **Add user**.
2. Enter email + password, tick **Auto Confirm User**, click **Create**.
   The `on_auth_user_created` trigger auto-creates a `profiles` row with
   `role = 'PESERTA'`.
3. In **SQL Editor**, run (replace the email):
   ```sql
   update public.profiles set role = 'SUPER_ADMIN' where emel = 'you@eduoasis.my';
   ```
4. Log in to the LMS with that email/password → you land on the Super Admin
   dashboard.

Repeat for `ADMIN`, `KEWANGAN`, `JURULATIH`, `MAJIKAN`, `PESERTA` as needed
(promote via the same `update`, or via the Super Admin **Pengguna & Peranan**
page once the frontend is wired to Supabase).

## 3. RLS at a glance

- **Public (anon key)**: read published courses, categories, sessions,
  instructors (active), `app_settings`.
- **Peserta**: own enrollments + payment proofs; insert enrollments & proofs;
  own certificates & feedback.
- **Majikan (HR)**: own employees' enrollments/proofs/HRD requests for their
  employer.
- **Jurulatih**: own instructor profile, documents, bank account, sessions.
- **Admin / Super Admin**: full catalog, sessions, enrollments, HRD, trainers.
- **Kewangan**: read all enrollments/proofs; verify (update) payment proofs.
- **Audit logs**: staff read-only (writes happen via the service-role key from
  the backend, never the publishable key).

## 4. Why this wasn't applied from the build sandbox

The Supabase **direct** connection host (`db.<ref>.supabase.co`) is **IPv6-only**
on this project, and the **Supavisor connection pooler** tenant
(`postgres.<ref> @ aws-0-<region>.pooler.supabase.com`) is **not yet
provisioned**, so there is no IPv4 Postgres path from the IPv4-only build
sandbox. Applying via the Dashboard SQL Editor avoids that entirely.

To enable a direct IPv4 path later (optional — only needed if you want to run
`psql`/migrations from a CI box without IPv6):

1. Dashboard → **Project Settings** → **Database** → **Connection pooling**.
2. Enable **Supavisor** (session or transaction mode). Supabase provisions the
   `postgres.<ref>@aws-0-<region>.pooler.supabase.com:6543` tenant.
3. Copy the **Connection pooling** string (IPv4) and use it for `psql`/migrations.
   The direct string in this repo's `.env` stays for IPv6-capable hosts only.

## 5. Next: wire the LMS frontend to Supabase

The browser→Supabase REST path (`https://ehmkapncaoupgunzoxba.supabase.co`) is
reachable over IPv4, so the frontend can use the Supabase JS client with the
**publishable key** for all data + auth. That integration is a separate task
and will replace the in-memory dummy backend in `download/edu-oasis-lms.html`
with live Supabase calls (same UI, same roles, same glassmorphism).
