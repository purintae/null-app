# Plugin Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ทำให้ `null-app` เป็น shell ที่รับฟีเจอร์เข้ามาเสียบเป็นโมดูล โดยเพิ่มได้ด้วยโฟลเดอร์เดียวกับหนึ่งบรรทัด และถอดออกได้สะอาดแบบพิสูจน์ได้

**Architecture:** `Core/` นิยาม protocol `Feature` และถือ `FeatureRegistry` ซึ่งเป็นไฟล์เดียวในโปรเจกต์ที่เอ่ยชื่อฟีเจอร์ `HomeView` วนอ่าน registry มาวาด grid ไอคอนโดยไม่รู้จักชื่อฟีเจอร์ใด ๆ ฟีเจอร์แต่ละตัวเป็นเจ้าของ Postgres schema `f_<id>`, โฟลเดอร์ `Application Support/Features/<id>/` และคีย์ `UserDefaults` ที่ขึ้นต้นด้วย `f.<id>.` การพึ่งพาวิ่งทางเดียวเสมอ — ฟีเจอร์เรียก core ได้ core เรียกฟีเจอร์ไม่ได้ ระบบ user เดิมไม่ถูกแก้เลย

**Tech Stack:** SwiftUI, Observation, Supabase (Postgres 17 + Auth), `supabase-swift` 2.55.0

**Spec:** [2026-08-13-plugin-architecture-design.md](../specs/2026-08-13-plugin-architecture-design.md)

## Global Constraints

- **ห้ามแก้ `project.pbxproj` ด้วยมือ** — ไฟล์ `.swift` ใหม่ใต้ `null-app/` ถูกเก็บเข้าโปรเจกต์อัตโนมัติ สร้างด้วย Write tool เท่านั้น
- **ไม่มี test target** — ตรวจด้วย `execute_sql` ผ่าน Supabase MCP สำหรับ SQL, `swiftc` harness สำหรับ logic ล้วน, build + simulator สำหรับ UI
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** — type ที่ไม่ประกาศอะไรเป็น main-actor อยู่แล้ว งานที่ต้องออกจาก main actor ต้องระบุ `nonisolated`
- **Deployment target 26.5** — ไม่ต้องเขียน `if #available`
- **หนึ่ง target สี่แพลตฟอร์ม** — ต้อง build ผ่านทั้ง iOS และ macOS ก่อนถือว่างานเสร็จ
- **UI strings เป็นภาษาอังกฤษ** ตามธรรมเนียมเดิมของโปรเจกต์ ส่วนคอมเมนต์ในโค้ดเป็นภาษาไทย
- **build ต้องไม่มี warning จาก source ของเรา** ทั้ง iOS และ macOS
- **`id` ของฟีเจอร์ใช้ตัวพิมพ์เล็กและ `_` เท่านั้น** เพราะถูกเอาไปประกอบเป็นชื่อ schema ใน Postgres
- **ชื่อ type ของฟีเจอร์ต้องขึ้นต้นด้วยชื่อฟีเจอร์** (`ExampleRootView`) เพราะทุกฟีเจอร์อยู่ในโมดูล Swift เดียวกัน ชื่อชนกันคือคอมไพล์ไม่ผ่าน
- **`Core/` ห้าม import หรืออ้างถึง type ของฟีเจอร์ใด ๆ** ยกเว้นบรรทัดใน `FeatureRegistry.installed`

## ค่าคงที่ของโปรเจกต์

```
Supabase project ref : yqeqzplufezlnudsxzql
Project URL          : https://yqeqzplufezlnudsxzql.supabase.co
Region               : ap-southeast-1 (Singapore)
PROJ                 : /Users/purintae/Documents/WROKSPACE/App Project/null-app/.claude/worktrees/super-app-plugin-architecture-f4df89
Bundle id            : purin.null-app
SIM_UDID             : C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF
```

`SIM_UDID` เป็นค่าจากแผนก่อนหน้า ยืนยันก่อนใช้ด้วย `xcrun simctl list devices booted` ถ้าไม่ตรงให้ใช้ค่าที่ได้จริง

## เรื่องการตรวจสอบ

| ชั้น | วิธีตรวจ |
|---|---|
| SQL, RLS (Task 2) | `mcp__02aadaf8-4f04-4de8-8415-1d6fc1a4d3b5__execute_sql` ยิงใส่ฐานข้อมูลจริง |
| Logic ล้วน (Task 4) | `swiftc` compile ไฟล์จริงรวมกับ harness ชั่วคราว |
| UI / end-to-end (Task 1, 3, 4) | build → install → launch → screenshot แล้ว**อ่านแถวจาก DB กลับมาเทียบ** |
| สถาปัตยกรรม (Task 5) | เดินขั้นตอนถอดจริงแล้วตรวจเกณฑ์ทั้ง 4 ข้อในสเปก |

**หน้าจอที่ดูถูกต้องไม่ใช่หลักฐาน** — ทุก task ที่เขียนข้อมูลต้องอ่านแถวจริงกลับมาเทียบ

## ขั้นตอนที่ทำแทนผู้ใช้ไม่ได้

**Task 3 Step 1 ต้องให้ผู้ใช้เข้า Supabase Dashboard เพิ่ม `f_example` ใน Exposed schemas ด้วยตัวเอง** — MCP ไม่มีเครื่องมือแก้ค่านี้ และถ้าไม่ทำ ทุก request จาก `.schema("f_example")` จะถูกปฏิเสธ ให้หยุดรอผู้ใช้ยืนยันก่อนเดินต่อ

## แผนที่ไฟล์

| ไฟล์ | หน้าที่ | Task |
|---|---|---|
| `null-app/Core/Feature.swift` | สัญญาที่ฟีเจอร์ต้องทำตาม | 1 |
| `null-app/Core/FeatureRegistry.swift` | รายชื่อฟีเจอร์ที่ติดตั้งอยู่ — ไฟล์เดียวที่รู้จักชื่อฟีเจอร์ | 1 |
| `null-app/Views/HomeView.swift` | เปลี่ยนจากหน้าว่างเป็น grid ที่อ่านจาก registry | 1 |
| `null-app/null_appApp.swift` | ส่ง `userID` เข้า `HomeView` และเรียก sweep ตอนเปิดแอป | 1, 4 |
| `null-app/Features/Example/ExampleFeature.swift` | conformance ของฟีเจอร์ตัวอย่าง | 1 |
| `null-app/Features/Example/Views/ExampleRootView.swift` | หน้าจอของฟีเจอร์ตัวอย่าง | 1, 3, 4 |
| `null-app/Features/Example/Storage/ExampleStore.swift` | อ่าน/เขียน `f_example.note` | 3 |
| `null-app/Core/FeatureStorage.swift` | ที่เก็บของในเครื่อง + การกวาดของกำพร้า | 4 |
| `docs/superpowers/UNINSTALL-template.md` | เทมเพลตขั้นตอนถอด อยู่นอก `Features/` เพื่อไม่ให้หายไปพร้อมฟีเจอร์ | 5 |
| `null-app/Features/Example/UNINSTALL.md` | สำเนาที่กรอกแล้วของฟีเจอร์ตัวอย่าง | 5 |

