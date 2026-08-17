//
//  WorkCard.swift
//  null-app
//

import SwiftUI

/// การ์ดงานหนึ่งใบบนหน้า Overview
///
/// ไม่มีตัวเลข progress % และไม่มี Task x/y — สเปกปัดทั้งสองทิ้ง
/// เพราะแถบ stage บอกได้ละเอียดกว่าและตีความง่ายกว่าตัวเลขโดด ๆ
struct WorkCard: View {
    let item: WorkItemRow
    let today: Date

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.name)
                .font(.subheadline)
                .fontWeight(.medium)
                // ไทยไม่มีช่องว่างระหว่างคำ ปล่อยให้ระบบตัดบรรทัดเองได้เต็มที่
                .fixedSize(horizontal: false, vertical: true)

            if item.stage.isEmpty {
                Label("Add a timeline", systemImage: "calendar.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                WorkStageBar(stages: item.stage)
            }

            if currentStageText != nil || badgeText != nil {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    stageAndBadgeText
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    if let late = WorkFilter.daysLate(item.stage, today: today, calendar: calendar) {
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

                Text(item.updatedAt, format: .relative(presentation: .numeric))
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
        guard !item.stage.isEmpty else { return nil }
        let names = WorkStageBar.currentStageNames(item.stage)
        if !names.isEmpty { return names.joined(separator: ", ") }
        return WorkFilter.isFinished(item.stage) ? "Finished" : "Not started yet"
    }

    private var badgeText: String? {
        guard let badge = item.badge, !badge.isEmpty else { return nil }
        return badge
    }

    /// stage ปัจจุบันกับ badge วางเป็นบรรทัดเดียวเมื่อพอ ถ้าไม่พอ (ข้อความไทยสองก้อนชนกัน)
    /// สลับเป็นวางซ้อนแทนการตัดคำทิ้ง — `ViewThatFits` วัดความกว้างที่ต้องการของแต่ละตัวเลือก
    /// ให้เองโดยไม่ต้องคำนวณความกว้างมือ
    @ViewBuilder
    private var stageAndBadgeText: some View {
        if let stage = currentStageText, let badge = badgeText {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    Text(stage)
                        .lineLimit(1)
                    badgeChip(badge)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(stage)
                    badgeChip(badge)
                }
            }
        } else if let stage = currentStageText {
            Text(stage)
        } else if let badge = badgeText {
            badgeChip(badge)
        }
    }

    /// badge เป็นวัตถุคนละชนิดกับชื่อ stage ไม่ใช่ข้อความอีกก้อนที่ต่อด้วย `·` —
    /// ชื่อ stage เองมี `·` อยู่ในตัว (เช่น `Requirement · IT`) ใช้ตัวเดียวกันเป็นตัวคั่นซ้ำ
    /// อีกชั้นจึงอ่านไม่ออกว่าอันไหนคั่นอะไร รูปทรง capsule ทำหน้าที่เป็นตัวคั่นแทน
    private func badgeChip(_ text: String) -> some View {
        Text(text)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
    }
}
