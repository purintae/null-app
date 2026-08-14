# ถอดฟีเจอร์ `work`

เขียนไว้ตั้งแต่วันติดตั้งตามกติกาของโปรเจกต์ ทำตามลำดับ ห้ามข้าม

**สถานะวันนี้ (14 ส.ค. 2026):** ฟีเจอร์นี้เป็น UI ล้วน ยังไม่มี schema `f_work`
และยังไม่ถูกเพิ่มใน Exposed schemas ดังนั้น **ข้อ 4–8 ยังไม่มีอะไรให้ทำ** —
คงไว้เพราะจะมีผลทันทีที่รอบ 2 สร้าง schema ขึ้นมา อย่าลบทิ้ง

1. ลบโฟลเดอร์ `null-app/Features/work/`
2. ลบบรรทัด `WorkFeature()` ใน `null-app/Core/FeatureRegistry.swift`
3. build ทั้งสองแพลตฟอร์ม — **ต้องผ่านโดยไม่ต้องแตะไฟล์อื่น**
   - `xcodebuild -scheme null-app -destination 'generic/platform=iOS Simulator' build`
   - `xcodebuild -scheme null-app -destination 'platform=macOS' build`
4. งานของผู้ใช้อยู่ใน `f_work.item` และ `f_work.stage` และกู้ไม่ได้หลังข้อ 7 —
   export ก่อนด้วย `execute_sql` (`f_work.work_type` เป็น reference data ไม่ต้อง export):

   ```sql
   select i.name, i.description, i.requested_by, i.badge, i.archived_at,
          s.code, s.name as stage_name, s.position,
          s.planned_start, s.planned_end, s.actual_start, s.actual_end
   from f_work.item i
   left join f_work.stage s on s.item_id = i.id
   order by i.created_at, s.position;
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
  "https://yqeqzplufezlnudsxzql.supabase.co/rest/v1/item?select=user_id&limit=1"
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
