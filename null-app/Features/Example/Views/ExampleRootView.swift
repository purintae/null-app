//
//  ExampleRootView.swift
//  null-app
//

import SwiftUI

/// หน้าจอของฟีเจอร์ตัวอย่าง — เขียนข้อความหนึ่งบรรทัดเก็บไว้บน server
struct ExampleRootView: View {
    let userID: UUID

    @State private var store: ExampleStore
    @State private var draft = ""
    @State private var saveError: String?

    /// ล็อกช่องพิมพ์ไว้จนกว่า .task จะโหลดเสร็จรอบแรก
    /// กัน race: ถ้าเปิดให้พิมพ์ได้ทันทีที่ view render ผู้ใช้อาจพิมพ์อยู่พอดีตอนที่
    /// load() กลับมาแล้ว draft = store.body จะไปทับสิ่งที่พิมพ์ค้างอยู่แบบเงียบ ๆ
    @State private var isLoading = true

    init(userID: UUID) {
        self.userID = userID
        _store = State(initialValue: ExampleStore(userID: userID))
    }

    var body: some View {
        Form {
            Section("Note") {
                TextField("Type something", text: $draft)
                    .disabled(isLoading)

                Button("Save") {
                    Task {
                        do {
                            saveError = nil
                            try await store.save(draft)
                        } catch {
                            saveError = error.localizedDescription
                        }
                    }
                }
                .disabled(store.loadFailed || draft == store.body)
            }

            if store.loadFailed {
                Section {
                    Text("Couldn't load your note. Reopen this screen to try again.")
                        .foregroundStyle(.red)
                }
            }

            if let saveError {
                Section {
                    Text(saveError)
                        .foregroundStyle(.red)
                }
            }

            Section("Signed in as") {
                Text(userID.uuidString.lowercased())
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Example")
        .task {
            await store.load()
            draft = store.body
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        ExampleRootView(userID: UUID())
    }
}
