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

    /// แยกจาก "โหลดแล้วได้โน้ตว่าง" — save() เป็น upsert ทับแถวเดิม
    /// ถ้าโหลดพังแล้วยังถือว่า body ว่างคือของจริง ผู้ใช้ที่มีโน้ตอยู่แล้วแต่ออฟไลน์
    /// จะพิมพ์ทับแล้วกด Save ได้ ซึ่งจะเขียนทับโน้ตเดิมบน server แบบเงียบ ๆ
    private(set) var loadFailed = false

    private let userID: UUID

    init(userID: UUID) {
        self.userID = userID
    }

    /// เปลี่ยนจาก try? เป็น do/catch เพราะตอนนี้ต้องแยกว่าโหลดพังหรือโหลดสำเร็จแล้วว่าง
    func load() async {
        do {
            let rows: [ExampleNote] = try await Backend.client
                .schema("f_example")
                .from("note")
                .select()
                .eq("user_id", value: userID)
                .execute()
                .value

            body = rows.first?.body ?? ""
            loadFailed = false
        } catch {
            loadFailed = true
        }
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
