-- 升级：截止时间 + 截止邮件提醒（可重复运行）

-- 1. 截止时间
alter table polls add column if not exists ends_at timestamptz;

drop policy if exists "cast vote" on votes;
create policy "cast vote" on votes for insert to anon with check (
  exists (select 1 from polls p where p.id = poll_id and (p.ends_at is null or p.ends_at > now()))
);

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
