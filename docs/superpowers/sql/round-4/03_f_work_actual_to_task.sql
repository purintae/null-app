-- ต้องรันหลัง 01 และ **ก่อน** 04 เสมอ
-- stage ที่ปิดไปแล้วจริงมีวันปิดอยู่ใน actual_end ถ้า drop ตรง ๆ ประวัติหายทั้งหมด
-- แปลงเป็น task หนึ่งอันที่เสร็จแล้ว เพื่อให้กติกาใหม่ยังอ่านว่า stage นั้นปิดแล้วเหมือนเดิม
insert into f_work.task (stage_id, title, done_at, position)
select s.id,
       'ปิด ' || s.name,
       s.actual_end::timestamptz,
       1
from f_work.stage s
where s.actual_end is not null;
