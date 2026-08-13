# Account & Authentication Implementation Plan (รอบ A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ให้ `null-app` มีบัญชีจริงบน Supabase — สมัครโดยกรอกแค่ชื่อ ไม่มีรหัสผ่าน แล้วโปรไฟล์กับรูปย้ายไปอยู่บน server

**Architecture:** `auth.users.id` เป็น identity ภายในที่ไม่มีวันเปลี่ยน ตาราง `public.profiles` ถือ public identity โดยฐานข้อมูลเป็นคนสร้าง `stable_suffix` และกันซ้ำเอง แอปสมัครด้วย anonymous sign-in ซึ่ง session ใน Keychain ทำหน้าที่เป็น device credential `ProfileStore` เปลี่ยนหลังบ้านจากไฟล์เป็น Supabase โดยหน้าตาสาธารณะเหมือนเดิม View ทุกตัวจึงไม่ต้องแก้

**Tech Stack:** Supabase (Postgres 17 + Auth + Storage), `supabase-swift` 2.55.0, SwiftUI, Observation

**Spec:** [2026-08-13-account-and-auth-design.md](../specs/2026-08-13-account-and-auth-design.md)

## Global Constraints

- **ห้ามแก้ `project.pbxproj` ด้วยมือ** — ไฟล์ `.swift` ใหม่ใต้ `null-app/` ถูกเก็บเข้าโปรเจกต์อัตโนมัติ สร้างด้วย Write tool เท่านั้น
- **ไม่มี test target** — การตรวจสอบใช้ `execute_sql` ผ่าน Supabase MCP สำหรับ SQL, `swiftc` harness สำหรับ logic ล้วน, และ build + simulator สำหรับ UI
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** — type ที่ไม่ประกาศอะไรเป็น main-actor อยู่แล้ว งานที่ต้องออกจาก main actor ต้องระบุ `nonisolated`
- **Deployment target 26.5** — ไม่ต้องเขียน `if #available`
- **หนึ่ง target สี่แพลตฟอร์ม** — iOS, iPadOS, macOS, visionOS
- **UI strings เป็นภาษาอังกฤษ** — ตามธรรมเนียมเดิมของโปรเจกต์
- **`stable_suffix`** — ยาว **6** ตัว จากชุดอักษร `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (32 ตัว ตัด `I O 0 1` ออก) และ **UNIQUE ทั้งตาราง**
- **`display_name`** — ตัดช่องว่างหัวท้ายแล้วต้องไม่ว่าง ยาวไม่เกิน **50** และเป็นอักษร ASCII ตัวเลข ช่องว่าง `-` `'` เท่านั้น
- **build ต้องไม่มี warning จาก source ของเรา** ทั้ง iOS และ macOS

## ค่าคงที่ของโปรเจกต์

```
Supabase project ref : yqeqzplufezlnudsxzql
Project URL          : https://yqeqzplufezlnudsxzql.supabase.co
Publishable key      : sb_publishable_TzWBdrFCJzBBL8wlrU-ksg_eJyYZto1
Region               : ap-southeast-1 (Singapore)
PROJ                 : /Users/purintae/Documents/WROKSPACE/App Project/null-app
SIM_UDID             : C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF
Bundle id            : purin.null-app
```

publishable key ฝังในแอปได้อย่างปลอดภัยโดยการออกแบบ — สิ่งที่ป้องกันข้อมูลคือ RLS

## เรื่องการตรวจสอบ

| ชั้น | วิธีตรวจ |
|---|---|
| SQL (Task 1, 2) | `mcp__02aadaf8-4f04-4de8-8415-1d6fc1a4d3b5__execute_sql` ยิง query จริงใส่ฐานข้อมูลจริง |
| Logic ล้วน | `swiftc` compile ไฟล์จริงรวมกับ harness ชั่วคราว |
| UI / end-to-end | build → install → launch → screenshot |

**กฎความปลอดภัยที่ไม่เคยถูกทดสอบคือกฎที่ไม่รู้ว่าทำงานหรือเปล่า** — Task 1 และ 2 จึงมีขั้นตอนพิสูจน์ว่า RLS ปฏิเสธจริง ไม่ใช่แค่ว่าสร้างสำเร็จ

---

### Task 1: ตาราง profiles, การสร้าง suffix, และ RLS

ทั้งหมดเป็น SQL ยังไม่แตะโค้ดแอป จบ task นี้แล้วฐานข้อมูลพร้อมรับข้อมูลและกันการแก้ข้ามบัญชีได้จริง

**Files:**
- ไม่มีไฟล์ในโปรเจกต์ — ใช้ `apply_migration` ผ่าน Supabase MCP

**Interfaces:**
- Consumes: ไม่มี
- Produces:
  - ตาราง `public.profiles(user_id uuid PK, display_name text, stable_suffix text UNIQUE, avatar_path text, cover_path text, created_at timestamptz, updated_at timestamptz)`
  - ฟังก์ชัน `public.create_profile(p_display_name text) returns public.profiles` — แอปเรียกผ่าน RPC
  - RLS policies: อ่านได้ทุกคนที่ล็อกอิน, เขียน/แก้ได้เฉพาะแถวของตัวเอง

- [ ] **Step 1: สร้าง migration**

เรียก `mcp__02aadaf8-4f04-4de8-8415-1d6fc1a4d3b5__apply_migration` ด้วย `project_id` = `yqeqzplufezlnudsxzql`, `name` = `create_profiles`, และ `query` ต่อไปนี้:

```sql
create table public.profiles (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  display_name  text not null default '',
  stable_suffix text not null unique,
  avatar_path   text,
  cover_path    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint display_name_length
    check (char_length(display_name) <= 50),

  -- อักษรอังกฤษ ตัวเลข ช่องว่าง - และ ' เท่านั้น ตรงกับกฎใน Profile.isValid ฝั่งแอป
  constraint display_name_charset
    check (display_name ~ '^[A-Za-z0-9 ''-]*$'),

  constraint stable_suffix_format
    check (stable_suffix ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$')
);

-- ชุดอักษรตัด I O 0 1 ออก เพราะแยกไม่ออกเวลาอ่านออกเสียงหรือพิมพ์ตาม
create or replace function public.generate_stable_suffix()
returns text
language plpgsql
volatile
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
begin
  for _ in 1..6 loop
    result := result || substr(alphabet, floor(random() * 32)::int + 1, 1);
  end loop;
  return result;
end;
$$;

-- user_id กับ stable_suffix ห้ามเปลี่ยนหลังสร้าง บังคับที่ฐานข้อมูล ไม่ใช่แค่ความตั้งใจฝั่งแอป
create or replace function public.freeze_profile_identity()
returns trigger
language plpgsql
as $$
begin
  if new.user_id is distinct from old.user_id then
    raise exception 'user_id is immutable';
  end if;
  if new.stable_suffix is distinct from old.stable_suffix then
    raise exception 'stable_suffix is immutable';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_freeze_identity
  before update on public.profiles
  for each row execute function public.freeze_profile_identity();

alter table public.profiles enable row level security;

create policy "profiles are readable by authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

create policy "users insert their own profile"
  on public.profiles for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "users update their own profile"
  on public.profiles for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
```

