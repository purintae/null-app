//
//  ProfileHeader.swift
//  null-app
//

import SwiftUI

/// Cover + avatar ที่เกยขอบล่างของ cover
/// รับทุกอย่างเข้ามาอ่านอย่างเดียว ไม่รู้จัก ProfileStore จึง preview ได้โดยไม่ต้องเตรียมอะไร
struct ProfileHeader: View {
    let profile: Profile
    var avatarImage: Image?
    var coverImage: Image?

    /// รวมพื้นที่ status bar กับแถบบนที่ cover ไหลขึ้นไปทับด้วย
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

                // ยืด cover ขึ้นไปข้างบนเท่ากับระยะที่ถูกดึง
                // ไม่งั้นจะเห็นพื้นหลังขาวโผล่เหนือ cover ตอนดึงลง
                cover
                    .frame(height: bannerHeight + pulled)
                    .clipped()
                    .overlay(alignment: .top) { scrim }
                    .offset(y: -pulled)
            }
            // ความสูงในเลย์เอาต์คงที่เสมอ การยืดเกิดขึ้นแค่ตอนวาด
            // avatar กับเนื้อหาข้างล่างจึงไม่ขยับตาม
            .frame(height: bannerHeight)
            .overlay(alignment: .bottomLeading) {
                ProfileAvatar(
                    image: avatarImage,
                    initials: profile.initials,
                    diameter: avatarSize,
                    tint: identityColor
                )
                .overlay {
                    // วงแหวนสีพื้นหลังทำให้ avatar แยกออกจาก cover ชัดเจน
                    Circle().strokeBorder(.background, lineWidth: 4)
                }
                .offset(x: horizontalPadding, y: avatarSize / 2)
            }

            // กันที่ให้ครึ่งล่างของ avatar ที่ห้อยพ้น cover ลงมา
            Color.clear
                .frame(height: avatarSize / 2)
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let coverImage {
            coverImage
                .resizable()
                .scaledToFill()
        } else {
            identityColor
        }
    }

    /// หัวข้อกับไอคอนบนแถบบนเป็นสีขาว ซึ่งอ่านได้เสมอบนสีที่เราคำนวณเอง (ความสว่างคงที่)
    /// แต่รูปของผู้ใช้จะสว่างแค่ไหนก็ได้ — รูปหิมะจะกลืนตัวหนังสือขาวหายไปเลย
    /// จึงใส่เฉพาะตอนมีรูป ไม่ใส่ทับสีพื้นที่คุมได้อยู่แล้ว
    @ViewBuilder
    private var scrim: some View {
        if coverImage != nil {
            LinearGradient(
                colors: [.black.opacity(0.45), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 130)
            .allowsHitTesting(false)
        }
    }
}

// ห่อด้วย ScrollView ให้ตรงกับที่ใช้จริง เพราะ .scrollView coordinate space
// ต้องมี ScrollView เป็นบรรพบุรุษถึงจะวัดค่าได้ถูก
#Preview("ยังไม่มีรูป") {
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
