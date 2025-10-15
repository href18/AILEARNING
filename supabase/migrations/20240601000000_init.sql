-- Initial schema for compliance training platform
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

create table public.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  billing_plan text not null default 'per_seat',
  created_at timestamptz not null default now()
);

create table public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  full_name text,
  preferred_locale text check (preferred_locale in ('nb', 'en')) default 'nb',
  created_at timestamptz not null default now()
);

create table public.org_members (
  org_id uuid references public.orgs(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  role text check (role in ('participant','admin','author','super_admin')) not null,
  invited_at timestamptz not null default now(),
  primary key (org_id, user_id)
);

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  status text check (status in ('draft','published')) not null default 'draft',
  duration_minutes int,
  certificate_valid_months int default 12,
  created_by uuid references public.users(id),
  created_at timestamptz not null default now()
);

create table public.course_i18n (
  course_id uuid references public.courses(id) on delete cascade,
  locale text check (locale in ('nb','en')),
  title text not null,
  summary text not null,
  primary key (course_id, locale)
);

create table public.modules (
  id uuid primary key default gen_random_uuid(),
  course_id uuid references public.courses(id) on delete cascade,
  type text check (type in ('video','article','quiz','simulation')) not null,
  position int not null,
  duration_seconds int,
  constraint modules_position_unique unique (course_id, position)
);

create table public.module_i18n (
  module_id uuid references public.modules(id) on delete cascade,
  locale text check (locale in ('nb','en')),
  title text not null,
  body_md text,
  video_url text,
  simulation_json jsonb,
  primary key (module_id, locale)
);

create table public.quizzes (
  id uuid primary key default gen_random_uuid(),
  module_id uuid references public.modules(id) on delete cascade,
  passing_score int not null default 80,
  shuffle boolean not null default true
);

create table public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid references public.quizzes(id) on delete cascade,
  body text not null,
  type text check (type in ('single','multi')) not null,
  explanation text
);

create table public.quiz_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid references public.quiz_questions(id) on delete cascade,
  body text not null,
  is_correct boolean not null default false
);

create table public.assignments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.orgs(id) on delete cascade,
  course_id uuid references public.courses(id) on delete cascade,
  assigned_by uuid references public.users(id),
  assigned_to uuid references public.users(id),
  due_at timestamptz,
  status text check (status in ('assigned','in_progress','completed','overdue','expired')) not null default 'assigned',
  created_at timestamptz not null default now()
);

create table public.progress (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid references public.assignments(id) on delete cascade,
  module_id uuid references public.modules(id) on delete cascade,
  completed_at timestamptz,
  last_position_seconds int,
  score int,
  attempts int not null default 0,
  unique (assignment_id, module_id)
);

create table public.certificates (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid references public.assignments(id) on delete cascade,
  issued_at timestamptz not null default now(),
  expires_at timestamptz,
  certificate_url text,
  unique (assignment_id)
);

create table public.audit_logs (
  id bigserial primary key,
  org_id uuid references public.orgs(id),
  actor uuid references public.users(id),
  action text not null,
  subject text,
  meta jsonb,
  created_at timestamptz not null default now()
);

create table public.reminders (
  id bigserial primary key,
  assignment_id uuid references public.assignments(id) on delete cascade,
  reminder_type text check (reminder_type in ('due_7','due_3','due_1','expiry_30','expiry_7','expiry_1')),
  sent_at timestamptz not null default now()
);

create index on public.assignments (assigned_to, status);
create index on public.assignments (org_id, course_id);
create index on public.progress (assignment_id);
create index on public.progress (module_id);
create index on public.audit_logs (org_id, created_at);
create index on public.certificates (expires_at);

alter table public.users enable row level security;
alter table public.orgs enable row level security;
alter table public.org_members enable row level security;
alter table public.courses enable row level security;
alter table public.course_i18n enable row level security;
alter table public.modules enable row level security;
alter table public.module_i18n enable row level security;
alter table public.quizzes enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_options enable row level security;
alter table public.assignments enable row level security;
alter table public.progress enable row level security;
alter table public.certificates enable row level security;
alter table public.audit_logs enable row level security;

-- Simplified policies (to be refined per project requirements)
create policy "Allow authenticated read" on public.courses
  for select using (auth.role() = 'authenticated');

create policy "Allow authenticated read" on public.modules
  for select using (auth.role() = 'authenticated');

create policy "Allow authenticated read" on public.module_i18n
  for select using (auth.role() = 'authenticated');

create policy "Allow authenticated read" on public.quizzes
  for select using (auth.role() = 'authenticated');

create policy "Allow authenticated read" on public.quiz_questions
  for select using (auth.role() = 'authenticated');

create policy "Allow authenticated read" on public.quiz_options
  for select using (auth.role() = 'authenticated');
