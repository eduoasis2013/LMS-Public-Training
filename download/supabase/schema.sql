-- =====================================================================
--  EDU OASIS LMS — Supabase / PostgreSQL schema
--  PRD v1.3: Latihan Awam NON-HRD & HRD Claimable (e-TRiS, HRD Corp)
--
--  HOW TO APPLY (from the Supabase Dashboard — no local tooling needed):
--    1. Open your project: https://supabase.com/dashboard/project/ehmkapncaoupgunzoxba
--    2. Left sidebar → SQL Editor → "+ New query"
--    3. Paste this entire file → Run (Ctrl+Enter).
--    4. Re-run any time — the file is idempotent (uses IF NOT EXISTS and
--       DROP POLICY IF EXISTS before each CREATE POLICY).
--
--  SCOPE (per product owner): katalog program, data jurulatih, pengguna &
--  peranan (admin), pendaftaran peserta, pengesahan bukti bayaran.
--  Invois rasmi TIDAK dijana di sini — diasingkan ke platform e-boss.
--  Fail ini TIDAK mengandungi sebarang kredensial / connection string.
-- =====================================================================

-- ---------- Extensions ----------
create extension if not exists pgcrypto;          -- gen_random_uuid()
create extension if not exists uuid-ossp;

-- ---------- Enums ----------
do $$ begin
  create type app_role as enum ('PESERTA','MAJIKAN','JURULATIH','ADMIN','KEWANGAN','SUPER_ADMIN');
exception when duplicate_object then null; end $$;

do $$ begin
  create type course_kursus as enum ('STANDARD','MICRO_SESSION');
exception when duplicate_object then null; end $$;

do $$ begin
  create type enrollment_status as enum ('BARU','MENUNGGU_BUKTI','BUKTI_DITERIMA','DISAHKAN','DITOLAK','SELESAI','HRD_PROSES');
exception when duplicate_object then null; end $$;

do $$ begin
  create type payment_status as enum ('MENUNGGU','DITERIMA','DISAHKAN','DITOLAK');
exception when duplicate_object then null; end $$;

do $$ begin
  create type session_status as enum ('akan datang','sedang berlangsung','tamat','penuh');
exception when duplicate_object then null; end $$;

do $$ begin
  create type cert_status as enum ('AKTIF','DIGANTUNG','DITARIK');
exception when duplicate_object then null; end $$;

-- ---------- Helper functions (RLS) ----------
-- SECURITY DEFINER so they can read profiles regardless of the caller's RLS.
create or replace function public.current_role()
returns app_role
language sql stable security definer set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_staff()
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce(public.current_role() in ('SUPER_ADMIN','ADMIN','KEWANGAN'), false);
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce(public.current_role() in ('SUPER_ADMIN','ADMIN'), false);
$$;

create or replace function public.is_super_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce(public.current_role() = 'SUPER_ADMIN', false);
$$;

-- ---------- Tables ----------
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  emel         text unique not null,
  nama         text not null default '',
  no_kp        text,
  telefon      text,
  jawatan      text,
  role         app_role not null default 'PESERTA',
  employer_id  uuid,
  pdpa_setuju  boolean not null default false,
  pdpa_versi   text,
  pdpa_ts      timestamptz,
  foto_url     text,
  created_at   timestamptz not null default now()
);

create table if not exists public.employers (
  id            uuid primary key default gen_random_uuid(),
  nama_syarikat text not null,
  no_ssm        text,
  id_hrd        text,
  created_at    timestamptz not null default now()
);