- [ ] **Step 2: สร้างฟังก์ชันสมัคร**

เรียก `apply_migration` อีกครั้ง `name` = `create_profile_rpc`:

```sql
-- ลูปจับ unique_violation แล้วสุ่มใหม่ แทนที่จะให้แอปรับภาระ retry เอง
-- security definer เพื่อให้ insert ได้โดยไม่ต้องพึ่ง policy ตอนที่ยังไม่มีแถว
create or replace function public.create_profile(p_display_name text)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  attempts int := 0;
  created public.profiles;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if exists (select 1 from public.profiles where user_id = auth.uid()) then
    raise exception 'profile already exists';
  end if;

  loop
    begin
      insert into public.profiles (user_id, display_name, stable_suffix)
      values (auth.uid(), p_display_name, public.generate_stable_suffix())
      returning * into created;
      return created;
    exception when unique_violation then
      attempts := attempts + 1;
      if attempts >= 5 then
        raise exception 'could not allocate a unique stable_suffix after % attempts', attempts;
      end if;
    end;
  end loop;
end;
$$;

revoke all on function public.create_profile(text) from public;
grant execute on function public.create_profile(text) to authenticated;
```

- [ ] **Step 3: พิสูจน์ว่ากฎรูปแบบทำงานจริง**

เรียก `execute_sql` ด้วย query นี้ — ทุกบรรทัดต้องได้ `true`:

```sql
select
  -- suffix ที่สร้างได้ต้องผ่านกฎรูปแบบเสมอ
  (select bool_and(public.generate_stable_suffix() ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$')
     from generate_series(1, 200))                                as suffix_format_ok,
  -- สุ่ม 500 ครั้งต้องไม่ซ้ำกันเกือบทั้งหมด
  (select count(distinct s) > 490 from (
      select public.generate_stable_suffix() as s from generate_series(1, 500)
   ) t)                                                           as suffix_spread_ok,
  -- ชุดอักษรต้องไม่มี I O 0 1 เลย
  (select bool_and(public.generate_stable_suffix() !~ '[IO01]')
     from generate_series(1, 500))                                as alphabet_ok,
  -- RLS ต้องเปิดอยู่
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass) as rls_enabled;
```

คาดหวัง: `suffix_format_ok = true`, `suffix_spread_ok = true`, `alphabet_ok = true`, `rls_enabled = true`

- [ ] **Step 4: พิสูจน์ว่า RLS ปฏิเสธจริง ไม่ใช่แค่เปิดไว้เฉย ๆ**

เรียก `execute_sql`:

```sql
-- สวมบทเป็นผู้ใช้ที่ล็อกอินแล้วซึ่งไม่มีตัวตนจริง แล้วลองอ่าน
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
select count(*) as rows_visible_to_stranger from public.profiles;
```

คาดหวัง: รันผ่านและได้ `0` — ตอนนี้ตารางยังว่าง สิ่งที่พิสูจน์คือ policy ไม่ระเบิด

จากนั้นพิสูจน์ว่าเขียนแทนคนอื่นไม่ได้:

```sql
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
insert into public.profiles (user_id, display_name, stable_suffix)
values ('00000000-0000-0000-0000-000000000002', 'Intruder', 'ABCDEF');
```

คาดหวัง: **ล้มเหลว** ด้วย error ที่มีคำว่า `row-level security` — ถ้าคำสั่งนี้สำเร็จ แปลว่า policy ผิด ต้องหยุดและแก้ก่อนไปต่อ

- [ ] **Step 5: บันทึกผล**

เขียนสรุปผลของ Step 3 และ 4 ลงในรายงาน พร้อม output ดิบของทั้งสอง query

---

### Task 2: Storage bucket สำหรับรูปโปรไฟล์

**Files:**
- ไม่มีไฟล์ในโปรเจกต์ — SQL ผ่าน Supabase MCP

**Interfaces:**
- Consumes: ตาราง `profiles` จาก Task 1
- Produces: bucket `profile-images` พร้อม policy ที่ผูก path กับ `user_id`

- [ ] **Step 1: สร้าง bucket และ policy**

เรียก `apply_migration` `name` = `create_profile_images_bucket`:

```sql
insert into storage.buckets (id, name, public)
values ('profile-images', 'profile-images', true)
on conflict (id) do nothing;

-- path เป็น "<user_id>/<ชื่อไฟล์>" การเช็คจึงเทียบส่วนแรกของ path กับ auth.uid()
create policy "profile images are readable by anyone"
  on storage.objects for select
  using (bucket_id = 'profile-images');

create policy "users upload into their own folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'profile-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "users update their own files"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'profile-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "users delete their own files"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'profile-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
```

- [ ] **Step 2: พิสูจน์ว่า policy ผูกกับ path จริง**

เรียก `execute_sql`:

```sql
select
  (select public from storage.buckets where id = 'profile-images')            as bucket_is_public,
  -- วงเล็บสำคัญ: ถ้าไม่ใส่ OR จะหลุดจากเงื่อนไข schema/table แล้วไปนับ policy ของตารางอื่นมาด้วย
  (select count(*) from pg_policies
     where schemaname = 'storage' and tablename = 'objects') as policy_count,
  -- ยืนยันว่า foldername แยก path ได้อย่างที่ policy คาดไว้
  (storage.foldername('11111111-1111-1111-1111-111111111111/avatar-x.jpg'))[1]
    = '11111111-1111-1111-1111-111111111111'                                   as foldername_ok;
```

คาดหวัง: `bucket_is_public = true`, `policy_count >= 4`, `foldername_ok = true`

- [ ] **Step 3: บันทึกผล**

เขียน output ดิบลงรายงาน

---

## ⛔ ขั้นตอนที่ผู้ใช้ต้องทำเอง — Task 3 เริ่มไม่ได้จนกว่าจะเสร็จทั้งสองข้อ

