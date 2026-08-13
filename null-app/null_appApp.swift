//
//  null_appApp.swift
//  null-app
//
//  Created by Purin Tae on 12/8/2569 BE.
//

import SwiftUI

@main
struct null_appApp: App {
    /// สร้างครั้งเดียวตอนแอปเริ่ม การอ่านไฟล์เกิดขึ้นใน initializer
    @State private var store = ProfileStore()

    /// ธีมที่ผู้ใช้เลือกใน Settings ต้องอ่านที่รากเพื่อครอบทั้งแอป
    @AppStorage("appearance") private var appearance: AppearanceSetting = .system

    var body: some Scene {
        WindowGroup {
            // Home เป็นรากเดียวของแอป ส่วน Profile ถูก push จากไอคอนบนแถบบนของ Home
            NavigationStack {
                HomeView()
            }
            .environment(store)
            .preferredColorScheme(appearance.colorScheme)
        }
    }
}