create table if not exists public.course_categories (
  id         uuid primary key default gen_random_uuid(),
  nama       text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.courses (
  id                  uuid primary key default gen_random_uuid(),
  kod                 text,
  tajuk               text not null,
  penerangan          text,
  kategori_id         uuid references public.course_categories(id) on delete set null,
  mod                 text,                                   -- Bersemuka / Dalam Talian Langsung / Kendiri / Hibrid
  kategori_kursus     course_kursus not null default 'STANDARD',
  yuran_non_hrd       numeric(12,2) not null default 0,
  yuran_hrd           numeric(12,2) not null default 0,
  micro_fee           numeric(12,2) not null default 50,
  layak_tuntutan_etris boolean not null default false,
  ambang_kehadiran    int not null default 80,
  skor_lulus          int not null default 70,
  status_publish      boolean not null default false,
  created_by          uuid references auth.users(id) on delete set null,
  created_at          timestamptz not null default now()
);

create table if not exists public.instructors (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users(id) on delete set null,
  nama       text not null,
  bio        text,
  kepakaran  text,
  status     text not null default 'AKTIF',     -- AKTIF / TIDAK_AKTIF
  created_at timestamptz not null default now()
);

create table if not exists public.sessions (
  id            uuid primary key default gen_random_uuid(),
  course_id     uuid not null references public.courses(id) on delete cascade,
  kluster       text,
  jurulatih_id  uuid references public.instructors(id) on delete set null,
  tarikh_mula   date,
  tarikh_tamat  date,
  tempat        text,
  kapasiti      int not null default 30,
  status        session_status not null default 'akan datang',
  created_at    timestamptz not null default now()
);

create table if not exists public.enrollments (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references auth.users(id) on delete cascade,
  session_id          uuid not null references public.sessions(id) on delete cascade,
  course_id           uuid not null references public.courses(id) on delete cascade,
  employer_id         uuid references public.employers(id) on delete set null,
  jalur_yuran         text not null default 'NON_HRD',   -- NON_HRD / HRD
  yuran_dikenakan     numeric(12,2) not null default 0,
  status_pendaftaran  enrollment_status not null default 'MENUNGGU_BUKTI',
  status_bayaran      payment_status not null default 'MENUNGGU',
  kehadiran_peratus   int not null default 0,
  skor_akhir          numeric(5,2),
  lulus               boolean,
  created_at          timestamptz not null default now(),
  unique (user_id, session_id)
);

create table if not exists public.payment_proofs (
  id                  uuid primary key default gen_random_uuid(),
  enrollment_ids      uuid[] not null default '{}',
  user_id             uuid references auth.users(id) on delete cascade,
  employer_id         uuid references public.employers(id) on delete set null,
  nama_fail           text not null,
  tarikh_bayar        date,
  jumlah              numeric(12,2) not null default 0,
  kaedah              text,                -- Pindahan Bank/IBG, FPX, Cek, Lain-lain
  rujukan_transaksi   text,
  status              payment_status not null default 'DITERIMA',
  disemak_oleh        text,
  sebab_tolak         text,
  created_at          timestamptz not null default now()
);

create table if not exists public.hrd_requests (
  id            uuid primary key default gen_random_uuid(),
  employer_id   uuid references public.employers(id) on delete cascade,
  session_id    uuid references public.sessions(id) on delete cascade,
  no_rujukan    text,
  status        text not null default 'Permintaan Baharu',
  created_at    timestamptz not null default now()
);

create table if not exists public.claim_cases (
  id             uuid primary key default gen_random_uuid(),
  hrd_request_id uuid references public.hrd_requests(id) on delete cascade,
  status         text not null default 'Belum Bermula',
  created_at     timestamptz not null default now()
);

create table if not exists public.certificates (
  id              uuid primary key default gen_random_uuid(),
  enrollment_id   uuid not null references public.enrollments(id) on delete cascade,
  user_id         uuid references auth.users(id) on delete cascade,
  no_sijil        text unique,
  kod_pengesahan  text,
  versi_templat   text,
  status          cert_status not null default 'AKTIF',
  issued_at       timestamptz not null default now()
);

create table if not exists public.trainer_documents (
  id             uuid primary key default gen_random_uuid(),
  instructor_id  uuid not null references public.instructors(id) on delete cascade,
  jenis          text,                  -- Sijil, Kontrak, resume, dll.
  nama_fail      text,
  status         text not null default 'DIPROSES',
  created_at     timestamptz not null default now()
);

create table if not exists public.trainer_bank_accounts (
  id              uuid primary key default gen_random_uuid(),
  instructor_id   uuid not null references public.instructors(id) on delete cascade,
  bank            text,
  nama_pemegang   text,
  no_akaun        text,
  tarikh_kemaskini timestamptz not null default now()
);

create table if not exists public.feedback_responses (
  id            uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.enrollments(id) on delete cascade,
  penilaian     int,                    -- 1..5
  ulasan        text,
  created_at    timestamptz not null default now()
);

create table if not exists public.feedback_reports (
  id         uuid primary key default gen_random_uuid(),
  session_id uuid references public.sessions(id) on delete cascade,
  status     text not null default 'Dianalisis',   -- Dianalisis / Dalam Semakan Admin / Selesai
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid,
  user_name  text,
  action     text,
  entity     text,
  entity_id  text,
  detail     text,
  ts         timestamptz not null default now()
);

create table if not exists public.pdpa_consents (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  versi      text,
  ts         timestamptz not null default now()
);

-- Singleton row for system settings (id fixed so seed can upsert).
create table if not exists public.app_settings (
  id                 int primary key default 1,
  jenama             text not null default 'Edu Oasis',
  micro_fee          numeric(12,2) not null default 50,
  sst_rate           numeric(5,4) not null default 0,
  ambang_kehadiran   int not null default 80,
  skor_lulus_default int not null default 70,
  tempat_dipegang_hari int not null default 7,
  tempoh_respons_bayaran int not null default 3,
  bank_edu           jsonb not null default '{"bank":"Maybank Berhad","namaPemegang":"Edu Oasis Training Sdn Bhd","noAkaun":"5128 0010 2233"}'::jsonb,
  dasar_pembatalan   text,
  pdpa_fail          text not null default 'PDPA_Notis_Edu_Oasis.pdf',
  pdpa_versi         text not null default 'v1.0',
  pdpa_tarikh        text not null default '16 Nov 2026',
  constraint app_settings_singleton check (id = 1)
);

-- ---------- Foreign key: profiles.employer_id ----------
do $$ begin
  alter table public.profiles
    add constraint profiles_employer_fk
    foreign key (employer_id) references public.employers(id) on delete set null;
exception when duplicate_object then null;
end $$;

-- ---------- Trigger: auto-create profile on signup ----------
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, emel, nama, role, pdpa_setuju)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'nama', ''),
    coalesce((new.raw_user_meta_data->>'role')::app_role, 'PESERTA'),
    coalesce((new.raw_user_meta_data->>'pdpa_setuju')::boolean, false)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------- Indexes ----------