**หยุดที่นี่แล้วแจ้งผู้ใช้** อย่าเดาว่าทำเสร็จแล้ว ให้ตรวจสอบก่อนเดินต่อ

1. **เปิด Anonymous sign-in**
   `https://supabase.com/dashboard/project/yqeqzplufezlnudsxzql/auth/providers`
   → หา "Anonymous sign-ins" → เปิด → Save

2. **เพิ่ม Swift package**
   Xcode → File → Add Package Dependencies…
   → `https://github.com/supabase/supabase-swift`
   → Dependency Rule: Up to Next Major, **2.55.0**
   → เลือก product **Supabase** → Add to target `null-app`

**วิธีตรวจว่าข้อ 2 เสร็จแล้ว:**

```bash
grep -c "supabase-swift" "$PROJ/null-app.xcodeproj/project.pbxproj"
```
คาดหวัง: มากกว่า 0

**วิธีตรวจว่าข้อ 1 เสร็จแล้ว** — ทำหลังจาก Task 3 Step 1 มีไฟล์ config แล้ว:

```bash
curl -s -X POST "https://yqeqzplufezlnudsxzql.supabase.co/auth/v1/signup" \
  -H "apikey: sb_publishable_TzWBdrFCJzBBL8wlrU-ksg_eJyYZto1" \
  -H "Content-Type: application/json" -d '{}' | head -c 300
```
ถ้ายังไม่เปิดจะได้ error ที่มีคำว่า `anonymous_provider_disabled` — ถ้าเปิดแล้วจะได้ JSON ที่มี `access_token`

---

### Task 3: ต่อ Supabase และรู้สถานะ session

**Files:**
- Create: `null-app/Storage/Backend.swift`
- Create: `null-app/Storage/SessionStore.swift`

**ไม่แตะ `null_appApp.swift` ใน task นี้** — การสลับ root ต้องอ้างทั้ง `SignUpView` และ `ProfileStore`
ซึ่งยังไม่มีทั้งคู่ ถ้าแก้ที่นี่ task จะจบลงด้วย build ที่พัง งานนั้นอยู่ท้าย Task 5

**Interfaces:**
- Consumes: ฟังก์ชัน `create_profile` จาก Task 1
- Produces:
  - `nonisolated enum Backend` มี `static let client: SupabaseClient`
  - `@Observable final class SessionStore` มี `enum State { case loading, signedOut, signedIn(userID: UUID) }`, `private(set) var state: State`, และ `func signUp(displayName: String) async throws`

- [ ] **Step 1: สร้าง `Backend.swift`**

```swift
//
//  Backend.swift
//  null-app
//

import Foundation
import Supabase

/// จุดเดียวที่ประกอบ Supabase client ไฟล์อื่นเรียกผ่าน Backend.client เท่านั้น
///
/// publishable key ฝังในแอปได้อย่างปลอดภัยโดยการออกแบบ — มันถูกออกแบบมาให้อยู่ใน client
/// สิ่งที่ป้องกันข้อมูลจริง ๆ คือ Row Level Security ไม่ใช่การซ่อน key นี้
nonisolated enum Backend {
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://yqeqzplufezlnudsxzql.supabase.co")!,
        supabaseKey: "sb_publishable_TzWBdrFCJzBBL8wlrU-ksg_eJyYZto1"
    )
}
```

- [ ] **Step 2: สร้าง `SessionStore.swift`**

```swift
//
//  SessionStore.swift
//  null-app
//

import Foundation
import Observation
import Supabase

/// ถือสถานะการล็อกอิน และเป็นตัวตัดสินว่าแอปแสดงหน้าสมัครหรือหน้า Home
///
/// ไม่เก็บ token เอง — supabase-swift เก็บลง Keychain ให้อยู่แล้ว
/// session ที่อยู่ใน Keychain นั้นคือ "device credential" ตาม requirements
/// ไม่ใช่ของชั่วคราวที่รอถูกแทนที่
@Observable
final class SessionStore {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(userID: UUID)
    }

    private(set) var state: State = .loading

    private var watcher: Task<Void, Never>?

    init() {
        // authStateChanges ส่ง .initialSession ให้เสมอตอนเริ่มฟัง
        // สถานะ .loading จึงอยู่แค่ชั่วครู่ ไม่ค้าง
        watcher = Task { [weak self] in
            for await change in Backend.client.auth.authStateChanges {
                guard let self else { return }

                switch change.event {
                case .signedOut:
                    state = .signedOut
                default:
                    state = change.session.map { .signedIn(userID: $0.user.id) } ?? .signedOut
                }
            }
        }
    }

    deinit {
        watcher?.cancel()
    }

    /// สมัครสองขั้นตอนที่ต้องสำเร็จทั้งคู่: สร้างบัญชี แล้วสร้างโปรไฟล์
    /// ถ้าขั้นที่สองล้มเหลว จะได้บัญชีที่ไม่มีโปรไฟล์ ซึ่ง ProfileStore ตรวจเจอและพากลับมากรอกใหม่
    func signUp(displayName: String) async throws {
        try await Backend.client.auth.signInAnonymously()
        try await createProfile(displayName: displayName)
    }

    /// แยกออกมาเพราะถูกเรียกซ้ำได้ ในกรณีที่บัญชีมีแล้วแต่โปรไฟล์ยังไม่มี
    func createProfile(displayName: String) async throws {
        try await Backend.client
            .rpc("create_profile", params: ["p_display_name": displayName])
            .execute()
    }
}
```

- [ ] **Step 3: Build ทั้งสองแพลตฟอร์ม**

```bash
xcodebuild -scheme null-app -project "$PROJ/null-app.xcodeproj" -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "warning:|error:|BUILD (SUCCEEDED|FAILED)" | grep -v appintentsmetadataprocessor
xcodebuild -scheme null-app -project "$PROJ/null-app.xcodeproj" -destination 'platform=macOS' build 2>&1 | grep -E "^/.*(warning|error):|BUILD (SUCCEEDED|FAILED)"
```

คาดหวัง: `** BUILD SUCCEEDED **` ทั้งคู่ และไม่มี warning จาก source ของเรา

ไฟล์ทั้งสองที่สร้างในนี้ไม่ได้อ้างอะไรที่ยังไม่มี จึงต้องผ่านตั้งแต่รอบนี้
ถ้าไม่ผ่าน แปลว่า package ยังไม่ถูกเพิ่มหรือ import ผิด — หยุดแก้ก่อนไปต่อ

