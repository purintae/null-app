//
//  ExampleStore.swift
//  null-app
//

import Foundation
import Observation
import Supabase

/// แถวใน f_example.note
///
/// ไม่มีฟิลด์ Optional จึงใช้ synthesized Encodable ได้อย่างปลอดภัย
/// ถ้าวันหนึ่งเพิ่มคอลัมน์ที่เป็น Optional แล้วส่ง PATCH ต้องเขียน encode(to:) เอง
/// มิฉะนั้น encodeIfPresent จะตัดคีย์ทิ้งและ PostgREST จะอ่านว่า "ไม่ต้องแตะคอลัมน์นี้"
nonisolated struct ExampleNote: Codable {
    let userID: UUID
    var body: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case body
    }
}

/// เจ้าของ state ของฟีเจอร์ตัวอย่าง
///
/// เรียกผ่าน .schema("f_example") เพราะตารางไม่ได้อยู่ใน public
/// ซึ่งเป็นราคาที่จ่ายเพื่อให้ถอดฟีเจอร์ได้ด้วย drop schema คำสั่งเดียว
@Observable
final class ExampleStore {
    private(set) var body = ""

    private let userID: UUID

    init(userID: UUID) {
        self.userID = userID
    }

    /// ไม่ throw เพราะการเปิดหน้าตอนไม่มีเน็ตควรได้หน้าว่าง ไม่ใช่ error กลางหน้าจอ
    func load() async {
        let rows: [ExampleNote]? = try? await Backend.client
            .schema("f_example")
            .from("note")
            .select()
            .eq("user_id", value: userID)
            .execute()
            .value

        body = rows?.first?.body ?? ""
    }

    /// throw เพราะการกด Save แล้วเงียบคือสิ่งที่ผู้ใช้ตีความว่าบันทึกสำเร็จ
    func save(_ newBody: String) async throws {
        try await Backend.client
            .schema("f_example")
            .from("note")
            .upsert(ExampleNote(userID: userID, body: newBody))
            .execute()

        body = newBody
    }
}
