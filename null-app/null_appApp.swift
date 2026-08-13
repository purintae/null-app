//
//  null_appApp.swift
//  null-app
//
//  Created by Purin Tae on 12/8/2569 BE.
//

import SwiftUI

@main
struct null_appApp: App {
    @State private var session = SessionStore()
    @State private var profileStore = ProfileStore()

    /// ธีมที่ผู้ใช้เลือกใน Settings ต้องอ่านที่รากเพื่อครอบทั้งแอป
    @AppStorage("appearance") private var appearance: AppearanceSetting = .system

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.state {
                case .loading:
                    ProgressView()

                case .signedOut:
                    SignUpView(session: session)

                case .signedIn:
                    // Home เป็นรากเดียวของแอป ส่วน Profile ถูก push จากไอคอนบนแถบบนของ Home
                    NavigationStack {
                        HomeView()
                    }
                    .environment(profileStore)
                    .task { await profileStore.refresh() }
                }
            }
            .preferredColorScheme(appearance.colorScheme)
        }
    }
}