- [ ] **Step 4: ยืนยันว่า anonymous sign-in เปิดแล้วจริง**

```bash
curl -s -X POST "https://yqeqzplufezlnudsxzql.supabase.co/auth/v1/signup" \
  -H "apikey: sb_publishable_TzWBdrFCJzBBL8wlrU-ksg_eJyYZto1" \
  -H "Content-Type: application/json" -d '{}' | head -c 300
```

คาดหวัง: JSON ที่มี `access_token` — ถ้าเจอ `anonymous_provider_disabled` แปลว่าผู้ใช้ยังไม่ได้เปิด
ให้หยุดและแจ้ง ไม่ต้องเดินต่อ

ผู้ใช้ทดสอบนี้จะสร้างบัญชีทิ้งไว้หนึ่งใบ — ลบออกใน Task 7 Step 3 อยู่แล้ว

- [ ] **Step 5: Commit**

```bash
cd "$PROJ" && git add null-app && git commit -m "Add Supabase client and session state"
```

---

### Task 4: หน้าสมัคร

**Files:**
- Create: `null-app/Views/SignUpView.swift`

**Interfaces:**
- Consumes: `SessionStore.signUp(displayName:)` จาก Task 3, `Profile.isValid` และ `Profile.hasUnsupportedNameCharacters` ที่มีอยู่แล้ว
- Produces: `struct SignUpView: View` — `init(session: SessionStore)`

- [ ] **Step 1: สร้าง `SignUpView.swift`**

```swift
//
//  SignUpView.swift
//  null-app
//

import SwiftUI

/// สมัครโดยกรอกชื่ออย่างเดียว ไม่มีรหัสผ่าน ไม่มีอีเมล
/// ใช้กฎชื่อชุดเดียวกับหน้าแก้ไขโปรไฟล์ผ่าน Profile.isValid
/// เพื่อไม่ให้มีกฎสองชุดที่หลุดจากกันได้
struct SignUpView: View {
    let session: SessionStore

    @State private var displayName = ""
    @State private var isWorking = false
    @State private var failure: String?

    /// สร้าง Profile ชั่วคราวเพื่อยืมกฎ validation ที่มีอยู่แล้วมาใช้
    private var draft: Profile {
        Profile(displayName: displayName, bio: "")
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 8) {
                Text("What should we call you?")
                    .font(.title2.weight(.bold))

                Text("You can change this at any time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Display name", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .disabled(isWorking)

                if draft.hasUnsupportedNameCharacters {
                    Label(
                        "Use English letters, numbers, spaces, - or ' only",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.red)
                }
            }

            Button {
                Task { await submit() }
            } label: {
                if isWorking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!draft.isValid || isWorking)

            Spacer()
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 420)
        .alert(
            "Couldn't create your account",
            isPresented: Binding(
                get: { failure != nil },
                set: { if !$0 { failure = nil } }
            ),
            presenting: failure
        ) { _ in
            Button("OK", role: .cancel) { failure = nil }
        } message: { message in
            Text(message)
        }
    }

    /// เก็บชื่อที่ตัดช่องว่างแล้ว จะได้ไม่มีช่องว่างค้างในฐานข้อมูล
    private func submit() async {
        isWorking = true
        defer { isWorking = false }

        do {
            try await session.signUp(displayName: draft.trimmedDisplayName)
        } catch {
            failure = error.localizedDescription
        }
    }
}

#Preview {
    SignUpView(session: SessionStore())
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme null-app -project "$PROJ/null-app.xcodeproj" -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "warning:|error:|BUILD (SUCCEEDED|FAILED)" | grep -v appintentsmetadataprocessor
xcodebuild -scheme null-app -project "$PROJ/null-app.xcodeproj" -destination 'platform=macOS' build 2>&1 | grep -E "^/.*(warning|error):|BUILD (SUCCEEDED|FAILED)"
```

คาดหวัง: `** BUILD SUCCEEDED **` ทั้งคู่ ไม่มี warning

`SignUpView` อ้างแค่ `SessionStore` กับ `Profile` ซึ่งมีครบแล้ว จึงต้องผ่านตั้งแต่รอบนี้
ยังไม่มีใครเรียกใช้มัน — การสลับ root เกิดใน Task 5

- [ ] **Step 3: Commit**

```bash
cd "$PROJ" && git add null-app/Views/SignUpView.swift && git commit -m "Add the sign-up screen"
```

---

### Task 5: ProfileStore อ่านเขียนผ่าน Supabase

หัวใจของรอบนี้ — เปลี่ยนหลังบ้านโดยไม่แตะ View สักตัว

**Files:**
- Create: `null-app/Storage/RemoteProfile.swift`
- Modify: `null-app/Storage/ProfileStore.swift` (แทนที่ทั้งไฟล์)
- Modify: `null-app/Models/Profile.swift` (ลบ `makeUsernameSuffix()`)

**Interfaces:**
- Consumes: `Backend.client`, ฟังก์ชัน `create_profile`
- Produces: `ProfileStore` ที่มี `init()` ไม่รับ argument, `private(set) var profile: Profile`, `var needsProfile: Bool`, `func refresh() async`, `func update(_:avatar:cover:) async throws` — **signature เดิมทุกตัวที่ View ใช้อยู่**

- [ ] **Step 1: สร้าง `RemoteProfile.swift`**

```swift
//
//  RemoteProfile.swift
//  null-app
//

import Foundation

/// รูปร่างของแถวในตาราง profiles
/// เขียน CodingKeys เองทั้งหมดแทนการพึ่ง key decoding strategy ของ decoder
/// เพราะ decoder ที่ใช้เป็นของ library ซึ่งเราไม่ได้ตั้งค่าเอง
nonisolated struct RemoteProfile: Codable, Sendable {
    let userID: UUID
    var displayName: String
    let stableSuffix: String
    var avatarPath: String?
    var coverPath: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case stableSuffix = "stable_suffix"
        case avatarPath = "avatar_path"
        case coverPath = "cover_path"
        case createdAt = "created_at"
    }
}
```

- [ ] **Step 2: แทนที่ `ProfileStore.swift` ทั้งไฟล์**

