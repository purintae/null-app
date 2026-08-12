//
//  InitialsAvatar.swift
//  null-app
//

import SwiftUI

/// วงกลมแสดงอักษรย่อแทนรูปโปรไฟล์
/// เป็นจุดเดียวที่ต้องแก้เมื่อวันหนึ่งเปลี่ยนไปใช้รูปจริง
struct InitialsAvatar: View {
    let initials: String
    var diameter: CGFloat = 96
    var tint: Color = .accentColor

    var body: some View {
        Circle()
            // ทึบแสงโดยตั้งใจ — วงกลมนี้วางทับ banner สี ถ้าพื้นโปร่งจะเห็นสี banner ทะลุขึ้นมา
            .fill(.background)
            .overlay {
                Circle().fill(tint.opacity(0.18))
            }
            .frame(width: diameter, height: diameter)
            .overlay {
                Text(initials)
                    .font(.system(size: diameter * 0.36, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }
            // ชื่อถูกอ่านออกเสียงจาก Text ที่อยู่ข้าง ๆ อยู่แล้ว
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 20) {
        InitialsAvatar(initials: "PT")
        InitialsAvatar(initials: "?")
        InitialsAvatar(initials: "A", diameter: 48, tint: .purple)
    }
    .padding()
}
