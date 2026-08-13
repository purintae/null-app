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

    /// จริงตลอดช่วงที่ signUp ยังทำงานอยู่ และเป็นตัวกั้น watcher ไม่ให้ประกาศ .signedIn
    ///
    /// signInAnonymously ยิง event ทันทีที่ได้ token ซึ่งเร็วกว่าการสร้างแถวใน profiles
    /// ถ้าปล่อยให้ประกาศตอนนั้น SwiftUI จะสลับ root ไป Home แล้ว .task ก็จะเรียก
    /// ProfileStore.refresh() ไปเจอตารางที่ยังไม่มีแถวของเรา ได้ needsProfile = true
    /// ทั้งที่การสมัครกำลังจะสำเร็จ — ผู้ใช้จะถูกส่งกลับไปกรอกชื่อใหม่ทั้งที่ไม่มีอะไรผิด
    private var isCompletingSignUp = false

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
                    // ระหว่าง signUp ปล่อยให้ signUp เป็นคนประกาศเองเมื่อโปรไฟล์เสร็จแล้ว
                    if isCompletingSignUp { continue }
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
    ///
    /// .signedIn ถูกกลั้นไว้จนครบทั้งสองขั้น สถานะนี้จึงแปลว่า "ใช้งานได้จริง" ไม่ใช่แค่ "มี token"
    /// ตอนที่ล้มเหลวจะยังเป็น .signedOut ทั้งที่ session มีแล้ว ซึ่งพาไปหน้าสมัครได้ถูกต้อง
    /// เพราะหน้านั้นดูจาก currentSession เพื่อเลือกว่าจะสมัครใหม่หรือสร้างแค่โปรไฟล์
    func signUp(displayName: String) async throws {
        isCompletingSignUp = true
        defer { isCompletingSignUp = false }

        try await Backend.client.auth.signInAnonymously()
        try await createProfile(displayName: displayName)
    }

    /// แยกออกมาเพราะถูกเรียกซ้ำได้ ในกรณีที่บัญชีมีแล้วแต่โปรไฟล์ยังไม่มี
    ///
    /// ประกาศ .signedIn ที่นี่ ไม่ใช่ใน signUp เพราะทั้งสองเส้นทางผ่านจุดนี้เหมือนกัน
    /// และ event ที่ signInAnonymously ยิงออกมาถูก watcher ทิ้งไปแล้วระหว่างที่กั้นอยู่
    /// ถ้าประกาศเฉพาะตอน signUp สำเร็จ กรณีที่ createProfile ล้มเหลวรอบแรกแล้วผู้ใช้กดใหม่
    /// จะสร้างโปรไฟล์สำเร็จแต่ state ค้างที่ .signedOut ตลอด ผู้ใช้ติดอยู่หน้าสมัครจนกว่าจะปิดแอป
    func createProfile(displayName: String) async throws {
        try await Backend.client
            .rpc("create_profile", params: ["p_display_name": displayName])
            .execute()

        guard let session = Backend.client.auth.currentSession else { return }
        state = .signedIn(userID: session.user.id)
    }
}