```swift
//
//  ProfileStore.swift
//  null-app
//

import Foundation
import Observation
import Supabase
import SwiftUI

/// สิ่งที่ผู้ใช้ตั้งใจทำกับช่องรูปหนึ่งช่อง
/// แยก "ไม่แตะ" ออกจาก "เอาออก" ชัดเจน เพราะ nil อย่างเดียวบอกไม่ได้ว่าอันไหน
nonisolated enum ImageEdit: Equatable, Sendable {
    case unchanged
    case replace(Data)
    case remove
}

/// เจ้าของ state ของโปรไฟล์เพียงผู้เดียว
/// หน้าตาสาธารณะเหมือนตอนเก็บไฟล์ในเครื่องทุกประการ View จึงไม่ต้องแก้อะไรเลย
/// สิ่งที่เปลี่ยนคือหลังบ้าน จากไฟล์ JSON เป็น Supabase
@Observable
final class ProfileStore {
    private(set) var profile: Profile
    private(set) var avatarImage: Image?
    private(set) var coverImage: Image?

    /// จริงเมื่อมีบัญชีแล้วแต่ยังไม่มีแถวใน profiles
    /// เกิดได้เมื่อสมัครค้างกลางทาง — สร้างบัญชีสำเร็จแต่สร้างโปรไฟล์ไม่สำเร็จ
    private(set) var needsProfile = false

    private let cacheURL: URL

    /// อ่าน cache แบบ synchronous ตอนสร้างโดยตั้งใจ — เห็นโปรไฟล์ทันทีโดยไม่ต้องรอเน็ต
    /// แล้วค่อย refresh ทับด้วยของจริงจาก server
    ///
    /// ถ้ายังไม่มี session ให้ล้างข้อมูลเก่าทิ้งก่อน — ไฟล์ที่ค้างอยู่จากยุคที่แอปเก็บข้อมูล
    /// ในเครื่องล้วนไม่ใช่ของบัญชีใด และการปล่อยไว้จะทำให้เห็นโปรไฟล์ของคนก่อนหน้า
    /// หลังสมัครบัญชีใหม่ ซึ่งเป็นข้อมูลรั่วข้ามบัญชีบนเครื่องที่ใช้ร่วมกัน
    init(cacheURL: URL = ProfileStore.defaultCacheURL) {
        self.cacheURL = cacheURL

        if Backend.client.auth.currentSession == nil {
            ProfileStore.clearLocalData(cacheURL: cacheURL)
            self.profile = .empty
            self.avatarImage = nil
            self.coverImage = nil
            return
        }

        self.profile = ProfileStore.readCache(from: cacheURL)

        let directory = ProfileStore.imagesDirectory(besides: cacheURL)
        self.avatarImage = ProfileStore.loadImage(named: profile.avatarFileName, in: directory)
        self.coverImage = ProfileStore.loadImage(named: profile.coverFileName, in: directory)
    }

    nonisolated static func clearLocalData(cacheURL: URL) {
        try? FileManager.default.removeItem(at: cacheURL)
        try? FileManager.default.removeItem(at: imagesDirectory(besides: cacheURL))
    }

    /// ดึงของจริงจาก server มาทับ cache
    /// ไม่ throw เพราะการเปิดแอปตอนไม่มีเน็ตควรใช้งานต่อได้ด้วยข้อมูลที่แคชไว้
    func refresh() async {
        guard let userID = Backend.client.auth.currentSession?.user.id else { return }

        do {
            let rows: [RemoteProfile] = try await Backend.client
                .from("profiles")
                .select()
                .eq("user_id", value: userID)
                .execute()
                .value

            guard let row = rows.first else {
                needsProfile = true
                return
            }

            needsProfile = false
            profile = Profile(
                displayName: row.displayName,
                bio: profile.bio,
                usernameSuffix: row.stableSuffix,
                createdAt: row.createdAt,
                avatarFileName: profile.avatarFileName,
                coverFileName: profile.coverFileName
            )
            ProfileStore.writeCache(profile, to: cacheURL)
        } catch {
            // เก็บ cache ไว้ใช้ต่อ ไม่รบกวนผู้ใช้ด้วย error ตอนเปิดแอป
        }
    }

    /// ตั้งค่าใน memory ก่อน แล้วค่อยส่งขึ้น server
    /// ถ้าส่งพลาด ค่าใน memory ยังอยู่ ผู้ใช้ไม่เสียสิ่งที่พิมพ์ไป
    /// รูปยังไม่ถูกจัดการใน task นี้ — Task 6 มาเติม
    func update(
        _ newProfile: Profile,
        avatar: ImageEdit = .unchanged,
        cover: ImageEdit = .unchanged
    ) async throws {
        _ = avatar
        _ = cover

        profile = newProfile
        ProfileStore.writeCache(newProfile, to: cacheURL)

        struct Patch: Encodable {
            let display_name: String
        }

        guard let userID = Backend.client.auth.currentSession?.user.id else {
            throw ProfileStoreError.notSignedIn
        }

        try await Backend.client
            .from("profiles")
            .update(Patch(display_name: newProfile.trimmedDisplayName))
            .eq("user_id", value: userID)
            .execute()
    }

    // MARK: - Cache

    static var defaultCacheURL: URL {
        URL.applicationSupportDirectory.appending(path: "profile.json")
    }

    nonisolated static func imagesDirectory(besides fileURL: URL) -> URL {
        fileURL.deletingLastPathComponent().appending(path: "images")
    }

    nonisolated static func readCache(from url: URL) -> Profile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard
            let data = try? Data(contentsOf: url),
            let decoded = try? decoder.decode(Profile.self, from: data)
        else {
            return .empty
        }
        return decoded
    }

    /// cache พังไม่ใช่เรื่องที่ผู้ใช้ต้องรับรู้ ของจริงอยู่บน server
    nonisolated static func writeCache(_ profile: Profile, to url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(profile) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func loadImage(named name: String?, in directory: URL) -> Image? {
        guard
            let name,
            let data = try? Data(contentsOf: directory.appending(path: name)),
            let decoded = ProfileImage.decode(data)
        else {
            return nil
        }
        return Image(decorative: decoded, scale: 1)
    }
}

nonisolated enum ProfileStoreError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        "You're not signed in."
    }
}
```

- [ ] **Step 3: ลบตัวสร้าง suffix ฝั่งแอป**

ใน `null-app/Models/Profile.swift` ลบฟังก์ชันนี้ทั้งก้อน:

```swift
    static func makeUsernameSuffix() -> String {
        let alphabet = usernameSuffixAlphabet
        return String((0 ..< usernameSuffixLength).map { _ in
            alphabet[Int.random(in: 0 ..< alphabet.count)]
        })
    }
```

เก็บ `usernameSuffixAlphabet` และ `usernameSuffixLength` ไว้ เพราะยังใช้ตรวจรูปแบบได้

