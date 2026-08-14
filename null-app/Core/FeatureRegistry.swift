//
//  FeatureRegistry.swift
//  null-app
//

import Foundation

/// ไฟล์เดียวในโปรเจกต์ที่เอ่ยชื่อฟีเจอร์
///
/// เพิ่มฟีเจอร์ = เติมหนึ่งบรรทัด ถอดฟีเจอร์ = ลบหนึ่งบรรทัด
/// ลำดับใน array คือลำดับไอคอนบนหน้า Home
///
/// ถ้าวันหนึ่งมีไฟล์ที่สองที่รู้จักชื่อฟีเจอร์ นั่นคือสัญญาณว่าเส้นแบ่งเริ่มรั่ว
enum FeatureRegistry {
    static let installed: [any Feature] = [
        WorkFeature(),
    ]

    /// ตรวจกติกาของ id ทั้ง registry ตอนเปิดแอป — ดังกว่าเงียบโดยตั้งใจ
    ///
    /// id เป็นทั้งชื่อ schema, ชื่อโฟลเดอร์, prefix ของคีย์ UserDefaults และ identity ของ ForEach
    /// พร้อมกัน ความผิดพลาดที่นี่จึงไม่แสดงตัวเป็น error แต่เป็นสองฟีเจอร์ที่แชร์ลิ้นชักเดียวกัน
    /// หรือ query ที่หา schema ไม่เจอตลอดกาล — อาการที่ไล่ย้อนกลับมาถึงต้นเหตุยากมาก
    /// ตกลงแลกเป็น crash ตอนเปิดแอปของนักพัฒนา ซึ่งเกิดทันทีที่เติมบรรทัดผิดและแก้ได้ใน 5 วินาที
    static func validateInstalled() {
        validate(installed.map(\.id))
    }

    static func validate(_ ids: [String]) {
        for id in ids {
            precondition(
                FeatureStorage.isValidID(id),
                "Feature id \"\(id)\" is invalid — use ^[a-z][a-z0-9_]*$ only"
            )
        }
        precondition(
            Set(ids).count == ids.count,
            "Duplicate feature id in FeatureRegistry.installed — ids own a schema, a folder and a key namespace each"
        )
    }
}
