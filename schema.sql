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
