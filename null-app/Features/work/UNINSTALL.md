# ถอดฟีเจอร์ `work`

เขียนไว้ตั้งแต่วันติดตั้งตามกติกาของโปรเจกต์ ทำตามลำดับ ห้ามข้าม

**สถานะวันนี้ (20 ส.ค. 2026):** schema `f_work` และตารางทั้งห้า (`work_type`, `stage_type`, `work`, `stage`, `task`)
พร้อม RLS และข้อมูลทดสอบมีอยู่จริงแล้ว และ `f_work` ถูกเพิ่มใน Exposed schemas แล้ว —
**ข้อ 4–8 มีผลจริงทุกข้อ ทำตามลำดับ** โดยเฉพาะข้อ 5 ต้องทำ**ก่อน**ข้อ 7 เสมอ ตามเหตุผลที่อธิบายไว้ที่ข้อ 5

1. ลบโฟลเดอร์ `null-app/Features/work/`
2. ลบบรรทัด `WorkFeature()` ใน `null-app/Core/FeatureRegistry.swift`
3. build ทั้งสองแพลตฟอร์ม — **ต้องผ่านโดยไม่ต้องแตะไฟล์อื่น**
   - `xcodebuild -scheme null-app -destination 'generic/platform=iOS Simulator' build`
   - `xcodebuild -scheme null-app -destination 'platform=macOS' build`
4. งานของผู้ใช้อยู่ใน `f_work.work` และ `f_work.stage` และกู้ไม่ได้หลังข้อ 7 —
   export ก่อนด้วย `execute_sql`:
   `baseline_*` คือแผนตั้งแต่แรกที่ตกลงกัน `planned_*` คือแผนหลังจากมีการเปลี่ยนแปลง
   มีแต่ `baseline_*` เท่านั้นที่ไม่สามารถสร้างขึ้นมาใหม่ได้จากข้อมูลอื่น

   ```sql
   select w.name, w.description, w.requested_by, w.archived_at,
          s.code, s.name as stage_name, s.position,
          s.planned_start, s.planned_end, s.baseline_start, s.baseline_end
   from f_work.work w
   left join f_work.stage s on s.work_id = w.id
   order by w.created_at, s.position;
   ```

   `f_work.work_type` กับ `f_work.stage_type` เป็น reference data ที่คุมจากหลังบ้าน ไม่มีข้อมูล
   ของผู้ใช้อยู่ในนั้น แต่ **export ไว้ด้วย** เพราะรหัสใน `f_work.stage.code` เป็น text เปล่า ๆ
   ไม่มี FK ไปหารายการ ไฟล์ export ข้างบนจึงอ่านไม่ออกว่า `SU` แปลว่าอะไรถ้าไม่มีตารางนี้คู่มา:

   ```sql
   select 'work_type' as list, code, label, position, is_active from f_work.work_type
   union all
   select 'stage_type', code, label, position, is_active from f_work.stage_type
   order by list, position;
   ```

   **ตั้งแต่รอบ 4** งานที่เสร็จสิ้นและวันปิดของแต่ละ stage อยู่ใน `f_work.task` เท่านั้น — คอลัมน์ `actual_end` ที่เคยเก็บวันปิดของ stage ไม่มีอีกแล้ว
   export งาน (task) ก่อนลบด้วย:

   ```sql
   select w.name as work_name, s.code as stage_code, t.title, t.done_at, t.position
   from f_work.task t
   join f_work.stage s on s.id = t.stage_id
   join f_work.work w on w.id = s.work_id
   order by w.created_at, s.position, t.position;
   ```

5. เอา `f_work` ออกจาก Exposed schemas (Project Settings → Integrations → Data API → แท็บ Settings)
   **ก่อน** ข้อ 7 เสมอ — ลำดับนี้กลับกันไม่ได้ การ drop schema ที่ยังอยู่ในรายการทำให้ PostgREST
   สร้าง schema cache ไม่ได้ และตอบ `PGRST002` กับทุก request ของโปรเจกต์ รวมถึงตารางของ core
6. **ยืนยันว่าการเอาออกมีผลจริง ก่อนเดินต่อ** — ข้อ 5 เป็นการกดปุ่มใน Dashboard
   ที่ไม่มีอะไรตอบกลับมาว่าสำเร็จ ส่วนข้อ 7 ย้อนกลับไม่ได้ จุดนี้จึงเป็นที่เดียวที่การเดาแพงที่สุด

```bash
curl -s \
  -H "apikey: sb_publishable_TzWBdrFCJzBBL8wlrU-ksg_eJyYZto1" \
  -H "Accept-Profile: f_work" \
  "https://yqeqzplufezlnudsxzql.supabase.co/rest/v1/work?select=user_id&limit=1"
```

   ต้องได้ `PGRST106` "Only the following schemas are exposed: …" และในรายการนั้น**ต้องไม่มี** `f_work`
   ถ้ายังได้ `200` แปลว่าค่ายังไม่ถูกบันทึก — **หยุด** อย่า drop เพราะจะทำให้ Data API
   ของทั้งโปรเจกต์ล้มทันที กลับไปดูว่าใส่ถูกช่องหรือยัง (หน้าเดียวกันมีช่อง **Extra search path**
   ที่หน้าตาคล้ายกันและคนละเรื่องกัน)

7. `drop schema f_work cascade;` ผ่าน `apply_migration`
8. ฟีเจอร์นี้ไม่มี Storage bucket ของตัวเอง ไม่ต้องทำอะไร
9. ของค้างในเครื่องผู้ใช้ไม่ต้องทำอะไร `FeatureStorage.sweepOrphans` เก็บกวาดเองตอนเปิดแอป
   (ทำงานเฉพาะ build ที่ไม่ใช่ DEBUG)

ตรวจว่าสะอาดจริงครบทั้ง 4 ข้อ:

- [ ] build ผ่านทั้ง iOS และ macOS โดยไม่ได้แก้ไฟล์อื่นนอกจากสองข้อแรก
- [ ] `drop schema` สำเร็จโดยไม่ชนกับวัตถุของ core
- [ ] เปิดแอป Release ใหม่แล้วโฟลเดอร์และคีย์ของฟีเจอร์หายไปจริง
- [ ] `grep -ri work null-app/` ไม่เหลืออะไร
      (ระวัง: `work` เป็นคำที่โผล่ในบริบทอื่นได้ เช่น `network` — ตรวจผลลัพธ์ด้วยตา ไม่ใช่ดูแค่จำนวน)
