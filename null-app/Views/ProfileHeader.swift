//
//  ProfileHeader.swift
//  null-app
//

import SwiftUI

/// Banner สีประจำตัว + avatar ที่เกยขอบล่างของ banner + ปุ่ม Edit
/// รับ Profile เข้ามาอ่านอย่างเดียว และคืนเจตนาออกไปทาง closure
/// จึงไม่รู้จัก ProfileStore และ preview ได้โดยไม่ต้องเตรียมอะไร
struct ProfileHeader: View {
    let profile: Profile

    /// รวมพื้นที่ status bar ที่ cover ไหลขึ้นไปทับด้วย
    /// ส่วนที่มองเห็นใต้ status bar จึงเหลือราว 110
    private let bannerHeight: CGFloat = 170
    private let avatarSize: CGFloat = 84
    private let horizontalPadding: CGFloat = 16

    private var identityColor: Color {
        Color(hue: profile.bannerHue, saturation: 0.5, brightness: 0.7)
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                // ระยะที่ผู้ใช้ดึงเลยขอบบนลงมา — เป็นบวกเฉพาะตอน overscroll เท่านั้น
                let pulled = max(0, geometry.frame(in: .scrollView).minY)

                // ยืด banner ขึ้นไปข้างบนเท่ากับระยะที่ถูกดึง
                // ไม่งั้นจะเห็นพื้นหลังขาวโผล่เหนือ cover ตอนดึงลง
                identityColor
                    .frame(height: bannerHeight + pulled)
                    .offset(y: -pulled)
            }
            // ความสูงในเลย์เอาต์คงที่เสมอ การยืดเกิดขึ้นแค่ตอนวาด
            // avatar กับเนื้อหาข้างล่างจึงไม่ขยับตาม
            .frame(height: bannerHeight)
            .overlay(alignment: .bottomLeading) {
                    InitialsAvatar(
                        initials: profile.initials,
                        diameter: avatarSize,
                        tint: identityColor
                    )
                    .overlay {
                        // วงแหวนสีพื้นหลังทำให้ avatar แยกออกจาก banner ชัดเจน
                        Circle().strokeBorder(.background, lineWidth: 4)
                    }
                    .offset(x: horizontalPadding, y: avatarSize / 2)
                }

            // กันที่ให้ครึ่งล่างของ avatar ที่ห้อยพ้น banner ลงมา
            Color.clear
                .frame(height: avatarSize / 2)
        }
    }
}

// ห่อด้วย ScrollView ให้ตรงกับที่ใช้จริง เพราะ .scrollView coordinate space
// ต้องมี ScrollView เป็นบรรพบุรุษถึงจะวัดค่าได้ถูก
#Preview("มีชื่อแล้ว") {
    ScrollView {
        ProfileHeader(
            profile: Profile(
                displayName: "Purin Tae",
                bio: "Building null-app",
                usernameSuffix: "3Q6RDV",
                createdAt: .now
            )
        )
    }
}

#Preview("ยังไม่ตั้งชื่อ") {
    ScrollView {
        ProfileHeader(profile: .empty)
    }
}
