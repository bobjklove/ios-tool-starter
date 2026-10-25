// 模板 App 图标（Claude 设计，2026-10-18）：墨绿底 + 白纸 + 照片框 + 刻度尺 = 「按真实尺寸打印」。
// 新 App：改 brand 色和纸面内容即可；生成：
//   swift tools/generate-app-icon.swift tools/icon/DrawIcon.swift .build/icon/AppIcon.png
// 坐标系原点在左下角，画布 1024×1024，iOS 会自动裁圆角，四周不要留白。

import CoreGraphics

func drawIcon(context c: CGContext, size: CGFloat) {
    let brand = CGColor(red: 0.12, green: 0.44, blue: 0.36, alpha: 1)       // #1F6F5C
    let brandDeep = CGColor(red: 0.09, green: 0.35, blue: 0.29, alpha: 1)   // 底部渐深一档，不用渐变
    let paper = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    let soft = CGColor(red: 0.90, green: 0.95, blue: 0.93, alpha: 1)        // #E6F1EE
    let tick = CGColor(red: 0.12, green: 0.44, blue: 0.36, alpha: 0.55)

    // 底色：上浅下深两块，制造一点纵深
    c.setFillColor(brand)
    c.fill(CGRect(x: 0, y: 0, width: size, height: size))
    c.setFillColor(brandDeep)
    c.fill(CGRect(x: 0, y: 0, width: size, height: 300))

    // 纸张：略高的竖版 A 系比例，带极轻投影
    let sheet = CGRect(x: 262, y: 170, width: 500, height: 680)
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -18), blur: 40,
                color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.22))
    c.setFillColor(paper)
    c.addPath(CGPath(roundedRect: sheet, cornerWidth: 44, cornerHeight: 44, transform: nil))
    c.fillPath()
    c.restoreGState()

    // 照片框：浅绿底 + 远山 + 太阳
    let photo = CGRect(x: 322, y: 470, width: 380, height: 310)
    c.setFillColor(soft)
    c.addPath(CGPath(roundedRect: photo, cornerWidth: 22, cornerHeight: 22, transform: nil))
    c.fillPath()
    c.saveGState()
    c.addPath(CGPath(roundedRect: photo, cornerWidth: 22, cornerHeight: 22, transform: nil))
    c.clip()
    c.setFillColor(brand)
    c.move(to: CGPoint(x: 322, y: 470))
    c.addLine(to: CGPoint(x: 462, y: 640))
    c.addLine(to: CGPoint(x: 540, y: 560))
    c.addLine(to: CGPoint(x: 600, y: 610))
    c.addLine(to: CGPoint(x: 702, y: 500))
    c.addLine(to: CGPoint(x: 702, y: 470))
    c.closePath()
    c.fillPath()
    c.addEllipse(in: CGRect(x: 610, y: 680, width: 54, height: 54))
    c.fillPath()
    c.restoreGState()

    // 刻度尺：长短交替，表示「真实尺寸」
    c.setFillColor(tick)
    let baseY: CGFloat = 250
    for i in 0...10 {
        let x = 322 + CGFloat(i) * 38
        let h: CGFloat = i % 5 == 0 ? 120 : (i % 2 == 0 ? 80 : 56)
        c.addPath(CGPath(roundedRect: CGRect(x: x - 5, y: baseY, width: 10, height: h),
                         cornerWidth: 5, cornerHeight: 5, transform: nil))
    }
    c.fillPath()
}
