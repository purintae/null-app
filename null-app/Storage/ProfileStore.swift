//
//  ProfileStore.swift
//  null-app
//

import Foundation
import Observation
import Supabase
import SwiftUI

/// สิ่งที่ผู้ใช้ตั้งใจทำกับช่องรูปหนึ่งช่อง
/// แยก "ไม่แตะ" ออกจาก "เอาออก" ชัดเจน เพราะ nil อย่างเดียวบอกไม่ได้ว่าอันไหน
nonisolated enum ImageEdit: Equatable, Sendable {
    case unchanged
    case replace(Data)
    case remove
}

/// เจ้าของ state ของโปรไฟล์เพียงผู้เดียว
/// หน้าตาสาธารณะเหมือนตอนเก็บไฟล์ในเครื่องทุกประการ View จึงไม่ต้องแก้อะไรเลย
/// สิ่งที่เปลี่ยนคือหลังบ้าน จากไฟล์ JSON เป็น Supabase
@Observable
final class ProfileStore {
    private(set) var profile: Profile
    private(set) var avatarImage: Image?
    private(set) var coverImage: Image?

    /// จริงเมื่อมีบัญชีแล้วแต่ยังไม่มีแถวใน profiles
    /// เกิดได้เมื่อสมัครค้างกลางทาง — สร้างบัญชีสำเร็จแต่สร้างโปรไฟล์ไม่สำเร็จ
    private(set) var needsProfile = false

    private let cacheURL: URL

    /// อ่าน cache แบบ synchronous ตอนสร้างโดยตั้งใจ — เห็นโปรไฟล์ทันทีโดยไม่ต้องรอเน็ต
    /// แล้วค่อย refresh ทับด้วยของจริงจาก server
    ///
    /// ถ้ายังไม่มี session ให้ล้างข้อมูลเก่าทิ้งก่อน — ไฟล์ที่ค้างอยู่จากยุคที่แอปเก็บข้อมูล
    /// ในเครื่องล้วนไม่ใช่ของบัญชีใด และการปล่อยไว้จะทำให้เห็นโปรไฟล์ของคนก่อนหน้า
    /// หลังสมัครบัญชีใหม่ ซึ่งเป็นข้อมูลรั่วข้ามบัญชีบนเครื่องที่ใช้ร่วมกัน
    init(cacheURL: URL = ProfileStore.defaultCacheURL) {
        self.cacheURL = cacheURL

        if Backend.client.auth.currentSession == nil {
            ProfileStore.clearLocalData(cacheURL: cacheURL)
            self.profile = .empty
            self.avatarImage = nil
            self.coverImage = nil
            return
        }

        self.profile = ProfileStore.readCache(from: cacheURL)

        let directory = ProfileStore.imagesDirectory(besides: cacheURL)
        self.avatarImage = ProfileStore.loadImage(named: profile.avatarFileName, in: directory)
        self.coverImage = ProfileStore.loadImage(named: profile.coverFileName, in: directory)
    }

    nonisolated static func clearLocalData(cacheURL: URL) {
        try? FileManager.default.removeItem(at: cacheURL)
        try? FileManager.default.removeItem(at: imagesDirectory(besides: cacheURL))
    }

    /// ดึงของจริงจาก server มาทับ cache
    /// ไม่ throw เพราะการเปิดแอปตอนไม่มีเน็ตควรใช้งานต่อได้ด้วยข้อมูลที่แคชไว้
    func refresh() async {
        guard let userID = Backend.client.auth.currentSession?.user.id else { return }

        do {
            let rows: [RemoteProfile] = try await Backend.client
                .from("profiles")
                .select()
                .eq("user_id", value: userID)
                .execute()
                .value

            guard let row = rows.first else {
                needsProfile = true
                return
            }

            needsProfile = false
            profile = Profile(
                displayName: row.displayName,
                bio: profile.bio,
                usernameSuffix: row.stableSuffix,
                createdAt: row.createdAt,
                avatarFileName: row.avatarPath,
                coverFileName: row.coverPath
            )
            ProfileStore.writeCache(profile, to: cacheURL)

            avatarImage = await Self.downloadImage(path: row.avatarPath)
            coverImage = await Self.downloadImage(path: row.coverPath)
        } catch {
            // เก็บ cache ไว้ใช้ต่อ ไม่รบกวนผู้ใช้ด้วย error ตอนเปิดแอป
        }
    }

