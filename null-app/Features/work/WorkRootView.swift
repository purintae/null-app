//
//  WorkRootView.swift
//  null-app
//

import SwiftUI

/// หน้าแรกของฟีเจอร์ Work
///
/// รอบนี้ไม่มีข้อมูลและไม่เรียกเซิร์ฟเวอร์เลย ตัวนับทั้งสี่เป็นศูนย์คงที่
/// และ `+` แสดงไว้แต่กดไม่ได้ เพื่อให้เลย์เอาต์นิ่งตั้งแต่แรกและรอบหน้าแค่ต่อสายเข้ามา
///
/// ตัวกรองประเภทงานยังไม่มีในรอบนี้โดยตั้งใจ — รายชื่อประเภทมาจากตาราง `work_type`
/// ที่ยังไม่ถูกสร้าง และ spec ห้ามเขียนชื่อประเภทตายตัวไว้ใน view
struct WorkRootView: View {
    var body: some View {
        VStack(spacing: 0) {
            summary

            ContentUnavailableView(
                "No work yet",
                systemImage: "briefcase",
                description: Text("Projects and requests will show up here.")
            )
        }
        .navigationTitle("Work")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    // รอบหน้า: เปิดหน้าเพิ่มงาน
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(true)
                .accessibilityLabel("Add work")
            }
        }
    }

    /// การ์ดสรุปสี่ใบ — ทั้งสี่มองจากมุมเวลาคนละมุม (ตอนนี้ / สาย / จะจบ / จะเริ่ม)
    /// และไม่มีใบไหนคำนวณจากใบอื่นได้ ซึ่งเป็นเหตุผลเดียวที่กริดนี้คุ้มพื้นที่
    ///
    /// spec กำหนดให้ทุกใบกดเพื่อกรองรายการข้างล่างได้ — รอบนี้ยังไม่มีรายการให้กรอง
    /// จึงยังไม่ผูกการกด และไม่ทำให้ดูเหมือนกดได้
    private var summary: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(SummaryTile.roundOne) { tile in
                tile
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }
}

/// หนึ่งช่องในกริดสรุป
private struct SummaryTile: View, Identifiable {
    let label: String
    let value: Int

    var id: String { label }

    /// ค่าของรอบที่ยังไม่มีข้อมูล — ศูนย์ทั้งหมด รอบหน้าค่านี้จะมาจากการนับจริง
    static let roundOne = [
        SummaryTile(label: "Running", value: 0),
        SummaryTile(label: "Behind", value: 0),
        SummaryTile(label: "Due this month", value: 0),
        SummaryTile(label: "Starting soon", value: 0),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(.title2)
                .fontWeight(.medium)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        WorkRootView()
    }
}
