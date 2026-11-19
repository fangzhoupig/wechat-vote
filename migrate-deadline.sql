-- 升级：给投票加截止时间（已有数据库运行一次即可）
alter table polls add column if not exists ends_at timestamptz;

-- 截止后数据库直接拒绝新的投票
drop policy if exists "cast vote" on votes;
create policy "cast vote" on votes for insert to anon with check (
  exists (select 1 from polls p where p.id = poll_id and (p.ends_at is null or p.ends_at > now()))
);
