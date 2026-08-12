//
//  SettingsView.swift
//  null-app
//

import SwiftUI

/// ตั้งค่าระดับแอป แยกเป็น section ตั้งแต่แรกเพื่อให้เพิ่มกลุ่ม Account
/// (เปลี่ยนรหัสผ่าน ออกจากระบบ) เข้ามาทีหลังได้โดยไม่ต้องรื้อโครง
struct SettingsView: View {
    @AppStorage("appearance") private var appearance: AppearanceSetting = .system

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppearanceSetting.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.appVersion)
                LabeledContent("Build", value: Bundle.main.appBuild)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

extension Bundle {
    /// อ่านจาก bundle แทนการ hard-code เลขไว้ในโค้ด
    /// โปรเจกต์ตั้ง GENERATE_INFOPLIST_FILE = YES ค่าพวกนี้จึงมาจาก build setting
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var appBuild: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
