//
//  Backend.swift
//  null-app
//

import Foundation
import Supabase

/// จุดเดียวที่ประกอบ Supabase client ไฟล์อื่นเรียกผ่าน Backend.client เท่านั้น
///
/// publishable key ฝังในแอปได้อย่างปลอดภัยโดยการออกแบบ — มันถูกออกแบบมาให้อยู่ใน client
/// สิ่งที่ป้องกันข้อมูลจริง ๆ คือ Row Level Security ไม่ใช่การซ่อน key นี้
nonisolated enum Backend {
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://yqeqzplufezlnudsxzql.supabase.co")!,
        supabaseKey: "sb_publishable_TzWBdrFCJzBBL8wlrU-ksg_eJyYZto1"
    )
}
