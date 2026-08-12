//
//  ProfileAvatar.swift
//  null-app
//

import SwiftUI

/// วงกลมโปรไฟล์ที่แสดงรูปจริงถ้ามี ไม่มีก็ถอยไปใช้อักษรย่อ
/// อักษรย่อไม่ได้ถูกทิ้งเมื่อมีรูปแล้ว — มันคือสิ่งที่ผู้ใช้ใหม่ทุกคนเห็นก่อนเสมอ
struct ProfileAvatar: View {
    let image: Image?
    let initials: String
    var diameter: CGFloat = 96
    var tint: Color = .accentColor

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: diameter, height: diameter)
                    .clipShape(.circle)
            } else {
                InitialsAvatar(initials: initials, diameter: diameter, tint: tint)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfileAvatar(image: nil, initials: "PT", tint: .teal)
        ProfileAvatar(image: nil, initials: "?", diameter: 48)
    }
    .padding()
}
