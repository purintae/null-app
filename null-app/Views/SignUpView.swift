//
//  SignUpView.swift
//  null-app
//

import Supabase
import SwiftUI

/// สมัครโดยกรอกชื่ออย่างเดียว ไม่มีรหัสผ่าน ไม่มีอีเมล
/// ใช้กฎชื่อชุดเดียวกับหน้าแก้ไขโปรไฟล์ผ่าน Profile.isValid
/// เพื่อไม่ให้มีกฎสองชุดที่หลุดจากกันได้
struct SignUpView: View {
    let session: SessionStore

    /// เรียกเมื่อสร้างโปรไฟล์สำเร็จ เพื่อให้ผู้เรียกไปดึงข้อมูลใหม่
    ///
    /// จำเป็นสำหรับเส้นทางกู้คืน — ตอนนั้น session.state เป็น .signedIn อยู่แล้ว
    /// หน้าจอจึงไม่เปลี่ยนตามสถานะ session สิ่งเดียวที่พาออกจากหน้านี้ได้คือ
    /// needsProfile ที่กลับเป็น false ซึ่งมีแต่ ProfileStore.refresh() เท่านั้นที่ทำให้เกิด
    var onProfileCreated: () async -> Void = {}

    @State private var displayName = ""
    @State private var isWorking = false
    @State private var failure: String?

    /// สร้าง Profile ชั่วคราวเพื่อยืมกฎ validation ที่มีอยู่แล้วมาใช้
    private var draft: Profile {
        Profile(displayName: displayName, bio: "")
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 8) {
                Text("What should we call you?")
                    .font(.title2.weight(.bold))

                Text("You can change this at any time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Display name", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .disabled(isWorking)

                if draft.hasUnsupportedNameCharacters {
                    Label(
                        "Use English letters, numbers, spaces, - or ' only",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.red)
                }
            }

            Button {
                Task { await submit() }
            } label: {
                if isWorking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!draft.isValid || isWorking)

            Spacer()
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 420)
        .alert(
            "Couldn't create your account",
            isPresented: Binding(
                get: { failure != nil },
                set: { if !$0 { failure = nil } }
            ),
            presenting: failure
        ) { _ in
            Button("OK", role: .cancel) { failure = nil }
        } message: { message in
            Text(message)
        }
    }

    /// เก็บชื่อที่ตัดช่องว่างแล้ว จะได้ไม่มีช่องว่างค้างในฐานข้อมูล
    private func submit() async {
        isWorking = true
        defer { isWorking = false }

        do {
            if Backend.client.auth.currentSession == nil {
                try await session.signUp(displayName: draft.trimmedDisplayName)
            } else {
                try await session.createProfile(displayName: draft.trimmedDisplayName)
            }
            await onProfileCreated()
        } catch {
            failure = error.localizedDescription
        }
    }
}

#Preview {
    SignUpView(session: SessionStore())
}