---

### Task 1: สัญญา, registry, และ Home ที่เป็น launcher

จบ task นี้แล้วหน้า Home มีไอคอน Example กดเข้าไปเห็น `userID` ของตัวเอง โดยที่ `HomeView` ไม่มีคำว่า Example อยู่ในไฟล์เลย

**Files:**
- Create: `null-app/Core/Feature.swift`
- Create: `null-app/Core/FeatureRegistry.swift`
- Create: `null-app/Features/Example/ExampleFeature.swift`
- Create: `null-app/Features/Example/Views/ExampleRootView.swift`
- Modify: `null-app/Views/HomeView.swift` (เขียนทับทั้งไฟล์)
- Modify: `null-app/null_appApp.swift:28-40`

**Interfaces:**
- Consumes: `SessionStore.State.signedIn(userID: UUID)` ที่มีอยู่แล้ว
- Produces:
  - `protocol Feature { var id: String { get }; var title: String { get }; var systemImage: String { get }; func makeRoot(userID: UUID) -> AnyView }`
  - `enum FeatureRegistry { static let installed: [any Feature] }`
  - `struct ExampleFeature: Feature` — `id == "example"`
  - `struct ExampleRootView: View` — `init(userID: UUID)`
  - `struct HomeView: View` — `init(userID: UUID)`

- [ ] **Step 1: สร้าง `null-app/Core/Feature.swift`**

```swift
//
//  Feature.swift
//  null-app
//

import SwiftUI

/// สัญญาของฟีเจอร์ที่เสียบเข้ามาในแอป
///
/// การพึ่งพาวิ่งทางเดียวเท่านั้น — ฟีเจอร์เรียก core ได้ core เรียกฟีเจอร์ไม่ได้
/// ยกเว้นผ่าน [any Feature] ใน FeatureRegistry ซึ่งเป็นไฟล์เดียวที่รู้จักชื่อฟีเจอร์
/// กฎข้อนี้คือเหตุผลทั้งหมดที่ถอดฟีเจอร์ออกแล้วแอปยังคอมไพล์ผ่าน
protocol Feature {
    /// namespace ของทุกอย่างที่ฟีเจอร์นี้เป็นเจ้าของ — DB schema `f_<id>`,
    /// โฟลเดอร์ `Features/<id>/` และคีย์ UserDefaults `f.<id>.*`
    ///
    /// ใช้ตัวพิมพ์เล็กและ _ เท่านั้น เพราะถูกเอาไปประกอบเป็นชื่อ schema ใน Postgres
    /// การให้ทุกชื่ออนุมานจากค่านี้ทำให้ "รายการของที่ต้องลบ" คำนวณได้แทนที่จะต้องจำ
    var id: String { get }

    /// ชื่อใต้ไอคอนบนหน้า Home
    var title: String { get }

    /// ชื่อ SF Symbol
    var systemImage: String { get }

    /// หน้าจอรากของฟีเจอร์ ถูก push จาก NavigationStack ของ Home
    ///
    /// รับ userID เป็นพารามิเตอร์แทนที่จะให้ฟีเจอร์ไปอ่านเองจาก Backend.client.auth
    /// เพราะการพึ่งพาที่โผล่อยู่ในลายเซ็นคือการพึ่งพาที่มองเห็นและทดสอบได้
    /// ส่วนการหยิบจาก singleton เองคือรอยรั่วชนิดที่ทำให้ระบบ plugin ถอดไม่ออกในระยะยาว
    func makeRoot(userID: UUID) -> AnyView
}
```

- [ ] **Step 2: สร้าง `null-app/Core/FeatureRegistry.swift`**

```swift
//
//  FeatureRegistry.swift
//  null-app
//

import Foundation

/// ไฟล์เดียวในโปรเจกต์ที่เอ่ยชื่อฟีเจอร์
///
/// เพิ่มฟีเจอร์ = เติมหนึ่งบรรทัด ถอดฟีเจอร์ = ลบหนึ่งบรรทัด
/// ลำดับใน array คือลำดับไอคอนบนหน้า Home
///
/// ถ้าวันหนึ่งมีไฟล์ที่สองที่รู้จักชื่อฟีเจอร์ นั่นคือสัญญาณว่าเส้นแบ่งเริ่มรั่ว
enum FeatureRegistry {
    static let installed: [any Feature] = [
        ExampleFeature(),
    ]
}
```

- [ ] **Step 3: สร้าง `null-app/Features/Example/ExampleFeature.swift`**

```swift
//
//  ExampleFeature.swift
//  null-app
//

import SwiftUI

/// ฟีเจอร์ตัวอย่างที่สร้างขึ้นมาเพื่อถูกลบ
///
/// มันใช้ครบทุกช่องทางของสัญญา — หน้าจอ, ตารางที่มี RLS, ไฟล์ในเครื่อง, คีย์ UserDefaults
/// เพื่อให้การถอดใน Task 5 พิสูจน์ได้จริงว่าสะอาด ไม่ใช่แค่ในทางทฤษฎี
struct ExampleFeature: Feature {
    let id = "example"
    let title = "Example"
    let systemImage = "square.dashed"

    func makeRoot(userID: UUID) -> AnyView {
        AnyView(ExampleRootView(userID: userID))
    }
}
```

- [ ] **Step 4: สร้าง `null-app/Features/Example/Views/ExampleRootView.swift`**

```swift
//
//  ExampleRootView.swift
//  null-app
//

import SwiftUI

/// แสดง userID ที่ core ส่งเข้ามา เพื่อพิสูจน์ว่าเส้นทางจาก SessionStore ถึงฟีเจอร์ต่อกันจริง
struct ExampleRootView: View {
    let userID: UUID

    var body: some View {
        Form {
            Section("Signed in as") {
                Text(userID.uuidString.lowercased())
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Example")
    }
}

#Preview {
    NavigationStack {
        ExampleRootView(userID: UUID())
    }
}
```

- [ ] **Step 5: เขียนทับ `null-app/Views/HomeView.swift`**

