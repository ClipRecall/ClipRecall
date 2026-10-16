import AppKit

/// 菜单栏图标：代码绘制的"剪贴板 + 召回箭头"（模板图，自动适配深/浅色菜单栏）。
/// 纯 AppKit 绘制，透明底完全可控；调整形状只需改这里的坐标参数。
enum MenuBarIcon {
    @MainActor static let icon: NSImage = {
        // 画布紧贴图形比例（18×24），图形占满画布、仅留少量边距——
        // 菜单栏按图像整体宽度占位，画布留白越多图标离邻居越远
        let image = NSImage(size: NSSize(width: 18, height: 24))
        image.lockFocus()
        // 1) 垂直翻转：AppKit 原点在左下，让坐标按"左上原点"理解
        let flip = NSAffineTransform()
        flip.translateX(by: 0, yBy: 24)
        flip.scaleX(by: 1, yBy: -1)
        flip.concat()
        // 2) 图形缩放（按原始坐标中心）
        let fit = NSAffineTransform()
        fit.translateX(by: 16, yBy: 17.3)
        fit.scaleX(by: 0.92, yBy: 0.85)
        fit.translateX(by: -16, yBy: -17.3)
        fit.concat()
        // 3) 平移入画布（画布中心 9,12）
        let move = NSAffineTransform()
        move.translateX(by: 9 - 16, yBy: 12 - 17.3)
        move.concat()
        NSColor.black.setStroke()
        NSColor.black.setFill()

        // 剪贴板主体（描边）
        let bodyRect = NSRect(x: 8.5, y: 10, width: 15, height: 18)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 2.6, yRadius: 2.6)
        bodyPath.lineWidth = 2
        bodyPath.stroke()

        // 顶部夹子（填充）
        let clipRect = NSRect(x: 12, y: 6.6, width: 8, height: 4.2)
        NSBezierPath(roundedRect: clipRect, xRadius: 1.7, yRadius: 1.7).fill()

        // 召回回转箭头（填充，指向左、尾部向右回环）
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: 10.8, y: 18))
        arrow.line(to: NSPoint(x: 15.8, y: 14.6))
        arrow.line(to: NSPoint(x: 15.8, y: 17.4))
        arrow.line(to: NSPoint(x: 20.6, y: 17.4))
        arrow.curve(
            to: NSPoint(x: 21.6, y: 18.4),
            controlPoint1: NSPoint(x: 21.15, y: 17.4),
            controlPoint2: NSPoint(x: 21.6, y: 17.85)
        )
        arrow.line(to: NSPoint(x: 21.6, y: 19.6))
        arrow.curve(
            to: NSPoint(x: 20.6, y: 20.6),
            controlPoint1: NSPoint(x: 21.6, y: 20.15),
            controlPoint2: NSPoint(x: 21.15, y: 20.6)
        )
        arrow.line(to: NSPoint(x: 15.8, y: 20.6))
        arrow.line(to: NSPoint(x: 15.8, y: 21.4))
        arrow.close()
        arrow.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }()
}
