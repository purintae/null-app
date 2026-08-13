# Account & Authentication — Design Spec (รอบ A)

วันที่: 2026-08-13
สถานะ: รออนุมัติ
ที่มา: requirements "Authentication & Identity System" ที่ผู้ใช้เขียนขึ้นเอง

## เป้าหมาย

ให้ `null-app` มีบัญชีผู้ใช้จริงบน backend โดยที่ **การสมัครง่ายที่สุดเท่าที่เป็นไปได้** —
กรอกแค่ชื่อที่ใช้แสดง ไม่มีรหัสผ่าน ไม่มีอีเมล

และวางโครง identity ให้เพิ่มวิธีล็อกอินอื่นทีหลังได้โดยไม่ต้องแก้โมเดลบัญชี

## การแบ่งงานเป็น 3 รอบ

requirements ต้นทางครอบคลุมอย่างน้อย 3 ระบบย่อย ถ้าทำเป็น spec เดียวจะได้ของที่ทำครึ่งเดียวแล้วค้าง
จึงแบ่งเป็น:

| รอบ | ได้อะไร | กระทบ identity model ไหม |
|---|---|---|
| **A (spec นี้)** | สมัคร → มีบัญชีจริง → โปรไฟล์และรูปอยู่บน server | สร้างขึ้นครบทั้ง 3 ชั้น |
| B | Recovery Email + คำเตือนเรื่องการกู้บัญชี | ไม่แก้ |
| C | Passkey / Apple / Google + Device Transfer | ไม่แก้ |

ที่แยกได้เพราะ requirements ข้อ 5 ระบุเองว่าเพิ่ม authentication provider ได้โดยไม่แตะ identity model
รอบ B และ C จึงเป็นการ *เพิ่ม* ไม่ใช่การ *รื้อ*

## ขอบเขตรอบ A

อยู่ในขอบเขต:

- โปรเจกต์ Supabase `null-app` (ref `yqeqzplufezlnudsxzql`, region `ap-southeast-1`)
- ตาราง `profiles` + RLS
- สมัครด้วย anonymous sign-in แล้วกรอกชื่อ
- `stable_suffix` สร้างและกันซ้ำโดยฐานข้อมูล
- อ่าน/เขียนโปรไฟล์ผ่าน Supabase
- รูป avatar และ cover ย้ายขึ้น Supabase Storage
- สถานะ "ยังไม่มีบัญชี" กับ "มีบัญชีแล้ว" ในแอป
- session เก็บใน Keychain

ไม่อยู่ในขอบเขต (เลื่อนโดยตั้งใจ):

- รหัสผ่าน, อีเมล, OTP — รอบ B
- Recovery Key — ดูหัวข้อ "ทำไมไม่ทำ Recovery Key ในรอบนี้"
- Passkey, Sign in with Apple, Google — รอบ C ติดกำแพงจริงที่อธิบายด้านล่าง
- Device Transfer — รอบ C
- การย้ายโปรไฟล์เดิมในเครื่องขึ้น server — ผู้ใช้เลือก "เริ่มใหม่หมด"

**ข้อมูลเดิมในเครื่องถูกล้างทิ้ง** ตอนเปิดแอปเวอร์ชันใหม่ครั้งแรก ทั้ง `profile.json` และโฟลเดอร์ `images/`
โปรไฟล์ `Purin Tae` / `@purintae-3Q6RDV` และรูปที่มีอยู่จะหายไป แล้วผู้ใช้เริ่มจากหน้าสมัครใหม่
ซึ่ง server จะ mint `stable_suffix` ตัวใหม่ให้ — **suffix เดิมไม่ถูกรักษาไว้**

## โมเดล 3 ชั้น

ตาม requirements ข้อ 2 ทุกประการ

```
auth.users.id (uuid)            ← Internal Identity
   │                              immutable, Supabase เป็นคน mint
   │                              ผู้ใช้ไม่จำเป็นต้องเห็น
   │
   ├── public.profiles          ← Public Identity
   │      user_id (PK, FK → auth.users)
   │      display_name
   │      stable_suffix          UNIQUE ทั้งระบบ
   │      avatar_path, cover_path
   │      created_at, updated_at
   │
   └── auth.identities          ← Authentication Identity
          รอบ A: anonymous (device credential)
          รอบ B: email
          รอบ C: apple, google, passkey
```