```swift
//
//  HomeView.swift
//  null-app
//

import SwiftUI

/// Home เป็น launcher — ไอคอนทั้งหมดมาจาก FeatureRegistry
///
/// ไฟล์นี้ต้องไม่มีชื่อฟีเจอร์ใด ๆ ปรากฏอยู่เลย ถ้าวันหนึ่งมี if ที่เช็กชื่อฟีเจอร์
/// การถอดฟีเจอร์นั้นจะพังที่นี่ ซึ่งเป็นสิ่งที่ทั้งสถาปัตยกรรมนี้ตั้งใจป้องกัน
struct HomeView: View {
    let userID: UUID

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 16)]

    var body: some View {
        Group {
            if FeatureRegistry.installed.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(FeatureRegistry.installed, id: \.id) { feature in
                            NavigationLink {
                                feature.makeRoot(userID: userID)
                            } label: {
                                FeatureTile(title: feature.title, systemImage: feature.systemImage)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .navigationTitle("Home")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    ProfileView()
                } label: {
                    Image(systemName: "person")
                }
                .accessibilityLabel("Profile")
            }
        }
    }

    /// ยังคงหน้าตาเดิมไว้สำหรับตอนที่ยังไม่มีฟีเจอร์ใดถูกติดตั้ง
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "square.dashed")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)

            Text("Nothing here yet")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }
}

/// ไอคอนหนึ่งช่องบน Home — เป็นของ core ไม่ใช่ของฟีเจอร์ใด
private struct FeatureTile: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .frame(width: 64, height: 64)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))

            Text(title)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(.primary)
    }
}

#Preview {
    NavigationStack {
        HomeView(userID: UUID())
    }
    .environment(ProfileStore(cacheURL: URL.temporaryDirectory.appending(path: "preview.json")))
}
```

- [ ] **Step 6: แก้ `null-app/null_appApp.swift`**

เปลี่ยน `case .signedIn:` ให้ผูกค่า `userID` ออกมาแล้วส่งเข้า `HomeView` — แทนที่บล็อกเดิมทั้งบล็อก:

```swift
                case .signedIn(let userID):
                    if profileStore.needsProfile {
                        // สมัครค้างกลางทาง — มีบัญชีแล้วแต่ยังไม่มีโปรไฟล์
                        // ให้กรอกชื่อเพื่อสร้างแถวให้ครบ ไม่ใช่สร้างบัญชีใหม่ซ้อน
                        signUpScreen
                    } else {
                        // Home เป็นรากเดียวของแอป ส่วน Profile ถูก push จากไอคอนบนแถบบนของ Home
                        NavigationStack {
                            HomeView(userID: userID)
                        }
                        .environment(profileStore)
                        .task { await profileStore.refresh() }
                    }
```

- [ ] **Step 7: build ทั้งสองแพลตฟอร์ม**

```bash
xcodebuild -scheme null-app -destination 'generic/platform=iOS Simulator' build
```

```bash
xcodebuild -scheme null-app -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED` ทั้งคู่ และไม่มี warning จากไฟล์ของเรา

- [ ] **Step 8: ติดตั้งและเปิดบน simulator**

```bash
xcrun simctl install C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF "$(xcodebuild -scheme null-app -destination 'generic/platform=iOS Simulator' -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2"/null-app.app"}')" && xcrun simctl launch C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF purin.null-app
```

- [ ] **Step 9: ตรวจด้วยภาพว่า grid ทำงาน**

```bash
xcrun simctl io C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF screenshot /tmp/home-grid.png
```

Expected: หน้า Home มีไอคอน `square.dashed` พร้อมคำว่า Example อยู่มุมซ้ายบนของ grid ไม่ใช่ข้อความ "Nothing here yet"

จากนั้นแตะไอคอน Example แล้วถ่ายอีกครั้ง:

```bash
xcrun simctl io C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF screenshot /tmp/example-root.png
```

Expected: หน้าชื่อ Example แสดง uuid ตัวพิมพ์เล็ก

- [ ] **Step 10: ยืนยันว่า uuid บนหน้าจอคือของจริง**

เรียก `mcp__02aadaf8-4f04-4de8-8415-1d6fc1a4d3b5__execute_sql` ด้วย `project_id` = `yqeqzplufezlnudsxzql`:

```sql
select user_id, display_name from public.profiles;
```

Expected: `user_id` ของแถวใดแถวหนึ่งตรงกับ uuid ที่เห็นบนหน้าจอทุกตัวอักษร — ถ้าไม่ตรง แปลว่า `userID` ที่ส่งเข้าฟีเจอร์ไม่ใช่ผู้ใช้ที่ล็อกอินอยู่จริง

- [ ] **Step 11: ยืนยันว่า HomeView ไม่รู้จักชื่อฟีเจอร์**

```bash
grep -i example null-app/Views/HomeView.swift null-app/Core/Feature.swift null-app/null_appApp.swift
```

Expected: ไม่มีผลลัพธ์ (exit code 1) — ถ้ามีแม้แต่บรรทัดเดียว แสดงว่าเส้นแบ่งรั่วตั้งแต่ task แรก ต้องแก้ก่อนไปต่อ

- [ ] **Step 12: commit**

```bash
git add null-app/Core null-app/Features null-app/Views/HomeView.swift null-app/null_appApp.swift && git commit -m "Turn Home into a registry-driven launcher

Features plug in through one protocol and one line in FeatureRegistry.
HomeView renders whatever the registry holds and never learns a feature
name, which is what makes removal a delete rather than a refactor."
```

---

### Task 2: schema `f_example` และการพิสูจน์ว่า RLS ปฏิเสธจริง

เป็น SQL ล้วน ยังไม่แตะโค้ดแอป จบ task นี้แล้วฐานข้อมูลมีลิ้นชักของฟีเจอร์ที่ผู้ใช้อื่นเปิดไม่ได้

**Files:**
- ไม่มีไฟล์ในโปรเจกต์ — ใช้ `apply_migration` ผ่าน Supabase MCP

**Interfaces:**
- Consumes: `auth.users(id)` ที่มีอยู่แล้ว
- Produces: ตาราง `f_example.note(user_id uuid PK → auth.users, body text not null default '', updated_at timestamptz not null default now())` พร้อม RLS 4 policy

- [ ] **Step 1: สร้าง migration**

เรียก `mcp__02aadaf8-4f04-4de8-8415-1d6fc1a4d3b5__apply_migration` ด้วย `project_id` = `yqeqzplufezlnudsxzql`, `name` = `f_example_note`, และ `query`:

