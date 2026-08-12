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
    let onEdit: () -> Void

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
            identityColor
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

            // แถวนี้มีหน้าที่สองอย่าง: วางปุ่ม Edit และกันที่ให้ครึ่งล่างของ avatar
            HStack {
                Spacer()

                Button("Edit", action: onEdit)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .clipShape(.capsule)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 10)
            .frame(height: avatarSize / 2, alignment: .top)
        }
    }
}

#Preview("มีชื่อแล้ว") {
    ProfileHeader(
        profile: Profile(
            displayName: "Purin Tae",
            bio: "Building null-app",
            usernameSuffix: "3Q6RDV",
            createdAt: .now
        )
    ) {}
}

#Preview("ยังไม่ตั้งชื่อ") {
    ProfileHeader(profile: .empty) {}
}
