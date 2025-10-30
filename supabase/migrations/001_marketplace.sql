-- Marketplace schema migration
begin;

-- Extensions
create extension if not exists "uuid-ossp";
create extension if not exists pgcrypto;

-- Enumerations
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('student','creator','admin');
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'purchase_status') THEN
        CREATE TYPE purchase_status AS ENUM ('requires_payment','paid','refunded','failed');
    END IF;
END $$;

-- Tables
create table if not exists profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    display_name text not null,
    role user_role not null default 'student',
    created_at timestamptz not null default now()
);

create table if not exists courses (
    id uuid primary key default uuid_generate_v4(),
    creator_id uuid not null references profiles(id) on delete cascade,
    title text not null,
    slug text not null unique,
    description text,
    price_cents integer not null default 0,
    currency text not null default 'usd',
    is_published boolean not null default false,
    thumbnail_url text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists modules (
    id uuid primary key default uuid_generate_v4(),
    course_id uuid not null references courses(id) on delete cascade,
    title text not null,
    order_index integer not null default 0,
    required boolean not null default true,
    passing_score integer,
    created_at timestamptz not null default now()
);

create table if not exists lessons (
    id uuid primary key default uuid_generate_v4(),
    module_id uuid not null references modules(id) on delete cascade,
    title text not null,
    order_index integer not null default 0,
    content_url text,
    quiz_json jsonb,
    created_at timestamptz not null default now()
);

create table if not exists prerequisites (
    id uuid primary key default uuid_generate_v4(),
    course_id uuid not null references courses(id) on delete cascade,
    required_course_id uuid references courses(id) on delete cascade,
    required_module_id uuid references modules(id) on delete cascade,
    constraint prerequisites_xor check ((required_course_id is null) <> (required_module_id is null))
);

create table if not exists purchases (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references profiles(id) on delete cascade,
    course_id uuid not null references courses(id) on delete cascade,
    stripe_payment_intent text,
    amount_cents integer not null,
    currency text not null default 'usd',
    status purchase_status not null default 'requires_payment',
    created_at timestamptz not null default now(),
    constraint purchases_user_course_unique unique (user_id, course_id)
);

create table if not exists enrollments (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references profiles(id) on delete cascade,
    course_id uuid not null references courses(id) on delete cascade,
    created_at timestamptz not null default now(),
    constraint enrollments_user_course_unique unique (user_id, course_id)
);

create table if not exists progress (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references profiles(id) on delete cascade,
    lesson_id uuid not null references lessons(id) on delete cascade,
    is_completed boolean not null default false,
    score integer,
    completed_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint progress_user_lesson_unique unique (user_id, lesson_id)
);

create table if not exists certificates (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references profiles(id) on delete cascade,
    course_id uuid not null references courses(id) on delete cascade,
    issued_at timestamptz not null default now(),
    pdf_url text,
    constraint certificates_user_course_unique unique (user_id, course_id)
);

create table if not exists webhook_endpoints (
    id uuid primary key default uuid_generate_v4(),
    owner_id uuid not null references profiles(id) on delete cascade,
    url text not null,
    description text,
    secret text not null,
    is_active boolean not null default true,
    event_types text[] not null default array['module.completed','course.completed']
);

create table if not exists webhook_events (
    id uuid primary key default uuid_generate_v4(),
    event_type text not null,
    payload jsonb not null,
    attempts integer not null default 0,
    last_error text,
    delivered_at timestamptz,
    created_at timestamptz not null default now()
);

-- Optional nice-to-have tables
create table if not exists coupons (
    id uuid primary key default uuid_generate_v4(),
    code text not null unique,
    description text,
    discount_percent integer,
    expires_at timestamptz,
    max_redemptions integer,
    created_at timestamptz not null default now()
);

create table if not exists bundles (
    id uuid primary key default uuid_generate_v4(),
    title text not null,
    description text,
    price_cents integer not null,
    currency text not null default 'usd',
    created_at timestamptz not null default now()
);

create table if not exists bundle_courses (
    bundle_id uuid not null references bundles(id) on delete cascade,
    course_id uuid not null references courses(id) on delete cascade,
    primary key (bundle_id, course_id)
);

create table if not exists reviews (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references profiles(id) on delete cascade,
    course_id uuid not null references courses(id) on delete cascade,
    rating integer not null check (rating between 1 and 5),
    comment text,
    created_at timestamptz not null default now(),
    constraint reviews_unique unique (user_id, course_id)
);

create table if not exists learning_paths (
    id uuid primary key default uuid_generate_v4(),
    title text not null,
    description text,
    created_by uuid references profiles(id) on delete set null,
    created_at timestamptz not null default now()
);

create table if not exists learning_path_courses (
    path_id uuid not null references learning_paths(id) on delete cascade,
    course_id uuid not null references courses(id) on delete cascade,
    order_index integer not null default 0,
    primary key (path_id, course_id)
);

create table if not exists reminders (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid not null references profiles(id) on delete cascade,
    course_id uuid references courses(id) on delete cascade,
    last_activity_at timestamptz,
    remind_after_days integer default 7,
    created_at timestamptz not null default now()
);

create table if not exists organizations (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    owner_id uuid not null references profiles(id) on delete cascade,
    created_at timestamptz not null default now()
);

create table if not exists org_members (
    org_id uuid not null references organizations(id) on delete cascade,
    user_id uuid not null references profiles(id) on delete cascade,
    role text not null default 'member',
    created_at timestamptz not null default now(),
    primary key (org_id, user_id)
);

create table if not exists org_seat_purchases (
    id uuid primary key default uuid_generate_v4(),
    org_id uuid not null references organizations(id) on delete cascade,
    course_id uuid not null references courses(id) on delete cascade,
    seats integer not null,
    status purchase_status not null default 'requires_payment',
    created_at timestamptz not null default now()
);

-- Indexes
create index if not exists idx_courses_creator on courses(creator_id);
create index if not exists idx_modules_course on modules(course_id);
create index if not exists idx_modules_order on modules(course_id, order_index);
create index if not exists idx_lessons_module on lessons(module_id);
create index if not exists idx_lessons_order on lessons(module_id, order_index);
create index if not exists idx_prereq_course on prerequisites(course_id);
create index if not exists idx_prereq_required_course on prerequisites(required_course_id);
create index if not exists idx_prereq_required_module on prerequisites(required_module_id);
create index if not exists idx_purchases_user on purchases(user_id);
create index if not exists idx_purchases_course on purchases(course_id);
create index if not exists idx_enrollments_user_course on enrollments(user_id, course_id);
create index if not exists idx_progress_user_lesson on progress(user_id, lesson_id);
create index if not exists idx_progress_lesson on progress(lesson_id);
create index if not exists idx_certificates_user_course on certificates(user_id, course_id);
create index if not exists idx_webhook_endpoints_owner on webhook_endpoints(owner_id);
create index if not exists idx_webhook_events_type on webhook_events(event_type);
create index if not exists idx_reviews_course on reviews(course_id);
create index if not exists idx_learning_path_courses_order on learning_path_courses(path_id, order_index);
create index if not exists idx_org_members_user on org_members(user_id);
create index if not exists idx_org_seat_purchases_org_course on org_seat_purchases(org_id, course_id);

-- Views
create or replace view module_completion as
select
    m.id as module_id,
    e.user_id,
    bool_and(coalesce(pr.is_completed, false)) as is_completed,
    nullif(round(avg(pr.score)::numeric),0)::int as avg_score
from modules m
join lessons l on l.module_id = m.id
join enrollments e on e.course_id = m.course_id
left join progress pr on pr.lesson_id = l.id and pr.user_id = e.user_id
group by m.id, e.user_id;

create or replace view course_completion as
select
    c.id as course_id,
    e.user_id,
    bool_and(case when m.required then coalesce(mc.is_completed, false) else true end) as is_completed,
    nullif(round(avg(mc.avg_score)::numeric),0)::int as avg_score
from courses c
join enrollments e on e.course_id = c.id
join modules m on m.course_id = c.id
left join module_completion mc on mc.module_id = m.id and mc.user_id = e.user_id
group by c.id, e.user_id;

-- Trigger to update updated_at
create or replace function handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_courses_updated
before update on courses
for each row execute procedure handle_updated_at();

create trigger trg_progress_timestamp
before update on progress
for each row execute procedure handle_updated_at();

-- Trigger to set completed_at when completed
create or replace function set_progress_completed_at()
returns trigger as $$
begin
    if new.is_completed and new.completed_at is null then
        new.completed_at := now();
    elsif not new.is_completed then
        new.completed_at := null;
    end if;
    return new;
end;
$$ language plpgsql;

create trigger trg_progress_completed
before insert or update on progress
for each row execute procedure set_progress_completed_at();

-- Helper functions
create or replace function can_enroll(u uuid, c uuid)
returns boolean
stable
language plpgsql
as $$
declare
    unmet int;
begin
    -- ensure prerequisites satisfied
    select count(*) into unmet
    from prerequisites pr
    where pr.course_id = c
      and (
        (pr.required_course_id is not null and not exists (
            select 1 from course_completion cc where cc.course_id = pr.required_course_id and cc.user_id = u and cc.is_completed
        ))
        or
        (pr.required_module_id is not null and not exists (
            select 1 from module_completion mc where mc.module_id = pr.required_module_id and mc.user_id = u and mc.is_completed
        ))
      );

    return unmet = 0;
end;
$$;

-- Enrollment RPC
create or replace function enroll_in_course(course_id uuid, p_user_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_user uuid := coalesce(p_user_id, auth.uid(), nullif(current_setting('request.jwt.claim.sub', true), '')::uuid);
    v_paid boolean;
    v_allowed boolean;
begin
    if v_user is null then
        raise exception 'Not authenticated';
    end if;

    select exists (
        select 1 from purchases
        where user_id = v_user
          and course_id = enroll_in_course.course_id
          and status = 'paid'
    ) into v_paid;

    if not v_paid then
        raise exception 'Payment required';
    end if;

    select can_enroll(v_user, enroll_in_course.course_id) into v_allowed;

    if not v_allowed then
        raise exception 'Prerequisites not satisfied';
    end if;

    insert into enrollments (user_id, course_id)
    values (v_user, enroll_in_course.course_id)
    on conflict (user_id, course_id) do nothing;
end;
$$;

-- complete_lesson RPC
create or replace function complete_lesson(p_lesson_id uuid, p_score integer default null)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_user uuid := auth.uid();
    v_module modules%rowtype;
    v_course courses%rowtype;
    v_is_completed boolean;
    v_module_complete boolean;
    v_course_complete boolean;
    v_avg_score int;
    v_existing_event uuid;
    v_certificate_id uuid;
begin
    if v_user is null then
        raise exception 'Not authenticated';
    end if;

    select m.*, c.* into v_module, v_course
    from lessons l
    join modules m on m.id = l.module_id
    join courses c on c.id = m.course_id
    where l.id = p_lesson_id;

    if v_module.id is null then
        raise exception 'Lesson not found';
    end if;

    if not exists (
        select 1 from enrollments
        where user_id = v_user
          and course_id = v_module.course_id
    ) then
        raise exception 'Not enrolled in course';
    end if;

    v_is_completed := true;
    if p_score is not null and v_module.passing_score is not null then
        v_is_completed := p_score >= v_module.passing_score;
    end if;

    insert into progress (user_id, lesson_id, is_completed, score)
    values (v_user, p_lesson_id, v_is_completed, p_score)
    on conflict (user_id, lesson_id)
    do update set is_completed = EXCLUDED.is_completed,
                  score = EXCLUDED.score,
                  updated_at = now();

    -- Module completion check
    select mc.is_completed, mc.avg_score
    into v_module_complete, v_avg_score
    from module_completion mc
    where mc.module_id = v_module.id
      and mc.user_id = v_user;

    if coalesce(v_module_complete, false) then
        -- enqueue module completed event if not already
        select id into v_existing_event
        from webhook_events
        where event_type = 'module.completed'
          and payload @> jsonb_build_object('module_id', v_module.id::text, 'user_id', v_user::text);

        if v_existing_event is null then
            insert into webhook_events(event_type, payload)
            values ('module.completed', jsonb_build_object(
                'module_id', v_module.id::text,
                'course_id', v_module.course_id::text,
                'user_id', v_user::text,
                'avg_score', v_avg_score
            ));
        end if;
    end if;

    -- Course completion check
    select cc.is_completed
    into v_course_complete
    from course_completion cc
    where cc.course_id = v_course.id
      and cc.user_id = v_user;

    if coalesce(v_course_complete, false) then
        insert into certificates (user_id, course_id)
        values (v_user, v_course.id)
        on conflict (user_id, course_id) do update set issued_at = certificates.issued_at;

        select id into v_existing_event
        from webhook_events
        where event_type = 'course.completed'
          and payload @> jsonb_build_object('course_id', v_course.id::text, 'user_id', v_user::text);

        if v_existing_event is null then
            select id into v_certificate_id
            from certificates
            where user_id = v_user and course_id = v_course.id;

            insert into webhook_events(event_type, payload)
            values ('course.completed', jsonb_build_object(
                'course_id', v_course.id::text,
                'user_id', v_user::text,
                'certificate_id', v_certificate_id::text
            ));
        end if;
    end if;
end;
$$;

-- RLS Enable
alter table profiles enable row level security;
alter table courses enable row level security;
alter table modules enable row level security;
alter table lessons enable row level security;
alter table prerequisites enable row level security;
alter table purchases enable row level security;
alter table enrollments enable row level security;
alter table progress enable row level security;
alter table certificates enable row level security;
alter table webhook_endpoints enable row level security;
alter table webhook_events enable row level security;
alter table coupons enable row level security;
alter table bundles enable row level security;
alter table bundle_courses enable row level security;
alter table reviews enable row level security;
alter table learning_paths enable row level security;
alter table learning_path_courses enable row level security;
alter table reminders enable row level security;
alter table organizations enable row level security;
alter table org_members enable row level security;
alter table org_seat_purchases enable row level security;

-- RLS Policies
-- Profiles: self read, admin read all
create policy if not exists "profiles_self_select" on profiles
for select using (auth.uid() = id);

create policy if not exists "profiles_self_update" on profiles
for update using (auth.uid() = id) with check (auth.uid() = id);

create policy if not exists "profiles_admin_all" on profiles
for select using (exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin'));

-- Courses
create policy if not exists "courses_public_select" on courses
for select using (is_published or exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin'));

create policy if not exists "courses_creator_rw" on courses
for all using (
    exists (
        select 1
        from profiles p
        where p.id = auth.uid()
          and (p.role = 'admin' or (p.role = 'creator' and courses.creator_id = p.id))
    )
) with check (
    exists (
        select 1 from profiles p
        where p.id = auth.uid()
          and (p.role = 'admin' or (p.role = 'creator' and courses.creator_id = p.id))
    )
);

-- Modules & Lessons (creator/admin only)
create policy if not exists "modules_creator_rw" on modules
for all using (
    exists (
        select 1 from courses c
        join profiles p on p.id = auth.uid()
        where c.id = modules.course_id
          and (p.role = 'admin' or (p.role = 'creator' and c.creator_id = p.id))
    )
) with check (
    exists (
        select 1 from courses c
        join profiles p on p.id = auth.uid()
        where c.id = modules.course_id
          and (p.role = 'admin' or (p.role = 'creator' and c.creator_id = p.id))
    )
);

create policy if not exists "modules_enrolled_select" on modules
for select using (
    exists (
        select 1 from enrollments e
        where e.course_id = modules.course_id
          and e.user_id = auth.uid()
    )
    or modules.course_id in (
        select id from courses where is_published
    )
);

create policy if not exists "lessons_creator_rw" on lessons
for all using (
    exists (
        select 1 from modules m
        join courses c on c.id = m.course_id
        join profiles p on p.id = auth.uid()
        where lessons.module_id = m.id
          and (p.role = 'admin' or (p.role = 'creator' and c.creator_id = p.id))
    )
) with check (
    exists (
        select 1 from modules m
        join courses c on c.id = m.course_id
        join profiles p on p.id = auth.uid()
        where lessons.module_id = m.id
          and (p.role = 'admin' or (p.role = 'creator' and c.creator_id = p.id))
    )
);

create policy if not exists "lessons_enrolled_select" on lessons
for select using (
    exists (
        select 1 from enrollments e
        join modules m on m.id = lessons.module_id
        where e.course_id = m.course_id
          and e.user_id = auth.uid()
    )
);

-- Prerequisites (creator/admin)
create policy if not exists "prerequisites_creator_rw" on prerequisites
for all using (
    exists (
        select 1 from courses c
        join profiles p on p.id = auth.uid()
        where c.id = prerequisites.course_id
          and (p.role = 'admin' or (p.role = 'creator' and c.creator_id = p.id))
    )
) with check (
    exists (
        select 1 from courses c
        join profiles p on p.id = auth.uid()
        where c.id = prerequisites.course_id
          and (p.role = 'admin' or (p.role = 'creator' and c.creator_id = p.id))
    )
);

-- Purchases
create policy if not exists "purchases_self" on purchases
for select using (auth.uid() = user_id);

create policy if not exists "purchases_self_insert" on purchases
for insert with check (auth.uid() = user_id);

create policy if not exists "purchases_self_update" on purchases
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Creators analytics: allow select for their course purchases
create policy if not exists "purchases_creator_select" on purchases
for select using (
    exists (
        select 1 from courses c
        join profiles p on p.id = auth.uid()
        where purchases.course_id = c.id
          and (p.role = 'admin' or (p.role = 'creator' and c.creator_id = p.id))
    )
);

-- Enrollments
create policy if not exists "enrollments_self_select" on enrollments
for select using (auth.uid() = user_id);

create policy if not exists "enrollments_self_insert" on enrollments
for insert with check (auth.uid() = user_id);

create policy if not exists "enrollments_self_update" on enrollments
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy if not exists "enrollments_creator_select" on enrollments
for select using (
    exists (
        select 1 from courses c
        join profiles p on p.id = auth.uid()
        where enrollments.course_id = c.id
          and (p.role = 'admin' or (p.role = 'creator' and c.creator_id = p.id))
    )
);

-- Progress
create policy if not exists "progress_self" on progress
for select using (auth.uid() = user_id);

create policy if not exists "progress_self_insert" on progress
for insert with check (auth.uid() = user_id);

create policy if not exists "progress_self_update" on progress
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy if not exists "progress_creator_select" on progress
for select using (
    exists (
        select 1 from lessons l
        join modules m on m.id = l.module_id
        join courses c on c.id = m.course_id
        join profiles p on p.id = auth.uid()
        where progress.lesson_id = l.id
          and (p.role = 'admin' or (p.role = 'creator' and c.creator_id = p.id))
    )
);

-- Certificates
create policy if not exists "certificates_self" on certificates
for select using (auth.uid() = user_id);

create policy if not exists "certificates_creator" on certificates
for select using (
    exists (
        select 1 from courses c
        join profiles p on p.id = auth.uid()
        where certificates.course_id = c.id
          and (p.role = 'admin' or (p.role = 'creator' and c.creator_id = p.id))
    )
);

create policy if not exists "certificates_admin_manage" on certificates
for all using (exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin'));

-- Webhook endpoints
create policy if not exists "webhook_endpoints_owner" on webhook_endpoints
for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

create policy if not exists "webhook_endpoints_admin" on webhook_endpoints
for select using (exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin'));

-- Webhook events (admin only, inserts via security definer functions)
create policy if not exists "webhook_events_admin_select" on webhook_events
for select using (exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin'));

create policy if not exists "webhook_events_no_direct_mod" on webhook_events
for all using (false) with check (false);

-- Nice-to-have policies (restrict appropriately)
create policy if not exists "coupons_admin" on coupons
for all using (exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin'));

create policy if not exists "bundles_creator" on bundles
for all using (exists (select 1 from profiles p where p.id = auth.uid() and p.role in ('admin','creator')))
with check (exists (select 1 from profiles p where p.id = auth.uid() and p.role in ('admin','creator')));

create policy if not exists "bundle_courses_creator" on bundle_courses
for all using (exists (select 1 from profiles p where p.id = auth.uid() and p.role in ('admin','creator')))
with check (exists (select 1 from profiles p where p.id = auth.uid() and p.role in ('admin','creator')));

create policy if not exists "reviews_self" on reviews
for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy if not exists "reviews_public_read" on reviews
for select using (true);

create policy if not exists "learning_paths_creator" on learning_paths
for all using (exists (select 1 from profiles p where p.id = auth.uid() and p.role in ('admin','creator')))
with check (exists (select 1 from profiles p where p.id = auth.uid() and p.role in ('admin','creator')));

create policy if not exists "learning_path_courses_creator" on learning_path_courses
for all using (exists (select 1 from profiles p where p.id = auth.uid() and p.role in ('admin','creator')))
with check (exists (select 1 from profiles p where p.id = auth.uid() and p.role in ('admin','creator')));

create policy if not exists "reminders_self" on reminders
for select using (auth.uid() = user_id);

create policy if not exists "organizations_admin_owner" on organizations
for all using (exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin') or auth.uid() = owner_id)
with check ((exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin') or auth.uid() = owner_id));

create policy if not exists "org_members_owner" on org_members
for all using (exists (select 1 from organizations o where o.id = org_members.org_id and (o.owner_id = auth.uid() or exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin'))))
with check (exists (select 1 from organizations o where o.id = org_members.org_id and (o.owner_id = auth.uid() or exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin'))));

create policy if not exists "org_seat_purchases_owner" on org_seat_purchases
for all using (exists (select 1 from organizations o where o.id = org_seat_purchases.org_id and (o.owner_id = auth.uid() or exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin'))))
with check (exists (select 1 from organizations o where o.id = org_seat_purchases.org_id and (o.owner_id = auth.uid() or exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'admin'))));

commit;