create unique index if not exists uidx_courses_kod        on public.courses(kod) where kod is not null;
create unique index if not exists uidx_sessions_key        on public.sessions(course_id, kluster, tarikh_mula);
create index if not exists idx_profiles_role        on public.profiles(role);
create index if not exists idx_courses_kategori     on public.courses(kategori_id);
create index if not exists idx_courses_publish      on public.courses(status_publish);
create index if not exists idx_sessions_course      on public.sessions(course_id);
create index if not exists idx_enroll_user          on public.enrollments(user_id);
create index if not exists idx_enroll_session       on public.enrollments(session_id);
create index if not exists idx_enroll_status        on public.enrollments(status_pendaftaran);
create index if not exists idx_payments_user        on public.payment_proofs(user_id);
create index if not exists idx_payments_status      on public.payment_proofs(status);
create index if not exists idx_certs_enrollment     on public.certificates(enrollment_id);
create index if not exists idx_audit_ts             on public.audit_logs(ts desc);

-- =====================================================================
--  ROW LEVEL SECURITY
-- =====================================================================
alter table public.profiles               enable row level security;
alter table public.employers              enable row level security;
alter table public.course_categories     enable row level security;
alter table public.courses               enable row level security;
alter table public.instructors           enable row level security;
alter table public.sessions              enable row level security;
alter table public.enrollments           enable row level security;
alter table public.payment_proofs        enable row level security;
alter table public.hrd_requests          enable row level security;
alter table public.claim_cases           enable row level security;
alter table public.certificates          enable row level security;
alter table public.trainer_documents     enable row level security;
alter table public.trainer_bank_accounts enable row level security;
alter table public.feedback_responses    enable row level security;
alter table public.feedback_reports      enable row level security;
alter table public.audit_logs            enable row level security;
alter table public.pdpa_consents         enable row level security;
alter table public.app_settings          enable row level security;

-- helper: drop+create policy
-- profiles
drop policy if exists profiles_select_own_or_staff on public.profiles;
create policy profiles_select_own_or_staff on public.profiles
  for select using (id = auth.uid() or public.is_staff());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists profiles_staff_manage on public.profiles;
create policy profiles_staff_manage on public.profiles
  for all using (public.is_staff()) with check (public.is_staff());

-- employers: staff read/write; peserta read (for HRD context)
drop policy if exists employers_read on public.employers;
create policy employers_read on public.employers
  for select using (true);

drop policy if exists employers_staff_manage on public.employers;
create policy employers_staff_manage on public.employers
  for all using (public.is_staff()) with check (public.is_staff());

