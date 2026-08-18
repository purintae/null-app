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
/// การเรียงลำดับใช้ปุ่มขึ้น/ลง ไม่ใช่ `.onMove` กับ `EditButton` — `EditButton` ไม่มีบน macOS
/// และแอปนี้เป็นเป้าหมายเดียวที่ลงสี่แพลตฟอร์ม ปุ่มที่หน้าตาเหมือนกันทุกที่
/// ชนะการมีท่าเรียงลำดับที่ใช้ได้เฉพาะ iPhone
struct WorkStageEditorView: View {
    let workID: UUID
    let store: WorkStore

    @State private var drafts: [WorkStageDraft] = []
    @State private var didLoad = false
    @State private var isSaving = false
    @State private var validationMessage: String?

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
    private static let summaryStyle: Date.FormatStyle = {
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

            ForEach($drafts) { $draft in
                Section {
                    DisclosureGroup {
                        // ช่องพิมพ์รหัสกับชื่อโผล่เฉพาะ stage แบบ Other
                        // ขั้นที่ติ๊กจากรายการได้ชื่อมาจากหลังบ้านแล้ว แก้ที่นี่ไม่ได้โดยตั้งใจ
                        if draft.isCustom {
                            TextField("Code", text: $draft.code)
                            TextField("Stage name", text: $draft.name, axis: .vertical)
                                .lineLimit(1...3)
                        }

                        DatePicker("Planned start", selection: $draft.plannedStart, displayedComponents: .date)
                        DatePicker("Planned end", selection: $draft.plannedEnd, displayedComponents: .date)

                        optionalDate("Started", date: $draft.actualStart, fallback: draft.plannedStart)
                        optionalDate(
                            "Finished",
                            date: $draft.actualEnd,
                            fallback: draft.actualStart ?? draft.plannedEnd
                        )

                        HStack {
                            Button {
                                move(draft.id, by: -1)
                            } label: {
                                Label("Earlier", systemImage: "arrow.up")
                            }
                            .disabled(index(of: draft.id) == 0)

                            Spacer()

                            Button {
                                move(draft.id, by: 1)
                            } label: {
                                Label("Later", systemImage: "arrow.down")
                            }
                            .disabled(index(of: draft.id) == drafts.count - 1)
                        }
                        .buttonStyle(.borderless)

                        Button("Remove this stage", role: .destructive) {
                            drafts.removeAll { $0.id == draft.id }
                        }
                    } label: {
                        // หัวข้อเป็นข้อความล้วน ไม่มีปุ่ม — ปุ่มในหัวข้อของ DisclosureGroup
                        // แย่งการแตะกับตัวพับเอง ทำให้กดปุ่มแล้วกลุ่มพับ/กางแทน
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
                    }
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
                    drafts.append(WorkStageDraft(custom: nextStart, calendar: WorkFilter.calendar))
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
        .task {
            guard !didLoad else { return }
            let knownCodes = Set(store.stageTypes.map(\.code))
            drafts = (work?.stage ?? []).map { WorkStageDraft($0, knownCodes: knownCodes) }
            didLoad = true
        }
        .onDisappear { store.clearSaveError() }
    }

    /// toggle ที่แทน `Date?` ได้จริง — ปิดแล้วค่าเป็น nil ซึ่งจะกลายเป็น `null` ในสาย
    /// ไม่ใช่คีย์ที่หายไปจาก JSON ดู `WorkPayload.swift`
    @ViewBuilder
    private func optionalDate(
        _ label: String,
        date: Binding<Date?>,
        fallback: Date
    ) -> some View {
        Toggle(label, isOn: Binding(
            get: { date.wrappedValue != nil },
            set: { isOn in date.wrappedValue = isOn ? (date.wrappedValue ?? fallback) : nil }
        ))

        if date.wrappedValue != nil {
            DatePicker(
                "\(label) on",
                selection: Binding(
                    get: { date.wrappedValue ?? fallback },
                    // `guard` บรรทัดนี้คือสิ่งที่ทำให้ปิด toggle แล้วปิดได้จริง
                    // ตอน toggle เซ็ต nil ตัว DatePicker ที่กำลังจะหายไปยังเขียนค่าที่มันถืออยู่
                    // กลับมาในรอบ update เดียวกัน วันจึงฟื้นคืนและ toggle เด้งกลับเป็นเปิด
                    // — บั๊กที่ compile ผ่านและหน้าจอดูปกติ เจอได้ด้วยการกดจริงเท่านั้น
                    set: { newValue in
                        guard date.wrappedValue != nil else { return }
                        date.wrappedValue = newValue
                    }
                ),
                displayedComponents: .date
            )
        }
    }

    private func index(of id: UUID) -> Int {
        drafts.firstIndex { $0.id == id } ?? 0
    }

    private func move(_ id: UUID, by offset: Int) {
        let from = index(of: id)
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
