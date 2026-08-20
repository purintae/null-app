-- migration name: f_work_task
create table f_work.task (
    id uuid primary key default gen_random_uuid(),
    stage_id uuid not null references f_work.stage(id) on delete cascade,
    title text not null,
    done_at timestamptz,
    position int not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint task_title_not_blank check (btrim(title) <> '')
);

create index task_stage_id_idx on f_work.task(stage_id);

alter table f_work.task enable row level security;

-- เจ้าของสืบผ่าน stage → work สองชั้น
-- with check ต้องมีทั้ง insert และ update ไม่งั้นย้าย task ไปแขวนใต้ stage ของคนอื่นได้
create policy "own task select" on f_work.task
    for select using (
        exists (
            select 1 from f_work.stage s join f_work.work w on w.id = s.work_id
            where s.id = task.stage_id and w.user_id = auth.uid()
        )
    );

create policy "own task insert" on f_work.task
    for insert with check (
        exists (
            select 1 from f_work.stage s join f_work.work w on w.id = s.work_id
            where s.id = task.stage_id and w.user_id = auth.uid()
        )
    );

create policy "own task update" on f_work.task
    for update using (
        exists (
            select 1 from f_work.stage s join f_work.work w on w.id = s.work_id
            where s.id = task.stage_id and w.user_id = auth.uid()
        )
    ) with check (
        exists (
            select 1 from f_work.stage s join f_work.work w on w.id = s.work_id
            where s.id = task.stage_id and w.user_id = auth.uid()
        )
    );

create policy "own task delete" on f_work.task
    for delete using (
        exists (
            select 1 from f_work.stage s join f_work.work w on w.id = s.work_id
            where s.id = task.stage_id and w.user_id = auth.uid()
        )
    );

grant select, insert, update, delete on f_work.task to authenticated;

-- แก้ task คือการแก้ Work การ์ดบอก "อัปเดตล่าสุด" จากคอลัมน์ของ work
-- ไม่ใช่ security definer โดยตั้งใจ — authenticated มี policy own work update อยู่แล้ว
create or replace function f_work.touch_work_from_task()
returns trigger
language plpgsql
set search_path to ''
as $$
declare
    target uuid;
begin
    select s.work_id into target from f_work.stage s
    where s.id = coalesce(new.stage_id, old.stage_id);

    update f_work.work set updated_at = now() where id = target;

    if tg_op = 'DELETE' then return old; else return new; end if;
end;
$$;

create trigger task_touch_work
    after insert or update or delete on f_work.task
    for each row execute function f_work.touch_work_from_task();
