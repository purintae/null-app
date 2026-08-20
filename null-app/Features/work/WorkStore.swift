//
//  WorkStore.swift
//  null-app
//

import Foundation
import Observation
import Supabase

/// เจ้าของ state ของฟีเจอร์ work เพียงผู้เดียว ตามแบบเดียวกับ ProfileStore
/// view ไม่รู้ว่าข้อมูลมาจากไหน วันที่แหล่งข้อมูลเปลี่ยนจึงไม่ต้องแก้ view
@Observable
final class WorkStore {
    private(set) var works: [WorkRow] = []
    private(set) var types: [WorkTypeRow] = []

    /// รายการ stage มาตรฐาน — หน้าแบ่ง stage วนจากตัวนี้ ไม่มีชื่อขั้นตอนเขียนตายในโค้ดเลย
    private(set) var stageTypes: [WorkStageTypeRow] = []

    /// แยก "บันทึกไม่สำเร็จ" ออกจาก "โหลดไม่สำเร็จ" — สองอย่างนี้พูดคนละประโยคกับผู้ใช้
    /// และอยู่คนละที่บนจอ อันหนึ่งแทนที่รายการทั้งหน้า อีกอันอยู่ใต้ปุ่ม Save ที่กดไปแล้ว
    private(set) var saveError: String?

    /// จำนวน stage ที่เพิ่งถูกเลื่อนจากการปิด stage ช้า — 0 = ไม่มีอะไรเลื่อน
    /// หน้าจอเอาไปขึ้นแถบบอก เพราะการเขียนทับวันของหลาย stage ในคลิกเดียว
    /// ที่ไม่บอกอะไรเลยคือการเปลี่ยนแผนลับหลังผู้ใช้
    private(set) var lastShiftCount = 0

    func clearLastShift() { lastShiftCount = 0 }

    /// แยก "โหลดแล้วไม่มีงาน" ออกจาก "โหลดไม่สำเร็จ" — สองอย่างนี้หน้าตาเหมือนกันบนจอ
    /// ถ้าไม่แยก แล้วผู้ใช้จะเข้าใจว่าข้อมูลหายทั้งที่แค่เน็ตหลุด
    private(set) var loadFailed = false
    private(set) var hasLoaded = false

    private let userID: UUID

    /// คอลัมน์ที่หน้าจอต้องใช้ เขียนไว้ที่เดียวเพราะทั้ง `load()` และ `createWork(_:)` ใช้ชุดเดียวกัน
    /// สองสำเนาที่ต้องแก้พร้อมกันคือสองสำเนาที่วันหนึ่งจะไม่ตรงกัน
    private static let workSelect = """
        id,type_code,name,description,requested_by,updated_at,\
        stage(id,code,name,position,planned_start,planned_end,baseline_start,baseline_end,\
        task(id,title,done_at,position))
        """

    /// ไม่ทำงานใด ๆ ใน init — Home เรียก makeRoot ตอนวาดทุกไอคอน ไม่ใช่ตอนกด
    init(userID: UUID) {
        self.userID = userID
    }

