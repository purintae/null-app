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
            HStack(alignment: .firstTextBaseline) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    // ไทยไม่มีช่องว่างระหว่างคำ ปล่อยให้ระบบตัดบรรทัดเองได้เต็มที่
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                if let late = WorkFilter.daysLate(item.stage, today: today, calendar: calendar) {
                    Text("\(late)d late")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .layoutPriority(1)
                }
            }

            if item.stage.isEmpty {
                Label("Add a timeline", systemImage: "calendar.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                WorkStageBar(stages: item.stage)
            }

            HStack {
                if let badge = item.badge, !badge.isEmpty {
                    Text(badge)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(item.updatedAt, format: .relative(presentation: .numeric))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .layoutPriority(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}
