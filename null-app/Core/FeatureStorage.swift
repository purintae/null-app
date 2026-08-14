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
    static func sweepOrphans(installed: Set<String>, root: URL, defaults: UserDefaults) {
        let manager = FileManager.default

        if let entries = try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            for entry in entries where !installed.contains(entry.lastPathComponent) {
                try? manager.removeItem(at: entry)
            }
        }

        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("f.") {
            let id = String(key.dropFirst(2).prefix { $0 != "." })
            if !installed.contains(id) {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
