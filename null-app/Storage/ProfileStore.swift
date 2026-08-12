//
//  ProfileStore.swift
//  null-app
//

import Foundation
import Observation
import SwiftUI

/// สิ่งที่ผู้ใช้ตั้งใจทำกับช่องรูปหนึ่งช่อง
/// แยก "ไม่แตะ" ออกจาก "เอาออก" ชัดเจน เพราะ nil อย่างเดียวบอกไม่ได้ว่าอันไหน
nonisolated enum ImageEdit: Equatable, Sendable {
    case unchanged
    case replace(Data)
    case remove
}

/// เจ้าของ state ของโปรไฟล์เพียงผู้เดียว และเป็นจุดเดียวในแอปที่แตะไฟล์
@Observable
final class ProfileStore {
    private(set) var profile: Profile
    private(set) var avatarImage: Image?
    private(set) var coverImage: Image?

    private let fileURL: URL
    private var writeTask: Task<Void, Error>?

    private var imagesDirectory: URL {
        ProfileStore.imagesDirectory(besides: fileURL)
    }

    /// อ่านไฟล์แบบ synchronous โดยตั้งใจ — ไฟล์เล็กมาก การอ่านเร็วกว่าหนึ่งเฟรม
    /// และการทำแบบ async จะทำให้เห็นจอว่างแวบหนึ่งก่อนข้อมูลมา
    /// รูปก็อ่านที่นี่ด้วยเหตุผลเดียวกัน — ย่อไว้ที่ 512/1600px แล้วจึง decode เร็วพอ
    /// และการโหลดทีหลังจะทำให้เห็น avatar กระพริบจากอักษรย่อเป็นรูป
    init(fileURL: URL = ProfileStore.defaultFileURL) {
        self.fileURL = fileURL

        var loaded = ProfileStore.read(from: fileURL)

        // เติมค่าที่เกิดครั้งเดียวแล้วอยู่ถาวรให้ทันที แล้วเขียนลงดิสก์เดี๋ยวนั้นเลย
        // ไม่รอผู้ใช้กด Save เพราะถ้ารอ การปิดแอปก่อนบันทึกจะทำให้สุ่มใหม่ทุกครั้งที่เปิด
        // username กับสีประจำตัวก็จะไม่นิ่ง ซึ่งขัดกับเหตุผลทั้งหมดที่มีค่าพวกนี้
        //
        // ตรวจทีละค่าแยกกัน เพราะไฟล์ที่บันทึกไว้ระหว่างทางอาจมี suffix แล้วแต่ยังไม่มี createdAt
        //
        // ถ้าเขียนพลาดที่นี่ ค่ายังอยู่ใน memory และจะถูกบันทึกตอน save ครั้งถัดไป
        // ไม่ throw ออกไปเพราะการเปิดแอปไม่ควรล้มเหลวด้วยเรื่องนี้
        var needsSeeding = false

        if loaded.usernameSuffix.isEmpty {
            loaded.usernameSuffix = Profile.makeUsernameSuffix()
            needsSeeding = true
        }

        if loaded.createdAt == nil {
            loaded.createdAt = Date()
            needsSeeding = true
        }

        if needsSeeding {
            try? ProfileStore.write(loaded, to: fileURL)
        }

        self.profile = loaded

        let directory = ProfileStore.imagesDirectory(besides: fileURL)
        self.avatarImage = ProfileStore.loadImage(named: loaded.avatarFileName, in: directory)
        self.coverImage = ProfileStore.loadImage(named: loaded.coverFileName, in: directory)
    }

