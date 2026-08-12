//
//  HomeView.swift
//  null-app
//

import SwiftUI

/// หน้าแรกยังว่างโดยตั้งใจ — โปรไฟล์เข้าถึงได้จากแท็บแล้ว ไม่ต้องมีปุ่มที่นี่
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
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(ProfileStore(fileURL: URL.temporaryDirectory.appending(path: "preview.json")))
}
