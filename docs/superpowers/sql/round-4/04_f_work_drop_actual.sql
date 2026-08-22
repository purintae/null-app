-- migration name: f_work_drop_actual_dates
-- actual_start ไม่มีทางต่างจาก planned_start ได้ในกระบวนการจริง
-- actual_end คำนวณจาก max(task.done_at) ได้ ทั้งคู่จึงเป็นคอลัมน์ที่รอวันไม่ตรงกับความจริง
alter table f_work.stage drop constraint stage_actual_dates_ordered;
alter table f_work.stage drop column actual_start;
alter table f_work.stage drop column actual_end;