```sql
create schema if not exists f_example;

-- หนึ่งแถวต่อหนึ่งผู้ใช้ ให้ PK เป็น user_id ไปเลย โครงจะได้เล็กที่สุดเท่าที่พิสูจน์ได้
-- อ้าง auth.users ไม่ใช่ public.profiles ตามโมเดล 3 ชั้นของโปรเจกต์
-- on delete cascade ทำให้ไม่ต้องมี hook ลบข้อมูลตอนผู้ใช้ลบบัญชีในทุกฟีเจอร์
create table f_example.note (
    user_id uuid primary key references auth.users(id) on delete cascade,
    body text not null default '',
    updated_at timestamptz not null default now()
);

alter table f_example.note enable row level security;

create policy "own row select" on f_example.note
    for select using (user_id = auth.uid());

create policy "own row insert" on f_example.note
    for insert with check (user_id = auth.uid());

create policy "own row update" on f_example.note
    for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "own row delete" on f_example.note
    for delete using (user_id = auth.uid());

-- PostgREST เข้าถึง schema ได้ก็ต่อเมื่อมี grant ครบ การเปิดใน Exposed schemas อย่างเดียวไม่พอ
grant usage on schema f_example to anon, authenticated;
grant select, insert, update, delete on f_example.note to anon, authenticated;
```

- [ ] **Step 2: หา user จริงมาใช้ทดสอบ**

`execute_sql`:

```sql
select id from auth.users order by created_at limit 1;
```

Expected: ได้ uuid หนึ่งตัว บันทึกไว้เป็น `<A>` ถ้าไม่มีแถวเลย ให้สมัครบัญชีผ่านแอปบน simulator ก่อนแล้วรันใหม่

- [ ] **Step 3: พิสูจน์ว่าเจ้าของเขียนและอ่านได้**

`execute_sql` (แทน `<A>` ด้วยค่าจริง):

```sql
begin;
select set_config('request.jwt.claims', json_build_object('sub', '<A>')::text, true);
set local role authenticated;

insert into f_example.note (user_id, body) values ('<A>', 'written as A');
select count(*) as visible_to_owner from f_example.note;
rollback;
```

Expected: `visible_to_owner` = 1

- [ ] **Step 4: พิสูจน์ว่าคนอื่นอ่านไม่ได้ แก้ไม่ได้ ลบไม่ได้**

นี่คือขั้นตอนที่สำคัญที่สุดของ task นี้ — policy ที่ทดสอบแค่ว่า "เจ้าของทำได้" คือ policy ที่ยังไม่มีใครรู้พฤติกรรม

`execute_sql` (แทน `<A>` ด้วยค่าจริง ส่วน `<B>` เป็น uuid มั่ว ๆ ที่ไม่ต้องมีอยู่จริง):

```sql
begin;
select set_config('request.jwt.claims', json_build_object('sub', '<A>')::text, true);
set local role authenticated;
insert into f_example.note (user_id, body) values ('<A>', 'written as A');

select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000000bb')::text, true);

select count(*) as visible_to_stranger from f_example.note;

with u as (update f_example.note set body = 'hacked' returning 1)
select count(*) as rows_updated_by_stranger from u;

with d as (delete from f_example.note returning 1)
select count(*) as rows_deleted_by_stranger from d;
rollback;
```

Expected: ทั้งสามค่าเป็น **0** — ถ้าค่าใดมากกว่า 0 ห้ามไปต่อ ต้องแก้ policy ก่อน

- [ ] **Step 5: พิสูจน์ว่าคนอื่นแอบเขียนแถวในนามเราไม่ได้**

`execute_sql` (แทน `<A>` ด้วยค่าจริง):

```sql
begin;
select set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-0000-0000-0000000000bb')::text, true);
set local role authenticated;
insert into f_example.note (user_id, body) values ('<A>', 'forged');
rollback;
```

Expected: **error** `new row violates row-level security policy for table "note"` — การที่คำสั่งนี้สำเร็จคือความล้มเหลวของ task นี้

- [ ] **Step 6: ยืนยันว่าไม่มีอะไรใน core ชี้เข้ามาใน schema ของฟีเจอร์**

`execute_sql`:

```sql
select
    con.conname,
    src.nspname as from_schema,
    tgt.nspname as to_schema
from pg_constraint con
join pg_class srcrel on srcrel.oid = con.conrelid
join pg_namespace src on src.oid = srcrel.relnamespace
join pg_class tgtrel on tgtrel.oid = con.confrelid
join pg_namespace tgt on tgt.oid = tgtrel.relnamespace
where con.contype = 'f'
  and tgt.nspname = 'f_example';
```

Expected: ไม่มีแถว — ถ้ามี แปลว่ามีอะไรใน core ผูกเข้ามาในลิ้นชักของฟีเจอร์ และ `drop schema cascade` จะลากของ core ไปด้วย

`information_schema` มองไม่เห็น foreign key ข้าม schema จาก role ของ MCP จึงต้องถาม `pg_constraint` ตรง ๆ

- [ ] **Step 7: commit บันทึกผลการพิสูจน์**

ไม่มีไฟล์เปลี่ยนใน repo — บันทึกผลลัพธ์ทั้งหมดลง `.superpowers/sdd/2026-08-13-plugin-architecture/progress.md` (สร้างโฟลเดอร์ถ้ายังไม่มี) ระบุค่าที่ได้จริงของทุก Step เพื่อให้เซสชันถัดไปไม่ต้องรันซ้ำ

---

### Task 3: ฟีเจอร์ตัวอย่างอ่านและเขียนข้อมูลจริง

จบ task นี้แล้วพิมพ์ข้อความในแอปแล้วแถวใน `f_example.note` เปลี่ยนตามจริง

**Files:**
- Create: `null-app/Features/Example/Storage/ExampleStore.swift`
- Modify: `null-app/Features/Example/Views/ExampleRootView.swift` (เขียนทับทั้งไฟล์)

**Interfaces:**
- Consumes: `f_example.note` จาก Task 2, `Backend.client` ที่มีอยู่แล้ว
- Produces:
  - `struct ExampleNote: Codable` — คีย์ `user_id`, `body`
  - `final class ExampleStore` — `init(userID: UUID)`, `var body: String { get }`, `func load() async`, `func save(_ newBody: String) async throws`

- [ ] **Step 1: ให้ผู้ใช้เปิด schema ใน Dashboard — หยุดรอตรงนี้**

แจ้งผู้ใช้ให้เข้า Supabase Dashboard → Project Settings → API → **Exposed schemas** → เพิ่ม `f_example` → Save

**ห้ามเดินต่อจนกว่าผู้ใช้จะยืนยันว่าทำแล้ว** ถ้าข้ามขั้นนี้ ทุก request จะได้ `PGRST106` และจะเสียเวลาไล่หาสาเหตุผิดที่

- [ ] **Step 2: สร้าง `null-app/Features/Example/Storage/ExampleStore.swift`**

