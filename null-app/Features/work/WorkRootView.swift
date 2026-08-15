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

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

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
        .refreshable { await store.load() }
        .task {
            today = Date()
            await store.load()
        }
    }

    /// งานที่ผ่านตัวกรองประเภทแล้ว — ทั้งตัวนับสี่ใบและรายการข้างล่างต้องอ่านจากตัวนี้ตัวเดียว
    /// ไม่ใช่กรองประเภทแยกกันคนละที่ ไม่งั้นวันหนึ่งจะมีที่ใดที่หนึ่งลืมเช็ค activeType
    /// แล้วตัวนับกับรายการจะไม่ตรงกันตอนเลือก chip ประเภทพร้อมกับใบสรุป
    /// (ตัวนับต้องนับเฉพาะในประเภทที่กำลังกรองอยู่ ไม่ใช่นับทั้งหมดแล้วเอาไปโชว์ข้างใบที่ถูกจำกัดประเภท)
    private var typeFilteredItems: [WorkItemRow] {
        guard let activeType else { return store.items }
        return store.items.filter { $0.typeCode == activeType }
    }

    /// งานที่ผ่านทั้งตัวกรองประเภทและตัวกรองสถานะ — ต่อจาก typeFilteredItems เสมอ
    private var visibleItems: [WorkItemRow] {
        typeFilteredItems.filter { item in
            guard let activeFilter else { return true }
            return activeFilter.matches(item.stage, today: today, calendar: calendar)
        }
    }

    private func count(_ filter: WorkFilter) -> Int {
        typeFilteredItems.filter { filter.matches($0.stage, today: today, calendar: calendar) }.count
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
        } else if visibleItems.isEmpty {
            ContentUnavailableView(
                store.items.isEmpty ? "No work yet" : "Nothing matches",
                systemImage: "briefcase",
                description: Text(
                    store.items.isEmpty
                        ? "Your work will show up here."
                        : "Tap the selected filter again to clear it."
                )
            )
            .padding(.top, 24)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(visibleItems) { item in
                    WorkCard(item: item, today: today)
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
