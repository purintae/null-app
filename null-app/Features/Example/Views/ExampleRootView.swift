//
//  ExampleRootView.swift
//  null-app
//

import SwiftUI

/// แสดง userID ที่ core ส่งเข้ามา เพื่อพิสูจน์ว่าเส้นทางจาก SessionStore ถึงฟีเจอร์ต่อกันจริง
struct ExampleRootView: View {
    let userID: UUID

    var body: some View {
        Form {
            Section("Signed in as") {
                Text(userID.uuidString.lowercased())
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Example")
    }
}

#Preview {
    NavigationStack {
        ExampleRootView(userID: UUID())
    }
}