```swift
//
//  ExampleStore.swift
//  null-app
//

import Foundation
import Observation
import Supabase

/// แถวใน f_example.note
///
/// ไม่มีฟิลด์ Optional จึงใช้ synthesized Encodable ได้อย่างปลอดภัย
/// ถ้าวันหนึ่งเพิ่มคอลัมน์ที่เป็น Optional แล้วส่ง PATCH ต้องเขียน encode(to:) เอง
/// มิฉะนั้น encodeIfPresent จะตัดคีย์ทิ้งและ PostgREST จะอ่านว่า "ไม่ต้องแตะคอลัมน์นี้"
nonisolated struct ExampleNote: Codable {
    let userID: UUID
    var body: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case body
    }
}

/// เจ้าของ state ของฟีเจอร์ตัวอย่าง
///
/// เรียกผ่าน .schema("f_example") เพราะตารางไม่ได้อยู่ใน public
/// ซึ่งเป็นราคาที่จ่ายเพื่อให้ถอดฟีเจอร์ได้ด้วย drop schema คำสั่งเดียว
@Observable
final class ExampleStore {
    private(set) var body = ""

    private let userID: UUID

    init(userID: UUID) {
        self.userID = userID
    }

    /// ไม่ throw เพราะการเปิดหน้าตอนไม่มีเน็ตควรได้หน้าว่าง ไม่ใช่ error กลางหน้าจอ
    func load() async {
        let rows: [ExampleNote]? = try? await Backend.client
            .schema("f_example")
            .from("note")
            .select()
            .eq("user_id", value: userID)
            .execute()
            .value

        body = rows?.first?.body ?? ""
    }

    /// throw เพราะการกด Save แล้วเงียบคือสิ่งที่ผู้ใช้ตีความว่าบันทึกสำเร็จ
    func save(_ newBody: String) async throws {
        try await Backend.client
            .schema("f_example")
            .from("note")
            .upsert(ExampleNote(userID: userID, body: newBody))
            .execute()

        body = newBody
    }
}
```

- [ ] **Step 3: เขียนทับ `null-app/Features/Example/Views/ExampleRootView.swift`**

```swift
//
//  ExampleRootView.swift
//  null-app
//

import SwiftUI

/// หน้าจอของฟีเจอร์ตัวอย่าง — เขียนข้อความหนึ่งบรรทัดเก็บไว้บน server
struct ExampleRootView: View {
    let userID: UUID

    @State private var store: ExampleStore
    @State private var draft = ""
    @State private var saveError: String?

    init(userID: UUID) {
        self.userID = userID
        _store = State(initialValue: ExampleStore(userID: userID))
    }

    var body: some View {
        Form {
            Section("Note") {
                TextField("Type something", text: $draft)

                Button("Save") {
                    Task {
                        do {
                            saveError = nil
                            try await store.save(draft)
                        } catch {
                            saveError = error.localizedDescription
                        }
                    }
                }
                .disabled(draft == store.body)
            }

            if let saveError {
                Section {
                    Text(saveError)
                        .foregroundStyle(.red)
                }
            }

            Section("Signed in as") {
                Text(userID.uuidString.lowercased())
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Example")
        .task {
            await store.load()
            draft = store.body
        }
    }
}

#Preview {
    NavigationStack {
        ExampleRootView(userID: UUID())
    }
}
```

- [ ] **Step 4: build ทั้งสองแพลตฟอร์ม**

```bash
xcodebuild -scheme null-app -destination 'generic/platform=iOS Simulator' build
```

```bash
xcodebuild -scheme null-app -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED` ทั้งคู่

- [ ] **Step 5: ติดตั้ง เปิด แล้วบันทึกข้อความ**

```bash
xcrun simctl install C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF "$(xcodebuild -scheme null-app -destination 'generic/platform=iOS Simulator' -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2"/null-app.app"}')" && xcrun simctl launch C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF purin.null-app
```

แตะ Example → พิมพ์ `hello from task 3` → กด Save → ถ่ายหน้าจอ:

```bash
xcrun simctl io C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF screenshot /tmp/example-saved.png
```

- [ ] **Step 6: อ่านแถวจริงกลับมาเทียบ**

`execute_sql`:

```sql
select user_id, body, updated_at from f_example.note;
```

Expected: มีแถวเดียว `body` = `hello from task 3` และ `user_id` ตรงกับ uuid ที่แสดงบนหน้าจอ

**หน้าจอที่แสดงข้อความถูกต้องไม่ใช่หลักฐาน** — บั๊กหลายตัวในโปรเจกต์นี้เคยแสดงหน้าจอที่ถูกทับ state ฝั่ง server ที่ผิด

- [ ] **Step 7: ปิดแอปแล้วเปิดใหม่เพื่อยืนยันว่าอ่านกลับมาได้**

```bash
xcrun simctl terminate C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF purin.null-app && xcrun simctl launch C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF purin.null-app
```

แตะ Example อีกครั้ง Expected: ช่องข้อความมี `hello from task 3` อยู่แล้วโดยไม่ต้องพิมพ์ใหม่

- [ ] **Step 8: commit**

```bash
git add null-app/Features/Example && git commit -m "Give the example feature its own schema-backed storage

The feature reaches its table through .schema(\"f_example\") rather than
public, which is the price paid for making removal a single drop schema."
```

---

### Task 4: ที่เก็บของในเครื่องและการกวาดของกำพร้า

จบ task นี้แล้วของที่ฟีเจอร์ทิ้งไว้ในเครื่องผู้ใช้จะหายเองหลังถอดฟีเจอร์ ซึ่งเป็นจุดที่ระบบ plugin ส่วนใหญ่พัง

**Files:**
- Create: `null-app/Core/FeatureStorage.swift`
- Modify: `null-app/Features/Example/Views/ExampleRootView.swift` (เพิ่ม 3 ที่ ระบุไว้ใน Step)
- Modify: `null-app/null_appApp.swift` (เพิ่ม `init()`)

**Interfaces:**
- Consumes: `FeatureRegistry.installed` จาก Task 1
- Produces:
  - `enum FeatureStorage` — `static var root: URL`, `static func directory(for id: String) -> URL`, `static func defaultsKey(_ id: String, _ key: String) -> String`, `static func sweepOrphans(installed: Set<String>, root: URL, defaults: UserDefaults)`

- [ ] **Step 1: สร้าง `null-app/Core/FeatureStorage.swift`**

พารามิเตอร์ทั้งสามของ `sweepOrphans` ถูกฉีดเข้ามาแทนที่จะอ่านจาก global โดยตั้งใจ — เพื่อให้ harness ใน Step ถัดไปทดสอบมันได้จริงโดยไม่แตะข้อมูลของแอปจริง

