//
//  WorkStageBar.swift
//  null-app
//

import SwiftUI

/// แถบ stage ย่อบนการ์ด — ความกว้างของแต่ละช่องคือความยาวตามแผน
/// จึงเป็น timeline ที่ผู้ใช้ตีไว้จริง ไม่ใช่ progress bar ที่แบ่งเท่า ๆ กัน
///
/// stage ทับซ้อนกันได้ตามของจริง แถบนี้จึงเรียงตาม position ไม่ได้พยายามวางตามปฏิทิน
/// (การวางตามปฏิทันจริงอยู่ในหน้า Timeline เต็มซึ่งเลื่อนแนวนอนได้)
///
/// ความกว้างคำนวณเองด้วย `GeometryReader` แทนการพึ่ง `layoutPriority` — `layoutPriority`
/// ตัดสินแค่ว่าใครถูกบีบก่อนเมื่อพื้นที่ไม่พอ ไม่ได้ทำให้ความกว้างเป็นสัดส่วนกับน้ำหนัก และ
/// `.frame(maxWidth: .infinity)` บน HStack ก็บังคับให้แบ่งพื้นที่เท่ากันอยู่แล้วไม่ว่า
/// layoutPriority จะเป็นเท่าไหร่ จึงต้องวัดความกว้างที่มีจริงแล้วคำนวณสัดส่วนเอง
struct WorkStageBar: View {
    let stages: [WorkStageRow]

    private let spacing: CGFloat = 3
    private let barHeight: CGFloat = 22

    /// stage สั้นสุดที่ยังต้องอ่านออก — และเป็นค่าที่ stage วันที่พังใช้แทนด้วย
    private static let minWeight: Double = 7

    var body: some View {
        GeometryReader { geometry in
            let totalWeight = max(stages.reduce(0.0) { $0 + weight(of: $1) }, .leastNonzeroMagnitude)
            let gaps = CGFloat(max(stages.count - 1, 0)) * spacing
            let available = max(geometry.size.width - gaps, 0)

            HStack(spacing: spacing) {
                ForEach(stages) { stage in
                    Text(stage.code)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: available * CGFloat(weight(of: stage) / totalWeight))
                        .frame(height: barHeight)
                        .background(background(for: stage.state), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(foreground(for: stage.state))
                }
            }
        }
        .frame(height: barHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// ยิ่ง stage ยาวตามแผน ยิ่งได้พื้นที่มาก — ใช้จำนวนวันดิบ ไม่ปรับสเกล
    /// เพราะความกว้างคำนวณเป็นสัดส่วนของผลรวมอยู่แล้ว ไม่ต้องบีบให้อยู่ในช่วงแคบแบบ layoutPriority
    /// floor กันสอง­กรณี: stage จริงที่สั้นกว่าหนึ่งสัปดาห์ไม่หายไปเป็นเส้นบาง ๆ
    /// และ stage ที่วันที่ parse ไม่ได้ก็ยังได้ส่วนแบ่งเท่ากับ stage หนึ่งสัปดาห์แทนที่จะเป็นศูนย์
    private func weight(of stage: WorkStageRow) -> Double {
        guard let start = stage.plannedStartDate, let end = stage.plannedEndDate else {
            return Self.minWeight
        }
        let days = end.timeIntervalSince(start) / 86_400
        return max(days, Self.minWeight)
    }

    private func background(for state: WorkStageRow.State) -> AnyShapeStyle {
        switch state {
        case .completed: AnyShapeStyle(.quaternary)
        case .current: AnyShapeStyle(Color.accentColor)
        case .ahead: AnyShapeStyle(.quaternary.opacity(0.4))
        }
    }

    private func foreground(for state: WorkStageRow.State) -> Color {
        switch state {
        case .completed: .secondary
        case .current: .white
        case .ahead: .secondary
        }
    }

    /// VoiceOver อ่านชื่อ stage สามสิบตัวติดกันไม่มีประโยชน์ — สรุปให้แทน
    private var accessibilitySummary: String {
        let done = stages.filter { $0.state == .completed }.count
        let current = stages.filter { $0.state == .current }.map(\.name).joined(separator: ", ")
        if current.isEmpty {
            return "\(done) of \(stages.count) stages done"
        }
        return "\(done) of \(stages.count) stages done, now in \(current)"
    }
}
