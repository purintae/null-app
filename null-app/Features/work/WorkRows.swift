//
//  WorkRows.swift
//  null-app
//

import Foundation

/// รูปร่างของแถวในตาราง f_work.*
///
/// **ห้าม import Supabase ในไฟล์นี้** — ความบริสุทธิ์ตรงนี้คือสิ่งเดียวที่ทำให้
/// คอมไพล์ไฟล์นี้กับ harness ด้วย swiftc เพื่อทดสอบตรรกะการนับได้โดยไม่ต้องมี Xcode
///
/// วันที่ของ stage เก็บเป็น `String` ไม่ใช่ `Date` โดยตั้งใจ — คอลัมน์เป็น Postgres `date`
/// ซึ่งส่งกลับมาเป็น `"2026-06-01"` ส่วน decoder ที่ supabase-swift ตั้งค่าไว้คาดหวัง
/// ISO8601 แบบเต็มพร้อมเวลา การ decode ตรง ๆ เป็น Date จึงล้มทั้งคำขอ
nonisolated struct WorkStageRow: Codable, Sendable, Identifiable {
    let id: UUID
    let code: String
    let name: String
    let position: Int
    let plannedStart: String
    let plannedEnd: String
    let actualStart: String?
    let actualEnd: String?

    enum CodingKeys: String, CodingKey {
        case id, code, name, position
        case plannedStart = "planned_start"
        case plannedEnd = "planned_end"
        case actualStart = "actual_start"
        case actualEnd = "actual_end"
    }

    /// ตัวแปลงตัวเดียวของทั้งฟีเจอร์ — locale คงที่และ UTC เพื่อให้ `"2026-06-01"`
    /// แปลเป็นวันเดียวกันเสมอไม่ว่าเครื่องผู้ใช้ตั้งโซนเวลาอะไร
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var plannedStartDate: Date? { Self.dayFormatter.date(from: plannedStart) }
    var plannedEndDate: Date? { Self.dayFormatter.date(from: plannedEnd) }
    var actualStartDate: Date? { actualStart.flatMap(Self.dayFormatter.date(from:)) }
    var actualEndDate: Date? { actualEnd.flatMap(Self.dayFormatter.date(from:)) }

    /// สามสถานะที่อนุมานจากวันจริง ไม่ต้องมีคอลัมน์เก็บ
    enum State: Sendable {
        case completed
        case current
        case ahead
    }

    var state: State {
        if actualEnd != nil { return .completed }
        if actualStart != nil { return .current }
        return .ahead
    }
}

nonisolated struct WorkRow: Codable, Sendable, Identifiable {
    let id: UUID
    let typeCode: String
    let name: String
    let description: String?
    let requestedBy: String?
    let updatedAt: Date
    var stage: [WorkStageRow]

    enum CodingKeys: String, CodingKey {
        case id, name, description, stage
        case typeCode = "type_code"
        case requestedBy = "requested_by"
        case updatedAt = "updated_at"
    }
}

nonisolated struct WorkTypeRow: Codable, Sendable, Identifiable {
    let code: String
    let label: String
    let position: Int

    var id: String { code }
}

/// รายการ stage มาตรฐานจากตาราง `f_work.stage_type`
///
/// รูปร่างเหมือน `WorkTypeRow` ทุกอย่าง แต่เป็นคนละตารางและคนละความหมาย จึงเป็นคนละ type
/// การใช้ type เดียวกันสองที่จะทำให้ส่งรายการผิดตัวเข้า `Picker` ได้โดย compiler ไม่ทัก
nonisolated struct WorkStageTypeRow: Codable, Sendable, Identifiable {
    let code: String
    let label: String
    let position: Int

    var id: String { code }
}
