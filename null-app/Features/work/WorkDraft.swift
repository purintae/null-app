//
//  WorkDraft.swift
//  null-app
//

import Foundation

/// ค่าที่ฟอร์มกำลังถืออยู่ และกติกาว่าอะไรถูกอะไรผิด
///
/// **ห้าม import Supabase ในไฟล์นี้** — ดูเหตุผลใน WorkRows.swift
///
/// กติกาทุกข้อในนี้มีคู่แฝดเป็น check constraint ในฐานข้อมูล ไม่ใช่การเขียนซ้ำโดยเปล่าประโยชน์
/// แต่เพราะสองชั้นทำคนละหน้าที่: ชั้นนี้บอกผู้ใช้ว่าอะไรยังไม่ครบ *ก่อน* กด Save
/// ส่วนชั้นฐานข้อมูลรับประกันว่าไม่มีทางใดเลยที่ข้อมูลเสียเข้าไปได้ รวมถึงทางที่ยังไม่ได้เขียน
nonisolated struct WorkDraft: Sendable, Equatable {
    var typeCode = ""
    var name = ""

    /// ตรงกับคอลัมน์ `description` — ตั้งชื่อ property ว่า `detail` เพราะ `description`
    /// เป็นชื่อที่ `CustomStringConvertible` จองไว้ การมี stored property ชื่อนั้นทำให้
    /// string interpolation ของ struct นี้พ่นคำอธิบายงานออกมาแทนที่จะพ่นตัว struct
    var detail = ""
    var requestedBy = ""

    static let nameLimit = 200

    init() {}

    init(_ row: WorkRow) {
        typeCode = row.typeCode
        name = row.name
        detail = row.description ?? ""
        requestedBy = row.requestedBy ?? ""
    }

    var isValid: Bool { validationError == nil }

    /// ช่องบังคับมีสองช่องตามสเปก — Work Type และชื่อ ที่เหลือว่างได้ทั้งหมด
    var validationError: String? {
        if typeCode.isEmpty { return "Pick a type" }
        let trimmed = trimmedName
        if trimmed.isEmpty { return "Name can't be empty" }
        if trimmed.count > Self.nameLimit { return "Name is too long" }
        return nil
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedDetail: String? { Self.emptyToNil(detail) }
    var trimmedRequestedBy: String? { Self.emptyToNil(requestedBy) }

    /// ช่องที่ผู้ใช้ล้างทิ้งต้องกลายเป็น nil ไม่ใช่ `""`
    /// สตริงว่างในคอลัมน์ที่ null ได้ คือค่าที่ไม่มีความหมายและต้องเช็กสองแบบตลอดไป
    static func emptyToNil(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// stage หนึ่งแถวที่กำลังถูกแก้อยู่
///
/// วันที่เป็น `Date` ที่นี่ (ไม่ใช่ `String` แบบ `WorkStageRow`) เพราะ `DatePicker` ต้องการ `Date`
/// การแปลงกลับเป็น `yyyy-MM-dd` เกิดที่เดียวคือ `WorkPayload.swift`
///
/// **ไม่มีวันจริงในนี้แล้ว** — รอบ 4 ตัด `actual_start` / `actual_end` ทิ้งทั้งคู่
/// เพราะ stage เริ่มตามแผนเสมอ (พอไม่ตามก็แก้แผนแทน) และวันปิดคำนวณจาก task ได้
nonisolated struct WorkStageDraft: Sendable, Equatable, Identifiable {
    /// id ของแถวจริงเมื่อ `isNew == false` — เมื่อเป็นแถวใหม่ ตัวนี้เป็นแค่ identity ให้ `ForEach`
    /// และถูกทิ้งตอนบันทึก เพราะ id จริงเป็นของที่ฐานข้อมูลแจก
    let id: UUID
    let isNew: Bool

    /// true = stage ที่ผู้ใช้ตั้งเอง ไม่ได้มาจากรายการ `stage_type`
    ///
    /// เก็บไว้เพราะหน้าจอต้องรู้ว่าจะโชว์ช่องพิมพ์รหัสกับชื่อหรือไม่ ส่วนฐานข้อมูล**ไม่เก็บ**
    /// ค่านี้ — `stage.code` เป็น text เฉย ๆ ไม่มี FK ไปหารายการ ตอนโหลดกลับมาจึงอนุมานเอา
    /// จากว่ารหัสนั้นอยู่ในรายการหรือเปล่า
    var isCustom: Bool

    var code = ""
    var name = ""
    var plannedStart: Date
    var plannedEnd: Date

    static let codeLimit = 8
    static let nameLimit = 80

    /// stage ที่ติ๊กมาจากรายการ — รหัสกับชื่อมาจากรายการ ผู้ใช้เหลือแค่ใส่วัน
    init(type: WorkStageTypeRow, startingFrom start: Date, calendar: Calendar) {
        id = UUID()
        isNew = true
        isCustom = false
        code = type.code
        name = type.label
        plannedStart = calendar.startOfDay(for: start)
        plannedEnd = calendar.date(byAdding: .month, value: 1, to: plannedStart) ?? plannedStart
    }

    /// stage ที่ผู้ใช้ตั้งเอง — เริ่มจากรหัสและชื่อว่าง ฟอร์มจะฟ้องจนกว่าจะกรอก
    init(custom start: Date, calendar: Calendar) {
        id = UUID()
        isNew = true
        isCustom = true
        plannedStart = calendar.startOfDay(for: start)
        plannedEnd = calendar.date(byAdding: .month, value: 1, to: plannedStart) ?? plannedStart
    }

    init(_ row: WorkStageRow, knownCodes: Set<String>) {
        id = row.id
        isNew = false
        isCustom = !knownCodes.contains(row.code)
        code = row.code
        name = row.name
        plannedStart = row.plannedStartDate ?? Date()
        plannedEnd = row.plannedEndDate ?? plannedStart
    }

    /// เทียบวันที่ระดับวัน ไม่ใช่ระดับวินาที — `DatePicker` คืนเวลาติดมาด้วยเสมอ
    /// stage ที่เริ่มและจบวันเดียวกันจะฟ้องผิดทันทีถ้าเทียบ `Date` ตรง ๆ
    /// เพราะเวลาบ่ายของวันเริ่มมากกว่าเวลาเช้าของวันจบ
    func validationError(calendar: Calendar) -> String? {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCode.isEmpty { return "Code can't be empty" }
        if trimmedCode.count > Self.codeLimit { return "Code is too long" }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return "Stage name can't be empty" }
        if trimmedName.count > Self.nameLimit { return "Stage name is too long" }

        if calendar.startOfDay(for: plannedEnd) < calendar.startOfDay(for: plannedStart) {
            return "Planned end is before the planned start"
        }

        return nil
    }

    /// ข้อผิดพลาดแรกของทั้งรายการ พร้อมบอกว่าเป็นของ stage ไหน
    /// ผู้ใช้ที่มีแปด stage ต้องรู้ว่าต้องไปแก้บรรทัดไหน ไม่ใช่แค่รู้ว่ามีอะไรผิดสักที่
    static func firstError(in drafts: [WorkStageDraft], calendar: Calendar) -> String? {
        for draft in drafts {
            guard let message = draft.validationError(calendar: calendar) else { continue }
            let label = draft.code.trimmingCharacters(in: .whitespacesAndNewlines)
            return label.isEmpty ? message : "\(label): \(message)"
        }
        return nil
    }
}
