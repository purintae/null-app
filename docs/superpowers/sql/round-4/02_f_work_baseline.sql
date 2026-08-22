-- migration name: f_work_stage_baseline
-- แผนแรกที่ตั้งไว้ เขียนครั้งเดียวตอน insert ไม่แตะอีกตลอดชีวิตของแถว
-- planned_* จะถูกเขียนทับเมื่อ stage ปิดช้าแล้วแผนที่เหลือเลื่อน ตัวนี้จึงเป็น
-- ที่เดียวที่ยังตอบได้ว่าหลุดจาก Action Plan ต้นปีไปเท่าไหร่
begin;

alter table f_work.stage
    add column baseline_start date,
    add column baseline_end date;

-- แถวเดิมยังไม่มีแผนแรกบันทึกไว้ ใช้แผนปัจจุบัน ณ วันย้ายเป็น baseline
update f_work.stage
set baseline_start = planned_start,
    baseline_end = planned_end
where baseline_start is null;

alter table f_work.stage
    alter column baseline_start set not null,
    alter column baseline_end set not null,
    add constraint stage_baseline_dates_ordered check (baseline_end >= baseline_start);

commit;