เหตุผลที่ลบ: ฐานข้อมูลเป็นเจ้าของการสร้าง suffix แล้ว การเหลือตัวสร้างฝั่งแอปไว้เป็นกับดักให้ใครสักคนเรียกใช้แล้วได้ค่าที่ไม่ผ่านการกันซ้ำ

- [ ] **Step 4: แทนที่ `null_appApp.swift` ทั้งไฟล์ — สลับ root ตามสถานะ session**

ตอนนี้ทั้ง `SignUpView` และ `ProfileStore()` แบบไม่มี argument มีครบแล้ว จึงเป็นจังหวะที่ต่อสายได้โดย build ไม่พัง

```swift
//
//  null_appApp.swift
//  null-app
//
//  Created by Purin Tae on 12/8/2569 BE.
//

import SwiftUI

@main
struct null_appApp: App {
    @State private var session = SessionStore()
    @State private var profileStore = ProfileStore()

    /// ธีมที่ผู้ใช้เลือกใน Settings ต้องอ่านที่รากเพื่อครอบทั้งแอป
    @AppStorage("appearance") private var appearance: AppearanceSetting = .system

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.state {
                case .loading:
                    ProgressView()

                case .signedOut:
                    SignUpView(session: session)

                case .signedIn:
                    // Home เป็นรากเดียวของแอป ส่วน Profile ถูก push จากไอคอนบนแถบบนของ Home
                    NavigationStack {
                        HomeView()
                    }
                    .environment(profileStore)
                    .task { await profileStore.refresh() }
                }
            }
            .preferredColorScheme(appearance.colorScheme)
        }
    }
}
```

- [ ] **Step 5: Build ทั้งสองแพลตฟอร์ม**

```bash
xcodebuild -scheme null-app -project "$PROJ/null-app.xcodeproj" -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "warning:|error:|BUILD (SUCCEEDED|FAILED)" | grep -v appintentsmetadataprocessor
xcodebuild -scheme null-app -project "$PROJ/null-app.xcodeproj" -destination 'platform=macOS' build 2>&1 | grep -E "^/.*(warning|error):|BUILD (SUCCEEDED|FAILED)"
```

คาดหวัง: `** BUILD SUCCEEDED **` ทั้งคู่ ไม่มี warning

- [ ] **Step 6: ทดสอบสมัครจริงบน simulator**

ล้างข้อมูลเก่าออกก่อน เพื่อให้ได้สภาพ "เปิดครั้งแรก" จริง ๆ:

```bash
xcrun simctl uninstall C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF purin.null-app
APP=$(xcodebuild -scheme null-app -project "$PROJ/null-app.xcodeproj" -destination 'generic/platform=iOS Simulator' -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2"/null-app.app"}')
xcrun simctl install C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF "$APP"
xcrun simctl launch C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF purin.null-app
```

จากนั้นใช้ `mcp__Claude_Code_iOS_Simulator__control` — `attach` ก่อน แล้ว `screenshot`

คาดหวัง: เห็นหน้า "What should we call you?" ไม่ใช่หน้า Home

พิมพ์ `Purin Tae` ลงในช่อง แล้วกด Continue จากนั้น `screenshot`

คาดหวัง: เข้าหน้า Home

- [ ] **Step 6b: พิสูจน์ว่าข้อมูลยุคเก่าถูกล้างจริง**

ก่อนติดตั้งใหม่ใน Step 6 ให้ตรวจก่อนว่าเครื่องยังมีข้อมูลเก่าอยู่:

```bash
C=$(xcrun simctl get_app_container C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF purin.null-app data 2>/dev/null)
cat "$C/Library/Application Support/profile.json" 2>/dev/null; echo
ls "$C/Library/Application Support/images" 2>/dev/null | wc -l
```

หลังเปิดแอปเวอร์ชันใหม่แล้วยังไม่ได้สมัคร ให้ตรวจซ้ำด้วยคำสั่งเดียวกัน

คาดหวัง: ไฟล์ `profile.json` และโฟลเดอร์ `images/` **หายไปแล้ว** — โปรไฟล์ `Purin Tae` กับ suffix
`3Q6RDV` เดิมต้องไม่หลงเหลือ ถ้ายังอยู่แปลว่า `clearLocalData` ไม่ทำงานและมีความเสี่ยงที่
ผู้ใช้บัญชีใหม่จะเห็นข้อมูลของบัญชีก่อนหน้า

- [ ] **Step 7: ยืนยันที่ฐานข้อมูลว่ามีแถวจริง**

เรียก `execute_sql`:

```sql
select user_id, display_name, stable_suffix, created_at from public.profiles;
```

คาดหวัง: มี 1 แถว `display_name = 'Purin Tae'` และ `stable_suffix` เป็น 6 ตัวจากชุดอักษรที่กำหนด

เข้าหน้า Profile ในแอปแล้ว `screenshot` — username ที่แสดงต้องลงท้ายด้วย suffix ตัวเดียวกับที่เห็นในฐานข้อมูล **นี่คือข้อพิสูจน์ว่าแอปกับ server ตรงกันจริง**

- [ ] **Step 8: Commit**

```bash
cd "$PROJ" && git add null-app && git commit -m "Back ProfileStore with Supabase instead of a local file"
```

---

### Task 6: รูปโปรไฟล์และรูป cover บน Supabase Storage

**Files:**
- Modify: `null-app/Storage/ProfileStore.swift` (เติมส่วนรูปใน `update` และเพิ่ม `syncImages`)

**Interfaces:**
- Consumes: bucket `profile-images` จาก Task 2, `ProfileImage.prepare(_:maxPixel:)` ที่มีอยู่แล้ว
- Produces: `ProfileStore.update(_:avatar:cover:)` ที่จัดการรูปครบวงจร

- [ ] **Step 1: เพิ่มการอัปโหลดใน `ProfileStore`**

แทนที่เมธอด `update` ด้วยตัวนี้ และเพิ่มเมธอดช่วยด้านล่าง:

