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

    /// เปิดแถวพิมพ์ task ใหม่ — ตั้งจากปุ่ม New Task บนหัวเรื่อง ส่งลงไปเป็น binding ให้ `WorkTaskListView`
    @State private var isAddingTask = false

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
    /// `01/05/2026` — ตรึงปฏิทินเกรกอเรียนและโซนเดียวกับ `WorkFilter.calendar`
    ///
    /// **ห้ามปล่อยให้ตามเครื่อง** — เครื่องที่ตั้งภาษาไทยจะเรนเดอร์เป็นพุทธศักราช
    /// แล้วบรรทัดนี้จะขึ้น 2569 ขณะที่ `DatePicker` ในหน้าแก้ (ซึ่งถูกตรึงเกรกอเรียนไว้)
    /// ขึ้น 2026 — วันเดียวกันแต่คนละปฏิทินบนสองหน้าจอที่กดต่อกัน
    static let dayStyle: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = WorkFilter.calendar
        f.timeZone = WorkFilter.calendar.timeZone
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            if drafts.isEmpty {
                emptyStages
            } else {
                stageTabs
                Divider()
                stageHeader
                progressCard

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

            if store.lastShiftCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                    Text("Moved \(store.lastShiftCount) later stage\(store.lastShiftCount == 1 ? "" : "s") to keep the gap.")
                        .font(.footnote)
                    Spacer(minLength: 0)
                    Button("OK") { store.clearLastShift() }
                        .font(.footnote)
                }
                .padding()
                .background(.quaternary.opacity(0.4))
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
            ToolbarItem(placement: .primaryAction) {
                addStageMenu
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

    /// แท็บรหัส stage มีเส้นใต้ที่ตัวที่เลือก
    ///
    /// แสดง**รหัสอย่างเดียว** ชื่อเต็มไปอยู่เป็นหัวเรื่องข้างล่าง — timeline จริงมีถึงเก้าขั้น
    /// และขั้นที่ผู้ใช้ตั้งเองมีชื่อไทยยาว ๆ ได้ ถ้าเอาชื่อขึ้นแท็บ แถบจะยาวจนเลื่อนหาไม่เจอ
    private var stageTabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(drafts) { draft in
                        let isOn = draft.id == selectedDraft?.id

                        Button {
                            withAnimation(.snappy) { selectedStage = draft.id }
                        } label: {
                            VStack(spacing: 6) {
                                Text(displayCode(draft))
                                    .font(.subheadline)
                                    .fontWeight(isOn ? .semibold : .regular)
                                    .foregroundStyle(isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                                    .lineLimit(1)

                                // เส้นใต้กินความกว้างเท่าแท็บเสมอ ใช้ `.clear` แทนการเอาออก
                                // ไม่งั้นความสูงของแถบจะกระตุกทุกครั้งที่เปลี่ยนแท็บ
                                Rectangle()
                                    .fill(isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(.clear))
                                    .frame(height: 2)
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 10)
                            .frame(minWidth: Self.minTapTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(draft.id)
                        .accessibilityLabel(displayName(draft))
                        .accessibilityAddTraits(isOn ? [.isSelected] : [])
                    }
                }
            }
            // เปลี่ยน stage ด้วยการปัดแล้วแท็บต้องเลื่อนตามมาให้เห็น
            // ไม่งั้นปัดไปสามอันแล้วไม่รู้ว่าตอนนี้อยู่ตรงไหนของ timeline
            .onChange(of: selectedStage) { _, id in
                guard let id else { return }
                withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
            }
        }
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

    // ── หัวเรื่องของ stage ที่เลือก ────────────────────────────────

    /// ชื่อเต็ม ช่วงวัน และปุ่มเพิ่ม task
    ///
    /// ป้าย "ช้ากี่วัน" ต่อท้ายบรรทัด Timeline แทนที่จะเป็นจุดสีบนแท็บ — มันเป็นข้อเท็จจริง
    /// เกี่ยวกับวัน อ่านตรงที่พูดถึงวันจึงเข้าใจได้ทันทีโดยไม่ต้องจำว่าสีไหนแปลว่าอะไร
    @ViewBuilder
    private var stageHeader: some View {
        if let draft = selectedDraft {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        editingStage = draft.id
                    } label: {
                        HStack(spacing: 6) {
                            Text(displayName(draft))
                                .font(.headline)
                                .foregroundStyle(.primary)
                                // ชื่อขั้นภาษาไทยไม่มีช่องว่าง ปล่อยให้ระบบตัดบรรทัดเอง
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        Text("Timeline : \(Self.dayStyle.string(from: draft.plannedStart)) - \(Self.dayStyle.string(from: draft.plannedEnd))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let late = daysLate(draft) {
                            Text("· \(late)d late")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.red)
                                .accessibilityLabel(Text("\(late) day\(late == 1 ? "" : "s") late"))
                        }
                    }

                    if let message = draft.validationError(calendar: WorkFilter.calendar) {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                Button("New Task") { isAddingTask = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.top, 14)
        }
    }

    /// แถบความคืบหน้าของ stage ที่เลือก นับจาก task ที่ปิดแล้ว
    @ViewBuilder
    private var progressCard: some View {
        if selectedDraft != nil {
            let row = work?.stage.first { $0.id == selectedDraft?.id }
            let done = row?.doneCount ?? 0
            let total = row?.taskCount ?? 0
            let ratio = total == 0 ? 0 : Double(done) / Double(total)

            VStack(spacing: 10) {
                HStack {
                    Text("Progress : \(Int(ratio * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Spacer()

                    Text("Task ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    + Text("\(done) / \(total)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)

                        Capsule()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * ratio)
                    }
                }
                .frame(height: 6)
            }
            .padding(14)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.top, 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Progress \(Int(ratio * 100)) percent, \(done) of \(total) tasks done")
        }
    }

    /// พื้นที่แตะขั้นต่ำตาม HIG
    private static let minTapTarget: CGFloat = 44

    private func displayCode(_ draft: WorkStageDraft) -> String {
        draft.code.isEmpty ? "—" : draft.code
    }

    private func displayName(_ draft: WorkStageDraft) -> String {
        if !draft.name.isEmpty { return draft.name }
        return draft.code.isEmpty ? "New stage" : draft.code
    }

    /// ช้ากี่วันนับจากวันจบตามแผน — นิยามเดียวกับที่การ์ดบนหน้ารายการใช้
    ///
    /// **stage ที่ปิดแล้วไม่นับว่า "ช้า" ต่อไปเรื่อย ๆ** — `WorkStageDraft` เก็บแค่วันตามแผน
    /// ไม่รู้ตัวเองว่าปิดหรือยัง ต้องย้อนไปหาแถวจริงจาก `work?.stage` (แหล่งเดียวกับที่
    /// การ์ด Progress ใช้) ถ้าข้ามขั้นนี้ไป stage ที่ปิดไปตั้งแต่สัปดาห์ก่อนจะยังโชว์
    /// "Nd late" และเลขนั้นจะโตขึ้นทุกวันแม้ไม่มีอะไรค้างอยู่แล้วจริง ๆ
    private func daysLate(_ draft: WorkStageDraft) -> Int? {
        let row = work?.stage.first { $0.id == draft.id }
        if row?.isClosed == true { return nil }

        let calendar = WorkFilter.calendar
        let end = calendar.startOfDay(for: draft.plannedEnd)
        let now = calendar.startOfDay(for: today)
        guard end < now else { return nil }
        return calendar.dateComponents([.day], from: end, to: now).day
    }

    @ViewBuilder
    private var tasks: some View {
        if let row = work?.stage.first(where: { $0.id == selectedDraft?.id }) {
            if row.task.isEmpty && !isAddingTask {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No tasks yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("A stage closes when all of its tasks are done.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
            } else {
                WorkTaskListView(
                    stage: row,
                    workID: workID,
                    store: store,
                    isAdding: $isAddingTask
                )
            }
        }
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

        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("More")
    }

    /// เพิ่ม stage อยู่บนแถบบนคู่กับ … ไม่ได้ซ่อนอยู่ในเมนู
    /// เป็นสิ่งที่ต้องทำบ่อยที่สุดบนหน้านี้ตอนงานเพิ่งตั้ง
    private var addStageMenu: some View {
        Menu {
            // วนจากรายการที่เซิร์ฟเวอร์ให้มา ไม่มีชื่อขั้นตอนเขียนตายในไฟล์นี้เลย
            // วันที่มีขั้นที่สิบ หน้านี้ไม่ต้องแก้สักบรรทัด
            ForEach(unusedTypes) { type in
                Button("\(type.code) · \(type.label)") { add(type) }
            }

            Button {
                addCustom()
            } label: {
                Label("Other…", systemImage: "plus")
            }
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Add a stage")
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
/// **ไม่มีสวิตช์ Started / Finished แล้ว** — stage ปิดเมื่อ task ครบ ไม่ใช่เมื่อกดปุ่ม
/// ดู `docs/superpowers/specs/2026-08-19-work-round-4-design.md`
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
}
