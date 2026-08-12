//
//  Profile.swift
//  null-app
//

import Foundation

/// โปรไฟล์ของผู้ใช้ มีอยู่ชุดเดียวในแอป
struct Profile: Codable, Equatable, Sendable {
    var displayName: String
    var bio: String

    static let empty = Profile(displayName: "", bio: "")

    static let displayNameLimit = 50
    static let bioLimit = 160

    /// ชื่อที่ตัดช่องว่างหัวท้ายแล้ว ใช้ทั้งตอนแสดงผลและตอนตรวจความถูกต้อง
    var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// อักษรย่อสำหรับวงกลมแทนรูปโปรไฟล์
    /// เอาอักษรตัวแรกของสองคำแรก ถ้าไม่มีคำใดเลยคืน "?"
    var initials: String {
        let letters = trimmedDisplayName
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap(\.first)

        guard !letters.isEmpty else { return "?" }
        return String(letters).uppercased()
    }

    var isValid: Bool {
        let name = trimmedDisplayName
        return !name.isEmpty
            && name.count <= Self.displayNameLimit
            && bio.count <= Self.bioLimit
    }
}
