import UIKit

/// Generated TEST fixture only; no imported artwork or personal photo.
enum SampleFixture {
    static func png() -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 500, height: 700), format: format).pngData { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 500, height: 700))
            UIColor.black.setStroke(); context.cgContext.setLineWidth(4)
            context.cgContext.stroke(CGRect(x: 2, y: 2, width: 496, height: 696))
            ("TEST" as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: [.font: UIFont.systemFont(ofSize: 48), .foregroundColor: UIColor.black])
        }
    }
}
