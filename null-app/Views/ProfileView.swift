//
//  ProfileView.swift
//  null-app
//

import SwiftUI

struct ProfileView: View {
    @Environment(ProfileStore.self) private var store

    private var name: String {
        let trimmed = store.profile.trimmedDisplayName
        return trimmed.isEmpty ? "No name yet" : trimmed
    }

    var body: some View {
        VStack(spacing: 16) {
            InitialsAvatar(initials: store.profile.initials)

            Text(name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(store.profile.trimmedDisplayName.isEmpty ? .secondary : .primary)

            if !store.profile.bio.isEmpty {
                Text(store.profile.bio)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .navigationTitle("Profile")
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(ProfileStore(fileURL: URL.temporaryDirectory.appending(path: "preview.json")))
}
