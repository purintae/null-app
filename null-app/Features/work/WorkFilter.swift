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
            // เริ่มแล้ว = ถึงวันเริ่มของ stage แรกแล้ว ไม่ใช่ = มีใครกดปุ่ม
            // สเปกรอบ 4 ตัด actual_start ทิ้งเพราะงานเริ่มตามแผนเสมอ
            // พอเริ่มไม่ได้ตามแผน สิ่งที่เกิดคือเลื่อน timeline ไม่ใช่บันทึกส่วนต่าง
            guard !Self.isFinished(stages) else { return false }
            guard let first = stages.compactMap(\.plannedStartDate).min() else { return false }
            return calendar.startOfDay(for: first) <= calendar.startOfDay(for: today)

        case .overdue:
            return Self.blockingStage(stages, today: today, calendar: calendar) != nil

        case .dueThisMonth:
            guard !Self.isFinished(stages) else { return false }
            guard let last = stages.compactMap(\.plannedEndDate).max() else { return false }
            return calendar.isDate(last, equalTo: today, toGranularity: .month)

        case .startingSoon:
            guard !Self.isFinished(stages) else { return false }
            guard let first = stages.compactMap(\.plannedStartDate).min() else { return false }
            // ยังไม่ถึงวันเริ่ม — งานที่เลยวันเริ่มมาแล้วอยู่ใน Active ไม่ใช่ที่นี่
            guard calendar.startOfDay(for: first) > calendar.startOfDay(for: today) else { return false }
            guard let limit = calendar.date(byAdding: .day, value: Self.startingSoonWindow, to: today)
            else { return false }
            return first <= limit
        }
    }

    /// stage ที่บล็อกงานอยู่ — ตัวแรกตามลำดับที่ยังไม่ปิดและเลย `planned_end` มาแล้ว
    ///
    /// **มีได้ไม่เกินหนึ่งอันต่องานหนึ่งชิ้น และนี่คือทั้งหมดของ Freeze**
    /// ถ้า RU ค้างเพราะ user ยังไม่ออก proposal อีกสี่ stage ข้างหลังก็เลยวันตามแผนไปด้วย
    /// การนับทั้งห้าเป็น overdue คือการรายงานว่ามีปัญหาห้าจุดทั้งที่มีจุดเดียว —
    /// ตัวเลขที่เกินความจริงบ่อย ๆ คือตัวเลขที่คนเลิกเชื่อทั้งใบ
    /// ส่วนอีกสี่อันไม่ได้ช้า มันรอ ซึ่งไม่ใช่ความผิดของใคร
    static func blockingStage(
        _ stages: [WorkStageRow],
        today: Date,
        calendar: Calendar
    ) -> WorkStageRow? {
        stages
            .sorted { $0.position < $1.position }
            .first { stage in
                guard !stage.isClosed, let end = stage.plannedEndDate else { return false }
                return calendar.startOfDay(for: end) < calendar.startOfDay(for: today)
            }
    }

    /// ช้ากี่วัน นับจาก stage ที่บล็อกอยู่ตัวเดียว ไม่ใช่ตัวที่เลยกำหนดมานานที่สุด
    /// คืน nil เมื่อไม่มีอะไรบล็อก — ต่างจาก 0 ซึ่งจะแปลว่า "เลยกำหนดวันนี้พอดี"
    static func daysLate(_ stages: [WorkStageRow], today: Date, calendar: Calendar) -> Int? {
        guard let blocking = blockingStage(stages, today: today, calendar: calendar),
              let end = blocking.plannedEndDate
        else { return nil }

        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: end),
            to: calendar.startOfDay(for: today)
        ).day
    }

    /// ทุก stage ปิดครบ = งานเสร็จ ไม่ต้องมีคอลัมน์ status
    static func isFinished(_ stages: [WorkStageRow]) -> Bool {
        !stages.isEmpty && stages.allSatisfy(\.isClosed)
    }

    /// ปฏิทินตัวเดียวของทั้งฟีเจอร์ ตรึงที่ UTC ให้ตรงกับ `WorkStageRow.dayFormatter`
    ///
    /// วันของ stage เป็น Postgres `date` ซึ่งไม่มีโซนเวลาติดมา การอ่านและการเขียนจึงต้อง
    /// ตีความมันด้วยโซนเดียวกันเสมอ ไม่ใช่โซนของเครื่องผู้ใช้ — ไม่งั้นคนที่กรุงเทพฯ (UTC+7)
    /// เลือก `2026-09-01` บน `DatePicker` จะได้ Date ที่เท่ากับ `2026-08-31T17:00Z`
    /// แล้ว formatter ที่เป็น UTC จะเขียนลงฐานข้อมูลว่า `2026-08-31` — ผิดไปหนึ่งวันทุกครั้ง
    /// โดยไม่มี error ใด ๆ
    ///
    /// ผลที่ตามมา: view ที่มี `DatePicker` ต้องใส่ `.environment(\.timeZone, ...)` ให้ตรงกับตัวนี้ด้วย
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()
}
