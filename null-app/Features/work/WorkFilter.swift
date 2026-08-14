//
//  WorkFilter.swift
//  null-app
//

import Foundation

/// ตรรกะการนับทั้งหมดของฟีเจอร์อยู่ที่เดียวคือที่นี่
///
/// ตัวนับสี่ใบบนหัวหน้าจอกับการกดกรองรายการข้างล่างใช้ฟังก์ชันเดียวกัน
/// ถ้าแยกกันวันหนึ่งจะเกิดสภาพที่ตัวนับบอกว่ามีสองงาน แต่กดแล้วรายการขึ้นสามงาน
/// แล้วไม่มีใครบอกได้ว่าอันไหนถูก
///
/// **ห้าม import Supabase ในไฟล์นี้** — ดูเหตุผลใน WorkRow.swift
nonisolated enum WorkFilter: String, CaseIterable, Sendable, Identifiable {
    case active
    case overdue
    case dueThisMonth
    case startingSoon

    var id: String { rawValue }

    /// ป้ายกำกับของแอปเป็นอังกฤษตามสเปก
    var label: String {
        switch self {
        case .active: "Active"
        case .overdue: "Overdue"
        case .dueThisMonth: "Due this month"
        case .startingSoon: "Starting soon"
        }
    }

    /// จำนวนวันที่เข้าเกณฑ์ startingSoon
    static let startingSoonWindow = 30

    func matches(_ stages: [WorkStageRow], today: Date, calendar: Calendar) -> Bool {
        // งานที่ยังไม่มี stage ไม่เข้าเกณฑ์ใดเลย — ทั้งสี่ใบวัดจากวันที่ของ stage
        // การ์ดของงานแบบนี้จะขึ้นคำเชิญให้ใส่ timeline แทน
        guard !stages.isEmpty else { return false }

        switch self {
        case .active:
            return stages.contains { $0.actualStart != nil } && !Self.isFinished(stages)

        case .overdue:
            return Self.overdueStages(stages, today: today, calendar: calendar).isEmpty == false

        case .dueThisMonth:
            guard !Self.isFinished(stages) else { return false }
            guard let last = stages.compactMap(\.plannedEndDate).max() else { return false }
            return calendar.isDate(last, equalTo: today, toGranularity: .month)

        case .startingSoon:
            guard stages.allSatisfy({ $0.actualStart == nil }) else { return false }
            guard let first = stages.compactMap(\.plannedStartDate).min() else { return false }
            guard let limit = calendar.date(byAdding: .day, value: Self.startingSoonWindow, to: today)
            else { return false }
            // ไม่มีขอบล่าง — งานที่เลยวันเริ่มตามแผนแล้วแต่ยังไม่เริ่ม ต้องยังโผล่ที่นี่
            // ไม่งั้นมันจะหลุดจากทั้งสี่ใบและหายไปจากสายตาพอดีตอนที่ควรถูกมองที่สุด
            return first <= limit
        }
    }

    /// stage ที่เลยกำหนดจบมาแล้วแต่ยังไม่ปิด
    static func overdueStages(
        _ stages: [WorkStageRow],
        today: Date,
        calendar: Calendar
    ) -> [WorkStageRow] {
        stages.filter { stage in
            guard stage.actualEnd == nil, let end = stage.plannedEndDate else { return false }
            return calendar.startOfDay(for: end) < calendar.startOfDay(for: today)
        }
    }

    /// ช้ากี่วัน นับจาก stage ที่เลยกำหนดมานานที่สุด
    /// คืน nil เมื่อไม่มีอะไรเลยกำหนด — ต่างจาก 0 ซึ่งจะแปลว่า "เลยกำหนดวันนี้พอดี"
    static func daysLate(_ stages: [WorkStageRow], today: Date, calendar: Calendar) -> Int? {
        let overdue = overdueStages(stages, today: today, calendar: calendar)
        guard let earliest = overdue.compactMap(\.plannedEndDate).min() else { return nil }
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: earliest),
            to: calendar.startOfDay(for: today)
        ).day
    }

    /// ทุก stage ปิดครบ = งานเสร็จ ไม่ต้องมีคอลัมน์ status
    static func isFinished(_ stages: [WorkStageRow]) -> Bool {
        !stages.isEmpty && stages.allSatisfy { $0.actualEnd != nil }
    }
}