    /// ดึงงานพร้อม stage ในคำขอเดียวผ่าน embed ของ PostgREST
    /// สองคำขอแยกจะทำให้เกิดช่วงที่การ์ดมีงานแต่ยังไม่มีแถบ stage ซึ่งกระพริบ
    func load() async {
        do {
            async let worksTask: [WorkRow] = Backend.client
                .schema("f_work")
                .from("work")
                .select(Self.workSelect)
                .eq("user_id", value: userID)
                .is("archived_at", value: nil)
                .order("updated_at", ascending: false)
                .execute()
                .value

            async let typesTask: [WorkTypeRow] = Backend.client
                .schema("f_work")
                .from("work_type")
                .select("code,label,position")
                .eq("is_active", value: true)
                .order("position")
                .execute()
                .value

            async let stageTypesTask: [WorkStageTypeRow] = Backend.client
                .schema("f_work")
                .from("stage_type")
                .select("code,label,position")
                .eq("is_active", value: true)
                .order("position")
                .execute()
                .value

            let (loadedWorks, loadedTypes, loadedStageTypes) =
                try await (worksTask, typesTask, stageTypesTask)

            // stage และ task มาจากเซิร์ฟเวอร์โดยไม่รับประกันลำดับ เรียงที่นี่ครั้งเดียว
            // แทนที่จะให้ทุก view ที่ใช้มันเรียงเอง
            works = loadedWorks.map { work in
                var sorted = work
                sorted.stage.sort { $0.position < $1.position }
                sorted.stage = sorted.stage.map { stage in
                    var s = stage
                    s.task.sort { $0.position < $1.position }
                    return s
                }
                return sorted
            }
            types = loadedTypes
            stageTypes = loadedStageTypes
            loadFailed = false
        } catch is CancellationError {
            // SwiftUI cancels this task when the view disappears (e.g. quick back-navigation).
            // That is not a load failure — leave loadFailed untouched so a stale error doesn't flash.
        } catch {
            loadFailed = true
        }

        hasLoaded = true
    }

    func clearSaveError() { saveError = nil }

    /// `error.localizedDescription` ของ PostgrestError คือข้อความจาก Postgres ทั้งดุ้น
    /// รวมชื่อ constraint ที่ผู้ใช้ไม่มีทางรู้จัก จึงแปลงเป็นประโยคเดียวที่พาไปทำอะไรต่อได้
    /// ส่วนตัวเต็มพิมพ์ลง console ไว้ตอน debug — การซ่อนทั้งหมดทำให้ไล่ปัญหาไม่ได้เลย
    private func fail(_ error: Error) {
        #if DEBUG
        print("[WorkStore] \(error)")
        #endif
        saveError = "Couldn't save. Check your connection and try again."
    }

    /// สร้าง Work ใหม่ คืน id ของแถวที่เกิดขึ้นจริง
    ///
    /// ต้องได้ id กลับมา ไม่ใช่แค่ true/false เพราะ id คือสิ่งที่พาผู้ใช้ไปหน้าแบ่ง stage
    /// ต่อได้ทันที และ **id เป็นของที่ฐานข้อมูลแจก** แอปห้ามมินต์เอง กติกาเดียวกับ `stable_suffix`
    func createWork(_ draft: WorkDraft) async -> UUID? {
        do {
            let created: [WorkRow] = try await Backend.client
                .schema("f_work")
                .from("work")
                .insert(WorkPayload(insertFor: userID, draft: draft))
                .select(Self.workSelect)
                .execute()
                .value
            saveError = nil
            await load()
            return created.first?.id
        } catch {
            fail(error)
            return nil
        }
    }

    func updateWork(_ id: UUID, draft: WorkDraft) async -> Bool {
        do {
            try await Backend.client
                .schema("f_work")
                .from("work")
                .update(WorkPayload(updateFrom: draft))
                .eq("id", value: id)
                .execute()
            saveError = nil
            await load()
            return true
        } catch {
            fail(error)
            return false
        }
    }

    /// ลบถาวร — stage ตามไปด้วยผ่าน `on delete cascade` ที่ประกาศไว้ตั้งแต่รอบ 2
    /// นี่คือทางเดียวในแอปที่ข้อมูลหายจริง และมันต้องมาจากการกดยืนยันของผู้ใช้เท่านั้น
    func deleteWork(_ id: UUID) async -> Bool {
        do {
            try await Backend.client
                .schema("f_work")
                .from("work")
                .delete()
                .eq("id", value: id)
                .execute()
            saveError = nil
            await load()
            return true
        } catch {
            fail(error)
            return false
        }
    }