```swift
//
//  FeatureStorage.swift
//  null-app
//

import Foundation

/// ที่เก็บของในเครื่องของฟีเจอร์ ทุกชื่ออนุมานจาก id ไม่มีการตั้งชื่ออิสระ
///
/// อยู่ที่ Application Support ไม่ใช่ Caches เพื่อให้ตรงกับ ProfileStore ที่เก็บ profile.json
/// ไว้ที่นั่นอยู่แล้ว การมีที่เก็บสองแบบแลกมาด้วยจุดกวาดสองจุด
nonisolated enum FeatureStorage {
    static var root: URL {
        URL.applicationSupportDirectory.appending(path: "Features")
    }

    static func directory(for id: String) -> URL {
        root.appending(path: id)
    }

    static func defaultsKey(_ id: String, _ key: String) -> String {
        "f.\(id).\(key)"
    }

    /// ลบโฟลเดอร์และคีย์ของฟีเจอร์ที่ไม่ได้อยู่ใน registry แล้ว
    ///
    /// ผู้ใช้ที่ลงแอปไว้ก่อนถอดฟีเจอร์จะมีของค้างอยู่ตลอดกาล เพราะโค้ดที่เคยรู้จักมันถูกลบไปแล้ว
    /// ไม่เหลือใครลบให้ การตัดสินจาก registry ปัจจุบันยังทำให้มันกวาดของจากฟีเจอร์
    /// ที่ถูกถอดไปก่อนที่ฟังก์ชันนี้จะมีอยู่ได้ด้วย
    static func sweepOrphans(installed: Set<String>, root: URL, defaults: UserDefaults) {
        let manager = FileManager.default

        if let entries = try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            for entry in entries where !installed.contains(entry.lastPathComponent) {
                try? manager.removeItem(at: entry)
            }
        }

        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("f.") {
            let id = String(key.dropFirst(2).prefix { $0 != "." })
            if !installed.contains(id) {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
```

- [ ] **Step 2: เขียน harness ที่ต้องล้มเหลวก่อน**

สร้าง `/tmp/sweep-test/main.swift`:

```swift
import Foundation

func check(_ label: String, _ condition: Bool) {
    print(condition ? "PASS \(label)" : "FAIL \(label)")
    if !condition { exit(1) }
}

let root = URL.temporaryDirectory.appending(path: "sweep-\(UUID().uuidString)")
let manager = FileManager.default
try! manager.createDirectory(at: root.appending(path: "example"), withIntermediateDirectories: true)
try! manager.createDirectory(at: root.appending(path: "ghost"), withIntermediateDirectories: true)

let defaults = UserDefaults(suiteName: "sweep-test-\(UUID().uuidString)")!
defaults.set("keep", forKey: "f.example.tint")
defaults.set("drop", forKey: "f.ghost.tint")
defaults.set("untouched", forKey: "appearance")

FeatureStorage.sweepOrphans(installed: ["example"], root: root, defaults: defaults)

check("ลบโฟลเดอร์กำพร้า", !manager.fileExists(atPath: root.appending(path: "ghost").path))
check("เก็บโฟลเดอร์ที่ยังติดตั้งอยู่", manager.fileExists(atPath: root.appending(path: "example").path))
check("ลบคีย์กำพร้า", defaults.string(forKey: "f.ghost.tint") == nil)
check("เก็บคีย์ที่ยังติดตั้งอยู่", defaults.string(forKey: "f.example.tint") == "keep")
check("ไม่แตะคีย์ที่ไม่ใช่ของฟีเจอร์", defaults.string(forKey: "appearance") == "untouched")

print("ทุกข้อผ่าน")
```

- [ ] **Step 3: รัน harness เพื่อดูว่ามันล้มเหลวก่อน**

รันโดย**ยังไม่ใส่** `FeatureStorage.swift` เข้าไปในคำสั่ง:

```bash
cd "/Users/purintae/Documents/WROKSPACE/App Project/null-app/.claude/worktrees/super-app-plugin-architecture-f4df89" && swiftc /tmp/sweep-test/main.swift -o /tmp/sweep-test/run
```

Expected: **คอมไพล์ไม่ผ่าน** ด้วย `cannot find 'FeatureStorage' in scope` — ยืนยันว่า harness ทดสอบโค้ดจริง ไม่ได้ผ่านเพราะมันไม่ได้ทดสอบอะไรเลย

- [ ] **Step 4: รัน harness กับไฟล์จริง**

```bash
cd "/Users/purintae/Documents/WROKSPACE/App Project/null-app/.claude/worktrees/super-app-plugin-architecture-f4df89" && swiftc null-app/Core/FeatureStorage.swift /tmp/sweep-test/main.swift -o /tmp/sweep-test/run && /tmp/sweep-test/run
```

Expected: `PASS` ทั้ง 5 บรรทัด แล้วจบด้วย `ทุกข้อผ่าน`

- [ ] **Step 5: ให้ฟีเจอร์ตัวอย่างทิ้งของไว้ในเครื่องจริง**

แก้ `null-app/Features/Example/Views/ExampleRootView.swift` สามที่:

เพิ่มบรรทัดนี้ต่อจาก `@State private var saveError: String?`:

```swift
    /// คีย์ต้องขึ้นต้นด้วย f.<id>. เสมอ เพื่อให้ sweepOrphans เก็บกวาดได้ตอนฟีเจอร์ถูกถอด
    @AppStorage("f.example.showsUUID") private var showsUUID = true
```

เปลี่ยน `Section("Signed in as")` ทั้ง section เป็น:

```swift
            Section("Signed in as") {
                Toggle("Show user id", isOn: $showsUUID)

                if showsUUID {
                    Text(userID.uuidString.lowercased())
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            }
```

แทนที่ตั้งแต่บรรทัด `.task {` ไปจนถึงวงเล็บปีกกาที่ปิด `body` (สองบรรทัดสุดท้ายก่อน `#Preview`) ด้วยข้อความนี้ — สังเกตว่ามันปิด `body` ให้แล้วและเพิ่ม method ใหม่ต่อท้าย ส่วนปีกกาที่ปิด `struct` ให้คงไว้ตามเดิม:

```swift
        .task {
            await store.load()
            draft = store.body
            ExampleRootView.recordVisit()
        }
    }

    /// เขียนไฟล์ไว้ในโฟลเดอร์ของฟีเจอร์เพื่อให้มีของจริงให้ sweepOrphans กวาดใน Task 5
    nonisolated static func recordVisit() {
        let directory = FeatureStorage.directory(for: "example")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? Date.now.formatted(.iso8601)
            .data(using: .utf8)?
            .write(to: directory.appending(path: "last-visit.txt"), options: .atomic)
    }
```