```swift
    /// ลำดับสำคัญ: อัปโหลดรูปใหม่ → อัปเดตแถวใน DB → ค่อยลบรูปเก่า
    /// พังกลางทางจะเหลือไฟล์กำพร้าที่แค่กินที่ ส่วนลำดับกลับกันจะได้แถวที่ชี้ไปไฟล์ที่ถูกลบแล้ว
    func update(
        _ newProfile: Profile,
        avatar: ImageEdit = .unchanged,
        cover: ImageEdit = .unchanged
    ) async throws {
        guard let userID = Backend.client.auth.currentSession?.user.id else {
            throw ProfileStoreError.notSignedIn
        }

        let previousAvatar = profile.avatarFileName
        let previousCover = profile.coverFileName

        let avatarPath = try await Self.applyEdit(
            avatar,
            current: previousAvatar,
            kind: "avatar",
            maxPixel: ProfileImage.avatarMaxPixel,
            userID: userID
        )

        let coverPath = try await Self.applyEdit(
            cover,
            current: previousCover,
            kind: "cover",
            maxPixel: ProfileImage.coverMaxPixel,
            userID: userID
        )

        var finalProfile = newProfile
        finalProfile.avatarFileName = avatarPath
        finalProfile.coverFileName = coverPath

        profile = finalProfile
        ProfileStore.writeCache(finalProfile, to: cacheURL)

        struct Patch: Encodable {
            let display_name: String
            let avatar_path: String?
            let cover_path: String?
        }

        try await Backend.client
            .from("profiles")
            .update(
                Patch(
                    display_name: finalProfile.trimmedDisplayName,
                    avatar_path: avatarPath,
                    cover_path: coverPath
                )
            )
            .eq("user_id", value: userID)
            .execute()

        if avatar != .unchanged {
            avatarImage = await Self.downloadImage(path: avatarPath)
        }
        if cover != .unchanged {
            coverImage = await Self.downloadImage(path: coverPath)
        }

        await Self.deleteIfReplaced(previousAvatar, by: avatarPath)
        await Self.deleteIfReplaced(previousCover, by: coverPath)
    }

    /// path ขึ้นต้นด้วย user_id เสมอ เพื่อให้ policy ของ Storage เทียบกับ auth.uid() ได้ตรง ๆ
    static func applyEdit(
        _ edit: ImageEdit,
        current: String?,
        kind: String,
        maxPixel: Int,
        userID: UUID
    ) async throws -> String? {
        switch edit {
        case .unchanged:
            return current

        case .remove:
            return nil

        case .replace(let raw):
            let jpeg = try await Task.detached(priority: .userInitiated) {
                try ProfileImage.prepare(raw, maxPixel: maxPixel)
            }.value

            let path = "\(userID.uuidString)/\(kind)-\(UUID().uuidString).jpg"

            try await Backend.client.storage
                .from("profile-images")
                .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg"))

            return path
        }
    }

    static func downloadImage(path: String?) async -> Image? {
        guard let path else { return nil }

        guard
            let data = try? await Backend.client.storage
                .from("profile-images")
                .download(path: path),
            let decoded = ProfileImage.decode(data)
        else {
            return nil
        }
        return Image(decorative: decoded, scale: 1)
    }

    static func deleteIfReplaced(_ old: String?, by new: String?) async {
        guard let old, old != new else { return }
        _ = try? await Backend.client.storage.from("profile-images").remove(paths: [old])
    }
```

เพิ่ม `import Supabase` ให้ครบถ้ายังไม่มี และเพิ่มการโหลดรูปใน `refresh()` ต่อจากการตั้งค่า `profile`:

```swift
            avatarImage = await Self.downloadImage(path: row.avatarPath)
            coverImage = await Self.downloadImage(path: row.coverPath)
```

พร้อมกับเปลี่ยนบรรทัดที่สร้าง `Profile` ใน `refresh()` ให้ใช้ path จาก server:

```swift
                avatarFileName: row.avatarPath,
                coverFileName: row.coverPath
```

- [ ] **Step 2: Build ทั้งสองแพลตฟอร์ม**

```bash
xcodebuild -scheme null-app -project "$PROJ/null-app.xcodeproj" -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "warning:|error:|BUILD (SUCCEEDED|FAILED)" | grep -v appintentsmetadataprocessor
xcodebuild -scheme null-app -project "$PROJ/null-app.xcodeproj" -destination 'platform=macOS' build 2>&1 | grep -E "^/.*(warning|error):|BUILD (SUCCEEDED|FAILED)"
```

- [ ] **Step 3: ทดสอบอัปโหลดรูปจริง**

ติดตั้งใหม่และเปิดแอป เข้าหน้า Profile → Edit Profile → Choose cover → เลือกรูป → Save

รูปทดสอบสองใบยังอยู่ในคลังภาพของ simulator (ลายเฉียงส้ม และวงกลมม่วงบนเหลือง)

จากนั้น `screenshot` — cover ต้องเปลี่ยนเป็นรูปที่เลือก

- [ ] **Step 4: ยืนยันว่าไฟล์ขึ้นไปจริงและ path ถูกต้อง**

เรียก `execute_sql`:

```sql
select
  p.display_name,
  p.avatar_path,
  p.cover_path,
  (select count(*) from storage.objects
     where bucket_id = 'profile-images' and name = p.cover_path) as cover_file_exists
from public.profiles p;
```

คาดหวัง: `cover_path` ขึ้นต้นด้วย `user_id` ตามด้วย `/cover-` และ `cover_file_exists = 1`

- [ ] **Step 5: พิสูจน์ว่าเปลี่ยนรูปแล้วไฟล์เก่าถูกลบ**

เปลี่ยน cover เป็นรูปอีกใบแล้ว Save จากนั้น:

```sql
select count(*) as files_in_bucket from storage.objects where bucket_id = 'profile-images';
```

คาดหวัง: จำนวนไฟล์ **ไม่เพิ่ม** — ของเก่าถูกลบทิ้งแล้ว

- [ ] **Step 6: Commit**

```bash
cd "$PROJ" && git add null-app && git commit -m "Move profile images to Supabase Storage"
```

---

### Task 7: เก็บกวาดและตรวจครบวงจร

**Files:**
- Modify: `null-app/Views/ProfileView.swift` (จัดการสถานะ `needsProfile`)
- Modify: `docs/superpowers/specs/2026-08-12-profile-design.md` (บันทึกว่าที่เก็บข้อมูลเปลี่ยนไปแล้ว)

**Interfaces:**
- Consumes: `ProfileStore.needsProfile` จาก Task 5

- [ ] **Step 1: พาผู้ใช้กลับไปกรอกชื่อเมื่อบัญชีมีแต่โปรไฟล์ไม่มี**

ใน `null-app/null_appApp.swift` เปลี่ยน case `.signedIn` เป็น:

