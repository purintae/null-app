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

    /// กวาดของของฟีเจอร์ที่ถูกถอดออกไปแล้ว ตัดสินจาก registry ปัจจุบันเสมอ
    ///
    /// ปิดใน DEBUG เพราะการคอมเมนต์ registry ออกชั่วคราวเพื่อดีบัก
    /// ไม่ควรลบข้อมูลในเครื่องทิ้ง — ผลข้างเคียงคือการยืนยันเรื่องนี้ต้อง build แบบ Release
    init() {
        #if !DEBUG
        FeatureStorage.sweepOrphans(
            installed: Set(FeatureRegistry.installed.map(\.id)),
            root: FeatureStorage.root,
            defaults: .standard
        )
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch session.state {
                case .loading:
                    ProgressView()

                case .signedOut:
                    signUpScreen

                case .signedIn(let userID):
                    if profileStore.needsProfile {
                        // สมัครค้างกลางทาง — มีบัญชีแล้วแต่ยังไม่มีโปรไฟล์
                        // ให้กรอกชื่อเพื่อสร้างแถวให้ครบ ไม่ใช่สร้างบัญชีใหม่ซ้อน
                        signUpScreen
                    } else {
                        // Home เป็นรากเดียวของแอป ส่วน Profile ถูก push จากไอคอนบนแถบบนของ Home
                        NavigationStack {
                            HomeView(userID: userID)
                        }
                        .environment(profileStore)
                        .task { await profileStore.refresh() }
                    }
                }
            }
            .preferredColorScheme(appearance.colorScheme)
        }
    }

    /// ใช้ร่วมกันทั้งการสมัครใหม่และการกู้คืนบัญชีที่ไม่มีโปรไฟล์
    /// ทั้งสองเส้นทางจบด้วยการมีแถวใน profiles จึงต้อง refresh เหมือนกัน
    private var signUpScreen: some View {
        SignUpView(session: session) {
            await profileStore.refresh()
        }
    }
}