- [ ] **Step 6: เรียก sweep ตอนเปิดแอป**

เพิ่ม `init()` ใน `null_appApp.swift` ต่อจากบรรทัด `@AppStorage("appearance") private var appearance...`:

```swift
    /// กวาดของของฟีเจอร์ที่ถูกถอดออกไปแล้ว ตัดสินจาก registry ปัจจุบันเสมอ
    ///
    /// ปิดใน DEBUG เพราะการคอมเมนต์ registry ออกชั่วคราวเพื่อดีบัก
    /// ไม่ควรลบข้อมูลในเครื่องทิ้ง — ผลข้างเคียงคือการยืนยันเรื่องนี้ต้อง build แบบ Release
    init() {
        #if !DEBUG
        FeatureStorage.sweepOrphans(
            installed: Set(FeatureRegistry.installed.map(\.id)),
            root: FeatureStorage.root,
            defaults: .standard
        )
        #endif
    }
```

- [ ] **Step 7: build ทั้งสองแพลตฟอร์ม**

```bash
xcodebuild -scheme null-app -destination 'generic/platform=iOS Simulator' build
```

```bash
xcodebuild -scheme null-app -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED` ทั้งคู่

- [ ] **Step 8: ยืนยันว่าฟีเจอร์ทิ้งของไว้จริง**

ติดตั้ง เปิดแอป แตะเข้า Example หนึ่งครั้ง แล้ว:

```bash
ls "$(xcrun simctl get_app_container C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF purin.null-app data)/Library/Application Support/Features/example/"
```

Expected: เห็น `last-visit.txt`

```bash
plutil -p "$(xcrun simctl get_app_container C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF purin.null-app data)/Library/Preferences/purin.null-app.plist" | grep "f.example"
```

Expected: เห็นคีย์ `f.example.showsUUID`

ทั้งสองอย่างนี้คือของที่ Task 5 จะต้องพิสูจน์ว่ากวาดหายไปได้

- [ ] **Step 9: commit**

```bash
git add null-app/Core/FeatureStorage.swift null-app/Features/Example null-app/null_appApp.swift && git commit -m "Sweep local leftovers of features that are no longer installed

A removed feature's files and defaults would otherwise sit on every
existing install forever, since the code that knew about them is gone.
Deciding from the current registry also collects features removed before
this sweep existed."
```

---

### Task 5: ถอดฟีเจอร์ตัวอย่างออกจริง — บทพิสูจน์

task นี้ทดสอบสถาปัตยกรรม ไม่ใช่โค้ด และเป็น task เดียวที่ตอบคำถามตั้งต้นว่า "ถอดออกสะอาดไหม"

**Files:**
- Create: `docs/superpowers/UNINSTALL-template.md`
- Create: `null-app/Features/Example/UNINSTALL.md`
- Delete: `null-app/Features/Example/` ทั้งโฟลเดอร์
- Modify: `null-app/Core/FeatureRegistry.swift` (ลบหนึ่งบรรทัด)

**Interfaces:**
- Consumes: ทุกอย่างจาก Task 1-4
- Produces: `FeatureRegistry.installed == []` และเทมเพลตขั้นตอนถอดที่ฟีเจอร์ในอนาคตใช้ต่อได้

- [ ] **Step 1: สร้าง `docs/superpowers/UNINSTALL-template.md`**

เทมเพลตอยู่นอก `Features/` โดยตั้งใจ ถ้าเก็บไว้ในโฟลเดอร์ฟีเจอร์ มันจะหายไปพร้อมฟีเจอร์แรกที่ถูกถอด

```markdown
# ถอดฟีเจอร์ `<id>`

แทน `<id>` ด้วย id จริงของฟีเจอร์ ทำตามลำดับ ห้ามข้าม

1. ลบโฟลเดอร์ `null-app/Features/<Id>/`
2. ลบบรรทัดของฟีเจอร์ใน `null-app/Core/FeatureRegistry.swift`
3. build ทั้งสองแพลตฟอร์ม — **ต้องผ่านโดยไม่ต้องแตะไฟล์อื่น**
   - `xcodebuild -scheme null-app -destination 'generic/platform=iOS Simulator' build`
   - `xcodebuild -scheme null-app -destination 'platform=macOS' build`
4. ถ้าฟีเจอร์เก็บข้อมูลที่ผู้ใช้อาจอยากได้คืน ให้ export ก่อน — ข้อ 5 ลบถาวรและกู้ไม่ได้
5. `drop schema f_<id> cascade;` ผ่าน `apply_migration`
6. เอา `f_<id>` ออกจาก Exposed schemas ใน Supabase Dashboard
7. ลบ bucket `f_<id>` ผ่าน Storage API หรือ Dashboard ถ้าฟีเจอร์นั้นมี
   (ลบ `storage.objects` ด้วย SQL ไม่ได้ — trigger `storage.protect_delete()` ปฏิเสธ)
8. ของค้างในเครื่องผู้ใช้ไม่ต้องทำอะไร `FeatureStorage.sweepOrphans()` เก็บกวาดเองตอนเปิดแอป
   (ทำงานเฉพาะ build ที่ไม่ใช่ DEBUG)

ตรวจว่าสะอาดจริงครบทั้ง 4 ข้อ:

- [ ] build ผ่านทั้ง iOS และ macOS โดยไม่ได้แก้ไฟล์อื่นนอกจากสองข้อแรก
- [ ] `drop schema` สำเร็จโดยไม่ชนกับวัตถุของ core
- [ ] เปิดแอป Release ใหม่แล้วโฟลเดอร์และคีย์ของฟีเจอร์หายไปจริง
- [ ] `grep -ri <id> null-app/` ไม่เหลืออะไร
```

- [ ] **Step 2: สร้าง `null-app/Features/Example/UNINSTALL.md`**

```markdown
# ถอดฟีเจอร์ `example`

ฟีเจอร์นี้ถูกสร้างขึ้นมาเพื่อถูกลบ — มันมีไว้พิสูจน์ว่าสถาปัตยกรรมถอดได้สะอาดจริง

ทำตาม `docs/superpowers/UNINSTALL-template.md` โดยแทน `<id>` = `example` และ `<Id>` = `Example`

สิ่งที่ฟีเจอร์นี้เป็นเจ้าของ:

| ของ | ชื่อ |
|---|---|
| Postgres schema | `f_example` (ตาราง `note`) |
| โฟลเดอร์ในเครื่อง | `Application Support/Features/example/last-visit.txt` |
| คีย์ UserDefaults | `f.example.showsUUID` |
| Storage bucket | ไม่มี |

ไม่ต้อง export อะไรก่อนลบ ข้อมูลในนั้นเป็นข้อความทดสอบ
```

