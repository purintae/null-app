//
//  WorkStageEditorView.swift
//  null-app
//

import SwiftUI

/// ปลายทางของ "Stages" บนหน้าแก้ Work
nonisolated struct WorkStageRoute: Hashable {
    let workID: UUID
}

/// แบ่ง Stage ของ Work หนึ่งชิ้น
///
/// รายการ `stage_type` เป็น **เมนูให้ติ๊ก ไม่ใช่ลำดับบังคับ** — Work ที่ข้าม SIT ก็ไม่ติ๊ก
/// Work ที่รวม SIT กับ UAT ก็ติ๊ก `SU` และยังตั้ง stage นอกรายการเองได้ผ่าน "Other"
///
/// หน้านี้เป็น**รายการอย่างเดียว** ส่วนการแก้รายละเอียดอยู่ในหน้าของ stage นั้น ๆ
/// รอบแรกเขียนเป็น `DisclosureGroup` ที่กางอยู่กับที่ แล้วเจอว่า `DatePicker` แบบ compact
/// กินพื้นที่รับสัมผัสล้ำขึ้นไปทับ `Toggle` ที่อยู่เหนือมันในคอนเทนเนอร์เดียวกัน —
/// stage ที่โหลดมาพร้อมวันจริงจึงกดปิดไม่ได้เลย โดยไม่มี error และหน้าจอดูปกติทุกอย่าง
/// ดู `.superpowers/sdd/2026-08-18-work-round-3/progress.md` สำหรับหลักฐานที่ไล่มา
struct WorkStageEditorView: View {
    let workID: UUID
    let store: WorkStore

    @State private var drafts: [WorkStageDraft] = []
    @State private var didLoad = false
    @State private var isSaving = false
    @State private var validationMessage: String?
    @State private var editingStage: UUID?

    @Environment(\.dismiss) private var dismiss

    private var work: WorkRow? { store.works.first { $0.id == workID } }

    /// ขั้นที่ยังไม่ถูกติ๊ก — เมนู "Add a stage" แสดงเฉพาะพวกนี้
    /// ขั้นที่ติ๊กแล้วหายจากเมนู เพราะปุ่มที่กดแล้วไม่เกิดอะไรคือความสับสน
    private var unusedTypes: [WorkStageTypeRow] {
        let used = Set(drafts.map(\.code))
        return store.stageTypes.filter { !used.contains($0.code) }
    }

    /// stage ใหม่เริ่มวันถัดจากวันจบของอันสุดท้าย เพราะนั่นคือรูปแบบที่พบบ่อยที่สุด
    /// stage ทับกันได้ก็จริง (PT คาบ UAT, IMP คาบ PVT) แต่ให้ผู้ใช้เลื่อนให้ทับเอง
    /// ง่ายกว่าให้แอปเดาว่าจะทับตรงไหน
    private var nextStart: Date {
        guard let last = drafts.last else { return Date() }
        return WorkFilter.calendar.date(byAdding: .day, value: 1, to: last.plannedEnd)
            ?? last.plannedEnd
    }

    /// `Date.formatted()` **ไม่ได้** อ่านโซนเวลาจาก environment เหมือน `DatePicker`
    /// จึงต้องบอกที่นี่เอง ไม่งั้นหัวข้อจะโชว์วันคลาดจากที่ DatePicker ข้างในแสดงหนึ่งวัน
    static let summaryStyle: Date.FormatStyle = {
        var style = Date.FormatStyle.dateTime.day().month(.abbreviated).year()
        style.timeZone = TimeZone(secondsFromGMT: 0)!
        return style
    }()

