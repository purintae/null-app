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

    var body: some Scene {
        WindowGroup {
            // NavigationStack อยู่ข้างในแต่ละแท็บ ไม่ใช่ครอบ TabView
            // เพื่อให้แต่ละแท็บมี navigation history และ toolbar ของตัวเอง
            TabView {
                Tab("Home", systemImage: "house") {
                    NavigationStack {
                        HomeView()
                    }
                }

                Tab("Profile", systemImage: "person.crop.circle") {
                    NavigationStack {
                        ProfileView()
                    }
                }
            }
            // iPhone ได้ tab bar ล่างจอ ส่วน iPad/Mac/visionOS กลายเป็น sidebar
            .tabViewStyle(.sidebarAdaptable)
            .environment(store)
        }
    }
}