    /// บันทึก stage ทั้งชุดของ Work หนึ่งชิ้น โดยเทียบของเก่ากับของใหม่ทีละแถว
    ///
    /// **ห้ามลบทั้งชุดแล้วใส่ใหม่** ถึงโค้ดจะสั้นกว่ามาก — รอบ 4 จะมีตาราง `task`
    /// แขวนใต้ `stage` ด้วย `on delete cascade` การลบ stage เพื่อเขียนทับจะพา task
    /// ที่ผู้ใช้ติ๊กสะสมมาทั้งเดือนหายไปด้วย และหน้าจอจะบอกว่าบันทึกสำเร็จทุกอย่าง
    ///
    /// `position` มาจากตำแหน่งในรายการที่ผู้ใช้เห็น ไม่ใช่ช่องให้พิมพ์เลขเอง —
    /// เลขที่พิมพ์เองคือเลขที่ซ้ำกันได้และไม่มีใครสังเกต
    func saveStages(
        _ drafts: [WorkStageDraft],
        for workID: UUID,
        existing: [WorkStageRow]
    ) async -> Bool {
        let keptIDs = Set(drafts.filter { !$0.isNew }.map(\.id))
        let removed = existing.map(\.id).filter { !keptIDs.contains($0) }

        do {
            if !removed.isEmpty {
                try await Backend.client
                    .schema("f_work").from("stage")
                    .delete()
                    .in("id", values: removed)
                    .execute()
            }

            for (index, draft) in drafts.enumerated() where !draft.isNew {
                try await Backend.client
                    .schema("f_work").from("stage")
                    .update(WorkStagePayload(updateFor: draft.id, draft: draft, position: index + 1))
                    .eq("id", value: draft.id)
                    .execute()
            }

            let inserts = drafts.enumerated()
                .filter(\.element.isNew)
                .map { WorkStagePayload(insertFor: workID, draft: $0.element, position: $0.offset + 1) }
            if !inserts.isEmpty {
                try await Backend.client
                    .schema("f_work").from("stage")
                    .insert(inserts)
                    .execute()
            }

            saveError = nil
            await load()
            return true
        } catch {
            fail(error)
            return false
        }
    }

    /// เพิ่ม task ต่อท้ายรายการของ stage นั้น
    /// `position` มาจากจำนวนที่มีอยู่ ไม่ใช่ช่องให้พิมพ์เลขเอง
    func addTask(_ title: String, to stageID: UUID) async -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let existing = works
            .flatMap(\.stage)
            .first { $0.id == stageID }?
            .task.count ?? 0

