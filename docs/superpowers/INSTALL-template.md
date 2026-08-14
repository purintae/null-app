# ติดตั้งฟีเจอร์ `<id>`

แทน `<id>` ด้วย id จริงของฟีเจอร์ และ `<table>` ด้วยชื่อตาราง ทำตามลำดับ ห้ามข้าม

`<id>` ต้องตรง `^[a-z][a-z0-9_]*$` — ตัวเล็ก ตัวเลข และ `_` เท่านั้น ขึ้นต้นด้วยตัวอักษร
`FeatureRegistry.validateInstalled()` บังคับกฎนี้ด้วย `precondition` ตอนเปิดแอป
ใช้ตัวพิมพ์ใหญ่แล้วจะพังแบบสับสนที่สุด: Postgres พับ identifier ที่ไม่ได้ครอบ quote เป็นตัวเล็ก
`create schema f_MyFeature` จึงได้ `f_myfeature` ส่วน `.schema("f_MyFeature")` ส่งสตริงตรง ๆ แล้วหาไม่เจอ

1. **สร้าง schema และตาราง** ผ่าน `apply_migration` (ห้ามพิมพ์ใน Dashboard — ประวัติ migration คือบันทึก)
   ตั้งชื่อ migration ขึ้นต้นด้วย `f_<id>_` เพื่อให้ไล่ดูได้ว่าอันไหนเป็นของฟีเจอร์ไหน

```sql
create schema if not exists f_<id>;

-- ผูกกับ auth.users ไม่ใช่ public.profiles ตามโมเดล 3 ชั้นของโปรเจกต์
-- profiles จึงเปลี่ยนรูปได้โดยไม่ลากฟีเจอร์ไปด้วย
-- on delete cascade ทำให้ไม่ต้องมี hook "ลบข้อมูลตอนผู้ใช้ลบบัญชี" ในทุกฟีเจอร์
create table f_<id>.<table> (
    user_id uuid not null references auth.users(id) on delete cascade,
    -- คอลัมน์ของฟีเจอร์วางตรงนี้
    updated_at timestamptz not null default now()
);

alter table f_<id>.<table> enable row level security;

-- ครบทั้งสี่คำสั่ง และ insert/update ต้องมี with check
-- using อย่างเดียวกันคนอื่นอ่านของเราไม่ได้ แต่ไม่กันการยัดแถวที่ user_id เป็นของคนอื่น
create policy "own row select" on f_<id>.<table>
    for select using (user_id = auth.uid());

create policy "own row insert" on f_<id>.<table>
    for insert with check (user_id = auth.uid());

create policy "own row update" on f_<id>.<table>
    for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "own row delete" on f_<id>.<table>
    for delete using (user_id = auth.uid());

-- default now() ทำงานตอน INSERT เท่านั้น ถ้าไม่มี trigger นี้ upsert ที่กลายเป็น UPDATE
-- จะทิ้ง updated_at ไว้ที่ค่าเดิม — คอลัมน์ที่โกหกแย่กว่าคอลัมน์ที่ไม่มี
-- ฟังก์ชันอยู่ใน schema ของฟีเจอร์เอง drop schema cascade จึงเก็บไปด้วย
create function f_<id>.touch_updated_at() returns trigger
    language plpgsql
    set search_path = ''
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger touch_updated_at
    before update on f_<id>.<table>
    for each row execute function f_<id>.touch_updated_at();

-- ให้ authenticated เท่านั้น ไม่ต้องให้ anon
-- anon เขียนไม่ได้อยู่แล้วเพราะ auth.uid() เป็น NULL แต่การให้สิทธิ์ที่ไม่มีใครใช้
-- คือสิทธิ์ที่ไม่มีใครตรวจ วันที่นโยบายเปลี่ยนมันจะกลายเป็นรูที่ไม่มีใครรู้ว่าเปิดไว้ตั้งแต่เมื่อไร
grant usage on schema f_<id> to authenticated;
grant select, insert, update, delete on f_<id>.<table> to authenticated;
```

2. **พิสูจน์ว่า RLS ปฏิเสธจริง** ไม่ใช่แค่ยอมให้เจ้าของผ่าน ใช้ `execute_sql` กับ user จริงสองคน
   สวมสิทธิ์คนที่สองแล้ว select / update / delete แถวของคนแรกต้องได้ 0 แถว และ insert ที่ปลอม
   `user_id` ต้อง error ด้วย `new row violates row-level security policy`
   policy ที่ยังไม่เคยถูกลองแหกคือ policy ที่ยังไม่มีใครรู้พฤติกรรมของมัน

3. **เปิดให้ Data API เห็น schema** — ขั้นตอนเดียวที่ทำผ่าน MCP ไม่ได้
   Supabase Dashboard → Project Settings → **Integrations → Data API → แท็บ Settings**
   → **Exposed schemas** → เพิ่ม `f_<id>` → Save

   ⚠️ หน้านี้มีช่อง **Extra search path** อยู่ใกล้กันและหน้าตาคล้ายกันมาก **มันคนละเรื่องกัน**
   ใส่ schema ผิดช่องแล้ว **ไม่มี error ใด ๆ** ทุกอย่างดูเหมือนบันทึกสำเร็จ แต่ REST ยังตอบ
   `PGRST106` เหมือนเดิม — branch นี้เสียเวลาไปกับกับดักช่องนี้มาแล้ว

