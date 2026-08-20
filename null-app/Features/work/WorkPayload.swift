//
//  WorkPayload.swift
//  null-app
//

import Foundation

/// รูปร่างของ JSON ที่ส่งขึ้น PostgREST
///
/// **ห้าม import Supabase ในไฟล์นี้** — ดูเหตุผลใน WorkRows.swift
///
/// **ทุก type ในไฟล์นี้เขียน `encode(to:)` เอง ห้ามพึ่งตัวที่ compiler สังเคราะห์ให้**
/// ตัวสังเคราะห์ใช้ `encodeIfPresent` กับ Optional ฟิลด์ที่เป็น nil จึงหายไปจาก JSON ทั้งคีย์
/// แล้ว PostgREST อ่าน "ไม่มีคีย์" ว่า "อย่าแตะคอลัมน์นี้" ผลคือการลบคำอธิบายทิ้ง
/// หรือถอนวันจบจริงออก กลายเป็นการกด Save ที่ไม่เกิดอะไรขึ้นเลย และหน้าจอก็ยังดูถูกต้องทุกอย่าง
/// กับดักนี้กินเวลาไปแล้วครั้งหนึ่ง — ดู CLAUDE.md หัวข้อ "Traps that have already cost time"
nonisolated struct WorkPayload: Encodable, Sendable {
    /// ส่งเฉพาะตอน insert — เจ้าของแถวเปลี่ยนไม่ได้ PATCH จึงไม่ควรเอ่ยถึงคอลัมน์นี้เลย
    /// **นี่คือฟิลด์เดียวในไฟล์ที่ "ไม่ส่ง" เป็นพฤติกรรมที่ถูกต้อง** ที่เหลือต้องส่งเสมอ
    let userID: UUID?
    let typeCode: String

    /// รหัสงาน (`26-BP-07-02`) รวมอยู่ในนี้ ไม่มีคอลัมน์แยก — สเปกตัดสินไว้แล้วว่า
    /// รหัสถูกใช้เป็นส่วนหนึ่งของชื่อในการสื่อสารจริงอยู่แล้ว การแยกออกมาจะได้ช่องบังคับ
    /// เพิ่มมาหนึ่งช่องแลกกับความสามารถที่ยังไม่มีใครขอ
    let name: String
    let detail: String?
    let requestedBy: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case typeCode = "type_code"
        case name
        case detail = "description"
        case requestedBy = "requested_by"
    }

    init(insertFor userID: UUID, draft: WorkDraft) {
        self.userID = userID
        typeCode = draft.typeCode
        name = draft.trimmedName
        detail = draft.trimmedDetail
        requestedBy = draft.trimmedRequestedBy
    }

    init(updateFrom draft: WorkDraft) {
        userID = nil
        typeCode = draft.typeCode
        name = draft.trimmedName
        detail = draft.trimmedDetail
        requestedBy = draft.trimmedRequestedBy
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let userID { try container.encode(userID, forKey: .userID) }
        try container.encode(typeCode, forKey: .typeCode)
        try container.encode(name, forKey: .name)
        // `encodeNil` เขียนเจตนาให้เห็นชัด การเรียก `encode` ทับ Optional ตรง ๆ ได้ผลเหมือนกัน
        // แต่หน้าตาเหมือน encodeIfPresent จนคนอ่านครั้งหน้าแยกไม่ออกว่าตั้งใจหรือพลาด
        if let detail { try container.encode(detail, forKey: .detail) }
        else { try container.encodeNil(forKey: .detail) }
        if let requestedBy { try container.encode(requestedBy, forKey: .requestedBy) }
        else { try container.encodeNil(forKey: .requestedBy) }
    }
}

