//
//  ProfileStore.swift
//  null-app
//

import Foundation
import Observation

/// เจ้าของ state ของโปรไฟล์เพียงผู้เดียว และเป็นจุดเดียวในแอปที่แตะไฟล์
@Observable
final class ProfileStore {
    private(set) var profile: Profile

    private let fileURL: URL
    private var writeTask: Task<Void, Error>?

    /// อ่านไฟล์แบบ synchronous โดยตั้งใจ — ไฟล์เล็กมาก การอ่านเร็วกว่าหนึ่งเฟรม
    /// และการทำแบบ async จะทำให้เห็นจอว่างแวบหนึ่งก่อนข้อมูลมา
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
    }

    /// ตั้งค่าใน memory ก่อน แล้วค่อยเขียนดิสก์
    /// ถ้าเขียนพลาด ค่าใน memory ยังอยู่ ผู้ใช้ไม่เสียสิ่งที่พิมพ์ไป
    func update(_ newProfile: Profile) async throws {
        profile = newProfile

        let url = fileURL
        let previous = writeTask
        let task = Task.detached(priority: .utility) {
            _ = try? await previous?.value
            try ProfileStore.write(newProfile, to: url)
        }
        writeTask = task
        try await task.value
    }

    static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "profile.json")
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
}