    /// ตั้งค่าใน memory ก่อน แล้วค่อยเขียนดิสก์
    /// ถ้าเขียนพลาด ค่าใน memory ยังอยู่ ผู้ใช้ไม่เสียสิ่งที่พิมพ์ไป
    ///
    /// ลำดับสำคัญมาก: เขียนไฟล์รูปใหม่ → เขียน JSON → ค่อยลบรูปเก่า
    /// ถ้าพังกลางทางจะเหลือรูปกำพร้าที่ไม่มีใครอ้างถึง ซึ่งแค่กินที่
    /// ส่วนลำดับกลับกันจะได้ JSON ที่ชี้ไปยังไฟล์ที่ถูกลบไปแล้ว ซึ่งคือรูปหาย
    func update(
        _ newProfile: Profile,
        avatar: ImageEdit = .unchanged,
        cover: ImageEdit = .unchanged
    ) async throws {
        let directory = imagesDirectory
        let previous = profile

        let avatarName = try await ProfileStore.applyEdit(
            avatar,
            current: previous.avatarFileName,
            maxPixel: ProfileImage.avatarMaxPixel,
            in: directory
        )

        let coverName = try await ProfileStore.applyEdit(
            cover,
            current: previous.coverFileName,
            maxPixel: ProfileImage.coverMaxPixel,
            in: directory
        )

        var finalProfile = newProfile
        finalProfile.avatarFileName = avatarName
        finalProfile.coverFileName = coverName

        profile = finalProfile

        if avatar != .unchanged {
            avatarImage = ProfileStore.loadImage(named: avatarName, in: directory)
        }
        if cover != .unchanged {
            coverImage = ProfileStore.loadImage(named: coverName, in: directory)
        }

        let url = fileURL
        let pending = writeTask
        let task = Task.detached(priority: .utility) {
            _ = try? await pending?.value
            try ProfileStore.write(finalProfile, to: url)
        }
        writeTask = task
        try await task.value

        ProfileStore.deleteIfReplaced(previous.avatarFileName, by: avatarName, in: directory)
        ProfileStore.deleteIfReplaced(previous.coverFileName, by: coverName, in: directory)
    }

    static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "profile.json")
    }

    nonisolated static func imagesDirectory(besides fileURL: URL) -> URL {
        fileURL.deletingLastPathComponent().appending(path: "images")
    }

    /// ทุกความล้มเหลวของการอ่านแปลงเป็นค่าว่าง — ไม่มีไฟล์คือเรื่องปกติของการเปิดครั้งแรก
    /// ส่วนไฟล์เสียก็ไม่ควรทำให้แอปเปิดไม่ขึ้น
    nonisolated static func read(from url: URL) -> Profile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard
            let data = try? Data(contentsOf: url),
            let decoded = try? decoder.decode(Profile.self, from: data)
        else {
            return .empty
        }
        return decoded
    }

    /// throw ออกไปให้ผู้เรียกจัดการ เพราะผู้ใช้ต้องรู้ว่าบันทึกไม่สำเร็จ
    nonisolated static func write(_ profile: Profile, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // ISO8601 แทนตัวเลข timestamp เพื่อให้เปิดไฟล์อ่านเองแล้วเข้าใจได้
        // encoder กับ decoder ต้องใช้กลยุทธ์เดียวกันเสมอ ไม่งั้นอ่านกลับไม่ออก
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(profile)
        try data.write(to: url, options: .atomic)
    }

    /// คืนชื่อไฟล์ที่ควรอยู่ใน Profile หลังทำตามเจตนาของผู้ใช้
    /// การย่อรูปหนักพอที่จะไม่ควรทำบน main actor จึงโยนเข้า detached task
    nonisolated static func applyEdit(
        _ edit: ImageEdit,
        current: String?,
        maxPixel: Int,
        in directory: URL
    ) async throws -> String? {
        switch edit {
        case .unchanged:
            return current

        case .remove:
            return nil

        case .replace(let raw):
            return try await Task.detached(priority: .userInitiated) {
                let jpeg = try ProfileImage.prepare(raw, maxPixel: maxPixel)

                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )

                // ชื่อใหม่ทุกครั้งแทนการเขียนทับชื่อเดิม
                // ไฟล์เก่ายังอยู่จนกว่า JSON จะบันทึกสำเร็จ จึงย้อนกลับได้ถ้าพัง
                let name = "\(UUID().uuidString).jpg"
                try jpeg.write(to: directory.appending(path: name), options: .atomic)
                return name
            }.value
        }
    }

    static func loadImage(named name: String?, in directory: URL) -> Image? {
        guard
            let name,
            let data = try? Data(contentsOf: directory.appending(path: name)),
            let decoded = ProfileImage.decode(data)
        else {
            return nil
        }
        return Image(decorative: decoded, scale: 1)
    }

    nonisolated static func deleteIfReplaced(_ old: String?, by new: String?, in directory: URL) {
        guard let old, old != new else { return }
        try? FileManager.default.removeItem(at: directory.appending(path: old))
    }
}