**ทุกตารางที่จะเกิดขึ้นในอนาคตต้องอ้าง `user_id` เท่านั้น** ห้ามใช้ `username` หรือ `stable_suffix`
เป็น foreign key เพราะ username เปลี่ยนได้ทุกเมื่อ

## `stable_suffix` ต้อง unique ทั้งระบบ

requirements ไม่ได้ระบุขอบเขตของความไม่ซ้ำไว้ ซึ่งเป็นช่องโหว่ที่ต้องปิด

ถ้าให้ unique เป็นคู่ `(slug, suffix)` จะเกิดเคสนี้:

```
ผมคือ @bob-ABC123          คนอื่นคือ @alice-ABC123      ยังไม่ชน
ผมเปลี่ยนชื่อเป็น Alice  →  @alice-ABC123               ชนทันที
```

การเปลี่ยนชื่อจะล้มเหลวได้ ซึ่งขัดกับสัญญาข้อ 2 ที่ว่าเปลี่ยนชื่อแล้ว `stable_suffix` ต้องไม่เปลี่ยน

**จึงบังคับ `UNIQUE` บน `stable_suffix` เดี่ยว ๆ** การเปลี่ยนชื่อจึงปลอดภัยเสมอไม่ว่าเปลี่ยนเป็นอะไร
พื้นที่ 32⁶ = 1,073,741,824 ค่า ยังเหลือเฟือ

นี่คือจุดที่ความหมายของ suffix เปลี่ยนไปจากตอนเป็น local — จาก "ความน่าจะเป็นที่ต่ำจนไม่ต้องแคร์"
กลายเป็น "การรับประกันโดยฐานข้อมูล" โค้ดฝั่งแอปหน้าตาเหมือนเดิม แต่คำสัญญาที่ให้ผู้ใช้แข็งแรงขึ้น

ชุดอักษรยังเป็นชุดเดิมที่ตัด `I O 0 1` ออก (ดู `Profile.usernameSuffixAlphabet`)

## Schema

```sql
create table public.profiles (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  display_name  text not null default '',
  stable_suffix text not null unique,
  avatar_path   text,
  cover_path    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
```

กฎที่บังคับในฐานข้อมูล ไม่ใช่แค่ในแอป:

- `display_name` ยาวไม่เกิน 50 และเป็น ASCII ตามกฎเดิม (`CHECK`)
- `stable_suffix` ยาว 6 และอยู่ในชุดอักษรที่กำหนด (`CHECK`)
- `updated_at` อัปเดตด้วย trigger

`stable_suffix` สร้างโดยฟังก์ชันใน Postgres ไม่ใช่ฝั่งแอป — ฝั่งแอปรับประกันความไม่ซ้ำไม่ได้
ถ้าชนกับที่มีอยู่แล้ว ให้สุ่มใหม่และลองซ้ำสูงสุด 5 ครั้ง

## RLS

เปิด RLS บน `profiles` และบน bucket ของ Storage

| การกระทำ | ใครทำได้ |
|---|---|
| อ่านโปรไฟล์ | ทุกคนที่ล็อกอินแล้ว — public identity ควรเห็นได้ ตาม requirements ข้อ 2 |
| สร้างโปรไฟล์ | เฉพาะแถวที่ `user_id = auth.uid()` |
| แก้ไขโปรไฟล์ | เฉพาะแถวที่ `user_id = auth.uid()` |
| ลบ | ไม่เปิดให้ทำจากแอปในรอบนี้ |

`stable_suffix` และ `user_id` **แก้ไม่ได้หลังสร้าง** บังคับด้วย trigger ไม่ใช่แค่ความตั้งใจฝั่งแอป

publishable key ฝังในแอปได้อย่างปลอดภัยโดยการออกแบบ — สิ่งที่ป้องกันข้อมูลคือ RLS ไม่ใช่การซ่อน key