/// stage หนึ่งแถวที่กำลังจะถูกส่งขึ้น
///
/// วันที่ถูกแปลงเป็น `yyyy-MM-dd` ที่นี่ที่เดียว ด้วย formatter ตัวเดียวกับที่ขาอ่านใช้
/// การส่ง `Date` ตรง ๆ ให้ encoder ของ library จะได้ ISO8601 พร้อมเวลาและโซน
/// ซึ่งคอลัมน์ `date` รับได้แต่ตัดเวลาทิ้งตามโซนของเซิร์ฟเวอร์ ไม่ใช่ตามที่ผู้ใช้เลือก
nonisolated struct WorkStagePayload: Encodable, Sendable {
    /// ส่งเฉพาะตอน update — บอกว่าจะแก้แถวไหน
    let id: UUID?
    /// ส่งเฉพาะตอน insert — บอกว่าแขวนใต้ Work ไหน แถวที่มีอยู่แล้วย้ายเจ้าของไม่ได้
    let workID: UUID?
    let code: String
    let name: String
    let position: Int
    let plannedStart: String
    let plannedEnd: String
    /// ส่งเฉพาะตอน insert — แผนแรกเขียนครั้งเดียวแล้วห้ามแตะอีก
    /// **นี่คือฟิลด์ที่ "ไม่ส่ง" เป็นพฤติกรรมที่ถูกต้องตอน update**
    let baselineStart: String?
    let baselineEnd: String?

    enum CodingKeys: String, CodingKey {
        case id
        case workID = "work_id"
        case code, name, position
        case plannedStart = "planned_start"
        case plannedEnd = "planned_end"
        case baselineStart = "baseline_start"
        case baselineEnd = "baseline_end"
    }

    private init(id: UUID?, workID: UUID?, draft: WorkStageDraft, position: Int, baseline: Bool) {
        self.id = id
        self.workID = workID
        code = draft.code.trimmingCharacters(in: .whitespacesAndNewlines)
        name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.position = position
        plannedStart = WorkStageRow.dayFormatter.string(from: draft.plannedStart)
        plannedEnd = WorkStageRow.dayFormatter.string(from: draft.plannedEnd)
        baselineStart = baseline ? WorkStageRow.dayFormatter.string(from: draft.plannedStart) : nil
        baselineEnd = baseline ? WorkStageRow.dayFormatter.string(from: draft.plannedEnd) : nil
    }

    init(insertFor workID: UUID, draft: WorkStageDraft, position: Int) {
        self.init(id: nil, workID: workID, draft: draft, position: position, baseline: true)
    }

    init(updateFor id: UUID, draft: WorkStageDraft, position: Int) {
        self.init(id: id, workID: nil, draft: draft, position: position, baseline: false)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let id { try container.encode(id, forKey: .id) }
        if let workID { try container.encode(workID, forKey: .workID) }
        try container.encode(code, forKey: .code)
        try container.encode(name, forKey: .name)
        try container.encode(position, forKey: .position)
        try container.encode(plannedStart, forKey: .plannedStart)
        try container.encode(plannedEnd, forKey: .plannedEnd)
        // baseline ส่งเฉพาะตอน insert — ตอน update ต้อง**ไม่มีคีย์** เพื่อให้ PostgREST
        // ไม่แตะคอลัมน์ ต่างจากฟิลด์อื่นในไฟล์นี้ที่ต้องส่งเสมอแม้เป็น null
        if let baselineStart { try container.encode(baselineStart, forKey: .baselineStart) }
        if let baselineEnd { try container.encode(baselineEnd, forKey: .baselineEnd) }
    }
}

/// task หนึ่งอันที่กำลังจะถูกส่งขึ้น
///
/// `done_at` เป็น `timestamptz` จึงส่งเป็น ISO8601 ผ่าน `WorkTaskRow.instantFormatter`
/// ไม่ใช่ `yyyy-MM-dd` แบบวันของ stage — คนละชนิดคอลัมน์ คนละตัวแปลง
nonisolated struct WorkTaskPayload: Encodable, Sendable {
    let stageID: UUID?
    let title: String?
    let position: Int?
    /// `.some(nil)` = ติ๊กออก ต้องส่ง null · `.none` = ไม่แตะคอลัมน์นี้
    let doneAt: Date??

    enum CodingKeys: String, CodingKey {
        case title, position
        case stageID = "stage_id"
        case doneAt = "done_at"
    }

    init(insertFor stageID: UUID, title: String, position: Int) {
        self.stageID = stageID
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.position = position
        doneAt = nil
    }

    /// ติ๊กเสร็จหรือติ๊กออก — แตะคอลัมน์เดียว
    init(done: Date?) {
        stageID = nil
        title = nil
        position = nil
        doneAt = .some(done)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let stageID { try container.encode(stageID, forKey: .stageID) }
        if let title { try container.encode(title, forKey: .title) }
        if let position { try container.encode(position, forKey: .position) }

        // หัวใจของไฟล์นี้ — ติ๊ก task ออกต้องส่ง null ไม่ใช่ปล่อยคีย์หายไป
        // ถ้าคีย์หาย PostgREST จะไม่แตะคอลัมน์ แล้ว task ที่ติ๊กออกจะยังเสร็จอยู่
        // และ stage ก็จะยังปิดอยู่ทั้งที่ผู้ใช้เพิ่งเปิดมันกลับมา
        if let doneAt {
            if let value = doneAt {
                try container.encode(WorkTaskRow.instantFormatter.string(from: value), forKey: .doneAt)
            } else {
                try container.encodeNil(forKey: .doneAt)
            }
        }
    }
}
