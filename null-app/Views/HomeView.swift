//
//  HomeView.swift
//  null-app
//

import SwiftUI

/// หน้าแรกยังว่างโดยตั้งใจ — ทางเข้าโปรไฟล์อยู่บนแถบบน ไม่ใช่กลางหน้า
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
        }
        .padding()
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
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(ProfileStore(cacheURL: URL.temporaryDirectory.appending(path: "preview.json")))
}
