//
//  SessionStore.swift
//  null-app
//

import Foundation
import Observation
import Supabase

/// ถือสถานะการล็อกอิน และเป็นตัวตัดสินว่าแอปแสดงหน้าสมัครหรือหน้า Home
///
/// ไม่เก็บ token เอง — supabase-swift เก็บลง Keychain ให้อยู่แล้ว
/// session ที่อยู่ใน Keychain นั้นคือ "device credential" ตาม requirements
/// ไม่ใช่ของชั่วคราวที่รอถูกแทนที่
@Observable
final class SessionStore {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(userID: UUID)
    }

    private(set) var state: State = .loading

    private var watcher: Task<Void, Never>?

    init() {
        // authStateChanges ส่ง .initialSession ให้เสมอตอนเริ่มฟัง
        // สถานะ .loading จึงอยู่แค่ชั่วครู่ ไม่ค้าง
        watcher = Task { [weak self] in
            for await change in Backend.client.auth.authStateChanges {
                guard let self else { return }

                switch change.event {
                case .signedOut:
                    state = .signedOut
                default:
                    state = change.session.map { .signedIn(userID: $0.user.id) } ?? .signedOut
                }
            }
        }
    }

    deinit {
        watcher?.cancel()
    }

    /// สมัครสองขั้นตอนที่ต้องสำเร็จทั้งคู่: สร้างบัญชี แล้วสร้างโปรไฟล์
    /// ถ้าขั้นที่สองล้มเหลว จะได้บัญชีที่ไม่มีโปรไฟล์ ซึ่ง ProfileStore ตรวจเจอและพากลับมากรอกใหม่
    func signUp(displayName: String) async throws {
        try await Backend.client.auth.signInAnonymously()
        try await createProfile(displayName: displayName)
    }

    /// แยกออกมาเพราะถูกเรียกซ้ำได้ ในกรณีที่บัญชีมีแล้วแต่โปรไฟล์ยังไม่มี
    func createProfile(displayName: String) async throws {
        try await Backend.client
            .rpc("create_profile", params: ["p_display_name": displayName])
            .execute()
    }
}
