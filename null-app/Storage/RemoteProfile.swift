//
//  RemoteProfile.swift
//  null-app
//

import Foundation

/// รูปร่างของแถวในตาราง profiles
/// เขียน CodingKeys เองทั้งหมดแทนการพึ่ง key decoding strategy ของ decoder
/// เพราะ decoder ที่ใช้เป็นของ library ซึ่งเราไม่ได้ตั้งค่าเอง
nonisolated struct RemoteProfile: Codable, Sendable {
    let userID: UUID
    var displayName: String
    var bio: String
    let stableSuffix: String
    var avatarPath: String?
    var coverPath: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case bio
        case stableSuffix = "stable_suffix"
        case avatarPath = "avatar_path"
        case coverPath = "cover_path"
        case createdAt = "created_at"
    }
}
