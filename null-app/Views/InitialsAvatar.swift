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

    var body: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.15))
            .frame(width: diameter, height: diameter)
            .overlay {
                Text(initials)
                    .font(.system(size: diameter * 0.36, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
            }
            // ชื่อถูกอ่านออกเสียงจาก Text ที่อยู่ข้าง ๆ อยู่แล้ว
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 20) {
        InitialsAvatar(initials: "PT")
        InitialsAvatar(initials: "?")
        InitialsAvatar(initials: "A", diameter: 48)
    }
    .padding()
}
