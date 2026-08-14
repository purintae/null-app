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

    init(userID: UUID) {
        self.userID = userID
        _store = State(initialValue: ExampleStore(userID: userID))
    }

    var body: some View {
        Form {
            Section("Note") {
                TextField("Type something", text: $draft)

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
                .disabled(draft == store.body)
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
        }
    }
}

#Preview {
    NavigationStack {
        ExampleRootView(userID: UUID())
    }
}