-- course_categories: public read, staff manage
drop policy if exists categories_read on public.course_categories;
create policy categories_read on public.course_categories
  for select using (true);

drop policy if exists categories_staff_manage on public.course_categories;
create policy categories_staff_manage on public.course_categories
  for all using (public.is_staff()) with check (public.is_staff());

-- courses: published courses public; unpublished staff-only; staff manage
drop policy if exists courses_read on public.courses;
create policy courses_read on public.courses
  for select using (status_publish = true or public.is_staff());

drop policy if exists courses_staff_manage on public.courses;
create policy courses_staff_manage on public.courses
  for all using (public.is_staff()) with check (public.is_staff());

-- instructors: public read (catalog), staff/trainer manage
drop policy if exists instructors_read on public.instructors;
create policy instructors_read on public.instructors
  for select using (status = 'AKTIF' or public.is_staff() or user_id = auth.uid());

drop policy if exists instructors_manage on public.instructors;
create policy instructors_manage on public.instructors
  for all using (public.is_staff() or user_id = auth.uid())
  with check (public.is_staff() or user_id = auth.uid());

-- sessions: public read (catalog), staff manage
drop policy if exists sessions_read on public.sessions;
create policy sessions_read on public.sessions
  for select using (true);

drop policy if exists sessions_staff_manage on public.sessions;
create policy sessions_staff_manage on public.sessions
  for all using (public.is_staff()) with check (public.is_staff());

-- enrollments: owner OR their employer's HR OR staff
drop policy if exists enroll_select on public.enrollments;
create policy enroll_select on public.enrollments
  for select using (
    user_id = auth.uid()
    or public.is_staff()
    or (
      public.current_role() = 'MAJIKAN'
      and employer_id in (select employer_id from public.profiles where id = auth.uid())
    )
  );

drop policy if exists enroll_insert on public.enrollments;
create policy enroll_insert on public.enrollments
  for insert with check (
    user_id = auth.uid()
    or (
      public.current_role() = 'MAJIKAN'
      and employer_id in (select employer_id from public.profiles where id = auth.uid())
    )
    or public.is_staff()
  );

drop policy if exists enroll_update on public.enrollments;
create policy enroll_update on public.enrollments
  for update using (public.is_staff() or user_id = auth.uid())
  with check (true);

drop policy if exists enroll_delete on public.enrollments;
create policy enroll_delete on public.enrollments
  for delete using (public.is_staff());

-- payment_proofs: owner insert/read; KEWANGAN/ADMIN verify
drop policy if exists pay_select on public.payment_proofs;
create policy pay_select on public.payment_proofs
  for select using (
    user_id = auth.uid() or public.is_staff()
    or (
      public.current_role() = 'MAJIKAN'
      and employer_id in (select employer_id from public.profiles where id = auth.uid())
    )
  );

drop policy if exists pay_insert on public.payment_proofs;
create policy pay_insert on public.payment_proofs
  for insert with check (user_id = auth.uid() or public.is_staff());

drop policy if exists pay_update on public.payment_proofs;
create policy pay_update on public.payment_proofs
  for update using (public.is_staff()) with check (public.is_staff());

-- hrd_requests / claim_cases: staff + MAJIKAN (own employer)
drop policy if exists hrd_select on public.hrd_requests;
create policy hrd_select on public.hrd_requests
  for select using (
    public.is_staff()
    or (
      public.current_role() = 'MAJIKAN'
      and employer_id in (select employer_id from public.profiles where id = auth.uid())
    )
  );

drop policy if exists hrd_manage on public.hrd_requests;
create policy hrd_manage on public.hrd_requests
  for all using (public.is_staff())
  with check (public.is_staff());

drop policy if exists claims_select on public.claim_cases;
create policy claims_select on public.claim_cases
  for select using (public.is_staff());

drop policy if exists claims_manage on public.claim_cases;
create policy claims_manage on public.claim_cases
  for all using (public.is_staff()) with check (public.is_staff());

-- certificates: owner read; staff manage
drop policy if exists certs_select on public.certificates;
create policy certs_select on public.certificates
  for select using (user_id = auth.uid() or public.is_staff());

drop policy if exists certs_manage on public.certificates;
create policy certs_manage on public.certificates
  for all using (public.is_staff()) with check (public.is_staff());