```swift
                case .signedIn:
                    if profileStore.needsProfile {
                        // สมัครค้างกลางทาง — มีบัญชีแล้วแต่ยังไม่มีโปรไฟล์
                        // ให้กรอกชื่อเพื่อสร้างแถวให้ครบ ไม่ใช่สร้างบัญชีใหม่ซ้อน
                        SignUpView(session: session)
                    } else {
                        NavigationStack {
                            HomeView()
                        }
                        .environment(profileStore)
                        .task { await profileStore.refresh() }
                    }
```

`SignUpView` ต้องเพิ่ม `import Supabase` ด้วย เพราะบรรทัดถัดไปอ้าง `Backend.client.auth`
ซึ่งไฟล์นี้เดิม import แค่ SwiftUI (ไม่งั้น build พังทั้งสองแพลตฟอร์ม)

และใน `SignUpView.submit()` เปลี่ยนให้เลือกเส้นทางตามว่ามีบัญชีอยู่แล้วหรือยัง:

```swift
    private func submit() async {
        isWorking = true
        defer { isWorking = false }

        do {
            if Backend.client.auth.currentSession == nil {
                try await session.signUp(displayName: draft.trimmedDisplayName)
            } else {
                try await session.createProfile(displayName: draft.trimmedDisplayName)
            }
        } catch {
            failure = error.localizedDescription
        }
    }
```

**เส้นทางกู้คืนต้องมีทางออก** — หลัง `createProfile` สำเร็จ `needsProfile` ยังเป็น true อยู่
เพราะมีแต่ `ProfileStore.refresh()` เท่านั้นที่เปลี่ยนมันได้ และ `refresh()` ถูกแขวนไว้กับ
สาขา Home ที่ยังไม่ถูกแสดง ผู้ใช้จึงติดอยู่ที่หน้าสมัครวนไม่จบ
แก้โดยให้ `SignUpView` มี `var onProfileCreated: () async -> Void = {}` ที่เรียกหลังสำเร็จ
แล้ว `null_appApp` ส่ง `{ await profileStore.refresh() }` เข้าไปทั้งสองสาขา

- [ ] **Step 2: ตรวจว่า macOS ยัง build ผ่าน**

```bash
xcodebuild -scheme null-app -project "$PROJ/null-app.xcodeproj" -destination 'platform=macOS' clean build 2>&1 | grep -E "^/.*(warning|error):|BUILD (SUCCEEDED|FAILED)"
```

- [ ] **Step 3: ตรวจครบวงจรบนเครื่องสะอาด**

```bash
xcrun simctl uninstall C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF purin.null-app
xcrun simctl keychain C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF reset
```

**ต้องล้าง keychain ด้วย** — `uninstall` อย่างเดียวไม่พอ supabase-swift เก็บ session ไว้ใน
Keychain ซึ่งอยู่รอดข้ามการลบแอป ถ้าไม่ล้าง แอปจะเปิดเข้า Home ในฐานะผู้ใช้คนเดิมทันที
และการทดสอบ "เปิดครั้งแรก" จะไม่ได้ทดสอบอะไรเลย (เจอจริงตอนทำ Task 5)

ลบแถวเดิมออกจากฐานข้อมูลเพื่อให้เริ่มจากศูนย์จริง ๆ:

> ⚠️ `execute_sql` ผ่าน MCP ถูก permission classifier บล็อกสำหรับคำสั่ง `delete` —
> ให้ผู้ใช้รันสองบรรทัดนี้เองใน Supabase SQL editor แล้วค่อยเดินต่อ

```sql
delete from storage.objects where bucket_id = 'profile-images';
delete from auth.users;
```

ติดตั้งและเปิดแอปใหม่ แล้วทำครบทั้งลำดับ พร้อม screenshot ทุกขั้น:

1. เห็นหน้าสมัคร ไม่ใช่ Home
2. กรอก `Purin Tae` → Continue → เข้า Home
3. เข้าหน้า Profile → เห็น `@purintae-` ตามด้วย suffix
4. Edit Profile → ใส่รูป cover → Save → cover เปลี่ยน
5. ปิดแอปสนิทแล้วเปิดใหม่ → ยังล็อกอินอยู่ ข้อมูลและรูปยังอยู่ครบ

- [ ] **Step 4: ยืนยันครั้งสุดท้ายที่ฐานข้อมูล**

```sql
select
  (select count(*) from auth.users)                                        as users,
  (select count(*) from public.profiles)                                   as profiles,
  (select count(*) from storage.objects where bucket_id = 'profile-images') as images,
  (select display_name || '-' || stable_suffix from public.profiles limit 1) as identity;
```

คาดหวัง: `users = 1`, `profiles = 1`, `images = 1`, และ `identity` ตรงกับที่เห็นบนจอ

- [ ] **Step 5: บันทึกลง spec เดิมว่าที่เก็บข้อมูลเปลี่ยนแล้ว**

เติมท้าย `docs/superpowers/specs/2026-08-12-profile-design.md` ในหัวข้อ "การเปลี่ยนแปลงหลังส่งมอบ":

```markdown
**2026-08-13 — ข้อมูลย้ายไปอยู่บน Supabase**

`profile.json` และโฟลเดอร์ `images/` ไม่ใช่แหล่งข้อมูลจริงอีกต่อไป กลายเป็นเพียง cache
ของจริงอยู่ในตาราง `public.profiles` และ bucket `profile-images` บน Supabase
ดูรายละเอียดที่ [2026-08-13-account-and-auth-design.md](2026-08-13-account-and-auth-design.md)

`Profile.makeUsernameSuffix()` ถูกลบ เพราะฐานข้อมูลเป็นเจ้าของการสร้าง suffix แล้ว
และเป็นตัวที่รับประกันความไม่ซ้ำจริงผ่าน UNIQUE constraint
```

- [ ] **Step 6: Commit**

```bash
cd "$PROJ" && git add -A null-app docs && git commit -m "Handle interrupted signup and record the storage move"
```

---

## หลังทำครบทุก task

- [ ] ลบ scratch ที่ใช้ตรวจ package

```bash
rm -rf "/private/tmp/claude-501/-Users-purintae-Documents-WROKSPACE-App-Project-null-app/42d7aa55-485e-4feb-89c6-9becd6c5d585/scratchpad/sbprobe"
```

- [ ] ยืนยันว่า working tree สะอาด

```bash
cd "$PROJ" && git status --short -uall
```

- [ ] แจ้งผู้ใช้เรื่องข้อจำกัดที่ยังเหลือ — **บัญชีนี้ยังกู้คืนไม่ได้ถ้าเสีย session** เพราะมี credential เดียวคือ device credential รอบ B คือรอบที่แก้เรื่องนี้
