//
//  WorkSchedule.swift
//  null-app
//

import Foundation

/// การเลื่อนแผนที่เหลือเมื่อ stage หนึ่งปิดช้ากว่ากำหนด
///
/// **ห้าม import Supabase ในไฟล์นี้** — ดูเหตุผลใน WorkRows.swift
///
/// แยกออกมาจาก `WorkStore` เพราะเป็นเลขล้วน ๆ ที่ทดสอบได้โดยไม่ต้องมีเซิร์ฟเวอร์
/// และเพราะการคำนวณผิดตรงนี้จะเขียนทับวันของ stage หลายอันพร้อมกันโดยไม่มีทางย้อน
nonisolated enum WorkSchedule {
    /// วันชุดใหม่ของ stage หนึ่งอัน
    nonisolated struct Shift: Sendable, Equatable {
        let stageID: UUID
        let plannedStart: Date
        let plannedEnd: Date
    }

    /// stage ที่อยู่หลัง `closed` และยังไม่ปิด ต้องเลื่อนไปกี่วันและเป็นวันอะไร
    ///
    /// **เลื่อนทุกอันด้วยจำนวนวันเท่ากัน ไม่ใช่ไล่ต่อท้ายตัวก่อนหน้าทีละอัน** —
    /// สเปกระบุว่า stage ทับกันได้ (PT คาบ SIT & UAT, IMP คาบ PVT) การไล่ต่อท้าย
    /// จะดึงของที่ตั้งใจให้ทับมาเรียงเป็นแถวเดี่ยว ผลลัพธ์เหมือนกันเป๊ะเมื่อ stage เรียงต่อกันอยู่แล้ว
    ///
    /// **ปิดเร็วกว่าแผนไม่ดึงอะไรขึ้นมา** — การที่เราเสร็จก่อนไม่ได้แปลว่าทีมถัดไป
    /// ว่างรับงานเร็วขึ้น การดึงแผนขึ้นเองจะสร้างวันที่ไม่มีใครตกลงด้วย
    static func shifts(
        after closed: WorkStageRow,
        in stages: [WorkStageRow],
        closedOn: Date,
        calendar: Calendar
    ) -> [Shift] {
        guard let plannedEnd = closed.plannedEndDate else { return [] }

        let delta = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: plannedEnd),
            to: calendar.startOfDay(for: closedOn)
        ).day ?? 0

        guard delta > 0 else { return [] }

        return stages
            .filter { $0.position > closed.position && !$0.isClosed }
            .compactMap { stage in
                guard let start = stage.plannedStartDate,
                      let end = stage.plannedEndDate,
                      let newStart = calendar.date(byAdding: .day, value: delta, to: start),
                      let newEnd = calendar.date(byAdding: .day, value: delta, to: end)
                else { return nil }

                return Shift(stageID: stage.id, plannedStart: newStart, plannedEnd: newEnd)
            }
    }
}
