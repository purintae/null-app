//
//  WorkStageEditorView.swift
//  null-app
//

import SwiftUI

/// ปลายทางของการกดการ์ดหนึ่งใบ — หน้าของงานชิ้นนั้น
///
/// การกดงานคือการอยากเห็นว่ามันไปถึงไหนแล้ว ไม่ใช่การอยากแก้ชื่อ ปลายทางของการ์ด
/// จึงเป็นรายการ stage ส่วนฟอร์มแก้รายละเอียดถอยไปเป็นปุ่มรองบนแถบบน
nonisolated struct WorkRoute: Hashable {
    let id: UUID
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
    @State private var editingDetails: WorkEditRoute?

    /// stage ที่แถบชิปกำลังเลือกอยู่ — รายการ task ข้างล่างเป็นของตัวนี้
    @State private var selectedStage: UUID?

    /// stage ที่ผู้ใช้สั่งลบ แต่ยังลบออกจาก `drafts` ไม่ได้จนกว่าหน้าของมันจะถอยออกไปหมด
    /// ดูเหตุผลที่ `onChange(of: editingStage)`
    @State private var pendingRemoval: UUID?

    /// ตรึงตอนหน้าจอปรากฏ ไม่คำนวณใหม่ทุกครั้งที่วาด — แบบเดียวกับหน้ารายการ
    @State private var today = Date()

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
        VStack(spacing: 0) {
            if drafts.isEmpty {
                emptyStages
            } else {
                stageChips
                stageSummary
                taskHeader

                tasks
                    // ปัดซ้าย/ขวาบนพื้นที่ task เพื่อเปลี่ยน stage — วางไว้ที่นี่ไม่ใช่ทั้งจอ
                    // เพราะแถบชิปข้างบนเลื่อนแนวนอนอยู่แล้ว สองอย่างจะแย่งนิ้วกัน
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 24)
                            .onEnded { value in
                                let dx = value.translation.width
                                let dy = value.translation.height
                                // ต้องเป็นการปัดแนวนอนจริง ๆ ไม่ใช่การเลื่อนขึ้นลงที่เอียงนิดหน่อย
                                guard abs(dx) > abs(dy) * 1.5, abs(dx) > 48 else { return }
                                step(dx < 0 ? 1 : -1)
                            }
                    )
            }

            if let message = validationMessage ?? store.saveError {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // `DatePicker` ในหน้าลูกอ่านปฏิทินและโซนเวลาจาก environment สองบรรทัดนี้คือสิ่งที่ทำให้
        // วันที่ผู้ใช้เลือกกับวันที่เซิร์ฟเวอร์ได้รับเป็นวันเดียวกัน — ดูข้อพิสูจน์ในงานที่ 5
        // ถ้าลบสองบรรทัดนี้ ทุกวันที่จะคลาดไปหนึ่งวันในโซนที่นำหน้า UTC โดยไม่มี error ใด ๆ
        .environment(\.calendar, WorkFilter.calendar)
        .environment(\.timeZone, WorkFilter.calendar.timeZone)
        .navigationTitle(work?.name ?? "Work")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                menu
            }
            if isSaving {
                ToolbarItem(placement: .confirmationAction) {
                    ProgressView()
                }
            }
        }
        .navigationDestination(item: $editingDetails) { route in
            WorkFormView(workID: route.workID, store: store)
        }
        .navigationDestination(item: $editingStage) { id in
            let index = drafts.firstIndex { $0.id == id }

            WorkStageDetailView(
                draft: binding(for: id),
                canMoveEarlier: (index ?? 0) > 0,
                canMoveLater: (index ?? 0) < drafts.count - 1,
                move: { offset in move(id, by: offset) },
                // สั่งลบได้ แต่ยังไม่ลบตรงนี้ — ดู onChange ข้างล่าง
                remove: { pendingRemoval = id }
            )
        }
        // กลับออกมาจากหน้าแก้ stage = แก้เสร็จแล้ว บันทึกตรงนั้น
        // ไม่ต้องให้ผู้ใช้จำว่ายังมีอะไรค้างอยู่
        //
        // **การลบต้องเกิดที่นี่ ไม่ใช่ตอนกดปุ่ม Remove** — หน้าของ stage ผูกอยู่กับ
        // `$drafts[index]` ถ้าเอาสมาชิกออกตอนที่หน้านั้นยังอยู่ แอนิเมชันถอยกลับจะอ่าน
        // ตำแหน่งเดิมต่ออีกเฟรมหนึ่งแล้ว index หลุดขอบ แอปดับทันทีโดยไม่มี error ให้เห็น
        .onChange(of: editingStage) { previous, current in
            guard previous != nil, current == nil else { return }

            if let id = pendingRemoval {
                drafts.removeAll { $0.id == id }
                if selectedStage == id { selectedStage = drafts.first?.id }
                pendingRemoval = nil
            }

            persist()
        }
        .task {
            guard !didLoad else { return }
            let knownCodes = Set(store.stageTypes.map(\.code))
            today = Date()
            drafts = (work?.stage ?? []).map { WorkStageDraft($0, knownCodes: knownCodes) }
            selectedStage = drafts.first?.id
            didLoad = true
        }
        .onDisappear { store.clearSaveError() }
    }

    /// ถอยไปหาอันแรกเสมอเมื่อตัวที่เลือกไว้ไม่มีอยู่แล้ว (เพิ่งถูกลบ หรือยังไม่ทันตั้งค่า)
    /// การเลือกที่ชี้ไปยังของที่ไม่มี ทำให้ทั้งหน้าว่างโดยที่ยังมี stage อยู่ครบ
    private var selectedDraft: WorkStageDraft? {
        drafts.first { $0.id == selectedStage } ?? drafts.first
    }

    /// ยังไม่มี stage — ปุ่มเพิ่มอยู่ในเมนูมุมขวาบน หน้านี้จึงบอกทางไปหามัน
    /// หน้าว่างที่ไม่บอกว่าต้องทำอะไรต่อคือทางตัน
    /// ยังไม่มี stage — ปุ่มเพิ่มอยู่ในเมนูมุมขวาบน หน้านี้จึงบอกทางไปหามัน
    /// หน้าว่างที่ไม่บอกว่าต้องทำอะไรต่อคือทางตัน
    private var emptyStages: some View {
        VStack(spacing: 8) {
            Spacer()

            Text("No stages yet")
                .font(.title3)
                .fontWeight(.medium)

            Text("Add the steps this work goes through\nfrom the menu in the top right.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // ── แถบเลือก stage ───────────────────────────────────────────

    /// สามสถานะเดียวกับที่การ์ดใช้ บวก "เลยกำหนด" ซึ่งเป็นสิ่งเดียวบนหน้านี้
    /// ที่บอกว่างานตรงแผนหรือไม่ — ถ้าไม่โชว์ตรงนี้ ต้องกดเข้าไปดูทีละ stage ถึงจะรู้
    private enum StageMark {
        case completed, late, current, ahead
    }

    private func mark(_ draft: WorkStageDraft) -> StageMark {
        if draft.actualEnd != nil { return .completed }
        let calendar = WorkFilter.calendar
        if calendar.startOfDay(for: draft.plannedEnd) < calendar.startOfDay(for: today) {
            return .late
        }
        return draft.actualStart != nil ? .current : .ahead
    }

    private func markColor(_ mark: StageMark) -> AnyShapeStyle {
        switch mark {
        case .completed: AnyShapeStyle(.secondary)
        case .late: AnyShapeStyle(Color.red)
        case .current: AnyShapeStyle(Color.accentColor)
        case .ahead: AnyShapeStyle(.tertiary)
        }
    }

    /// ชิปเลือก stage — ตัวที่เลือกกางชื่อเต็ม ตัวที่เหลือเหลือแค่รหัส
    /// timeline จริงมีถึงเก้าขั้น ถ้ากางชื่อเต็มทุกอันจะเลื่อนหาไม่เจอ
    ///
    /// จุดเล็กหน้าชิปบอกสถานะ ส่วนพื้นหลังบอกว่าอันไหนถูกเลือกอยู่ — แยกสองเรื่องนี้
    /// ออกจากกันคนละช่องทาง ถ้าใช้สีพื้นบอกทั้งคู่ อันที่เลือกกับอันที่กำลังทำจะแยกไม่ออก
    private var stageChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                ForEach(drafts) { draft in
                    let isOn = draft.id == selectedDraft?.id

                    Button {
                        selectedStage = draft.id
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(markColor(mark(draft)))
                                .frame(width: 7, height: 7)

                            Text(isOn ? displayName(draft) : displayCode(draft))
                                .font(.subheadline)
                                .fontWeight(isOn ? .semibold : .regular)
                                .lineLimit(1)
                        }
                        .foregroundStyle(isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            isOn ? AnyShapeStyle(Color.accentColor.opacity(0.15))
                                 : AnyShapeStyle(.quaternary.opacity(0.4)),
                            in: Capsule()
                        )
                        .frame(minHeight: Self.minTapTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .id(draft.id)
                    .accessibilityLabel(displayName(draft))
                    .accessibilityAddTraits(isOn ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal)
            }
            // เปลี่ยน stage ด้วยการปัดแล้วชิปต้องเลื่อนตามมาให้เห็น
            // ไม่งั้นปัดไปสามอันแล้วไม่รู้ว่าตอนนี้อยู่ตรงไหนของ timeline
            .onChange(of: selectedStage) { _, id in
                guard let id else { return }
                withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .padding(.top, 4)
    }

    /// ขยับไป stage ถัดไป/ก่อนหน้า หยุดที่ปลายทั้งสองข้าง ไม่วนกลับ
    /// timeline มีหัวมีท้ายจริง การวนกลับไปอันแรกจะทำให้เข้าใจผิดว่ายังมีต่อ
    private func step(_ offset: Int) {
        guard let current = selectedDraft,
              let index = drafts.firstIndex(where: { $0.id == current.id })
        else { return }

        let next = index + offset
        guard drafts.indices.contains(next) else { return }
        withAnimation(.snappy) { selectedStage = drafts[next].id }
    }

    /// stage ที่เลือก — ชื่อเต็ม ช่วงวันตามแผน และป้ายบอกว่าช้ากี่วันถ้าช้า
    /// ทั้งก้อนกดได้ พาไปหน้าที่แก้วันและลำดับ
    /// วันของ stage ที่เลือก บรรทัดเดียวเงียบ ๆ ไม่ใช่บล็อกทึบ
    ///
    /// mockup ไม่มีวันที่อยู่บนหน้านี้เลย แต่ถ้าไม่มีจริง ๆ หน้านี้จะตอบไม่ได้ว่า
    /// งานตรงแผนหรือไม่ ต้องกดเข้าไปดูทีละ stage — เก็บไว้บรรทัดเดียวและกดเข้าไปแก้ได้
    @ViewBuilder
    private var stageSummary: some View {
        if let draft = selectedDraft {
            Button {
                editingStage = draft.id
            } label: {
                HStack(spacing: 6) {
                    Text("\(draft.plannedStart.formatted(Self.summaryStyle)) – \(draft.plannedEnd.formatted(Self.summaryStyle))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let late = daysLate(draft) {
                        Text("· \(late)d late")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(.red)
                            .accessibilityLabel(Text("\(late) day\(late == 1 ? "" : "s") late"))
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top, 10)

            if let message = draft.validationError(calendar: WorkFilter.calendar) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }
        }
    }

    /// ช้ากี่วันนับจากวันจบตามแผน — นิยามเดียวกับที่การ์ดบนหน้ารายการใช้
    private func daysLate(_ draft: WorkStageDraft) -> Int? {
        guard draft.actualEnd == nil else { return nil }
        let calendar = WorkFilter.calendar
        let end = calendar.startOfDay(for: draft.plannedEnd)
        let now = calendar.startOfDay(for: today)
        guard end < now else { return nil }
        return calendar.dateComponents([.day], from: end, to: now).day
    }

    /// พื้นที่แตะขั้นต่ำตาม HIG — ชิปที่เห็นยังเท่าเดิม พื้นที่แตะขยายรอบ ๆ มันแทน
    private static let minTapTarget: CGFloat = 44

    private func displayCode(_ draft: WorkStageDraft) -> String {
        draft.code.isEmpty ? "—" : draft.code
    }

    private func displayName(_ draft: WorkStageDraft) -> String {
        if !draft.name.isEmpty { return draft.name }
        return draft.code.isEmpty ? "New stage" : draft.code
    }

    // ── task ─────────────────────────────────────────────────────

    /// ตัวนับซ้าย ปุ่มเพิ่มขวา — รอบ 4 จะมีตาราง task มาเติมทั้งสองฝั่ง
    private var taskHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("0/0 done")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()

            Button("New Task") {}
                // ยังไม่มีตาราง task — ปิดปุ่มไว้ตรงไปตรงมากว่าปุ่มที่กดแล้วไม่เกิดอะไร
                .disabled(true)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var tasks: some View {
        VStack(spacing: 8) {
            Spacer()

            Text("No tasks yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Tasks are what close a stage.")
                .font(.footnote)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var menu: some View {
        Menu {
            Button {
                editingDetails = WorkEditRoute(workID: workID)
            } label: {
                Label("Edit details", systemImage: "pencil")
            }

            if let draft = selectedDraft {
                Button {
                    editingStage = draft.id
                } label: {
                    Label("Edit \(displayCode(draft))", systemImage: "calendar")
                }
            }

            // วนจากรายการที่เซิร์ฟเวอร์ให้มา ไม่มีชื่อขั้นตอนเขียนตายในไฟล์นี้เลย
            // วันที่มีขั้นที่สิบ หน้านี้ไม่ต้องแก้สักบรรทัด
            Menu("Add a stage") {
                ForEach(unusedTypes) { type in
                    Button("\(type.code) · \(type.label)") { add(type) }
                }

                Button {
                    addCustom()
                } label: {
                    Label("Other…", systemImage: "plus")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("More")
    }

    private func add(_ type: WorkStageTypeRow) {
        let draft = WorkStageDraft(
            type: type,
            startingFrom: nextStart,
            calendar: WorkFilter.calendar
        )
        drafts.append(draft)
        selectedStage = draft.id
        persist()
    }

    private func addCustom() {
        let draft = WorkStageDraft(custom: nextStart, calendar: WorkFilter.calendar)
        drafts.append(draft)
        selectedStage = draft.id
        // stage แบบ Other ยังไม่มีรหัสและชื่อ พาไปกรอกทันทีดีกว่าปล่อยให้ผู้ใช้
        // เจอชิปที่เขียนว่า "—" แล้วต้องเดาว่าต้องกดตรงไหน
        editingStage = draft.id
    }

    /// binding ที่หา stage จาก id ไม่ใช่จากตำแหน่งใน array
    ///
    /// **ห้ามกลับไปใช้ `$drafts[index]`** — `dismiss()` ตั้ง `editingStage = nil` ตั้งแต่
    /// *เริ่ม* แอนิเมชันถอยกลับ ไม่ใช่ตอนจบ หน้าที่กำลังเลื่อนออกจึงยังอ่าน binding ต่ออีกหลายเฟรม
    /// ถ้าแถวถูกลบไปแล้ว การ subscript ด้วยตำแหน่งเดิมจะหลุดขอบและแอปดับกลางแอนิเมชัน
    /// (ยืนยันจาก crash log สองรอบ: `Array._checkSubscript` ใต้ `_UINavigationParallaxTransition`)
    ///
    /// ตัวนี้คืนค่าว่างเปล่าแทนการพังเมื่อหาไม่เจอ — เป็นฟังก์ชันที่นิยามครบทุกอินพุต
    /// ต่างจาก subscript ที่นิยามเฉพาะตอนที่แถวยังอยู่
    private func binding(for id: UUID) -> Binding<WorkStageDraft> {
        Binding(
            get: { drafts.first { $0.id == id } ?? Self.vanished },
            set: { newValue in
                guard let index = drafts.firstIndex(where: { $0.id == id }) else { return }
                drafts[index] = newValue
            }
        )
    }

    /// ค่าที่ binding คืนให้หน้าที่กำลังจะหายไป ระหว่างเฟรมสุดท้ายที่มันยังวาดอยู่
    /// ไม่มีทางถูกบันทึก เพราะ setter ปฏิเสธการเขียนเมื่อแถวไม่อยู่แล้ว
    private static let vanished = WorkStageDraft(custom: Date(), calendar: WorkFilter.calendar)

    private func move(_ id: UUID, by offset: Int) {
        guard let from = drafts.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard drafts.indices.contains(to) else { return }
        drafts.swapAt(from, to)
        persist()
    }

    /// เขียนทั้งชุดขึ้นเซิร์ฟเวอร์ เรียกทุกครั้งที่การกระทำหนึ่งจบลง ไม่มีปุ่ม Save
    ///
    /// stage ที่ยังกรอกไม่ครบ (เช่น Other ที่ยังไม่มีรหัส) จะไม่ถูกส่ง และ**ไม่ฟ้องเสียงดัง** —
    /// ผู้ใช้กำลังพิมพ์อยู่ ไม่ได้ทำอะไรผิด ข้อความบอกว่ายังขาดอะไรขึ้นอยู่ที่การ์ดของ stage
    /// นั้นอยู่แล้ว พอกรอกครบและออกจากหน้าแก้ ระบบจะลองบันทึกอีกครั้งเอง
    private func persist() {
        guard let work, !isSaving else { return }

        // ตรวจทั้งชุดก่อนยิง เพราะ error จากฐานข้อมูลจะบอกแค่ชื่อ constraint
        // ไม่บอกว่าเป็นของ stage ไหนในแปดอัน
        if WorkStageDraft.firstError(in: drafts, calendar: WorkFilter.calendar) != nil {
            return
        }
        validationMessage = nil

        isSaving = true
        Task {
            _ = await store.saveStages(drafts, for: workID, existing: work.stage)
            isSaving = false
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