    /// ลำดับสำคัญ: อัปโหลดรูปใหม่ → อัปเดตแถวใน DB → ค่อยลบรูปเก่า
    /// พังกลางทางจะเหลือไฟล์กำพร้าที่แค่กินที่ ส่วนลำดับกลับกันจะได้แถวที่ชี้ไปไฟล์ที่ถูกลบแล้ว
    func update(
        _ newProfile: Profile,
        avatar: ImageEdit = .unchanged,
        cover: ImageEdit = .unchanged
    ) async throws {
        guard let userID = Backend.client.auth.currentSession?.user.id else {
            throw ProfileStoreError.notSignedIn
        }

        let previousAvatar = profile.avatarFileName
        let previousCover = profile.coverFileName

        let avatarPath = try await Self.applyEdit(
            avatar,
            current: previousAvatar,
            kind: "avatar",
            maxPixel: ProfileImage.avatarMaxPixel,
            userID: userID
        )

        let coverPath = try await Self.applyEdit(
            cover,
            current: previousCover,
            kind: "cover",
            maxPixel: ProfileImage.coverMaxPixel,
            userID: userID
        )

        var finalProfile = newProfile
        finalProfile.avatarFileName = avatarPath
        finalProfile.coverFileName = coverPath

        profile = finalProfile
        ProfileStore.writeCache(finalProfile, to: cacheURL)

        struct Patch: Encodable {
            let display_name: String
            let avatar_path: String?
            let cover_path: String?
        }

        try await Backend.client
            .from("profiles")
            .update(
                Patch(
                    display_name: finalProfile.trimmedDisplayName,
                    avatar_path: avatarPath,
                    cover_path: coverPath
                )
            )
            .eq("user_id", value: userID)
            .execute()

        if avatar != .unchanged {
            avatarImage = await Self.downloadImage(path: avatarPath)
        }
        if cover != .unchanged {
            coverImage = await Self.downloadImage(path: coverPath)
        }

        await Self.deleteIfReplaced(previousAvatar, by: avatarPath)
        await Self.deleteIfReplaced(previousCover, by: coverPath)
    }

    /// path ขึ้นต้นด้วย user_id เสมอ เพื่อให้ policy ของ Storage เทียบกับ auth.uid() ได้ตรง ๆ
    ///
    /// ต้องเป็นตัวพิมพ์เล็ก — policy เทียบ (storage.foldername(name))[1] = auth.uid()::text
    /// ซึ่ง Postgres เขียน uuid ออกมาเป็นตัวพิมพ์เล็กเสมอ ส่วน UUID.uuidString ของ Swift
    /// เป็นตัวพิมพ์ใหญ่เสมอ ถ้าส่งไปตรง ๆ การเทียบสตริงจะไม่มีวันตรงและ upload จะโดนปฏิเสธ
    /// ทุกครั้งด้วย "new row violates row-level security policy"
    static func applyEdit(
        _ edit: ImageEdit,
        current: String?,
        kind: String,
        maxPixel: Int,
        userID: UUID
    ) async throws -> String? {
        switch edit {
        case .unchanged:
            return current

        case .remove:
            return nil

        case .replace(let raw):
            let jpeg = try await Task.detached(priority: .userInitiated) {
                try ProfileImage.prepare(raw, maxPixel: maxPixel)
            }.value

            let path = "\(userID.uuidString.lowercased())/\(kind)-\(UUID().uuidString).jpg"

            try await Backend.client.storage
                .from("profile-images")
                .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg"))

            return path
        }
    }

    static func downloadImage(path: String?) async -> Image? {
        guard let path else { return nil }

        guard
            let data = try? await Backend.client.storage
                .from("profile-images")
                .download(path: path),
            let decoded = ProfileImage.decode(data)
        else {
            return nil
        }
        return Image(decorative: decoded, scale: 1)
    }

    static func deleteIfReplaced(_ old: String?, by new: String?) async {
        guard let old, old != new else { return }
        _ = try? await Backend.client.storage.from("profile-images").remove(paths: [old])
    }

    // MARK: - Cache

    static var defaultCacheURL: URL {
        URL.applicationSupportDirectory.appending(path: "profile.json")
    }

    nonisolated static func imagesDirectory(besides fileURL: URL) -> URL {
        fileURL.deletingLastPathComponent().appending(path: "images")
    }

    nonisolated static func readCache(from url: URL) -> Profile {
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

    /// cache พังไม่ใช่เรื่องที่ผู้ใช้ต้องรับรู้ ของจริงอยู่บน server
    nonisolated static func writeCache(_ profile: Profile, to url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(profile) else { return }
        try? data.write(to: url, options: .atomic)
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
}

nonisolated enum ProfileStoreError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        "You're not signed in."
    }
}
