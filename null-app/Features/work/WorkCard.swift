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
                    // บรรทัดเดียวคือประเด็นของแบบนี้ — ถ้า badge ยาวเกินจนไม่พอ ให้ ViewThatFits
                    // เปลี่ยนไปใช้ตัวเลือกซ้อนบรรทัดข้างล่างแทน ไม่ใช่ปล่อยให้ตัวเองงอกบรรทัด
                    // ในนี้แล้วเบียดพื้นที่ของ stage
                    badgeChip(badge, lineLimit: 1)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(stage)
                    // ที่ตรงนี้มีที่ว่างให้ขึ้นบรรทัดใหม่ — ไม่ล็อก lineLimit เพื่อให้ข้อความไทย
                    // ยาว ๆ ที่ไม่มีช่องว่างขึ้นบรรทัดใหม่ตามพจนานุกรมของระบบแทนการตัดกลางคำ
                    badgeChip(badge, lineLimit: nil)
                }
            }
        } else if let stage = currentStageText {
            Text(stage)
        } else if let badge = badgeText {
            // ไม่มี stage มาแย่งพื้นที่ ปล่อย badge ขึ้นได้หลายบรรทัดเหมือนกัน
            badgeChip(badge, lineLimit: nil)
        }
    }

    /// badge เป็นวัตถุคนละชนิดกับชื่อ stage ไม่ใช่ข้อความอีกก้อนที่ต่อด้วย `·` —
    /// ชื่อ stage เองมี `·` อยู่ในตัว (เช่น `Requirement · IT`) ใช้ตัวเดียวกันเป็นตัวคั่นซ้ำ
    /// อีกชั้นจึงอ่านไม่ออกว่าอันไหนคั่นอะไร รูปทรง capsule ทำหน้าที่เป็นตัวคั่นแทน
    ///
    /// `lineLimit` รับมาจากผู้เรียกแทนที่จะล็อกเป็น 1 เสมอ — สาขาบรรทัดเดียวของ `ViewThatFits`
    /// ต้องการ 1 บรรทัดจริง ๆ (นั่นคือเงื่อนไขที่ทำให้มันเป็นตัวเลือก "พอดี") แต่สาขาซ้อนบรรทัด
    /// มีที่ว่างให้ badge ยาว ๆ ขึ้นหลายบรรทัดได้ ถ้าล็อก 1 ทั้งสองที่ badge ภาษาไทยยาว ๆ ที่ไม่มี
    /// ช่องว่างจะโดนตัดท้ายด้วย ellipsis กลางคำแทนที่จะขึ้นบรรทัดใหม่ — พังพอดีจุดที่
    /// `ViewThatFits` ถูกเอามาใช้เพื่อป้องกัน
    private func badgeChip(_ text: String, lineLimit: Int?) -> some View {
        Text(text)
            .lineLimit(lineLimit)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
    }
}

#Preview("Long Thai badge wraps, doesn't truncate") {
    WorkCard(
        item: WorkItemRow(
            id: UUID(),
            typeCode: "project",
            name: "26-BP-07-02 | ปรับปรุงแอป Umay+ ระยะที่หนึ่ง",
            description: nil,
            requestedBy: nil,
            badge: "รอผลตรวจสอบความปลอดภัยจากทีมโครงสร้างพื้นฐานก่อนเข้าสู่ขั้นตอนถัดไป",
            updatedAt: Date(),
            stage: [
                WorkStageRow(
                    id: UUID(), code: "RU", name: "Requirement · User", position: 1,
                    plannedStart: "2026-01-01", plannedEnd: "2026-02-01",
                    actualStart: "2026-01-01", actualEnd: "2026-02-01"
                ),
                WorkStageRow(
                    id: UUID(), code: "RI", name: "Requirement · IT", position: 2,
                    plannedStart: "2026-02-01", plannedEnd: "2026-03-01",
                    actualStart: "2026-02-01", actualEnd: nil
                ),
            ]
        ),
        today: Date()
    )
    .padding()
}
