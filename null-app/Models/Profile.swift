//
//  Profile.swift
//  null-app
//

import Foundation

/// โปรไฟล์ของผู้ใช้ มีอยู่ชุดเดียวในแอป
nonisolated struct Profile: Codable, Equatable, Sendable {
    var displayName: String
    var bio: String

    static let empty = Profile(displayName: "", bio: "")

    init(displayName: String, bio: String) {
        self.displayName = displayName
        self.bio = bio
    }

    /// Decoder เขียนเองโดยตั้งใจ ห้ามลดกลับไปใช้ synthesized เฉยๆ
    /// เหตุผล: ทั้งสอง field เป็น non-optional ถ้าปล่อยให้ compiler สร้าง decoder ให้เอง
    /// การเพิ่ม field ใหม่ (เช่น avatar ตามแผนในอนาคต) จะทำให้ profile.json เก่าที่ไม่มี
    /// key นั้น decode ไม่ผ่านทันที ProfileStore.read() จะยุบทุกความล้มเหลวเป็น .empty
    /// ผู้ใช้จะเห็นโปรไฟล์ว่างเปล่า แล้วการ save ครั้งถัดไปจะเขียนทับข้อมูลจริงอย่างเงียบๆ
    /// การ decodeIfPresent พร้อม default ทำให้ key ที่ขาดหายไปไม่ทำให้ทั้ง record หายไปด้วย
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? ""
    }

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
