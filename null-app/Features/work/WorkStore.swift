//
//  WorkStore.swift
//  null-app
//

import Foundation
import Observation
import Supabase

/// เจ้าของ state ของฟีเจอร์ work เพียงผู้เดียว ตามแบบเดียวกับ ProfileStore
/// view ไม่รู้ว่าข้อมูลมาจากไหน วันที่แหล่งข้อมูลเปลี่ยนจึงไม่ต้องแก้ view
@Observable
final class WorkStore {
    private(set) var items: [WorkItemRow] = []
    private(set) var types: [WorkTypeRow] = []

    /// แยก "โหลดแล้วไม่มีงาน" ออกจาก "โหลดไม่สำเร็จ" — สองอย่างนี้หน้าตาเหมือนกันบนจอ
    /// ถ้าไม่แยก แล้วผู้ใช้จะเข้าใจว่าข้อมูลหายทั้งที่แค่เน็ตหลุด
    private(set) var loadFailed = false
    private(set) var hasLoaded = false

    private let userID: UUID

    /// ไม่ทำงานใด ๆ ใน init — Home เรียก makeRoot ตอนวาดทุกไอคอน ไม่ใช่ตอนกด
    init(userID: UUID) {
        self.userID = userID
    }

    /// ดึงงานพร้อม stage ในคำขอเดียวผ่าน embed ของ PostgREST
    /// สองคำขอแยกจะทำให้เกิดช่วงที่การ์ดมีงานแต่ยังไม่มีแถบ stage ซึ่งกระพริบ
    func load() async {
        do {
            async let itemsTask: [WorkItemRow] = Backend.client
                .schema("f_work")
                .from("item")
                .select("id,type_code,name,description,requested_by,badge,updated_at,stage(id,code,name,position,planned_start,planned_end,actual_start,actual_end)")
                .eq("user_id", value: userID)
                .is("archived_at", value: nil)
                .order("updated_at", ascending: false)
                .execute()
                .value

            async let typesTask: [WorkTypeRow] = Backend.client
                .schema("f_work")
                .from("work_type")
                .select("code,label,position")
                .eq("is_active", value: true)
                .order("position")
                .execute()
                .value

            let (loadedItems, loadedTypes) = try await (itemsTask, typesTask)

            // stage มาจากเซิร์ฟเวอร์โดยไม่รับประกันลำดับ เรียงที่นี่ครั้งเดียว
            // แทนที่จะให้ทุก view ที่ใช้มันเรียงเอง
            items = loadedItems.map { item in
                var sorted = item
                sorted.stage.sort { $0.position < $1.position }
                return sorted
            }
            types = loadedTypes
            loadFailed = false
        } catch {
            loadFailed = true
        }

        hasLoaded = true
    }
}
