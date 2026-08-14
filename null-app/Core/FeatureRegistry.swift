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
    ]
}
