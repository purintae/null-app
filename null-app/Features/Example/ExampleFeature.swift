//
//  ExampleFeature.swift
//  null-app
//

import SwiftUI

/// ฟีเจอร์ตัวอย่างที่สร้างขึ้นมาเพื่อถูกลบ
///
/// มันใช้ครบทุกช่องทางของสัญญา — หน้าจอ, ตารางที่มี RLS, ไฟล์ในเครื่อง, คีย์ UserDefaults
/// เพื่อให้การถอดใน Task 5 พิสูจน์ได้จริงว่าสะอาด ไม่ใช่แค่ในทางทฤษฎี
struct ExampleFeature: Feature {
    let id = "example"
    let title = "Example"
    let systemImage = "square.dashed"

    func makeRoot(userID: UUID) -> AnyView {
        AnyView(ExampleRootView(userID: userID))
    }
}
