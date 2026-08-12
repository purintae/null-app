//
//  ProfileEditView.swift
//  null-app
//

import PhotosUI
import SwiftUI

/// ฟอร์มแก้ไขที่ทำงานบนสำเนา ไม่แตะ store โดยตรง
/// กด Cancel แล้วทุกอย่างที่พิมพ์และรูปที่เพิ่งเลือกถูกทิ้งทั้งหมด
/// เพราะรูปยังไม่ถูกเขียนลงดิสก์จนกว่าจะกด Save
struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Profile
    @State private var avatarEdit: ImageEdit = .unchanged
    @State private var coverEdit: ImageEdit = .unchanged
    @State private var avatarPreview: Image?
    @State private var coverPreview: Image?
    @State private var avatarItem: PhotosPickerItem?
    @State private var coverItem: PhotosPickerItem?

    private let onSave: (Profile, ImageEdit, ImageEdit) -> Void

    init(
        profile: Profile,
        avatarImage: Image? = nil,
        coverImage: Image? = nil,
        onSave: @escaping (Profile, ImageEdit, ImageEdit) -> Void
    ) {
        _draft = State(initialValue: profile)
        _avatarPreview = State(initialValue: avatarImage)
        _coverPreview = State(initialValue: coverImage)
        self.onSave = onSave
    }

    private var bioIsOverLimit: Bool {
        draft.bio.count > Profile.bioLimit
    }

    private var identityColor: Color {
        Color(hue: draft.bannerHue, saturation: 0.5, brightness: 0.7)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cover") {
                    HStack {
                        Text("Preview")
                        Spacer()
                        coverThumbnail
                    }

                    PhotosPicker("Choose cover", selection: $coverItem, matching: .images)

                    if coverPreview != nil {
                        Button("Remove cover", role: .destructive) {
                            coverItem = nil
                            coverPreview = nil
                            coverEdit = .remove
                        }
                    }
                }

                Section("Profile photo") {
                    HStack {
                        Text("Preview")
                        Spacer()
                        ProfileAvatar(
                            image: avatarPreview,
                            initials: draft.initials,
                            diameter: 44,
                            tint: identityColor
                        )
                    }

                    PhotosPicker("Choose photo", selection: $avatarItem, matching: .images)

                    if avatarPreview != nil {
                        Button("Remove photo", role: .destructive) {
                            avatarItem = nil
                            avatarPreview = nil
                            avatarEdit = .remove
                        }
                    }
                }

                Section("Name") {
                    TextField("Display name", text: $draft.displayName)
                        .autocorrectionDisabled()

                    if draft.hasUnsupportedNameCharacters {
                        Label(
                            "Use English letters, numbers, spaces, - or ' only",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(Color.red)
                    }
                }

                Section("Username") {
                    Text(draft.username)
                        .font(.body.monospaced())

                    Text("Built from your name. The part after the dash is yours for good — it stays the same however often you rename.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        onSave(cleaned, avatarEdit, coverEdit)
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
        .onChange(of: coverItem) { _, item in
            Task {
                guard let picked = await Self.load(item) else { return }
                coverEdit = .replace(picked.data)
                coverPreview = picked.preview
            }
        }
        .onChange(of: avatarItem) { _, item in
            Task {
                guard let picked = await Self.load(item) else { return }
                avatarEdit = .replace(picked.data)
                avatarPreview = picked.preview
            }
        }
        #if os(macOS)
        // sheet บน macOS ไม่มีขนาดเริ่มต้นที่ใช้งานได้ ต้องกำหนดเอง
        .frame(minWidth: 420, minHeight: 520)
        #endif
    }

    @ViewBuilder
    private var coverThumbnail: some View {
        Group {
            if let coverPreview {
                coverPreview
                    .resizable()
                    .scaledToFill()
            } else {
                identityColor
            }
        }
        .frame(width: 80, height: 44)
        .clipShape(.rect(cornerRadius: 6))
    }

    /// เก็บ data ดิบไว้ใน edit ไม่ใช่ตัวที่ย่อแล้ว — ให้ store เป็นคนย่อครั้งเดียวตอนบันทึกจริง
    /// ที่นี่ถอดรหัสแค่ขนาดพรีวิว เพื่อไม่เสียแรง decode รูปเต็มขนาดมาโชว์ในช่องจิ๋ว
    ///
    /// คืน nil เมื่อโหลดไม่สำเร็จ แล้วปล่อยให้สถานะเดิมคงอยู่
    /// ไม่ตั้ง .replace ทิ้งไว้ทั้งที่ไม่มีรูป ซึ่งจะทำให้ Save ล้มเหลวทีหลังโดยไม่มีใครรู้ว่าทำไม
    private static func load(_ item: PhotosPickerItem?) async -> (data: Data, preview: Image)? {
        guard
            let item,
            let data = try? await item.loadTransferable(type: Data.self),
            let thumbnail = ProfileImage.thumbnail(data)
        else {
            return nil
        }

        return (data, Image(decorative: thumbnail, scale: 1))
    }
}

#Preview("ยังไม่มีรูป") {
    ProfileEditView(
        profile: Profile(
            displayName: "Purin Tae",
            bio: "Building null-app",
            usernameSuffix: "3Q6RDV",
            createdAt: .now
        )
    ) { _, _, _ in }
}

#Preview("ชื่อที่ใช้ไม่ได้") {
    ProfileEditView(
        profile: Profile(displayName: "ปุริน แต้", bio: "", usernameSuffix: "3Q6RDV")
    ) { _, _, _ in }
}
