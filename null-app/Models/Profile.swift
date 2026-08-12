//
//  Profile.swift
//  null-app
//

import Foundation

/// โปรไฟล์ของผู้ใช้ มีอยู่ชุดเดียวในแอป
nonisolated struct Profile: Codable, Equatable, Sendable {
    var displayName: String
    var bio: String

    /// ส่วนท้ายของ username ที่สุ่มครั้งเดียวแล้วไม่เปลี่ยนอีกเลย
    /// เปลี่ยนชื่อกี่ครั้ง ส่วนนี้ก็คงเดิม — เป็นตัวที่ทำให้ username ไม่ซ้ำกับคนอื่น
    /// ค่าว่างหมายถึง "ยังไม่เคยสุ่ม" ซึ่ง ProfileStore จะจัดการให้ตอนโหลด
    var usernameSuffix: String

    /// วันที่โปรไฟล์นี้เกิดขึ้น ตั้งครั้งเดียวพร้อม usernameSuffix แล้วไม่เปลี่ยนอีก
    /// เป็น optional เพราะไฟล์ที่บันทึกไว้ก่อนฟีเจอร์นี้ไม่มีค่านี้จริง ๆ
    /// ProfileStore จะเติมให้ตอนโหลด แต่ View ต้องไม่ถือว่ามีเสมอ
    var createdAt: Date?

    /// เก็บแค่ *ชื่อไฟล์* ไม่ใช่ path เต็ม
    /// path ของ container เปลี่ยนได้ทุกครั้งที่ติดตั้งแอปใหม่ ถ้าเก็บ path เต็มไว้
    /// รูปจะหาไม่เจอทันทีหลังอัปเดต — ProfileStore เป็นคนประกอบ path ให้เอง
    var avatarFileName: String?
    var coverFileName: String?

    static let empty = Profile(displayName: "", bio: "", usernameSuffix: "")

    init(
        displayName: String,
        bio: String,
        usernameSuffix: String = "",
        createdAt: Date? = nil,
        avatarFileName: String? = nil,
        coverFileName: String? = nil
    ) {
        self.displayName = displayName
        self.bio = bio
        self.usernameSuffix = usernameSuffix
        self.createdAt = createdAt
        self.avatarFileName = avatarFileName
        self.coverFileName = coverFileName
    }

    /// Decoder เขียนเองโดยตั้งใจ ห้ามลดกลับไปใช้ synthesized เฉยๆ
    /// เหตุผล: ทุก field เป็น non-optional ถ้าปล่อยให้ compiler สร้าง decoder ให้เอง
    /// การเพิ่ม field ใหม่จะทำให้ profile.json เก่าที่ไม่มี key นั้น decode ไม่ผ่านทันที
    /// ProfileStore.read() จะยุบทุกความล้มเหลวเป็น .empty ผู้ใช้จะเห็นโปรไฟล์ว่างเปล่า
    /// แล้วการ save ครั้งถัดไปจะเขียนทับข้อมูลจริงอย่างเงียบๆ
    /// การ decodeIfPresent พร้อม default ทำให้ key ที่ขาดหายไปไม่ทำให้ทั้ง record หายไปด้วย
    /// — `usernameSuffix` คือกรณีนั้นที่เกิดขึ้นจริง ไฟล์ที่บันทึกไว้ก่อนหน้านี้ไม่มี key นี้
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? ""
        usernameSuffix = try container.decodeIfPresent(String.self, forKey: .usernameSuffix) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        avatarFileName = try container.decodeIfPresent(String.self, forKey: .avatarFileName)
        coverFileName = try container.decodeIfPresent(String.self, forKey: .coverFileName)
    }

    static let displayNameLimit = 50
    static let bioLimit = 160

    // MARK: - Username

    static let usernameSuffixLength = 6

    /// ตัด I O 0 1 ออกโดยตั้งใจ — สี่ตัวนี้แยกกันไม่ออกเวลาอ่านออกเสียงหรือพิมพ์ตาม
    /// เหลือ 32 ตัว ยกกำลัง 6 = 1,073,741,824 แบบ ชนกันแทบเป็นศูนย์โดยไม่ต้องมีทะเบียนกลาง
    static let usernameSuffixAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func makeUsernameSuffix() -> String {
        let alphabet = usernameSuffixAlphabet
        return String((0 ..< usernameSuffixLength).map { _ in
            alphabet[Int.random(in: 0 ..< alphabet.count)]
        })
    }

    /// ส่วนหน้าของ username ที่ได้จากชื่อ — เปลี่ยนตามชื่อเสมอ
    /// ชื่อถูกจำกัดให้เป็น ASCII อยู่แล้ว การกรองนี้จึงแค่ตัดช่องว่างกับเครื่องหมายออก
    /// "user" เป็นค่าสำรองสำหรับชื่อที่ไม่เหลืออักษรใดเลย เช่นชื่อที่มีแต่เครื่องหมาย
    var usernameSlug: String {
        let slug = trimmedDisplayName
            .lowercased()
            .filter { $0.isASCII && ($0.isLetter || $0.isNumber) }

        return slug.isEmpty ? "user" : slug
    }

    /// handle ที่แสดงให้ผู้ใช้เห็น เช่น "@purintae-K7M4XQ"
    var username: String {
        usernameSuffix.isEmpty ? "@\(usernameSlug)" : "@\(usernameSlug)-\(usernameSuffix)"
    }

    // MARK: - Identity colour

    /// สีประจำโปรไฟล์ที่คำนวณจาก suffix ด้วย djb2 hash
    /// suffix ถาวรอยู่แล้ว สีจึงถาวรตามไปด้วยโดยไม่ต้องเก็บข้อมูลเพิ่ม
    /// คืนค่าเป็น hue 0...1 ให้ View เอาไปประกอบเป็นสีเอง — model ไม่ import SwiftUI
    var bannerHue: Double {
        guard !usernameSuffix.isEmpty else { return 0.58 }

        var hash: UInt64 = 5381
        for byte in usernameSuffix.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return Double(hash % 360) / 360
    }

    // MARK: - Joined date

    /// เช่น "August 2026" — คืน nil เมื่อไม่รู้จริง ๆ เพื่อให้ View ซ่อนบรรทัดนั้นไปเลย
    /// ดีกว่าเดาวันแล้วแสดงข้อมูลที่ไม่จริง
    var joinedText: String? {
        guard let createdAt else { return nil }
        return createdAt.formatted(.dateTime.month(.wide).year())
    }

    // MARK: - Display

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

    // MARK: - Validation

    /// อนุญาต - และ ' เพราะ "Mary-Jane" กับ "O'Brien" เป็นชื่อจริง
    /// ทั้งคู่ถูกตัดทิ้งตอนทำ slug อยู่แล้ว
    static let allowedNameSymbols: Set<Character> = [" ", "-", "'"]

    static func isAllowedNameCharacter(_ character: Character) -> Bool {
        if character.isASCII, character.isLetter || character.isNumber { return true }
        return allowedNameSymbols.contains(character)
    }

    /// ชื่อถูกจำกัดเป็นอักษรอังกฤษเพื่อให้ username เป็น handle ที่พิมพ์และแชร์ได้ทุกที่
    /// ตรวจที่นี่แทนการลบตัวอักษรทิ้งตอนพิมพ์ เพราะการที่พิมพ์แล้วจอไม่ขึ้นอะไรเลย
    /// ทำให้ผู้ใช้นึกว่าคีย์บอร์ดพัง แทนที่จะรู้ว่าภาษานี้ใช้ไม่ได้
    var hasUnsupportedNameCharacters: Bool {
        !displayName.allSatisfy(Self.isAllowedNameCharacter)
    }

    var isValid: Bool {
        let name = trimmedDisplayName
        return !name.isEmpty
            && name.count <= Self.displayNameLimit
            && bio.count <= Self.bioLimit
            && !hasUnsupportedNameCharacters
    }
}
