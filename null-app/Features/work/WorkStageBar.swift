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
///
/// ความอ่านง่ายของช่องแคบรับประกันที่ระดับ**พิกเซล** ผ่าน `minChipWidth` ไม่ใช่การ floor
/// น้ำหนักวัน — floor น้ำหนักไม่คุ้มครองความกว้างจริงเมื่อ stage อื่นยาวกว่ามาก (เช่น stage
/// หนึ่งสัปดาห์อยู่ข้าง ๆ stage สองสามเดือน สัดส่วนก็ยังบีบมันเหลือไม่กี่พิกเซลอยู่ดี) จึงจอง
/// ความกว้างขั้นต่ำให้ช่องที่สัดส่วนธรรมดาจะทำให้เล็กเกินไปก่อน แล้วค่อยแบ่งพื้นที่ที่เหลือ
/// ตามน้ำหนักให้ช่องที่เหลือ (ดู `chipWidths(available:)`)
struct WorkStageBar: View {
    let stages: [WorkStageRow]
    let today: Date

    private let spacing: CGFloat = 3
    private let barHeight: CGFloat = 22

    /// ความกว้างที่เล็กที่สุดที่ยังอ่านรหัส stage ได้ที่ `.caption2` (~11pt) โดยไม่ต้องพึ่ง
    /// `minimumScaleFactor`
    ///
    /// ตัวอักษรพิมพ์ใหญ่ในฟอนต์ระบบ (SF) กว้างเฉลี่ยราว 0.6–0.65 เท่าของขนาดฟอนต์ต่อตัวอักษร
    /// (ตัวแคบอย่าง "I" กับตัวกว้างอย่าง "W" ถัวเฉลี่ยแล้วประมาณนี้) ที่ 11pt จึงกินที่ราว
    /// 6.8pt ต่อตัวอักษร รหัสสามตัวอย่าง "PVT" กินที่ราว 20pt บวกพื้นที่หายใจสองข้างเล็กน้อย
    /// แล้วปัดขึ้นเป็นเลขกลม ๆ ได้ 28pt — ที่ระดับนี้รหัสยาวกว่านั้น (สี่ถึงหกตัวอักษร) ยังอ่าน
    /// ได้เพราะ `minimumScaleFactor(0.7)` ลดขนาดฟอนต์ลงเหลือ ~7.7pt ซึ่งพอดีสำหรับรหัสยาวถึง
    /// หกตัวอักษร (6 × 0.62 × 7.7 ≈ 28.6pt) — 28pt จึงครอบคลุมทั้งกรณีปกติและกรณีชื่อยาว
    private static let minChipWidth: CGFloat = 28

    /// น้ำหนักของ stage ที่วันที่ parse ไม่ได้ และเป็นพื้นน้ำหนักกันค่าศูนย์/ลบสำหรับ stage
    /// อื่นด้วย — ความอ่านง่ายรับประกันแยกต่างหากด้วย `minChipWidth` แล้ว ค่านี้จึงมีหน้าที่
    /// แค่ทำให้สัดส่วนคำนวณได้ ไม่ใช่เพื่อความอ่านง่ายอีกต่อไป
    private static let minWeight: Double = 7

