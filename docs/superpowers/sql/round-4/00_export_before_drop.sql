-- รันเป็นไฟล์แรกสุด **ก่อน** 01 แล้วเก็บผลลัพธ์ไว้นอกฐานข้อมูล
--
-- ไฟล์ 04 จะ drop actual_start / actual_end ทิ้งถาวร ส่วนไฟล์ 03 เก็บเฉพาะ actual_end
-- ของ stage ที่ปิดแล้ว แถวที่เริ่มแล้วแต่ยังไม่ปิดจึงไม่มีอะไรรองรับ
-- ตรวจแล้วพบว่ามีแถวที่ actual_start ไม่ตรงกับ planned_start จริง — export ก่อนเสมอ
-- ตามหลักเดียวกับที่ UNINSTALL.md ของฟีเจอร์นี้ใช้
select w.name as work_name,
       s.code,
       s.position,
       s.planned_start,
       s.planned_end,
       s.actual_start,
       s.actual_end
from f_work.stage s
join f_work.work w on w.id = s.work_id
where s.actual_start is not null or s.actual_end is not null
order by w.created_at, s.position;