- [ ] **Step 3: commit เอกสารก่อนถอด**

```bash
git add docs/superpowers/UNINSTALL-template.md null-app/Features/Example/UNINSTALL.md && git commit -m "Write the uninstall checklist before proving it works

The template lives outside Features/ so it does not disappear along with
the first feature that gets removed."
```

- [ ] **Step 4: ลบโฟลเดอร์ฟีเจอร์**

```bash
cd "/Users/purintae/Documents/WROKSPACE/App Project/null-app/.claude/worktrees/super-app-plugin-architecture-f4df89" && git rm -r null-app/Features/Example
```

- [ ] **Step 5: ลบหนึ่งบรรทัดใน registry**

แก้ `null-app/Core/FeatureRegistry.swift` ให้ array ว่าง:

```swift
    static let installed: [any Feature] = [
    ]
```

- [ ] **Step 6: build ทั้งสองแพลตฟอร์ม — นี่คือบททดสอบตัวจริง**

```bash
xcodebuild -scheme null-app -destination 'generic/platform=iOS Simulator' build
```

```bash
xcodebuild -scheme null-app -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED` ทั้งคู่ **โดยไม่ได้แก้ไฟล์อื่นเลย**

ถ้าคอมไพล์ไม่ผ่าน ห้ามแก้ไฟล์ที่ error เพื่อให้มันผ่าน — นั่นคือหลักฐานว่าสถาปัตยกรรมรั่ว ให้บันทึกว่าไฟล์ไหนพัง แล้วกลับไปแก้ที่ต้นเหตุใน Task 1-4

- [ ] **Step 7: ยืนยันว่าไม่ได้แตะไฟล์อื่น**

```bash
git status --porcelain
```

Expected: มีเฉพาะไฟล์ใต้ `null-app/Features/Example/` ที่ถูกลบ และ `null-app/Core/FeatureRegistry.swift` ที่ถูกแก้ — ไม่มีชื่ออื่นเลย

- [ ] **Step 8: ลบ schema**

เรียก `apply_migration` ด้วย `name` = `drop_f_example`:

```sql
drop schema f_example cascade;
```

จากนั้น `execute_sql` ยืนยัน:

```sql
select nspname from pg_namespace where nspname = 'f_example';
```

Expected: ไม่มีแถว

- [ ] **Step 9: ยืนยันว่า core ไม่ได้หายไปด้วย**

`execute_sql`:

```sql
select count(*) as profiles_alive from public.profiles;
```

Expected: จำนวนแถวเท่าเดิมกับก่อนถอด — `drop schema cascade` ที่ลากของ core ไปด้วยคือความล้มเหลวของสถาปัตยกรรม

- [ ] **Step 10: แจ้งผู้ใช้ให้เอา schema ออกจาก Exposed schemas**

Supabase Dashboard → Project Settings → API → Exposed schemas → ลบ `f_example` → Save

รอผู้ใช้ยืนยันก่อนไปต่อ

- [ ] **Step 11: พิสูจน์ว่าของในเครื่องถูกกวาด — ต้อง build แบบ Release**

sweep ถูกกั้นด้วย `#if !DEBUG` การ build แบบปกติจึงไม่กวาดอะไรเลย

```bash
xcodebuild -scheme null-app -configuration Release -destination 'generic/platform=iOS Simulator' build
```

```bash
xcrun simctl install C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF "$(xcodebuild -scheme null-app -configuration Release -destination 'generic/platform=iOS Simulator' -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2"/null-app.app"}')" && xcrun simctl launch C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF purin.null-app
```

**ห้าม `simctl uninstall` ก่อนขั้นนี้** — ของที่ค้างอยู่คือสิ่งที่กำลังทดสอบ ถ้าลบแอปทิ้งก่อนก็ไม่เหลืออะไรให้กวาด

```bash
ls "$(xcrun simctl get_app_container C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF purin.null-app data)/Library/Application Support/Features/"
```

Expected: ว่าง — โฟลเดอร์ `example` หายไปแล้ว

```bash
plutil -p "$(xcrun simctl get_app_container C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF purin.null-app data)/Library/Preferences/purin.null-app.plist" | grep -c "f.example"
```

Expected: `0`

```bash
plutil -p "$(xcrun simctl get_app_container C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF purin.null-app data)/Library/Preferences/purin.null-app.plist" | grep appearance
```

Expected: ยังมีอยู่ — sweep ต้องไม่แตะคีย์ที่ไม่ใช่ของฟีเจอร์

- [ ] **Step 12: ยืนยันว่าแอปยังใช้งานได้ปกติหลังถอด**

```bash
xcrun simctl io C7CBA4C6-2050-41B9-8DD1-A5DB6D005FEF screenshot /tmp/home-after-removal.png
```

Expected: หน้า Home กลับไปแสดง "Nothing here yet" และปุ่ม Profile บนแถบบนยังกดเข้าไปเห็นโปรไฟล์ได้ตามปกติ

- [ ] **Step 13: grep หาเศษที่เหลือ**

```bash
grep -ri example null-app/
```

Expected: ไม่มีผลลัพธ์ (exit code 1)

- [ ] **Step 14: commit**

```bash
git add -A && git commit -m "Remove the example feature to prove removal is clean

Deleting the folder and one registry line left both platforms building
with no other file touched, drop schema took the data without reaching
into core, and the orphan sweep cleared the local leftovers while leaving
the appearance preference alone.

The architecture is now what ships: a shell with an empty registry."
```

- [ ] **Step 15: บันทึกผลลง progress**

เขียนผลจริงของทั้ง 4 เกณฑ์ลง `.superpowers/sdd/2026-08-13-plugin-architecture/progress.md` พร้อมคำสั่งที่รันและค่าที่ได้ เพื่อให้ครั้งหน้าที่ถอดฟีเจอร์จริงมีของเทียบ

---

## หลังแผนนี้จบ

repo จะเหลือโครงเปล่าที่พร้อมรับฟีเจอร์ — `Core/` สามไฟล์, `FeatureRegistry.installed` ว่าง, Home แสดงหน้าว่าง

การเพิ่มฟีเจอร์จริงตัวแรกคือแผนของตัวเอง และมีขั้นตอนนอก repo หนึ่งขั้นเสมอ คือเพิ่มชื่อ schema ใน Exposed schemas

ถ้าอยากได้ `Features/Example/` กลับมาเป็นตัวอย่างอ้างอิง มันอยู่ในประวัติ git — `git show` commit ก่อนหน้า Task 5 Step 14