    var body: some View {
        GeometryReader { geometry in
            let gaps = CGFloat(max(stages.count - 1, 0)) * spacing
            let available = max(geometry.size.width - gaps, 0)
            let widths = chipWidths(available: available)

            HStack(spacing: spacing) {
                ForEach(Array(zip(stages, widths)), id: \.0.id) { stage, width in
                    let state = stage.state(today: today, calendar: WorkFilter.calendar)
                    Text(stage.code)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: width)
                        .frame(height: barHeight)
                        .background(background(for: state), in: RoundedRectangle(cornerRadius: 4))
                        .overlay {
                            if case .ahead = state {
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(.tertiary, lineWidth: 1)
                            }
                        }
                        .foregroundStyle(foreground(for: state))
                }
            }
        }
        .frame(height: barHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// จองความกว้างขั้นต่ำ (`minChipWidth`) ให้ทุกช่องที่สัดส่วนธรรมดาจะทำให้เล็กกว่านั้นก่อน
    /// แล้วค่อยแบ่งพื้นที่ที่เหลือตามน้ำหนักให้ช่องที่เหลือ ทำซ้ำเป็นรอบเพราะการจองรอบหนึ่ง
    /// ลดพื้นที่ที่เหลือลง ซึ่งอาจทำให้สัดส่วนของช่องอื่นที่เพิ่งพอดีเมื่อกี้ตกลงมาต่ำกว่าขั้นต่ำ
    /// อีกได้ (ดูตัวอย่าง 7 stage ในรายงาน ที่ต้องวนสองรอบ)
    ///
    /// ถ้าจองขั้นต่ำให้ทุกช่องพร้อมกันแล้วยังเกินพื้นที่ที่มี (stage เยอะเกินไปสำหรับความกว้าง
    /// การ์ด) ไม่มีอะไรเหลือให้แบ่งตามสัดส่วนเลย — กรณีนี้เลือกแบ่งพื้นที่ที่มีเท่า ๆ กันแทน
    /// อย่างตั้งใจ แม้แต่ละช่องจะเล็กกว่า minChipWidth ก็ตาม ดีกว่าปล่อยให้สูตร reserve-then-
    /// distribute คำนวณความกว้างติดลบหรือ NaN ออกมา
    private func chipWidths(available: CGFloat) -> [CGFloat] {
        guard !stages.isEmpty else { return [] }
        guard available > 0 else { return Array(repeating: 0, count: stages.count) }

        let minTotal = CGFloat(stages.count) * Self.minChipWidth
        guard minTotal <= available else {
            let equalShare = available / CGFloat(stages.count)
            return Array(repeating: equalShare, count: stages.count)
        }

        let weights = stages.map { weight(of: $0) }
        var widths = Array(repeating: CGFloat(0), count: stages.count)
        var floored = Array(repeating: false, count: stages.count)

        while true {
            let freeIndices = (0..<stages.count).filter { !floored[$0] }
            if freeIndices.isEmpty { break }

            let reservedCount = floored.filter { $0 }.count
            let remaining = available - CGFloat(reservedCount) * Self.minChipWidth
            let freeWeightTotal = freeIndices.reduce(0.0) { $0 + weights[$1] }

            var newlyFloored: [Int] = []
            for i in freeIndices {
                let ideal = remaining * CGFloat(weights[i] / freeWeightTotal)
                if ideal < Self.minChipWidth {
                    widths[i] = Self.minChipWidth
                    floored[i] = true
                    newlyFloored.append(i)
                }
            }

            if newlyFloored.isEmpty {
                for i in freeIndices {
                    widths[i] = remaining * CGFloat(weights[i] / freeWeightTotal)
                }
                break
            }
        }

        return widths
    }

    /// ยิ่ง stage ยาวตามแผน ยิ่งได้พื้นที่มาก (ในบรรดาช่องที่ไม่ได้ถูกจองขั้นต่ำ) — ใช้จำนวนวันดิบ
    private func weight(of stage: WorkStageRow) -> Double {
        guard let start = stage.plannedStartDate, let end = stage.plannedEndDate else {
            return Self.minWeight
        }
        let days = end.timeIntervalSince(start) / 86_400
        return max(days, Self.minWeight)
    }

    /// สามสถานะต้องต่างกันที่**รูปทรง** ไม่ใช่แค่โทนเทา — เกรย์สองความเข้ม (`.quaternary` กับ
    /// `.quaternary.opacity(0.4)`) แยกไม่ออกบนจอจริง ทั้งยังพังพร้อมกันเมื่อ dark mode, contrast
    /// ต่ำ หรือตาบอดสี ตัดกันหมด — ตอนนี้ completed ทึบ (แท่งเต็ม), current เน้นด้วยสี accent
    /// (สีเดียวที่สงวนไว้ให้ตาเห็นก่อน), ahead กลวง (มีแต่เส้นขอบ ไม่มีพื้น) สามรูปทรงต่างกัน
    /// อ่านออกได้แม้ปิดสีทั้งหมด — เส้นขอบของ ahead วาดแยกที่ `.overlay` ข้างบน ฟังก์ชันนี้จึง
    /// คืนแค่พื้นหลัง (ว่างเปล่าสำหรับ ahead)
    private func background(for state: WorkStageRow.State) -> AnyShapeStyle {
        switch state {
        case .completed: AnyShapeStyle(.quaternary)
        case .current: AnyShapeStyle(Color.accentColor)
        case .ahead: AnyShapeStyle(.clear)
        }
    }

    private func foreground(for state: WorkStageRow.State) -> AnyShapeStyle {
        switch state {
        case .completed: AnyShapeStyle(.secondary)
        case .current: AnyShapeStyle(Color.white)
        case .ahead: AnyShapeStyle(.tertiary)
        }
    }

    /// ชื่อ stage ที่ "ปัจจุบัน" ทั้งหมด — เผื่อกรณีมีมากกว่าหนึ่งเพราะ stage ทับกันได้
    /// (ดู spec: Penetration Test เดินคาบกับ SIT & UAT, Production Verification Test คาบกับ Go-live)
    ///
    /// จุดเดียวที่คำนวณ "ชื่อ stage ปัจจุบันคืออะไร" — ทั้ง `accessibilitySummary` ข้างล่างและ
    /// `WorkCard` เรียกฟังก์ชันนี้แทนที่จะคำนวณเอง เพื่อไม่ให้มีตรรกะสองชุดที่ต้องคอยให้ตรงกันเอง
    static func currentStageNames(_ stages: [WorkStageRow], today: Date, calendar: Calendar) -> [String] {
        stages.filter { $0.state(today: today, calendar: calendar) == .current }.map(\.name)
    }

    /// VoiceOver อ่านชื่อ stage สามสิบตัวติดกันไม่มีประโยชน์ — สรุปให้แทน
    private var accessibilitySummary: String {
        let done = stages.filter { $0.state(today: today, calendar: WorkFilter.calendar) == .completed }.count
        let current = Self.currentStageNames(stages, today: today, calendar: WorkFilter.calendar)
        if current.isEmpty {
            return "\(done) of \(stages.count) stages done"
        }
        return "\(done) of \(stages.count) stages done, now in \(current.joined(separator: ", "))"
    }
}
