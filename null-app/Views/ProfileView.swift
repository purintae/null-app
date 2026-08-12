//
//  ProfileView.swift
//  null-app
//

import SwiftUI

struct ProfileView: View {
    @Environment(ProfileStore.self) private var store

    /// สิ่งที่ต้องจำไว้ทั้งชุดเมื่อบันทึกพลาด ไม่ใช่แค่ Profile
    /// ถ้าจำแต่ข้อความ การกด Try Again จะบันทึกสำเร็จโดยที่รูปที่ผู้ใช้เพิ่งเลือกหายไปเงียบ ๆ
    private struct PendingSave {
        let profile: Profile
        let avatar: ImageEdit
        let cover: ImageEdit
    }

    @State private var isEditing = false
    @State private var isShowingQRCode = false
    @State private var saveError: String?
    @State private var pendingSave: PendingSave?

    /// จริงเมื่อ cover ยังอยู่ใต้แถบบน ซึ่งเป็นตอนที่ตัวหนังสือขาวอ่านออก
    /// พอเลื่อนจน cover พ้นไป ใต้แถบบนกลายเป็นพื้นปกติ ต้องคืนแถบให้เป็นสีตามระบบ
    /// ไม่งั้นจะได้ตัวหนังสือขาวบนพื้นขาว
    @State private var coverIsBehindToolbar = true

    /// cover สูงเท่านี้ ส่วนแถบบนกับ status bar กินพื้นที่บนสุดราว 100
    /// เลื่อนเกินผลต่างนี้เมื่อไร ขอบล่างของ cover ก็พ้นแถบบน
    private static let coverClearsToolbarAt = ProfileHeader.bannerHeight - 100

    private var name: String {
        let trimmed = store.profile.trimmedDisplayName
        return trimmed.isEmpty ? "No name yet" : trimmed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ProfileHeader(
                    profile: store.profile,
                    avatarImage: store.avatarImage,
                    coverImage: store.coverImage
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(store.profile.trimmedDisplayName.isEmpty ? .secondary : .primary)

                    Text(store.profile.username)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    if !store.profile.bio.isEmpty {
                        Text(store.profile.bio)
                            .font(.body)
                            .padding(.top, 6)
                    }

                    if let joined = store.profile.joinedText {
                        Label("Joined \(joined)", systemImage: "calendar")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 6)
                    }

                    ProfileActionButtons(
                        onShowQRCode: { isShowingQRCode = true },
                        onEdit: { isEditing = true }
                    )
                    .padding(.top, 14)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        // ScrollView เป็นตัวที่กัน safe area ไว้ ไม่ใช่ตัว cover
        // ต้องปล่อยที่นี่ cover ถึงจะไหลขึ้นไปชนขอบบนสุดของจอได้จริง
        .ignoresSafeArea(edges: .top)
        // iOS 26 วาด scroll edge effect ให้เองที่ขอบบน เป็นแถบไล่สีจาง ๆ
        // เพื่อให้เนื้อหาที่ลอดใต้แถบบนยังอ่านออก
        // .toolbarBackground(.hidden) ลบแค่พื้นแถบ ไม่ได้ลบ effect ตัวนี้
        // ที่นี่ไม่ต้องการ เพราะ cover เป็นภาพเต็มที่ตั้งใจให้เรียบ และเรามี scrim ของตัวเองอยู่แล้ว
        .scrollEdgeEffectHidden(true, for: .top)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y < Self.coverClearsToolbarAt
        } action: { _, isBehind in
            coverIsBehindToolbar = isBehind
        }
        .navigationTitle("Profile")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        // สลับตามตำแหน่งเลื่อน: อยู่บน cover ก็ทำพื้นแถบให้ใสและบังคับตัวหนังสือเป็นสีขาว
        // พอ cover เลื่อนพ้นไปก็คืนทั้งสองอย่างให้ระบบจัดการ ไม่งั้นจะเหลือขาวบนขาว
        .toolbarBackground(coverIsBehindToolbar ? .hidden : .automatic, for: .navigationBar)
        .toolbarColorScheme(coverIsBehindToolbar ? .dark : nil, for: .navigationBar)
        #endif
        .animation(.easeInOut(duration: 0.2), value: coverIsBehindToolbar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $isEditing) {
            ProfileEditView(
                profile: store.profile,
                avatarImage: store.avatarImage,
                coverImage: store.coverImage
            ) { updated, avatar, cover in
                Task { await save(PendingSave(profile: updated, avatar: avatar, cover: cover)) }
            }
        }
        .sheet(isPresented: $isShowingQRCode) {
            UsernameQRSheet(username: store.profile.username)
        }
        .alert(
            "Couldn't save",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            ),
            presenting: saveError
        ) { _ in
            if let pendingSave {
                Button("Try Again") {
                    Task { await save(pendingSave) }
                }
            }
            Button("OK", role: .cancel) { saveError = nil }
        } message: { message in
            Text(message)
        }
    }

    /// ค่าใน store ถูกตั้งไปแล้วแม้เขียนดิสก์พลาด ผู้ใช้จึงยังเห็นสิ่งที่เพิ่งพิมพ์
    /// ถ้าเขียนพลาด เก็บทั้งชุดไว้ใน pendingSave เพื่อให้กด Try Again ได้โดยไม่ต้องเปิดฟอร์มใหม่
    private func save(_ change: PendingSave) async {
        do {
            try await store.update(change.profile, avatar: change.avatar, cover: change.cover)
            pendingSave = nil
        } catch {
            pendingSave = change
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(ProfileStore(fileURL: URL.temporaryDirectory.appending(path: "preview.json")))
}
