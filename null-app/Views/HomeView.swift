//
//  HomeView.swift
//  null-app
//

import SwiftUI

/// หน้าแรกยังว่างโดยตั้งใจ — มีแค่ทางเข้าไปหน้าโปรไฟล์
struct HomeView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "square.dashed")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)

            Text("Nothing here yet")
                .foregroundStyle(.secondary)

            Spacer()

            NavigationLink("View Profile") {
                ProfileView()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .navigationTitle("Home")
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(ProfileStore(fileURL: URL.temporaryDirectory.appending(path: "preview.json")))
}
