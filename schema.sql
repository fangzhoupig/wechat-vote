-- 在 Supabase 后台 SQL Editor 里整段粘贴运行一次

create table polls (
  id text primary key,
  title text not null check (char_length(title) <= 100),
  options jsonb not null,
  multi boolean not null default false,
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
create policy "cast vote"    on votes for insert to anon with check (true);
