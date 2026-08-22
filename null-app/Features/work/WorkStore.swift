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

    /// งาน (work) ที่กำลังมีการเลื่อนแผนค้างอยู่ — กันไม่ให้ `shiftClosedStage` ยิงซ้อนสองครั้ง
    /// สำหรับงานเดียวกัน ดูเหตุผลเต็มที่ `setTask`
    private var shiftingWorkIDs: Set<UUID> = []

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
    ///
    /// `position` มาจาก**เลขตำแหน่งสูงสุดที่มีอยู่จริง + 1** ไม่ใช่จำนวน task ทั้งหมด —
    /// ลบ task กลางรายการออกไปหนึ่งอันจากสามอัน (position 1,2,3 → เหลือ 1,3) แล้วนับด้วย
    /// `count` จะได้ `2 + 1 = 3` ซึ่งชนกับ position 3 ที่ยังอยู่จริง ใช้ค่าสูงสุด (`3 + 1 = 4`)
    /// แทนจึงรับประกันไม่ชนไม่ว่าจะลบตัวไหนออกไปก่อนหน้านี้
    func addTask(_ title: String, to stageID: UUID) async -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let highestPosition = works
            .flatMap(\.stage)
            .first { $0.id == stageID }?
            .task.map(\.position).max() ?? 0

        do {
            try await Backend.client
                .schema("f_work").from("task")
                .insert(WorkTaskPayload(insertFor: stageID, title: trimmed, position: highestPosition + 1))
                .execute()
            saveError = nil
            await load()
            return true
        } catch {
            fail(error)
            return false
        }
    }

    /// ติ๊กเสร็จหรือติ๊กออก แล้วถ้าการติ๊กนี้เป็นตัวที่ทำให้ stage ปิด **และ** ปิดช้ากว่ากำหนด
    /// ให้เลื่อนแผนของ stage ที่เหลือตามไปด้วย
    ///
    /// **ทำไมต้องเช็ค "เพิ่งปิดในคำเรียกนี้" ไม่ใช่แค่ "ปิดอยู่":** stage ที่ปิดช้าแล้วค้างอยู่
    /// จะยังคง "ปิดช้า" ตลอดไปตามนิยาม (`closedOn` ไม่เปลี่ยนเองหลังปิด) ถ้าฟังก์ชันเลื่อนแผน
    /// สแกนหา "stage ไหนก็ได้ที่ปิดช้า" ทุกครั้งที่มีการติ๊ก จะเจอ stage เดิมซ้ำทุกครั้งที่มีคน
    /// ติ๊ก task ของ stage อื่นที่ไม่เกี่ยวข้องเลย แล้วเลื่อนที่เหลือซ้ำไปเรื่อย ๆ ไม่มีที่สิ้นสุด
    /// การเช็คขอบ (edge) "ไม่ปิด → ปิด" เฉพาะของ stage ที่ task ตัวนี้สังกัดอยู่ ทำให้เลื่อน
    /// เกิดขึ้นแค่ครั้งเดียวต่อการปิดหนึ่งครั้งจริง ๆ โดยไม่ต้องเขียนคอลัมน์ทำเครื่องหมายเพิ่ม
    /// และไม่ทำให้ `planned_end` ของ stage ที่ปิดไปแล้วเสียความหมาย ("แผนตอนนี้") ไปเป็นอย่างอื่น
    func setTask(_ id: UUID, done: Bool, in workID: UUID) async -> Bool {
        let owningStage = works
            .flatMap(\.stage)
            .first { $0.task.contains { $0.id == id } }
        let wasClosed = owningStage?.isClosed ?? false

        do {
            try await Backend.client
                .schema("f_work").from("task")
                .update(WorkTaskPayload(done: done ? Date() : nil))
                .eq("id", value: id)
                .execute()

            saveError = nil
            await load()

            guard let stageID = owningStage?.id else { return true }
            let isNowClosed = works.flatMap(\.stage).first { $0.id == stageID }?.isClosed ?? false
            if !wasClosed && isNowClosed {
                // ติ๊ก task สองอันสุดท้ายของ stage เดียวกันพร้อมกันเร็ว ๆ ทำให้ทั้งสองคำเรียก
                // เห็น `wasClosed == false` ตัวเดียวกันก่อนเขียน (ดูเหตุผลเต็มด้านบน) —
                // `busyTaskIDs` ในหน้าจอกันการยิง `setTask` ซ้ำ*ต่อ task* แต่ตัวนี้ต้องกันซ้ำ
                // *ต่องาน* เพราะการเลื่อนแผนกระทบทุก stage ที่เหลือของงานนั้น ไม่ใช่แค่ stage ที่ปิด
                guard !shiftingWorkIDs.contains(workID) else { return true }
                shiftingWorkIDs.insert(workID)
                await shiftClosedStage(stageID, in: workID)
                shiftingWorkIDs.remove(workID)
            }
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

    /// เลื่อนแผนของ stage ที่เหลือ เพราะ `stageID` เพิ่งปิด (เรียกจาก `setTask` เฉพาะตอนที่
    /// การติ๊กครั้งนี้เป็นตัวที่ทำให้ stage เปลี่ยนจากไม่ปิด → ปิดเท่านั้น — ดูเหตุผลที่ `setTask`)
    ///
    /// **ส่งขึ้นเป็น dictionary ไม่ใช่ `WorkStagePayload`** — payload ตัวนั้นส่งทุกคอลัมน์
    /// เสมอตามกติกาของไฟล์ ซึ่งจะเขียนทับ `code`/`name` ด้วยค่าที่เราไม่ได้ตั้งใจแก้
    /// ที่นี่ต้องแตะแค่คอลัมน์ของวันเท่านั้น
    ///
    /// **ไม่มีการเขียนอะไรกลับไปที่ตัว `stageID` เอง** — `planned_end` ของ stage ที่ปิดแล้ว
    /// ยังคงหมายถึง "แผนปัจจุบัน" เหมือนเดิม ไม่ใช่ที่เก็บร่องรอยว่าเคยเลื่อนไปแล้ว การเช็คขอบที่
    /// `setTask` (เรียกฟังก์ชันนี้เฉพาะตอน stage เพิ่งปิดในคำเรียกนั้นจริง ๆ) คือสิ่งที่กัน
    /// การเลื่อนซ้ำ ไม่ใช่การเขียนคอลัมน์ทำเครื่องหมายที่นี่ ผลคือถ้าคำขอนี้ล้มเหลวกลางทาง
    /// (แอปปิดตัว, เน็ตหลุด) จะไม่มีการ retry เอง — ผู้ใช้ต้องติ๊กออกแล้วติ๊กกลับเพื่อให้ขอบ
    /// "ไม่ปิด → ปิด" เกิดใหม่อีกครั้ง ซึ่งตั้งใจให้เป็นแบบนี้: ดีกว่าเดายังไง delta ก็ยังถูก
    /// อยู่ ดีกว่าเสี่ยงเลื่อนซ้ำเงียบ ๆ โดยไม่มีใครรู้
    private func shiftClosedStage(_ stageID: UUID, in workID: UUID) async {
        guard let work = works.first(where: { $0.id == workID }),
              let closed = work.stage.first(where: { $0.id == stageID }),
              let closedOn = closed.closedOn
        else { return }

        let shifts = WorkSchedule.shifts(
            after: closed,
            in: work.stage,
            closedOn: closedOn,
            calendar: WorkFilter.calendar
        )
        guard !shifts.isEmpty else { return }

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

            lastShiftCount = shifts.count
            await load()
        } catch {
            fail(error)
        }
    }
}
