//
//  AppearanceSetting.swift
//  null-app
//

import SwiftUI

/// ธีมที่ผู้ใช้เลือกเอง เก็บใน UserDefaults ผ่าน @AppStorage
/// ที่นี่คือที่ถูกต้องของ *การตั้งค่า* — ต่างจากโปรไฟล์ซึ่งเป็น *เนื้อหาของผู้ใช้*
/// จึงอยู่ในไฟล์ JSON ที่ ProfileStore ดูแล
enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// nil แปลว่าปล่อยตามระบบ ซึ่งเป็นสิ่งที่ .preferredColorScheme ต้องการพอดี
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
