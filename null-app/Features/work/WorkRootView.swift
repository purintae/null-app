//
//  WorkRootView.swift
//  null-app
//

import SwiftUI

/// หน้าแรกของฟีเจอร์ Work
///
/// รอบนี้ไม่มีข้อมูลและไม่เรียกเซิร์ฟเวอร์เลย ตัวเลขสองตัวเป็นค่าคงที่
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

    /// บรรทัดสรุปพอร์ต — สองตัวเลขที่เปลี่ยนจริงและเรียกร้องให้ทำอะไรสักอย่าง
    ///
    /// spec ปัดการ์ดนับจำนวนสี่ใบทิ้งไปแล้ว เพราะเป็นการนับของในคลัง
    /// ซึ่งเปลี่ยนช้าจนสายตาเลิกอ่านภายในสัปดาห์เดียว
    private var summary: some View {
        HStack(spacing: 6) {
            Text("0 running")
            Text("·")
            Text("0 behind")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        WorkRootView()
    }
}
