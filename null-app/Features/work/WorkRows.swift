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
    let baselineStart: String
    let baselineEnd: String
    var task: [WorkTaskRow]

    enum CodingKeys: String, CodingKey {
        case id, code, name, position, task
        case plannedStart = "planned_start"
        case plannedEnd = "planned_end"
        case baselineStart = "baseline_start"
        case baselineEnd = "baseline_end"
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
    var baselineStartDate: Date? { Self.dayFormatter.date(from: baselineStart) }
    var baselineEndDate: Date? { Self.dayFormatter.date(from: baselineEnd) }

    /// **stage ที่ไม่มี task เลยปิดไม่ได้ตลอดกาล — ตั้งใจให้เป็นแบบนี้**
    ///
    /// ถ้าใช้กติกา "ไม่มี task ที่ค้าง" เฉย ๆ stage ที่เพิ่งสร้างจะกลายเป็นเสร็จแล้ว
    /// ตั้งแต่วินาทีแรก เพราะยังไม่มีอะไรให้ค้าง ผลที่ยอมรับคือทุก stage ต้องมี task
    /// อย่างน้อยหนึ่งอัน ซึ่งบังคับให้เขียนออกมาว่าอะไรคือของที่ต้องได้จาก stage นี้
    var isClosed: Bool {
        !task.isEmpty && task.allSatisfy(\.isDone)
    }

    /// วันที่ปิด stage คือวันที่ติ๊ก task ตัวสุดท้าย — ไม่มีคอลัมน์เก็บ
    var closedOn: Date? {
        guard isClosed else { return nil }
        return task.compactMap(\.doneAt).max()
    }

    var taskCount: Int { task.count }
    var doneCount: Int { task.count { $0.isDone } }

    /// 0 เมื่อยังไม่มี task — ไม่ใช่ 1 ดูเหตุผลที่ `isClosed`
    var progress: Double {
        guard !task.isEmpty else { return 0 }
        return Double(doneCount) / Double(task.count)
    }

    enum State: Sendable {
        case completed
        case current
        case ahead
    }

    /// สามสถานะที่อนุมานจาก task และปฏิทิน ไม่มีคอลัมน์เก็บ
    ///
    /// รับ `today` เข้ามาแทนการเรียก `Date()` เอง เพราะหน้าจอตรึงวันนี้ไว้ตอนปรากฏ
    /// ถ้าฟังก์ชันนี้อ่านนาฬิกาเอง การนับกับสิ่งที่วาดอาจคนละวินาทีกันข้ามเที่ยงคืน
    func state(today: Date, calendar: Calendar) -> State {
        if isClosed { return .completed }
        guard let start = plannedStartDate else { return .ahead }
        return calendar.startOfDay(for: start) <= calendar.startOfDay(for: today)
            ? .current
            : .ahead
    }
}

/// task หนึ่งอันใน stage
///
/// `done_at` เป็น `timestamptz` ไม่ใช่ `date` — ต่างจากวันของ stage โดยตั้งใจ
/// เพราะมันบันทึก**ช่วงเวลาที่ติ๊ก** ไม่ใช่วันที่คนเลือกเอง การเก็บเวลาไว้ด้วย
/// ทำให้เรียงลำดับการปิดภายในวันเดียวกันได้ถูกต้อง
nonisolated struct WorkTaskRow: Codable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let doneAt: Date?
    let position: Int

    enum CodingKeys: String, CodingKey {
        case id, title, position
        case doneAt = "done_at"
    }

    var isDone: Bool { doneAt != nil }

    /// ตัวแปลงขาเขียนของ `done_at` — ขาอ่าน decoder ของ library จัดการเอง
    /// ห้ามส่ง `Date` ตรง ๆ ให้ encoder ด้วยเหตุผลเดียวกับที่วันของ stage ห้ามส่ง
    static let instantFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
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
