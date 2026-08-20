//
//  WorkCard.swift
//  null-app
//

import SwiftUI

/// การ์ด Work หนึ่งใบบนหน้า Overview
///
/// ไม่มีตัวเลข progress % และไม่มี Task x/y — สเปกปัดทั้งสองทิ้ง
/// เพราะแถบ stage บอกได้ละเอียดกว่าและตีความง่ายกว่าตัวเลขโดด ๆ
///
/// บรรทัดใต้แถบเคยมี badge ที่ผู้ใช้พิมพ์เองต่อท้ายชื่อ stage — ตัดทิ้งแล้ว
/// รอบ 4 จะเอาบรรทัดนั้นกลับมาในรูปที่คำนวณจาก `task` แทนการพิมพ์มือ
struct WorkCard: View {
    let work: WorkRow
    let today: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(work.name)
                .font(.subheadline)
                .fontWeight(.medium)
                // ไทยไม่มีช่องว่างระหว่างคำ ปล่อยให้ระบบตัดบรรทัดเองได้เต็มที่
                .fixedSize(horizontal: false, vertical: true)

            if work.stage.isEmpty {
                Label("Add a timeline", systemImage: "calendar.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                WorkStageBar(stages: work.stage, today: today)
            }

            if let stageText = currentStageText {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(stageText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        // ไทยไม่มีช่องว่างระหว่างคำ ปล่อยให้ระบบตัดบรรทัดเองได้เต็มที่
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    if let late = WorkFilter.daysLate(work.stage, today: today, calendar: WorkFilter.calendar) {
                        Text("\(late)d late")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .layoutPriority(1)
                            .accessibilityLabel(Text("\(late) day\(late == 1 ? "" : "s") late"))
                    }
                }
            }

            HStack {
                Spacer(minLength: 0)

                Text(work.updatedAt, format: .relative(presentation: .numeric))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    /// ชื่อ stage ปัจจุบันของงานนี้ ต่อกันด้วย ", " เมื่อมีมากกว่าหนึ่ง (stage ทับกันได้ตามสเปก) —
    /// ใช้ `WorkStageBar.currentStageNames` ตัวเดียวกับที่ VoiceOver ใช้ ไม่คำนวณซ้ำที่นี่
    ///
    /// งานที่ไม่มี stage เลยไม่มีข้อความนี้ (การ์ดใช้คำเชิญใส่ timeline แทนอยู่แล้ว) งานที่มี stage
    /// แต่ไม่มีอันไหน "ปัจจุบัน" อยู่ในสองแบบ: จบครบทุก stage แล้ว หรือยังไม่เริ่มเลยสักอัน —
    /// ทั้งสองกรณีบอกตรง ๆ แทนที่จะปล่อยเป็นช่องว่าง
    private var currentStageText: String? {
        guard !work.stage.isEmpty else { return nil }
        let names = WorkStageBar.currentStageNames(work.stage, today: today, calendar: WorkFilter.calendar)
        if !names.isEmpty { return names.joined(separator: ", ") }
        return WorkFilter.isFinished(work.stage) ? "Finished" : "Not started yet"
    }
}

#Preview("Long Thai name wraps, doesn't truncate") {
    WorkCard(
        work: WorkRow(
            id: UUID(),
            typeCode: "project",
            name: "26-BP-07-02 | ปรับปรุงแอปพลิเคชัน Umay+ ระยะที่หนึ่ง สำหรับกลุ่มผู้ใช้ภายในองค์กร",
            description: nil,
            requestedBy: nil,
            updatedAt: Date(),
            stage: [
                WorkStageRow(
                    id: UUID(), code: "RU", name: "Requirement · User", position: 1,
                    plannedStart: "2026-01-01", plannedEnd: "2026-02-01",
                    baselineStart: "2026-01-01", baselineEnd: "2026-02-01",
                    task: [
                        WorkTaskRow(
                            id: UUID(), title: "ออก proposal",
                            doneAt: WorkTaskRow.instantFormatter.date(from: "2026-01-20T00:00:00Z"),
                            position: 1
                        ),
                    ]
                ),
                WorkStageRow(
                    id: UUID(), code: "RI", name: "Requirement · IT", position: 2,
                    plannedStart: "2026-02-01", plannedEnd: "2026-03-01",
                    baselineStart: "2026-02-01", baselineEnd: "2026-03-01",
                    task: [
                        WorkTaskRow(id: UUID(), title: "สรุป requirement", doneAt: nil, position: 1),
                    ]
                ),
            ]
        ),
        today: Date()
    )
    .padding()
}
