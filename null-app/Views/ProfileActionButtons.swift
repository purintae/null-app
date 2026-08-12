//
//  ProfileActionButtons.swift
//  null-app
//

import SwiftUI

/// ปุ่มคู่ใต้โปรไฟล์ กว้างเท่ากันคนละครึ่ง
/// ส่งเจตนาออกไปทาง closure ไม่รู้จัก store หรือ sheet ใด ๆ
struct ProfileActionButtons: View {
    let onShowQRCode: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onShowQRCode) {
                Label("My QR Code", systemImage: "qrcode")
            }

            Button(action: onEdit) {
                Label("Edit Profile", systemImage: "square.and.pencil")
            }
        }
        .buttonStyle(OutlinedActionButtonStyle())
    }
}

/// SwiftUI ไม่มีสไตล์ปุ่มแบบเส้นขอบมาให้ มีแค่ .bordered ที่เป็นพื้นทึบอ่อน
/// เขียนเองเพื่อให้ตรงกับแบบ และยังคงการตอบสนองตอนกดไว้ผ่าน isPressed
private struct OutlinedActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(.background, in: .rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.tertiary, lineWidth: 1)
            }
            .foregroundStyle(.primary)
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

#Preview {
    ProfileActionButtons(onShowQRCode: {}, onEdit: {})
        .padding()
}