## Flow สมัคร

```
เปิดแอป
  ├── มี session ใน Keychain → Home
  └── ไม่มี → SignUpView
        กรอก display name → Continue
          1. supabase.auth.signInAnonymously()   → ได้ user_id
          2. insert profiles (user_id, display_name)  → DB สร้าง suffix ให้
          3. session ถูกเก็บลง Keychain โดย SDK
        → Home
```

ไม่มีรหัสผ่าน ไม่มีอีเมล ไม่มี Recovery Key ในรอบนี้

session token ที่อยู่ใน Keychain **คือ "Device credential"** ตาม requirements ข้อ 2
ไม่ใช่ของชั่วคราวที่รอถูกแทนที่ แต่เป็น authentication method ที่ถูกต้องหนึ่งชนิด
รอบ B และ C จะเพิ่มวิธีอื่นผูกกับ `user_id` เดิม

## ทำไมไม่ทำ Recovery Key ในรอบนี้

requirements ข้อ 1 ให้แสดง Recovery Key ตอนสมัคร แต่ข้อนั้นขัดกับเป้าหมายข้อแรกของเอกสารเอง
คือ "สมัครใช้งานง่ายที่สุด"

ในทางปฏิบัติ ผู้ใช้ที่ถูกบังคับให้หยุดจดรหัสกู้คืนก่อนได้ใช้แอปจะกดข้ามโดยไม่จด
ผลคือได้ flow ที่ยาวขึ้นแต่ไม่ได้ความปลอดภัยเพิ่มจริง

จึงเลื่อนไปรอบ B ในรูปแบบ "ตั้งค่าการกู้คืน" ที่ผู้ใช้เลือกทำเองจาก Settings พร้อมคำเตือนที่ชัดเจน

## ความเสี่ยงที่ต้องยอมรับในรอบ A

**จบรอบ A แล้ว บัญชีจะกู้คืนไม่ได้ถ้าเสีย session**

มี authentication method เดียวคือ device credential ดังนั้น:

- ลบแอป → session หาย → บัญชีเข้าไม่ได้อีก
- เปลี่ยนเครื่อง → เข้าบัญชีเดิมไม่ได้
- refresh token หมดอายุหรือถูกเพิกถอน → เข้าไม่ได้

ข้อมูลไม่ได้หายจากฐานข้อมูล แต่ไม่มีใครพิสูจน์ความเป็นเจ้าของได้อีก

**นี่คือเหตุผลทั้งหมดที่รอบ B มีอยู่** และเป็นเหตุผลที่รอบ B ไม่ควรถูกเลื่อนออกไปนาน
ในรอบ A ยังไม่ต้องเตือนผู้ใช้ในแอป เพราะยังไม่มีทางแก้ให้เขาทำ — คำเตือนจะมาพร้อมทางแก้ในรอบ B

## ทำไม Passkey ไม่ใช่รอบนี้

requirements ข้อ 3 ระบุ Passkey เป็น default ซึ่งถูกต้องในระยะยาว แต่วันนี้ติดกำแพงสองชั้น:

1. **ฝั่ง Apple** — passkey ต้องมี associated domain (`webcredentials:`) ซึ่งต้องใช้ทั้ง
   paid Apple Developer account (โปรเจกต์นี้ยังไม่ผูก `DEVELOPMENT_TEAM`) และโดเมนจริงที่ serve
   ไฟล์ AASA — ยังไม่มีทั้งคู่
2. **ฝั่ง Supabase** — Supabase Auth ยังไม่รองรับ passkey เป็น method ในตัว
   ต้องเขียน WebAuthn เองบน Edge Functions ซึ่งคือการสร้างระบบ auth เอง

การเลื่อนไปรอบ C ไม่ใช่การประนีประนอมกับโมเดล แต่เป็นการใช้คุณสมบัติที่โมเดลออกแบบไว้เอง
ถ้าเพิ่ม provider ทีหลังแล้วต้องรื้อ identity model แปลว่าโมเดลมีปัญหาที่ควรรู้ตั้งแต่วันนี้

