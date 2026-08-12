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
        self.profile = ProfileStore.read(from: fileURL)
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
        guard
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(Profile.self, from: data)
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
        let data = try JSONEncoder().encode(profile)
        try data.write(to: url, options: .atomic)
    }
}