        do {
            try await Backend.client
                .schema("f_work").from("task")
                .insert(WorkTaskPayload(insertFor: stageID, title: trimmed, position: existing + 1))
                .execute()
            saveError = nil
            await load()
            return true
        } catch {
            fail(error)
            return false
        }
    }

    /// ติ๊กเสร็จหรือติ๊กออก แล้วถ้าการติ๊กนั้นทำให้ stage ปิดช้ากว่ากำหนด
    /// ให้เลื่อนแผนของ stage ที่เหลือตามไปด้วยในคำขอเดียวกัน
    func setTask(_ id: UUID, done: Bool, in workID: UUID) async -> Bool {
        do {
            try await Backend.client
                .schema("f_work").from("task")
                .update(WorkTaskPayload(done: done ? Date() : nil))
                .eq("id", value: id)
                .execute()

            saveError = nil
            await load()
            await shiftIfClosedLate(workID: workID)
            return true
        } catch {
            fail(error)
            return false
        }
    }

    func deleteTask(_ id: UUID) async -> Bool {
        do {
            try await Backend.client
                .schema("f_work").from("task")
                .delete()
                .eq("id", value: id)
                .execute()
            saveError = nil
            await load()
            return true
        } catch {
            fail(error)
            return false
        }
    }

    /// หลังโหลดใหม่แล้ว ดูว่ามี stage ไหนเพิ่งปิดช้ากว่ากำหนดหรือไม่ ถ้ามีก็เลื่อนที่เหลือ
    ///
    /// **ส่งขึ้นเป็น dictionary ไม่ใช่ `WorkStagePayload`** — payload ตัวนั้นส่งทุกคอลัมน์
    /// เสมอตามกติกาของไฟล์ ซึ่งจะเขียนทับ `code`/`name` ด้วยค่าที่เราไม่ได้ตั้งใจแก้
    /// ที่นี่ต้องแตะแค่คอลัมน์ของวันเท่านั้น
    ///
    /// **เรื่อง idempotency ที่บรีฟรอบแรกไม่ได้กันไว้:** `closed.plannedEndDate` กับ `closedOn`
    /// ไม่เปลี่ยนเองหลัง stage ปิด ดังนั้นถ้าคำนวณ delta จากคู่นี้แล้วไม่บันทึกร่องรอยไว้เลย
    /// ทุกครั้งที่ `setTask` ถูกเรียก — แม้ติ๊ก task ของ stage อื่นที่ไม่เกี่ยวกันเลย — ฟังก์ชันนี้
    /// จะเจอ stage เดิมว่า "ปิดช้า" ซ้ำอีก แล้วเอา delta เดิมไปบวกทับวันที่ถูกเลื่อนไปแล้วครั้งก่อน
    /// ซ้อนกันเรื่อย ๆ ไม่มีที่สิ้นสุด
    ///
    /// ทางแก้ที่นี่คือ "ใช้" ความช้าทิ้งทันทีที่เลื่อนเสร็จ: เขียน `planned_end` ของ stage
    /// ที่เพิ่งปิดช้าให้เท่ากับ `closedOn` เอง (แตะแค่คอลัมน์เดียว ไม่ใช่ผ่าน `WorkStagePayload`
    /// เหมือนกัน) ครั้งต่อไปที่ฟังก์ชันนี้เจอ stage ตัวเดียวกัน delta จะกลายเป็นศูนย์
    /// (`closedOn` ลบ `plannedEnd` ที่ตอนนี้เท่ากับ `closedOn` แล้ว) และ `guard delta > 0`
    /// จะกันไว้เอง โดยไม่ต้องมี state เพิ่มใน store หรือคอลัมน์ใหม่ในฐานข้อมูล — และไม่กระทบ
    /// stage อื่นที่ปิดช้าเป็นเหตุการณ์แยกต่างหาก (เช่น stage ถัดไปปิดช้าเพิ่มเองในภายหลัง)
    /// เพราะ delta ของแต่ละ stage คำนวณจากแถวของตัวเองเท่านั้น
    private func shiftIfClosedLate(workID: UUID) async {
        guard let work = works.first(where: { $0.id == workID }) else { return }

        let calendar = WorkFilter.calendar
        let candidates = work.stage.filter { $0.isClosed }

        for closed in candidates {
            guard let closedOn = closed.closedOn else { continue }

            let shifts = WorkSchedule.shifts(
                after: closed,
                in: work.stage,
                closedOn: closedOn,
                calendar: calendar
            )
            guard !shifts.isEmpty else { continue }

            do {
                for shift in shifts {
                    try await Backend.client
                        .schema("f_work").from("stage")
                        .update([
                            "planned_start": WorkStageRow.dayFormatter.string(from: shift.plannedStart),
                            "planned_end": WorkStageRow.dayFormatter.string(from: shift.plannedEnd),
                        ])
                        .eq("id", value: shift.stageID)
                        .execute()
                }

                // เก็บร่องรอยว่า stage นี้ "ปิดช้า" ถูกจัดการแล้ว — ดูคำอธิบายด้านบน
                try await Backend.client
                    .schema("f_work").from("stage")
                    .update(["planned_end": WorkStageRow.dayFormatter.string(from: closedOn)])
                    .eq("id", value: closed.id)
                    .execute()

                lastShiftCount = shifts.count
                await load()
            } catch {
                fail(error)
            }
            return
        }
    }
}
