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
            NavigationStack {
                HomeView()
            }
            .environment(store)
        }
    }
}
