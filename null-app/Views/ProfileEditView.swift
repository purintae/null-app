//
//  ProfileEditView.swift
//  null-app
//

import SwiftUI

/// ฟอร์มแก้ไขที่ทำงานบนสำเนา ไม่แตะ store โดยตรง
/// กด Cancel แล้วทุกอย่างที่พิมพ์ไปถูกทิ้ง
struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Profile
    private let onSave: (Profile) -> Void

    init(profile: Profile, onSave: @escaping (Profile) -> Void) {
        _draft = State(initialValue: profile)
        self.onSave = onSave
    }

    private var bioIsOverLimit: Bool {
        draft.bio.count > Profile.bioLimit
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Display name", text: $draft.displayName)
                }

                Section("Bio") {
                    TextField("Something about you", text: $draft.bio, axis: .vertical)
                        .lineLimit(3...6)

                    HStack {
                        Spacer()
                        Text("\(draft.bio.count)/\(Profile.bioLimit)")
                            .font(.caption)
                            .foregroundStyle(bioIsOverLimit ? Color.red : Color.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // เก็บชื่อที่ตัดช่องว่างแล้ว จะได้ไม่มีช่องว่างค้างในไฟล์
                        var cleaned = draft
                        cleaned.displayName = draft.trimmedDisplayName
                        onSave(cleaned)
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
        #if os(macOS)
        // sheet บน macOS ไม่มีขนาดเริ่มต้นที่ใช้งานได้ ต้องกำหนดเอง
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }
}

#Preview("ว่าง") {
    ProfileEditView(profile: .empty) { _ in }
}

#Preview("มีข้อมูลแล้ว") {
    ProfileEditView(profile: Profile(displayName: "Purin Tae", bio: "สวัสดีครับ")) { _ in }
}
