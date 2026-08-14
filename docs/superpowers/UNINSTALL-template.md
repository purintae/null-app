# ถอดฟีเจอร์ `<id>`

แทน `<id>` ด้วย id จริงของฟีเจอร์ ทำตามลำดับ ห้ามข้าม

1. ลบโฟลเดอร์ `null-app/Features/<Id>/`
2. ลบบรรทัดของฟีเจอร์ใน `null-app/Core/FeatureRegistry.swift`
3. build ทั้งสองแพลตฟอร์ม — **ต้องผ่านโดยไม่ต้องแตะไฟล์อื่น**
   - `xcodebuild -scheme null-app -destination 'generic/platform=iOS Simulator' build`
   - `xcodebuild -scheme null-app -destination 'platform=macOS' build`
4. ถ้าฟีเจอร์เก็บข้อมูลที่ผู้ใช้อาจอยากได้คืน ให้ export ก่อน — ข้อ 6 ลบถาวรและกู้ไม่ได้
5. เอา `f_<id>` ออกจาก Exposed schemas (Project Settings → Data API) **ก่อน** ข้อ 6 เสมอ
   — ลำดับนี้กลับกันไม่ได้ การ drop schema ที่ยังอยู่ในรายการทำให้ PostgREST สร้าง schema cache
   ไม่ได้ และตอบ `PGRST002` กับทุก request ของโปรเจกต์ รวมถึงตารางของ core
6. `drop schema f_<id> cascade;` ผ่าน `apply_migration`
7. ลบ bucket `f_<id>` ผ่าน Storage API หรือ Dashboard ถ้าฟีเจอร์นั้นมี
   (ลบ `storage.objects` ด้วย SQL ไม่ได้ — trigger `storage.protect_delete()` ปฏิเสธ)
8. ของค้างในเครื่องผู้ใช้ไม่ต้องทำอะไร `FeatureStorage.sweepOrphans()` เก็บกวาดเองตอนเปิดแอป
   (ทำงานเฉพาะ build ที่ไม่ใช่ DEBUG)

ตรวจว่าสะอาดจริงครบทั้ง 4 ข้อ:

- [ ] build ผ่านทั้ง iOS และ macOS โดยไม่ได้แก้ไฟล์อื่นนอกจากสองข้อแรก
- [ ] `drop schema` สำเร็จโดยไม่ชนกับวัตถุของ core
- [ ] เปิดแอป Release ใหม่แล้วโฟลเดอร์และคีย์ของฟีเจอร์หายไปจริง
- [ ] `grep -ri <id> null-app/` ไม่เหลืออะไร
