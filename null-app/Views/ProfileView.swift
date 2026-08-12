//
//  ProfileView.swift
//  null-app
//

import SwiftUI

struct ProfileView: View {
    @Environment(ProfileStore.self) private var store

    @State private var isEditing = false
    @State private var saveError: String?
    @State private var pendingSave: Profile?

    private var name: String {
        let trimmed = store.profile.trimmedDisplayName
        return trimmed.isEmpty ? "No name yet" : trimmed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ProfileHeader(profile: store.profile) { isEditing = true }

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
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationTitle("Profile")
        #if !os(macOS)
        // banner กินพื้นที่บนสุดอยู่แล้ว หัวข้อใหญ่จะไปแย่งที่และพูดซ้ำ
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $isEditing) {
            ProfileEditView(profile: store.profile) { updated in
                Task { await save(updated) }
            }
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
    /// ถ้าเขียนพลาด เก็บค่าไว้ใน pendingSave เพื่อให้กด Try Again ได้โดยไม่ต้องเปิดฟอร์มใหม่
    private func save(_ updated: Profile) async {
        do {
            try await store.update(updated)
            pendingSave = nil
        } catch {
            pendingSave = updated
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
