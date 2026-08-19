//
//  WorkRootView.swift
//  null-app
//

import SwiftUI

/// หน้าแรกของฟีเจอร์ Work
///
/// ตัวนับสี่ใบและการกดกรองใช้ WorkFilter ตัวเดียวกัน ตัวเลขบนหัวจึงตรงกับรายการข้างล่างเสมอ
/// โดยไม่ต้องมีใครคอยดูแลให้ตรง
struct WorkRootView: View {
    let userID: UUID

    @State private var store: WorkStore
    @State private var activeFilter: WorkFilter?
    @State private var activeType: String?

    /// วันนี้ถูกตรึงตอนหน้าจอปรากฏ ไม่ใช่คำนวณใหม่ทุกครั้งที่วาด
    /// ไม่งั้นการนับกับตัวเลขบนการ์ดอาจคนละวินาทีกันข้ามเที่ยงคืน
    @State private var today = Date()

    @State private var isCreating = false

    /// Work ที่กำลังจะเปิดหน้าแก้ — ปลายทางถูกสร้างตอนตัวนี้ไม่ใช่ nil เท่านั้น
    /// จึงยัง lazy เหมือน `NavigationLink(value:)` โดยไม่ต้องพึ่งการลงทะเบียนตามชนิด
    @State private var editingWork: WorkRoute?

    init(userID: UUID) {
        self.userID = userID
        _store = State(initialValue: WorkStore(userID: userID))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summary
                typeFilter
                list
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
        .navigationDestination(item: $editingWork) { route in
            WorkStageEditorView(workID: route.id, store: store)
        }
        .navigationTitle("Work")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreating = true
                } label: {
                    Image(systemName: "plus")
                }
                // ยังไม่มี Work Type ให้เลือกก็สร้างไม่ได้ เพราะเป็นช่องบังคับ
                // ปิดปุ่มไว้ตรงไปตรงมากว่าเปิดฟอร์มที่กด Save ไม่ได้
                .disabled(store.types.isEmpty)
                .accessibilityLabel("Add work")
            }
        }
        .refreshable { await store.load() }
        .task {
            today = Date()
            await store.load()
        }
        .sheet(isPresented: $isCreating) {
            NavigationStack {
                WorkFormView(workID: nil, store: store)
            }
        }
    }

    /// งานที่ผ่านตัวกรองประเภทแล้ว — ทั้งตัวนับสี่ใบและรายการข้างล่างต้องอ่านจากตัวนี้ตัวเดียว
    /// ไม่ใช่กรองประเภทแยกกันคนละที่ ไม่งั้นวันหนึ่งจะมีที่ใดที่หนึ่งลืมเช็ค activeType
    /// แล้วตัวนับกับรายการจะไม่ตรงกันตอนเลือก chip ประเภทพร้อมกับใบสรุป
    /// (ตัวนับต้องนับเฉพาะในประเภทที่กำลังกรองอยู่ ไม่ใช่นับทั้งหมดแล้วเอาไปโชว์ข้างใบที่ถูกจำกัดประเภท)
    private var typeFilteredWorks: [WorkRow] {
        guard let activeType else { return store.works }
        return store.works.filter { $0.typeCode == activeType }
    }

    /// งานที่ผ่านทั้งตัวกรองประเภทและตัวกรองสถานะ — ต่อจาก typeFilteredWorks เสมอ
    private var visibleWorks: [WorkRow] {
        typeFilteredWorks.filter { work in
            guard let activeFilter else { return true }
            return activeFilter.matches(work.stage, today: today, calendar: WorkFilter.calendar)
        }
    }

    private func count(_ filter: WorkFilter) -> Int {
        typeFilteredWorks.filter { filter.matches($0.stage, today: today, calendar: WorkFilter.calendar) }.count
    }

    private var summary: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(WorkFilter.allCases) { filter in
                Button {
                    activeFilter = activeFilter == filter ? nil : filter
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(count(filter), format: .number)
                            .font(.title2)
                            .fontWeight(.medium)

                        Text(filter.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        activeFilter == filter ? AnyShapeStyle(Color.accentColor.opacity(0.15))
                                               : AnyShapeStyle(.quaternary.opacity(0.4)),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(activeFilter == filter ? [.isSelected] : [])
            }
        }
    }

    /// chip เลื่อนแนวนอน ไม่ใช่ segmented picker — ประเภทงานเพิ่มได้จากหลังบ้าน
    /// และไม่มีชื่อประเภทใดถูกเขียนตายไว้ในไฟล์นี้
    private var typeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "All", isOn: activeType == nil) { activeType = nil }

                ForEach(store.types) { type in
                    chip(label: type.label, isOn: activeType == type.code) {
                        activeType = activeType == type.code ? nil : type.code
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    /// พื้นที่แตะขั้นต่ำตาม HIG (44pt) — capsule ที่เห็นยังเท่าเดิม พื้นที่แตะที่มองไม่เห็น
    /// ขยายออกรอบ ๆ มันแทน ไม่ใช่ดันด้วย padding จนตัว capsule เองอ้วนขึ้น
    private static let minTapTarget: CGFloat = 44

    private func chip(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    isOn ? AnyShapeStyle(Color.accentColor.opacity(0.15))
                         : AnyShapeStyle(.quaternary.opacity(0.4)),
                    in: Capsule()
                )
                .frame(minHeight: Self.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    @ViewBuilder
    private var list: some View {
        if !store.hasLoaded {
            ProgressView().padding(.top, 40)
        } else if store.loadFailed {
            ContentUnavailableView(
                "Couldn't load your work",
                systemImage: "exclamationmark.triangle",
                description: Text("Pull down to try again.")
            )
        } else if visibleWorks.isEmpty {
            ContentUnavailableView(
                store.works.isEmpty ? "No work yet" : "Nothing matches",
                systemImage: "briefcase",
                description: Text(
                    store.works.isEmpty
                        ? "Your work will show up here."
                        : "Tap the selected filter again to clear it."
                )
            )
            .padding(.top, 24)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(visibleWorks) { work in
                    // ปุ่มที่ตั้ง state แทน `NavigationLink(value:)` — ปลายทางยังถูกสร้าง
                    // ตอนกดจริงเท่านั้น ไม่ใช่ตอนวาดทุกใบแบบ `NavigationLink(destination:)`
                    Button {
                        editingWork = WorkRoute(id: work.id)
                    } label: {
                        WorkCard(work: work, today: today)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkRootView(userID: UUID())
    }
}