## การเปลี่ยนแปลงฝั่งแอป

| ไฟล์ | เปลี่ยนอะไร |
|---|---|
| `Storage/ProfileStore.swift` | เปลี่ยนหลังบ้านจากไฟล์ JSON → Supabase **หน้าตาสาธารณะเหมือนเดิม** |
| `Storage/SessionStore.swift` | ใหม่ — ถือ session และตัดสินว่าแสดง SignUp หรือ Home |
| `Storage/SupabaseClient.swift` | ใหม่ — จุดเดียวที่ประกอบ client และถือ URL/key |
| `Views/SignUpView.swift` | ใหม่ — ช่องชื่อช่องเดียวกับปุ่ม Continue ใช้กฎ validation เดิมจาก `Profile.isValid` ทุกข้อ (ASCII, ไม่ว่าง, ไม่เกิน 50) และข้อความเตือนแบบเดียวกับหน้าแก้ไข เพื่อไม่ให้มีกฎชื่อสองชุดในแอป |
| `null_appApp.swift` | สลับ root ตามสถานะ session |
| `Models/Profile.swift` | เพิ่ม `userID`; **ลบ `makeUsernameSuffix()` ทิ้ง** เพราะฐานข้อมูลเป็นเจ้าของการสร้าง suffix แล้ว การเหลือตัวสร้างฝั่งแอปไว้จะเป็นกับดักให้ใครสักคนเรียกใช้แล้วได้ค่าที่ไม่ผ่านการกันซ้ำ ส่วนกฎ slug, validation, `bannerHue` และชุดอักษรยังอยู่ครบ |
| `ProfileView`, `ProfileHeader`, `ProfileEditView`, `HomeView` | **ไม่แตะเลย** |

`ProfileStore` รอดจากการรื้อ navigation มาแล้ว 3 ครั้งเพราะ View คุยกับมันอย่างเดียวและไม่เคยรู้จัก
วิธีเก็บข้อมูล คราวนี้ขอบเขตนั้นได้ผลตอบแทนก้อนใหญ่ที่สุด

**ยังเก็บ `profile.json` ไว้เป็น cache** เปิดแอปแล้วเห็นโปรไฟล์ทันทีจากดิสก์ แล้วค่อย refresh
จาก server เบื้องหลัง รักษาคุณสมบัติ "ไม่มีจอว่างแวบหนึ่ง" ที่ออกแบบไว้ตั้งแต่ฟีเจอร์แรก

## รูปภาพ

ย้ายขึ้น Supabase Storage ในรอบนี้ ไม่แยกไปรอบหลัง

เหตุผล: ถ้าโปรไฟล์อยู่บน server แต่รูปอยู่ในเครื่อง แอปจะอยู่ในสภาพที่อธิบายให้ผู้ใช้ไม่ได้ —
มีบัญชีแล้วแต่รูปไม่ตามไปด้วย

- bucket ชื่อ `profile-images`
- path เป็น `<user_id>/avatar-<uuid>.jpg` และ `<user_id>/cover-<uuid>.jpg`
  การขึ้นต้นด้วย `user_id` ทำให้เขียน RLS ได้ตรงไปตรงมา
- `profiles.avatar_path` / `cover_path` เก็บ path ไม่ใช่ URL เต็ม
  เพราะ URL มี domain ของโปรเจกต์ปนอยู่ ซึ่งเปลี่ยนได้
- ยังย่อรูปก่อนอัปโหลดเหมือนเดิม (512 / 1600) โค้ดใน `ProfileImage` ใช้ซ้ำได้ทั้งหมด
- ลบไฟล์เก่าหลังอัปโหลดใหม่สำเร็จ ตามลำดับเดียวกับที่ใช้อยู่ในเครื่อง

รูปที่แคชไว้ในเครื่องยังอยู่เหมือนเดิม เพื่อไม่ให้ต้องโหลดใหม่ทุกครั้งที่เปิดแอป

## การจัดการ error

