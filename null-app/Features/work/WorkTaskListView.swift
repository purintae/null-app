//
//  WorkTaskListView.swift
//  null-app
//

import SwiftUI

/// รายการ task ของ stage ที่เลือกอยู่
///
/// ติ๊กแล้วบันทึกทันที ไม่มีปุ่ม Save — แบบเดียวกับที่หน้า stage ทำ
/// การติ๊กคือการรายงานว่าทำอะไรเสร็จ ถ้าต้องกดยืนยันอีกทีมันจะกลายเป็นงานเอกสาร
///
/// `isAdding` มาจากหน้าแม่เสมอ — ปุ่ม New Task อยู่บน `WorkStageEditorView` ไม่ใช่ที่นี่
/// เพราะฉะนั้นตัวที่สั่งเปิดแถวพิมพ์ต้องเป็น `@Binding` ไม่ใช่ state ของ view นี้เอง
struct WorkTaskListView: View {
    let stage: WorkStageRow
    let workID: UUID
    let store: WorkStore
    @Binding var isAdding: Bool

    @State private var newTitle = ""
    @FocusState private var isTypingNew: Bool

    /// task ที่กำลังรอผลจาก `setTask` — กันการยิงซ้อนขณะยังไม่รู้ผลของครั้งก่อน
    ///
    /// `WorkStore.setTask` อ่านว่า stage ปิดอยู่หรือไม่ทั้งก่อนและหลังเขียน แล้วเลื่อนแผน
    /// เฉพาะตอนเห็นขอบ "ไม่ปิด → ปิด" ถ้าสองคำเรียกซ้อนกัน ทั้งคู่จะเห็น "ก่อน" เดียวกัน
    /// และอาจเลื่อนแผนซ้ำสองครั้ง กันที่นี่ด้วยการปิดปุ่มของแถวที่ยังไม่ได้คำตอบ
    @State private var busyTaskIDs: Set<UUID> = []

    var body: some View {
        List {
            ForEach(stage.task) { task in
                let isBusy = busyTaskIDs.contains(task.id)

                Button {
                    guard !isBusy else { return }
                    busyTaskIDs.insert(task.id)
                    Task {
                        _ = await store.setTask(task.id, done: !task.isDone, in: workID)
                        busyTaskIDs.remove(task.id)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isDone ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                            .font(.title3)

                        Text(task.title)
                            .strikethrough(task.isDone, color: .secondary)
                            .foregroundStyle(task.isDone ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                            // ชื่อ task ภาษาไทยไม่มีช่องว่าง ปล่อยให้ระบบตัดบรรทัดเอง
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .opacity(isBusy ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        Task { _ = await store.deleteTask(task.id) }
                    }
                }
            }

            if isAdding {
                HStack(spacing: 12) {
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                        .font(.title3)

                    TextField("What has to happen", text: $newTitle)
                        .focused($isTypingNew)
                        .onSubmit(commit)
                }
            }
        }
        .listStyle(.plain)
        .onChange(of: isAdding) { _, adding in
            if adding { isTypingNew = true }
        }
        .onChange(of: isTypingNew) { _, focused in
            // เลิกพิมพ์แล้วยังไม่ได้ใส่อะไร ให้แถวหายไปเอง ไม่ต้องมีปุ่มยกเลิก
            if !focused { commit() }
        }
    }

    private func commit() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        newTitle = ""
        isAdding = false

        guard !title.isEmpty else { return }
        Task { _ = await store.addTask(title, to: stage.id) }
    }
}
