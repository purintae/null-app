//
//  WorkFeature.swift
//  null-app
//

import SwiftUI

/// ติดตามงานตาม Action Plan ประจำปี — ฟีเจอร์แรกที่ตั้งใจให้อยู่ยาวใน shell นี้
///
/// spec: `docs/superpowers/specs/2026-08-14-work-tracker-design.md`
///
/// รอบนี้เป็น UI ล้วน ยังไม่มี schema `f_work` และยังไม่แตะเซิร์ฟเวอร์
struct WorkFeature: Feature {
    let id = "work"
    let title = "Work"
    let systemImage = "briefcase"

    /// `userID` ยังไม่ถูกใช้จนกว่าจะถึงรอบที่อ่านข้อมูลจริง — รับไว้ตามสัญญาของ protocol
    /// เพราะการพึ่งพาที่โผล่อยู่ในลายเซ็นคือการพึ่งพาที่มองเห็นได้
    func makeRoot(userID: UUID) -> AnyView {
        AnyView(WorkRootView())
    }
}
