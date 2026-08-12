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
        .navigationTitle("Profile")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        // พื้นแถบบนโปร่งเพื่อให้เห็น cover ทะลุขึ้นมา และบังคับให้ตัวหนังสือกับไอคอนเป็นสีขาว
        // เพราะมันวางอยู่บน cover ไม่ใช่บนพื้นหลังปกติ
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
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