-- trainer_documents / trainer_bank_accounts: trainer (own) or staff
drop policy if exists tdocs_select on public.trainer_documents;
create policy tdocs_select on public.trainer_documents
  for select using (
    public.is_staff()
    or instructor_id in (select id from public.instructors where user_id = auth.uid())
  );

drop policy if exists tdocs_manage on public.trainer_documents;
create policy tdocs_manage on public.trainer_documents
  for all using (
    public.is_staff()
    or instructor_id in (select id from public.instructors where user_id = auth.uid())
  )
  with check (
    public.is_staff()
    or instructor_id in (select id from public.instructors where user_id = auth.uid())
  );

drop policy if exists tbank_select on public.trainer_bank_accounts;
create policy tbank_select on public.trainer_bank_accounts
  for select using (
    public.is_staff()
    or instructor_id in (select id from public.instructors where user_id = auth.uid())
  );

drop policy if exists tbank_manage on public.trainer_bank_accounts;
create policy tbank_manage on public.trainer_bank_accounts
  for all using (
    public.is_staff()
    or instructor_id in (select id from public.instructors where user_id = auth.uid())
  )
  with check (
    public.is_staff()
    or instructor_id in (select id from public.instructors where user_id = auth.uid())
  );

-- feedback_responses: owner insert/read; staff read; reports staff-only
drop policy if exists fb_select on public.feedback_responses;
create policy fb_select on public.feedback_responses
  for select using (
    enrollment_id in (select id from public.enrollments where user_id = auth.uid())
    or public.is_staff()
  );

drop policy if exists fb_insert on public.feedback_responses;
create policy fb_insert on public.feedback_responses
  for insert with check (
    enrollment_id in (select id from public.enrollments where user_id = auth.uid())
  );

drop policy if exists freports_staff on public.feedback_reports;
create policy freports_staff on public.feedback_reports
  for all using (public.is_staff()) with check (public.is_staff());

-- audit_logs: staff read only (no direct insert via API; backend/logs writes via service role)
drop policy if exists audit_staff_read on public.audit_logs;
create policy audit_staff_read on public.audit_logs
  for select using (public.is_staff());

-- pdpa_consents: owner read; staff read
drop policy if exists pdpa_select on public.pdpa_consents;
create policy pdpa_select on public.pdpa_consents
  for select using (user_id = auth.uid() or public.is_staff());

drop policy if exists pdpa_insert on public.pdpa_consents;
create policy pdpa_insert on public.pdpa_consents
  for insert with check (user_id = auth.uid());

-- app_settings: public read (catalog needs micro_fee etc.); staff update
drop policy if exists settings_read on public.app_settings;
create policy settings_read on public.app_settings
  for select using (true);

drop policy if exists settings_staff_update on public.app_settings;
create policy settings_staff_update on public.app_settings
  for update using (public.is_staff()) with check (public.is_staff());

-- =====================================================================
--  SEED DATA
-- =====================================================================
insert into public.app_settings (id) values (1)
  on conflict (id) do nothing;

insert into public.course_categories (nama)
select * from (values
  ('Kemahiran Digital'),
  ('Kepimpinan'),
  ('Keselamatan & Kesihatan Pekerjaan'),
  ('Komunikasi'),
  ('Pemasaran'),
  ('Kewangan')
) as v(nama)
on conflict (nama) do nothing;

-- Sample employers (HRD Corp)
insert into public.employers (id, nama_syarikat, no_ssm, id_hrd)
select * from (values
  ('11111111-1111-1111-1111-111111111101'::uuid, 'Tech Solutions Sdn Bhd',           '201801023456 (1234567-A)', 'HRD-2021-001122'),
  ('11111111-1111-1111-1111-111111111102'::uuid, 'Greenfield Manufacturing Sdn Bhd', '201903087654 (9876543-W)', 'HRD-2019-004455'),
  ('11111111-1111-1111-1111-111111111103'::uuid, 'Capital Bank Berhad',              '197001000012 (1234-H)',    'HRD-2015-009988')
) as v(id, nama_syarikat, no_ssm, id_hrd)
on conflict (id) do nothing;

-- Sample courses (published)
insert into public.courses
  (kod, tajuk, penerangan, kategori_id, mod, kategori_kursus, yuran_non_hrd, yuran_hrd, micro_fee, layak_tuntutan_etris, ambang_kehadiran, skor_lulus, status_publish)
