//
//  UsernameQRSheet.swift
//  null-app
//

import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/// QR ที่บรรจุ username ไว้ให้คนอื่นสแกน
/// รับ username เข้ามาเป็นสตริงเดียว ไม่รู้จัก Profile หรือ ProfileStore
/// จึง preview ได้ทันทีและใช้ซ้ำกับ handle อื่นได้
struct UsernameQRSheet: View {
    let username: String

    @Environment(\.dismiss) private var dismiss
    @State private var code: CGImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                if let code {
                    Image(decorative: code, scale: 1)
                        // QR เป็นภาพขาวดำคมชัด ถ้าปล่อยให้ระบบ interpolate ขอบจะเบลอจนสแกนพลาด
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)
                        .padding(20)
                        .background(.white, in: .rect(cornerRadius: 16))
                        .accessibilityLabel("QR code for \(username)")
                } else {
                    ProgressView()
                        .frame(maxWidth: 260, minHeight: 260)
                }

                Text(username)
                    .font(.headline)
                    .monospaced()
                    .textSelection(.enabled)

                Text("Anyone who scans this gets your username.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .navigationTitle("My QR Code")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            code = Self.makeCode(from: username)
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 460)
        #endif
    }

    /// สร้างครั้งเดียวใน .task ไม่ใช่ใน body — ไม่งั้นจะถูกสร้างใหม่ทุกครั้งที่ view วาด
    private static let context = CIContext()

    private static func makeCode(from text: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        // ผลลัพธ์ดิบเล็กมาก (ราวหลักสิบ pixel) ต้องขยายก่อนแปลงเป็น bitmap
        // ไม่งั้นตอนยืดให้เต็มจอจะเบลอ
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        return context.createCGImage(scaled, from: scaled.extent)
    }
}

#Preview {
    UsernameQRSheet(username: "@purintae-3Q6RDV")
}
