//
//  FeatureStorage.swift
//  null-app
//

import Foundation

/// ที่เก็บของในเครื่องของฟีเจอร์ ทุกชื่ออนุมานจาก id ไม่มีการตั้งชื่ออิสระ
///
/// อยู่ที่ Application Support ไม่ใช่ Caches เพื่อให้ตรงกับ ProfileStore ที่เก็บ profile.json
/// ไว้ที่นั่นอยู่แล้ว การมีที่เก็บสองแบบแลกมาด้วยจุดกวาดสองจุด
nonisolated enum FeatureStorage {
    /// ตัวอักษรที่ id ใช้ได้ — `^[a-z][a-z0-9_]*$`
    ///
    /// ไม่ใช่รสนิยม: id ตัวเดียวกันถูกใช้เป็นชื่อ schema ใน Postgres, ชื่อโฟลเดอร์,
    /// prefix ของคีย์ UserDefaults และ identity ของ ForEach พร้อมกัน
    /// - ตัวพิมพ์ใหญ่พังแบบสับสนที่สุด — Postgres พับ identifier ที่ไม่ได้ครอบ quote เป็นตัวเล็ก
    ///   `create schema f_MyFeature` จึงได้ `f_myfeature` ส่วน `.schema("f_MyFeature")`
    ///   ส่งสตริงตรง ๆ แล้วหาไม่เจอตลอดกาล
    /// - `.` ทำให้แยกไม่ออกว่าคีย์ `f.a.b.c` เป็นของ `a` หรือ `a.b`
    /// - `/` ทำให้ `directory(for:)` สร้างโฟลเดอร์ซ้อนชั้น ซึ่ง sweep มองไม่เห็น
    static func isValidID(_ id: String) -> Bool {
        guard let first = id.first, first.isASCII, first.isLowercase else { return false }
        return id.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "_") }
    }

    /// รากของโฟลเดอร์ฟีเจอร์ทั้งหมด
    ///
    /// `URL.applicationSupportDirectory` ชี้เข้า container ของแอปได้เพราะ `ENABLE_APP_SANDBOX = YES`
    /// ถ้าวันหนึ่งปิด sandbox ฝั่ง macOS ค่านี้จะกลายเป็น `~/Library/Application Support/Features`
    /// ที่ใช้ร่วมกับโปรแกรมอื่น แล้ว `sweepOrphans` จะลบทุกโฟลเดอร์ที่มันไม่รู้จักในนั้น
    /// การเติม bundle id ต่อท้ายเพื่อกันไว้ก่อนไม่คุ้ม เพราะมันทิ้งโฟลเดอร์เดิมของทุกเครื่อง
    /// ที่ลงแอปไว้แล้วให้ค้างอยู่ถาวร — จึงบันทึกเงื่อนไขนี้ไว้แทนการเปลี่ยน path
    static var root: URL {
        URL.applicationSupportDirectory.appending(path: "Features")
    }

    static func directory(for id: String) -> URL {
        root.appending(path: id)
    }

    static func defaultsKey(_ id: String, _ key: String) -> String {
        "f.\(id).\(key)"
    }

    /// ลบโฟลเดอร์และคีย์ของฟีเจอร์ที่ไม่ได้อยู่ใน registry แล้ว
    ///
    /// ผู้ใช้ที่ลงแอปไว้ก่อนถอดฟีเจอร์จะมีของค้างอยู่ตลอดกาล เพราะโค้ดที่เคยรู้จักมันถูกลบไปแล้ว
    /// ไม่เหลือใครลบให้ การตัดสินจาก registry ปัจจุบันยังทำให้มันกวาดของจากฟีเจอร์
    /// ที่ถูกถอดไปก่อนที่ฟังก์ชันนี้จะมีอยู่ได้ด้วย
    ///
    /// ถ้า id ตัวใดผิดรูป จะไม่ลบอะไรเลย — fail closed โดยตั้งใจ
    /// เพราะรายชื่อที่เชื่อไม่ได้ทำให้ "อะไรคือของกำพร้า" ตอบไม่ได้ และการเดาผิดที่นี่
    /// แปลว่าลบข้อมูลของฟีเจอร์ที่ยังติดตั้งอยู่ `FeatureRegistry.validateInstalled()`
    /// เป็นด่านที่ทำให้กรณีนี้ไม่เกิดจริงตั้งแต่ตอนเปิดแอป
    static func sweepOrphans(installed: Set<String>, root: URL, defaults: UserDefaults) {
        guard installed.allSatisfy(isValidID) else { return }

        let manager = FileManager.default

        if let entries = try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            for entry in entries where !installed.contains(entry.lastPathComponent) {
                try? manager.removeItem(at: entry)
            }
        }

        // ตัดสินจาก prefix ไม่ใช่จากการแยกชื่อ id ออกจากคีย์
        // การอ่าน `f.<id>.<key>` ย้อนกลับเป็น id ทำไม่ได้ถ้า id มีจุด — และการเดาผิด
        // ทำให้คีย์ของฟีเจอร์ที่ยังติดตั้งอยู่ถูกลบทุกครั้งที่เปิดแอป
        let owned = installed.map { "f.\($0)." }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("f.") {
            if !owned.contains(where: key.hasPrefix) {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