select
  v.kod, v.tajuk, v.penerangan, c.id, v.mod, v.kk, v.ynh, v.yh, v.mf, v.etris, 80, 70, true
from (values
  ('EO-DIG-101','Microsoft Excel Power Query — Micro-Session','Sesi pantas Power Query: import, transform dan gabung data dalam 3 jam.','Kemahiran Digital','Dalam Talian Langsung','MICRO_SESSION', 50.00, 50.00, 50.00, false),
  ('EO-DIG-201','Pengaturcaraan Python untuk Pemula','Asas Python: sintaks, struktur data, fungsi dan automasi ringkas.','Kemahiran Digital','Bersemuka','STANDARD', 800.00, 1200.00, 50.00, true),
  ('EO-LDR-101','Kepimpinan Efektif untuk Penyelia','Kemahiran menyelia, delegasi dan motivasi pasukan.','Kepimpinan','Hibrid','STANDARD', 900.00, 1400.00, 50.00, true),
  ('EO-OSH-101','Keselamatan & Kesihatan Pekerjaan (OSH)','Pengurusan risiko, HIRARC dan pematuhan OSHA 1994.','Keselamatan & Kesihatan Pekerjaan','Bersemuka','STANDARD', 1100.00, 1600.00, 50.00, true),
  ('EO-COM-101','Komunikasi Profesif & Pembentangan','Struktur mesej, storytelling dan teknik pembentangan berkesan.','Komunikasi','Dalam Talian Langsung','STANDARD', 700.00, 1000.00, 50.00, true),
  ('EO-MKT-301','Pemasaran Digital & Media Sosial','SEO, SEM, pengurusan kandungan dan analitik kempen.','Pemasaran','Hibrid','STANDARD', 1000.00, 1500.00, 50.00, true)
) as v(kod, tajuk, penerangan, kat, mod, kk, ynh, yh, mf, etris)
join public.course_categories c on c.nama = v.kat
on conflict (kod) do nothing;

-- Sample instructors
insert into public.instructors (id, nama, bio, kepakaran, status)
select * from (values
  ('22222222-2222-2222-2222-222222222201'::uuid, 'Aiman Fauzi','Jurulatih kanan data & automasi.','Data & Automasi','AKTIF'),
  ('22222222-2222-2222-2222-222222222202'::uuid, 'Saraswathy Nair','Konsultan kepimpinan & HRD.','Kepimpinan','AKTIF'),
  ('22222222-2222-2222-2222-222222222203'::uuid, 'Daniel Tan','Pakar pemasaran digital.','Pemasaran Digital','AKTIF')
) as v(id, nama, bio, kepakaran, status)
on conflict (id) do nothing;

-- Sample sessions for the courses above
insert into public.sessions (course_id, kluster, jurulatih_id, tarikh_mula, tarikh_tamat, tempat, kapasiti, status)
select c.id, v.kluster, i.id, v.tm, v.tt, v.tempat, v.kap, v.st::session_status
from (values
  ('EO-DIG-101','Kluster A','22222222-2222-2222-2222-222222222201'::uuid, '2026-12-05'::date,'2026-12-05'::date,'Online via Zoom',50,'akan datang'),
  ('EO-DIG-201','Kluster B','22222222-2222-2222-2222-222222222201'::uuid, '2026-12-10'::date,'2026-12-12'::date,'Edu Oasis Training Centre, KL Sentral',25,'akan datang'),
  ('EO-LDR-101','Kluster C','22222222-2222-2222-2222-222222222202'::uuid, '2026-12-15'::date,'2026-12-16'::date,'Sunway Putra Hotel, KL',20,'akan datang'),
  ('EO-OSH-101','Kluster D','22222222-2222-2222-2222-222222222202'::uuid, '2027-01-07'::date,'2027-01-09'::date,'Hotel Hilton Kuala Lumpur',30,'akan datang')
) as v(kod, kluster, jid, tm, tt, tempat, kap, st)
join public.courses c on c.kod = v.kod
left join public.instructors i on i.id = v.jid
on conflict (course_id, kluster, tarikh_mula) do nothing;

-- =====================================================================
--  DONE. Verify with:
--    select count(*) from information_schema.tables where table_schema='public';
--    select tajuk, yuran_non_hrd, layak_tuntutan_etris from public.courses where status_publish;
--    select nama, kepakaran from public.instructors;
-- =====================================================================