| สถานการณ์ | พฤติกรรม |
|---|---|
| ไม่มีเน็ตตอนสมัคร | สมัครไม่ได้ แสดงข้อความและให้กดลองใหม่ ไม่สร้างบัญชีชั่วคราวในเครื่อง |
| ไม่มีเน็ตตอนเปิดแอป (มี session แล้ว) | แสดงโปรไฟล์จาก cache ใช้งานอ่านได้ตามปกติ |
| ไม่มีเน็ตตอนกด Save | ใช้ alert "Couldn't save" + ปุ่ม Try Again ที่มีอยู่แล้ว ไม่ต้องสร้างกลไกใหม่ |
| suffix ที่สุ่มได้ชนกับที่มีอยู่ | ฐานข้อมูลสุ่มใหม่และลองซ้ำ สูงสุด 5 ครั้ง ผู้ใช้ไม่รับรู้ |
| สมัครสำเร็จแต่ insert profile ล้มเหลว | ดูหัวข้อถัดไป |
| session ใช้ไม่ได้แล้ว | กลับไปหน้า SignUp พร้อมข้อความอธิบาย ไม่เงียบ ๆ พากลับ |

**กรณีสมัครค้างกลางทาง** — `signInAnonymously` สำเร็จแต่ `insert profiles` ล้มเหลว จะได้บัญชี
ที่ไม่มีโปรไฟล์ แอปต้องตรวจสภาพนี้ตอนเปิดทุกครั้ง: มี session แต่ไม่มีแถวใน `profiles`
ให้กลับไปหน้ากรอกชื่อแล้วสร้างแถวให้ครบ ไม่ใช่สร้างบัญชีใหม่ซ้อน

## Test

ยังไม่มี test target — การเพิ่มต้องแก้ `project.pbxproj` ซึ่ง `CLAUDE.md` ห้ามไว้

สิ่งที่ยังทดสอบด้วย `swiftc` harness ได้: กฎ slug, รูปแบบ suffix, การย่อรูป — ทั้งหมดยังเป็น type ล้วน

สิ่งที่ทดสอบไม่ได้จนกว่าจะมี test target: โค้ดที่คุยกับเน็ต

สิ่งที่ทดสอบได้ทันทีโดยไม่ต้องผ่านแอป: กฎใน SQL ทั้งหมด ทดสอบผ่าน `execute_sql` ได้ตรง ๆ —
เช่น ยืนยันว่า insert suffix ซ้ำถูกปฏิเสธจริง และ RLS กันการแก้แถวของคนอื่นได้จริง
**ข้อนี้สำคัญกว่าที่ดู เพราะกฎความปลอดภัยที่ไม่เคยถูกทดสอบคือกฎที่ไม่รู้ว่าทำงานหรือเปล่า**

## สิ่งที่ต้องทำด้วยมือ

ผมทำสองอย่างนี้ให้ไม่ได้:

1. **เปิด Anonymous sign-in** ใน Supabase dashboard → Authentication → Sign In / Providers
   MCP ไม่มีคำสั่งเปิดให้
2. **เพิ่ม Swift package `supabase-swift`** ผ่าน Xcode → File → Add Package Dependencies
   `https://github.com/supabase/supabase-swift` — การเพิ่ม package แก้ `project.pbxproj`
   ซึ่ง `CLAUDE.md` ห้ามไม่ให้แก้เอง

## ทางไปต่อ

**รอบ B** — เพิ่มอีเมลเป็น recovery channel ผูกกับ `user_id` เดิมผ่าน identity linking
พร้อมคำเตือนในแอปว่ายังกู้บัญชีไม่ได้จนกว่าจะตั้งค่า
ห้าม auto-link บัญชีเพียงเพราะอีเมลตรงกัน ต้องมีการยืนยันชัดเจนก่อนเสมอ (requirements ข้อ 6)

**รอบ C** — Passkey เป็น method หลัก, Apple/Google เป็นทางเลือก, Device Transfer
ทั้งหมดเป็นการเพิ่มแถวใน `auth.identities` ที่ผูกกับ `user_id` เดิม ไม่แตะ `profiles`
