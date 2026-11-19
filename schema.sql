-- 在 Supabase 后台 SQL Editor 里整段粘贴运行一次

create table polls (
  id text primary key,
  title text not null check (char_length(title) <= 100),
  options jsonb not null,
  multi boolean not null default false,
  ends_at timestamptz,                -- 截止时间，空 = 不限时
  created_at timestamptz not null default now()
);

create table votes (
  id bigserial primary key,
  poll_id text not null references polls(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 20),
  choices jsonb not null,
  created_at timestamptz not null default now(),
  unique (poll_id, name)   -- 同一投票里同一昵称只能投一次
);

-- 开启行级权限：匿名用户只能读和新增，不能改、不能删
alter table polls enable row level security;
alter table votes enable row level security;

create policy "read polls"   on polls for select to anon using (true);
create policy "create polls" on polls for insert to anon with check (true);
create policy "read votes"   on votes for select to anon using (true);
create policy "cast vote"    on votes for insert to anon with check (   -- 截止后不能再投
  exists (select 1 from polls p where p.id = poll_id and (p.ends_at is null or p.ends_at > now()))
);

-- 新版 Supabase 可能不会自动授权给匿名用户，这里显式授权
grant select, insert on polls, votes to anon;
grant usage on sequence votes_id_seq to anon;

-- ===== 截止邮件提醒 =====
-- 2. 邮件提醒：单独一张表，网页只能写、不能读（邮箱不公开）
create table if not exists poll_notify (
  poll_id text primary key references polls(id) on delete cascade,
  email text not null check (char_length(email) <= 100 and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  sent_at timestamptz
);
alter table poll_notify enable row level security;

-- 只能给"刚创建、有截止时间"的投票登记邮箱，防止被拿来乱发邮件
drop policy if exists "add notify" on poll_notify;
create policy "add notify" on poll_notify for insert to anon with check (
  sent_at is null and exists (
    select 1 from polls p
    where p.id = poll_id and p.ends_at is not null and p.created_at > now() - interval '10 minutes'
  )
);
grant insert on poll_notify to anon;