4. **ยืนยันว่าการเปิดมีผลจริง ก่อนเขียนโค้ดแอปแม้แต่บรรทัดเดียว**

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "apikey: sb_publishable_TzWBdrFCJzBBL8wlrU-ksg_eJyYZto1" \
  -H "Accept-Profile: f_<id>" \
  "https://yqeqzplufezlnudsxzql.supabase.co/rest/v1/<table>?select=user_id&limit=1"
```

   ต้องได้ `200` (body เป็น `[]` เพราะยังไม่มีแถวและ anon ไม่ผ่าน RLS ซึ่งถูกต้อง)
   ถ้าได้ `404` พร้อม `PGRST106` "Only the following schemas are exposed" แปลว่าข้อ 3 ยังไม่มีผล
   — กลับไปดูว่าใส่ถูกช่องหรือยัง อย่าเดินต่อ เพราะโค้ดแอปที่เขียนบน schema ที่ยังไม่เปิด
   จะ debug ยากกว่าเดิมหลายเท่า

5. **สร้างโค้ดฝั่งแอป** ที่ `null-app/Features/<Id>/` — สร้างไฟล์ด้วย Write ได้ตรง ๆ
   (synchronized file group) **ห้ามแก้ `project.pbxproj`**

   - ตั้งชื่อ type ทุกตัวขึ้นต้นด้วย `<Id>` — `<Id>Feature`, `<Id>RootView`, `<Id>Store`
     ทุกฟีเจอร์อยู่ในโมดูล Swift เดียวกัน ชื่อที่ไม่มี prefix จะชนกันเมื่อมีฟีเจอร์ที่สอง
   - เข้าถึงตารางผ่าน `Backend.client.schema("f_<id>").from("<table>")` เท่านั้น
   - ไฟล์ในเครื่องอยู่ที่ `FeatureStorage.directory(for: "<id>")`
   - คีย์ `UserDefaults` / `@AppStorage` ต้องมาจาก `FeatureStorage.defaultsKey("<id>", "…")`
     **ห้ามพิมพ์สตริง `"f.<id>.…"` เอง** — ชื่อที่พิมพ์มือคือชื่อที่วันถอดจะหลุดจากการกวาด
   - รับ `userID` ผ่านพารามิเตอร์ของ `makeRoot(userID:)` ไม่ใช่ไปอ่านเองจาก `Backend.client.auth`
   - `makeRoot` ถูกเรียกตอนวาด Home ทุกไอคอน ไม่ใช่ตอนกด — ห้ามทำงานจริงในนั้นและใน `init`
     ของ view ราก ให้ไปอยู่ใน `.task`

6. **เติมหนึ่งบรรทัดใน `null-app/Core/FeatureRegistry.swift`** — `<Id>Feature(),`
   นี่คือไฟล์เดียวในโปรเจกต์ที่ได้รับอนุญาตให้เอ่ยชื่อฟีเจอร์ ถ้ามีไฟล์ที่สองรู้จักชื่อนี้ เส้นแบ่งรั่วแล้ว

7. **build ทั้งสองแพลตฟอร์ม**
   - `xcodebuild -scheme null-app -destination 'generic/platform=iOS Simulator' build`
   - `xcodebuild -scheme null-app -destination 'platform=macOS' build`

8. **ยืนยัน end-to-end กับข้อมูลจริง** — เขียนจากหน้าจอ แล้วอ่านแถวกลับมาจาก DB เทียบ
   หน้าจอที่ดูถูกไม่ใช่หลักฐาน

9. **คัดลอก `docs/superpowers/UNINSTALL-template.md` ไปเป็น `null-app/Features/<Id>/UNINSTALL.md`**
   แทน `<id>` ให้เรียบร้อยตั้งแต่วันติดตั้ง ถ้าฟีเจอร์เก็บข้อมูลที่ผู้ใช้อาจอยากได้คืน
   ให้เขียนคำสั่ง export พร้อมใช้ไว้ในนั้นด้วย — วันถอดคือวันที่ไม่มีใครอยากคิดคำสั่งใหม่

ตรวจว่าติดตั้งครบจริง:

- [ ] user คนที่สองอ่าน/แก้/ลบแถวของคนแรกไม่ได้ และปลอม `user_id` ไม่ผ่าน
- [ ] `curl` ในข้อ 4 ได้ 200 และ `public.profiles` ยังได้ 200 (schema cache สร้างใหม่แล้วไม่กระทบ core)
- [ ] UPDATE แถวเดิมแล้ว `updated_at` ขยับจริง
- [ ] build ผ่านทั้ง iOS และ macOS
- [ ] `grep -r '"f\.<id>' null-app/` ไม่เจอสตริงที่พิมพ์มือ (ทุกคีย์มาจาก `defaultsKey`)
- [ ] มี `UNINSTALL.md` ของฟีเจอร์อยู่ในโฟลเดอร์แล้ว