    var body: some View {
        List {
            if drafts.isEmpty {
                Section {
                    Text("Pick the stages this work goes through. The counters and the lateness number both come from their dates.")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(drafts) { draft in
                Section {
                    Button {
                        editingStage = draft.id
                    } label: {
                        row(draft)
                    }
                    .buttonStyle(.plain)
                } footer: {
                    if let message = draft.validationError(calendar: WorkFilter.calendar) {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }

            Section("Add a stage") {
                // วนจากรายการที่เซิร์ฟเวอร์ให้มา ไม่มีชื่อขั้นตอนเขียนตายในไฟล์นี้เลย
                // วันที่มีขั้นที่สิบ หน้านี้ไม่ต้องแก้สักบรรทัด
                ForEach(unusedTypes) { type in
                    Button {
                        drafts.append(WorkStageDraft(
                            type: type,
                            startingFrom: nextStart,
                            calendar: WorkFilter.calendar
                        ))
                    } label: {
                        LabeledContent(type.label) {
                            Text(type.code).foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    let draft = WorkStageDraft(custom: nextStart, calendar: WorkFilter.calendar)
                    drafts.append(draft)
                    // stage แบบ Other ยังไม่มีรหัสและชื่อ พาไปกรอกทันทีดีกว่าปล่อยให้
                    // ผู้ใช้เจอแถวที่ฟ้องว่า "Code can't be empty" แล้วต้องเดาว่าต้องกดตรงไหน
                    editingStage = draft.id
                } label: {
                    Label("Other…", systemImage: "plus")
                }
            }

            if validationMessage != nil || store.saveError != nil {
                Section {
                    if let validationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                    if let message = store.saveError {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        // `DatePicker` อ่านปฏิทินและโซนเวลาจาก environment สองบรรทัดนี้คือสิ่งที่ทำให้
        // วันที่ผู้ใช้เลือกกับวันที่เซิร์ฟเวอร์ได้รับเป็นวันเดียวกัน — ดูข้อพิสูจน์ในงานที่ 5
        // ถ้าลบสองบรรทัดนี้ ทุกวันที่จะคลาดไปหนึ่งวันในโซนที่นำหน้า UTC โดยไม่มี error ใด ๆ
        .environment(\.calendar, WorkFilter.calendar)
        .environment(\.timeZone, WorkFilter.calendar.timeZone)
        .navigationTitle("Stages")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).disabled(isSaving)
            }
        }
        // ผูกกับ `@State` ไม่ใช่จับคู่ตามชนิด — `navigationDestination(for:)` ไม่ทำงานในสแตกนี้
        // เพราะ Home push ฟีเจอร์เข้ามาด้วย `NavigationLink(destination:)` แบบเก่า
        .navigationDestination(item: $editingStage) { id in
            if let index = drafts.firstIndex(where: { $0.id == id }) {
                WorkStageDetailView(
                    draft: $drafts[index],
                    canMoveEarlier: index > 0,
                    canMoveLater: index < drafts.count - 1,
                    move: { offset in move(id, by: offset) },
                    remove: {
                        drafts.removeAll { $0.id == id }
                        editingStage = nil
                    }
                )
            }
        }
        .task {
            guard !didLoad else { return }
            let knownCodes = Set(store.stageTypes.map(\.code))
            drafts = (work?.stage ?? []).map { WorkStageDraft($0, knownCodes: knownCodes) }
            didLoad = true
        }
        .onDisappear { store.clearSaveError() }
    }

    private func row(_ draft: WorkStageDraft) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.code.isEmpty ? "New stage" : draft.code)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(draft.name.isEmpty ? "Needs a name" : draft.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // ชื่อขั้นภาษาไทยไม่มีช่องว่าง ปล่อยให้ระบบตัดบรรทัดเอง
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(draft.plannedStart.formatted(Self.summaryStyle)) – \(draft.plannedEnd.formatted(Self.summaryStyle))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let from = drafts.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard drafts.indices.contains(to) else { return }
        drafts.swapAt(from, to)
    }

    private func save() {
        guard let work else { return }

        // ตรวจทั้งชุดก่อนยิง เพราะ error จากฐานข้อมูลจะบอกแค่ชื่อ constraint
        // ไม่บอกว่าเป็นของ stage ไหนในแปดอัน
        if let message = WorkStageDraft.firstError(in: drafts, calendar: WorkFilter.calendar) {
            validationMessage = message
            return
        }
        validationMessage = nil

        isSaving = true
        Task {
            let ok = await store.saveStages(drafts, for: workID, existing: work.stage)
            isSaving = false
            if ok { dismiss() }
        }
    }
}

/// แก้ stage หนึ่งอัน
///
/// **`Toggle` กับ `DatePicker` ของมันอยู่คนละ `Section` โดยตั้งใจ ห้ามยุบรวมกัน** —
/// `DatePicker` แบบ compact กินพื้นที่รับสัมผัสล้ำขึ้นไปทับแถวที่อยู่เหนือมันในคอนเทนเนอร์
/// เดียวกัน ทำให้ `Toggle` กดไม่ติดเลยเมื่อ `DatePicker` ถูกวางมาตั้งแต่เฟรมแรก
/// เป็นบั๊กที่ compile ผ่าน หน้าจอดูถูกต้อง และเจอได้ด้วยการกดจริงเท่านั้น
struct WorkStageDetailView: View {
    @Binding var draft: WorkStageDraft

    let canMoveEarlier: Bool
    let canMoveLater: Bool
    let move: (Int) -> Void
    let remove: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            // ช่องพิมพ์รหัสกับชื่อโผล่เฉพาะ stage แบบ Other
            // ขั้นที่ติ๊กจากรายการได้ชื่อมาจากหลังบ้านแล้ว แก้ที่นี่ไม่ได้โดยตั้งใจ
            if draft.isCustom {
                Section {
                    TextField("Code", text: $draft.code)
                    TextField("Stage name", text: $draft.name, axis: .vertical)
                        .lineLimit(1...3)
                }
            }

            Section("Planned") {
                DatePicker("Start", selection: $draft.plannedStart, displayedComponents: .date)
                DatePicker("End", selection: $draft.plannedEnd, displayedComponents: .date)
            }

            Section { Toggle("Started", isOn: startedToggle) }
            if draft.actualStart != nil {
                Section { dateRow("Started on", date: $draft.actualStart) }
            }

            Section { Toggle("Finished", isOn: finishedToggle) }
            if draft.actualEnd != nil {
                Section { dateRow("Finished on", date: $draft.actualEnd) }
            }

            Section("Order") {
                Button { move(-1) } label: { Label("Earlier", systemImage: "arrow.up") }
                    .disabled(!canMoveEarlier)
                Button { move(1) } label: { Label("Later", systemImage: "arrow.down") }
                    .disabled(!canMoveLater)
            }

            Section {
                Button("Remove this stage", role: .destructive) {
                    remove()
                    dismiss()
                }
            }

            if let message = draft.validationError(calendar: WorkFilter.calendar) {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .environment(\.calendar, WorkFilter.calendar)
        .environment(\.timeZone, WorkFilter.calendar.timeZone)
        .navigationTitle(draft.code.isEmpty ? "New stage" : draft.code)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// toggle ที่แทน `Date?` ได้จริง — ปิดแล้วค่าเป็น nil ซึ่งจะกลายเป็น `null` ในสาย
    /// ไม่ใช่คีย์ที่หายไปจาก JSON ดู `WorkPayload.swift`
    private var startedToggle: Binding<Bool> {
        Binding(
            get: { draft.actualStart != nil },
            set: { isOn in
                draft.actualStart = isOn ? (draft.actualStart ?? draft.plannedStart) : nil
                // ปิด stage ที่ไม่เคยเปิดคือสภาพที่ฐานข้อมูลปฏิเสธด้วย constraint
                // ถอนวันเริ่มออกจึงต้องพาวันจบตามไปด้วย ไม่ใช่ปล่อยให้ฟอร์มฟ้องทีหลัง
                if !isOn { draft.actualEnd = nil }
            }
        )
    }

    private var finishedToggle: Binding<Bool> {
        Binding(
            get: { draft.actualEnd != nil },
            set: { isOn in
                draft.actualEnd = isOn ? (draft.actualEnd ?? draft.actualStart ?? draft.plannedEnd) : nil
                if isOn && draft.actualStart == nil { draft.actualStart = draft.plannedStart }
            }
        )
    }

    private func dateRow(_ label: String, date: Binding<Date?>) -> some View {
        DatePicker(
            label,
            selection: Binding(
                get: { date.wrappedValue ?? Date() },
                set: { date.wrappedValue = $0 }
            ),
            displayedComponents: .date
        )
    }
}
