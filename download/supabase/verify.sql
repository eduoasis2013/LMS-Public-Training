-- =====================================================================
--  EDU OASIS LMS — verification queries
--  Run in Supabase SQL Editor AFTER applying schema.sql.
--  Every query should return rows / 'ok'.
-- =====================================================================

-- 1. Tables created (expect 18)
select count(*) as table_count
from information_schema.tables
where table_schema='public' and table_type='BASE TABLE';

-- 2. Enum types
select t.typname from pg_type t join pg_namespace n on n.oid=t.typnamespace
where n.nspname='public' and t.typtype='e' order by 1;

-- 3. RLS enabled on every public table (expect all true)
select relname, relrowsecurity as rls_on
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and relkind='r' order by relname;

-- 4. Helper functions
select public.is_staff() as staff_for_anon, public.is_admin() as admin_for_anon;

-- 5. Seed: app settings singleton
select jenama, micro_fee, pdpa_fail, pdpa_versi from public.app_settings where id=1;

-- 6. Seed: course categories (expect 6)
select nama from public.course_categories order by nama;

-- 7. Seed: published courses (expect 6)
select kod, tajuk, kategori_kursus, yuran_non_hrd, layak_tuntutan_etris
from public.courses where status_publish order by kod;

-- 8. Seed: instructors (expect 3)
select nama, kepakaran, status from public.instructors order by nama;

-- 9. Seed: sessions (expect 4)
select s.kluster, c.kod, s.tarikh_mula, s.status
from public.sessions s join public.courses c on c.id=s.course_id order by s.tarikh_mula;

-- 10. Trigger exists
select tgname from pg_trigger where tgname='on_auth_user_created';

-- =====================================================================
--  PROMOTE A USER TO SUPER_ADMIN (run after creating the auth user)
--  Step A: Dashboard → Authentication → Users → "Add user" (email + password),
--          tick "Auto Confirm User". This creates the auth.users row and,
--          via the trigger, a public.profiles row with role='PESERTA'.
--  Step B: replace the email below and run:
-- =====================================================================
-- update public.profiles
--    set role = 'SUPER_ADMIN'
--  where emel = 'superadmin@eduoasis.my';
