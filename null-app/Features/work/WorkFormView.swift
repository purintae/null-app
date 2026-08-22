//
//  WorkFormView.swift
//  null-app
//

import SwiftUI

/// ปลายทางของปุ่มแก้รายละเอียดบนหน้างาน
///
/// เป็น struct ห่อ UUID ไม่ใช่ UUID เปล่า ๆ เพราะปลายทางอื่นในสแตกเดียวกันก็ใช้ UUID
/// เหมือนกัน สองปลายทางที่ผูกกับชนิดเดียวกันจะแย่งกันเงียบ ๆ
nonisolated struct WorkEditRoute: Hashable {
    let workID: UUID
}

/// หน้าสร้าง Work และหน้าแก้ Work — view เดียว สองโหมด
///
/// `workID == nil` คือสร้างใหม่ (เปิดเป็น sheet) มีค่าคือแก้ของเดิม (ผลักเข้าสแตก)
/// ทั้งสองโหมดใช้ฟอร์มชุดเดียวกัน เพราะช่องเหมือนกันทุกช่อง — สอง view จะกลายเป็น
/// สองชุดกติกาที่ค่อย ๆ ห่างกันขึ้นทุกครั้งที่มีการแก้ข้างเดียว
struct WorkFormView: View {
    /// nil = สร้าง Work ใหม่
    let workID: UUID?
    let store: WorkStore

    @State private var draft = WorkDraft()
    @State private var didLoadDraft = false
    @State private var isSaving = false
    @State private var confirmingDelete = false

    @Environment(\.dismiss) private var dismiss

    private var work: WorkRow? {
        guard let workID else { return nil }
        return store.works.first { $0.id == workID }
    }

    var body: some View {
        Form {
            Section {
                // ตัวเลือกวนจาก work_type ที่เซิร์ฟเวอร์ให้มา
                // ไม่มีชื่อ Work Type เขียนตายอยู่ในไฟล์นี้แม้แต่ตัวเดียว
                Picker("Type", selection: $draft.typeCode) {
                    Text("Choose…").tag("")
                    ForEach(store.types) { type in
                        Text(type.label).tag(type.code)
                    }
                }

                TextField("Name", text: $draft.name, axis: .vertical)
                    .lineLimit(1...4)
            } footer: {
                // รหัสงานอยู่ในชื่อ ไม่มีคอลัมน์แยก — สเปกตัดสินไว้แล้วว่าการแยกออกมา
                // จะได้ช่องบังคับเพิ่มมาหนึ่งช่อง แลกกับความสามารถที่ยังไม่มีใครขอ
                Text("Put the work code in the name, like 26-BP-07-02 | …")
            }

            Section("Optional") {
                TextField("What this covers", text: $draft.detail, axis: .vertical)
                    .lineLimit(2...6)
                TextField("Requested by", text: $draft.requestedBy)
            }

            if work != nil {
                Section {
                    Button("Delete this work", role: .destructive) {
                        confirmingDelete = true
                    }
                } footer: {
                    Text("Deleting removes its stages too. This can't be undone.")
                }
            } else {
                Section {
                    // stage ไม่บังคับตอนสร้างตามสเปก — บังคับติ๊กแปดขั้นพร้อมวันที่ก่อนกด Save
                    // ครั้งแรกได้ คือแบบฟอร์มที่คนกดยกเลิกกลางทาง
                    Text("You can pick the stages after saving.")
                        .foregroundStyle(.secondary)
                }
            }

            if let message = store.saveError {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(workID == nil ? "New work" : "Edit work")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!draft.isValid || isSaving)
            }
            if workID == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .confirmationDialog(
            "Delete this work?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: delete)
        } message: {
            Text("Its stages go too. This can't be undone.")
        }
        .task {
            // โหลดค่าเข้าฟอร์มครั้งเดียว — `store.works` เปลี่ยนทุกครั้งที่บันทึกสำเร็จ
            // ถ้าเติมค่าใหม่ทุกครั้งที่ store ขยับ ผู้ใช้ที่กำลังพิมพ์อยู่จะโดนเขียนทับกลางคัน
            guard !didLoadDraft else { return }
            if let work { draft = WorkDraft(work) }
            didLoadDraft = true
        }
        .onDisappear { store.clearSaveError() }
    }

    /// งานเขียนอยู่ใน `Task` ที่ไม่ผูกกับอายุของ view โดยตั้งใจ
    /// `.task` จะถูกยกเลิกเมื่อ view หายไป และคำขอที่ถูกยกเลิกกลางทางคือคำขอที่
    /// ไม่มีใครรู้ว่าแถวเข้าไปแล้วหรือยัง — สภาพที่แย่กว่าทั้งสำเร็จและล้มเหลว
    private func save() {
        isSaving = true
        Task {
            let ok: Bool
            if let workID {
                ok = await store.updateWork(workID, draft: draft)
            } else {
                ok = await store.createWork(draft) != nil
            }
            isSaving = false
            if ok { dismiss() }
        }
    }

    private func delete() {
        guard let workID else { return }
        isSaving = true
        Task {
            let ok = await store.deleteWork(workID)
            isSaving = false
            if ok { dismiss() }
        }
    }
}
