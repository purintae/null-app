//
//  ProfileImage.swift
//  null-app
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// การย่อและเข้ารหัสรูป ใช้ ImageIO ล้วน ไม่แตะ UIKit/AppKit
/// จึงใช้ได้ทั้งสี่แพลตฟอร์มและ compile ด้วย swiftc เดี่ยว ๆ เพื่อทดสอบได้
nonisolated enum ProfileImage {
    /// รูปจากกล้อง iPhone กว้างราว 4000px การเก็บขนาดนั้นไว้เปลืองที่โดยไม่ได้อะไร
    /// avatar แสดงจริงแค่ 84pt (252px บนจอ 3x) ส่วน cover เต็มความกว้างจอ
    static let avatarMaxPixel = 512
    static let coverMaxPixel = 1600

    static let jpegQuality = 0.85

    enum Failure: LocalizedError {
        case unreadable

        var errorDescription: String? {
            "That image couldn't be read. Try a different one."
        }
    }

    /// ย่อแล้วเข้ารหัสเป็น JPEG ในขั้นตอนเดียว
    /// รับ data ดิบจาก PhotosPicker ซึ่งอาจเป็น HEIC, PNG หรืออะไรก็ได้ที่ ImageIO อ่านออก
    static func prepare(_ data: Data, maxPixel: Int) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw Failure.unreadable
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // เคารพ EXIF orientation ไม่งั้นรูปที่ถ่ายแนวตั้งจะออกมาตะแคง
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]

        guard
            let scaled = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
            let encoded = encodeJPEG(scaled)
        else {
            throw Failure.unreadable
        }

        return encoded
    }

    static func encodeJPEG(_ image: CGImage) -> Data? {
        let buffer = NSMutableData()

        guard
            let destination = CGImageDestinationCreateWithData(
                buffer,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        else {
            return nil
        }

        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else { return nil }
        return buffer as Data
    }

    static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// ถอดรหัสแค่ขนาดเล็กสำหรับพรีวิวในฟอร์ม
    /// รูปที่ผู้ใช้เพิ่งเลือกอาจใหญ่หลาย MB การ decode เต็มขนาดเพื่อโชว์รูปจิ๋วคือการเผาแรงเปล่า
    static func thumbnail(_ data: Data, maxPixel: Int = 256) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
