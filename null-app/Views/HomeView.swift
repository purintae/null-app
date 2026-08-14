//
//  HomeView.swift
//  null-app
//

import SwiftUI

/// Home เป็น launcher — ไอคอนทั้งหมดมาจาก FeatureRegistry
///
/// ไฟล์นี้ต้องไม่มีชื่อฟีเจอร์ใด ๆ ปรากฏอยู่เลย ถ้าวันหนึ่งมี if ที่เช็กชื่อฟีเจอร์
/// การถอดฟีเจอร์นั้นจะพังที่นี่ ซึ่งเป็นสิ่งที่ทั้งสถาปัตยกรรมนี้ตั้งใจป้องกัน
struct HomeView: View {
    let userID: UUID

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 16)]

    var body: some View {
        Group {
            if FeatureRegistry.installed.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(FeatureRegistry.installed, id: \.id) { feature in
                            NavigationLink {
                                feature.makeRoot(userID: userID)
                            } label: {
                                FeatureTile(title: feature.title, systemImage: feature.systemImage)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .navigationTitle("Home")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    ProfileView()
                } label: {
                    Image(systemName: "person")
                }
                .accessibilityLabel("Profile")
            }
        }
    }

    /// ยังคงหน้าตาเดิมไว้สำหรับตอนที่ยังไม่มีฟีเจอร์ใดถูกติดตั้ง
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "square.dashed")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)

            Text("Nothing here yet")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }
}

/// ไอคอนหนึ่งช่องบน Home — เป็นของ core ไม่ใช่ของฟีเจอร์ใด
private struct FeatureTile: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .frame(width: 64, height: 64)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))

            Text(title)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(.primary)
        // ไม่งั้น VoiceOver อ่านคำบรรยาย SF Symbol ต่อด้วยชื่อ ("square dashed, Example")
        // แก้ที่ core ครั้งเดียวเพื่อให้ทุกฟีเจอร์ที่เสียบเข้ามาได้ผลนี้ไปเลย
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

#Preview {
    NavigationStack {
        HomeView(userID: UUID())
    }
    .environment(ProfileStore(cacheURL: URL.temporaryDirectory.appending(path: "preview.json")))
}
