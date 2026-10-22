-- PT app schema. Run in Supabase: SQL Editor > New query > paste > Run.
-- Step 1: create the PT's login in Authentication > Users, then replace the email below.

create table app_admin (user_id uuid primary key references auth.users on delete cascade);
insert into app_admin select id from auth.users where email = 'PT_EMAIL_HERE';

create function is_pt() returns boolean language sql security definer stable as
$$ select exists (select 1 from app_admin where user_id = auth.uid()) $$;

create table clients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users on delete set null, -- client's login, linked later
  name text not null, email text, phone text, goal text, notes text,
  start_date date default current_date,
  active boolean default true,
  created_at timestamptz default now()
);

create function my_client_id() returns uuid language sql security definer stable as
$$ select id from clients where user_id = auth.uid() $$;

create table exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null, muscle_group text, video_url text, notes text
);

create table workout_plans (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients on delete cascade,
  title text not null, start_date date, end_date date, notes text,
  created_at timestamptz default now()
);
create table workout_days (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references workout_plans on delete cascade,
  name text not null, position int default 0
);
create table workout_items (
  id uuid primary key default gen_random_uuid(),
  day_id uuid not null references workout_days on delete cascade,
  exercise_id uuid references exercises,
  sets int, reps text, rest_seconds int, notes text, position int default 0
);

create table meal_plans (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients on delete cascade,
  title text not null, start_date date, end_date date, notes text,
  created_at timestamptz default now()
);
create table meals (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references meal_plans on delete cascade,
  name text not null, time_of_day text, calories int, protein_g int, carbs_g int, fat_g int,
  position int default 0
);
create table meal_items (
  id uuid primary key default gen_random_uuid(),
  meal_id uuid not null references meals on delete cascade,
  food text not null, quantity text, notes text, position int default 0
);

create table questions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients on delete cascade, -- null = asked to all clients
  text text not null,
  answer_type text not null check (answer_type in ('text','number','yesno')),
  frequency text default 'weekly' check (frequency in ('once','daily','weekly','monthly')),
  active boolean default true
);
create table answers (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references questions on delete cascade,
  client_id uuid not null references clients on delete cascade,
  value text, answered_at timestamptz default now()
);

create table measurements (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients on delete cascade,
  measured_on date default current_date,
  weight_kg numeric, waist_cm numeric, hips_cm numeric, chest_cm numeric,
  arm_cm numeric, thigh_cm numeric, notes text
);

create table media_uploads (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients on delete cascade,
  kind text not null check (kind in ('photo','video')),
  file_path text not null, -- path inside the 'client-media' storage bucket
  note text, seen_by_pt boolean default false,
  created_at timestamptz default now()
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients on delete cascade,
  from_pt boolean not null, body text not null, created_at timestamptz default now()
);

create table faq (
  id uuid primary key default gen_random_uuid(),
  question text not null, answer text not null, position int default 0
);
create table video_links (
  id uuid primary key default gen_random_uuid(),
  title text not null, url text not null, description text, position int default 0
);

-- Row-level security: PT sees everything; each client sees only their own rows.
do $$ declare t text; begin
  foreach t in array array['clients','exercises','workout_plans','workout_days','workout_items',
    'meal_plans','meals','meal_items','questions','answers','measurements','media_uploads',
    'messages','faq','video_links','app_admin'] loop
    execute format('alter table %I enable row level security', t);
  end loop;
end $$;

-- PT: full access everywhere
do $$ declare t text; begin
  foreach t in array array['clients','exercises','workout_plans','workout_days','workout_items',
    'meal_plans','meals','meal_items','questions','answers','measurements','media_uploads',
    'messages','faq','video_links'] loop
    execute format('create policy pt_all on %I for all using (is_pt()) with check (is_pt())', t);
  end loop;
end $$;

-- Clients: read their own data
create policy c_self on clients for select using (user_id = auth.uid());
create policy c_plans on workout_plans for select using (client_id = my_client_id());
create policy c_days on workout_days for select using (plan_id in (select id from workout_plans where client_id = my_client_id()));
create policy c_items on workout_items for select using (day_id in (select d.id from workout_days d join workout_plans p on p.id = d.plan_id where p.client_id = my_client_id()));
create policy c_exercises on exercises for select using (my_client_id() is not null);
create policy c_mplans on meal_plans for select using (client_id = my_client_id());
create policy c_meals on meals for select using (plan_id in (select id from meal_plans where client_id = my_client_id()));
create policy c_mitems on meal_items for select using (meal_id in (select m.id from meals m join meal_plans p on p.id = m.plan_id where p.client_id = my_client_id()));
create policy c_questions on questions for select using (client_id = my_client_id() or (client_id is null and my_client_id() is not null));
create policy c_faq on faq for select using (my_client_id() is not null);
create policy c_videos on video_links for select using (my_client_id() is not null);

-- Clients: read and add their own answers, measurements, uploads, messages
create policy c_ans_r on answers for select using (client_id = my_client_id());
create policy c_ans_w on answers for insert with check (client_id = my_client_id());
create policy c_meas_r on measurements for select using (client_id = my_client_id());
create policy c_meas_w on measurements for insert with check (client_id = my_client_id());
create policy c_media_r on media_uploads for select using (client_id = my_client_id());
create policy c_media_w on media_uploads for insert with check (client_id = my_client_id());
create policy c_msg_r on messages for select using (client_id = my_client_id());
create policy c_msg_w on messages for insert with check (client_id = my_client_id() and from_pt = false);

-- Private storage bucket for photos/videos. Files live under <client_id>/<filename>.
insert into storage.buckets (id, name, public) values ('client-media', 'client-media', false);
create policy media_pt on storage.objects for all
  using (bucket_id = 'client-media' and is_pt()) with check (bucket_id = 'client-media' and is_pt());
create policy media_client_r on storage.objects for select
  using (bucket_id = 'client-media' and (storage.foldername(name))[1] = my_client_id()::text);
create policy media_client_w on storage.objects for insert
  with check (bucket_id = 'client-media' and (storage.foldername(name))[1] = my_client_id()::text);
