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

    /// แยก "โหลดแล้วไม่มีงาน" ออกจาก "โหลดไม่สำเร็จ" — สองอย่างนี้หน้าตาเหมือนกันบนจอ
    /// ถ้าไม่แยก แล้วผู้ใช้จะเข้าใจว่าข้อมูลหายทั้งที่แค่เน็ตหลุด
    private(set) var loadFailed = false
    private(set) var hasLoaded = false

    private let userID: UUID

    /// คอลัมน์ที่หน้าจอต้องใช้ เขียนไว้ที่เดียวเพราะทั้ง `load()` และ `createWork(_:)` ใช้ชุดเดียวกัน
    /// สองสำเนาที่ต้องแก้พร้อมกันคือสองสำเนาที่วันหนึ่งจะไม่ตรงกัน
    private static let workSelect = """
        id,type_code,name,description,requested_by,updated_at,\
        stage(id,code,name,position,planned_start,planned_end,actual_start,actual_end)
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

            // stage มาจากเซิร์ฟเวอร์โดยไม่รับประกันลำดับ เรียงที่นี่ครั้งเดียว
            // แทนที่จะให้ทุก view ที่ใช้มันเรียงเอง
            works = loadedWorks.map { work in
                var sorted = work
                sorted.stage.sort { $0.position < $1.position }
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
}
