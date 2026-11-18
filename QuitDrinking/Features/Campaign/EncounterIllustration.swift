import SwiftUI

/// 以百格方形為畫版。圖像是裝飾，關卡名稱和狀態由外層按鈕朗讀。
struct EncounterIllustration: View {
    let level: Int
    let isLocked: Bool

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            var plate = context
            plate.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
            plate.scaleBy(x: side / 100, y: side / 100)
            let print = CoasterPress(context: plate, isLocked: isLocked)
            print.draw(level: level)
        }
        .aspectRatio(1, contentMode: .fit)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CoasterPress {
    let context: GraphicsContext
    let isLocked: Bool

    private var ink: Color { ThemeTokens.receiptInk }
    private var paper: Color { ThemeTokens.receiptPaper }
    private var accent: Color {
        isLocked ? ThemeTokens.inkSecondary : ThemeTokens.amberShield
    }

    func draw(level: Int) {
        let border = Path(ellipseIn: CGRect(x: 3, y: 3, width: 94, height: 94))
        context.fill(border, with: .color(paper))
        context.stroke(border, with: .color(ink), lineWidth: 2)
        let ring = Path(ellipseIn: CGRect(x: 7, y: 7, width: 86, height: 86))
        context.stroke(ring, with: .color(ink.opacity(0.55)), lineWidth: 0.9)

        switch level {
        case 1: spilledGlass()
        case 2: dinnerTable()
        case 3: morningAlarm()
        case 4: eveningCabinet()
        default: break
        }
    }

    // 打翻的玻璃杯，灑出來的酒在桌面變成史萊姆。
    private func spilledGlass() {
        stamp(polygon([(18, 50), (20, 38), (43, 40), (39, 59)]), color: paper)
        var rim = Path()
        rim.addEllipse(in: CGRect(x: 38.5, y: 39.5, width: 5.5, height: 19),
                       transform: CGAffineTransform(translationX: 41, y: 49)
                           .rotated(by: 0.2)
                           .translatedBy(x: -41, y: -49))
        stamp(rim, color: paper, width: 1.6)
        line([(22, 47), (34, 51)], width: 1.8)
        line([(29, 63), (42, 63)], width: 2.2)

        var slime = Path()
        slime.move(to: CGPoint(x: 38, y: 67))
        slime.addQuadCurve(to: CGPoint(x: 48, y: 52), control: CGPoint(x: 35, y: 62))
        slime.addQuadCurve(to: CGPoint(x: 65, y: 37), control: CGPoint(x: 53, y: 35))
        slime.addQuadCurve(to: CGPoint(x: 77, y: 54), control: CGPoint(x: 76, y: 37))
        slime.addQuadCurve(to: CGPoint(x: 82, y: 67), control: CGPoint(x: 77, y: 58))
        slime.addQuadCurve(to: CGPoint(x: 71, y: 73), control: CGPoint(x: 86, y: 76))
        slime.addQuadCurve(to: CGPoint(x: 55, y: 73), control: CGPoint(x: 64, y: 77))
        slime.addQuadCurve(to: CGPoint(x: 38, y: 67), control: CGPoint(x: 33, y: 75))
        slime.closeSubpath()
        stamp(slime, color: accent)
        line([(53, 55), (58, 58)], width: 3)
        line([(67, 57), (72, 54)], width: 3)
        line([(60, 65), (64, 65)], width: 2.2)
        ellipse(x: 48, y: 29, width: 4, height: 6, color: accent)
    }

    // 坐在聚餐長桌後的哥布林；尖耳剪影與單杯構成兩個印色區。
    private func dinnerTable() {
        let head = polygon([
            (16, 38), (34, 41), (38, 32), (46, 27), (51, 30), (57, 26),
            (64, 34), (66, 40), (84, 34), (76, 49), (66, 52), (64, 61),
            (55, 67), (43, 65), (36, 58), (34, 52), (25, 50)
        ])
        stamp(head, color: isLocked ? accent : ThemeTokens.mintVitality)
        line([(38, 44), (45, 47)], width: 3)
        line([(56, 47), (62, 43)], width: 3)
        line([(50, 46), (47, 53), (52, 53)], width: 2)
        line([(43, 56), (48, 60), (55, 58)], width: 2.3)
        stamp(polygon([(17, 67), (82, 65), (85, 71), (20, 74)]), color: ink)
        line([(26, 74), (25, 81)], width: 3)
        line([(75, 72), (76, 79)], width: 3)
        stamp(polygon([(66, 53), (78, 53), (76, 66), (68, 66)]), color: paper, width: 1.8)
        line([(68, 58), (76, 58)], width: 2)
    }

    // 熬過宿醉的早晨：龍垂著眼皮，鬧鐘壓在前景。
    private func morningAlarm() {
        var dragon = Path()
        dragon.move(to: CGPoint(x: 43, y: 72))
        dragon.addQuadCurve(to: CGPoint(x: 59, y: 51), control: CGPoint(x: 63, y: 65))
        dragon.addLine(to: CGPoint(x: 48, y: 56))
        dragon.addLine(to: CGPoint(x: 38, y: 54))
        dragon.addLine(to: CGPoint(x: 35, y: 47))
        dragon.addLine(to: CGPoint(x: 51, y: 42))
        dragon.addLine(to: CGPoint(x: 57, y: 33))
        dragon.addLine(to: CGPoint(x: 56, y: 23))
        dragon.addLine(to: CGPoint(x: 65, y: 31))
        dragon.addLine(to: CGPoint(x: 75, y: 20))
        dragon.addLine(to: CGPoint(x: 72, y: 35))
        dragon.addLine(to: CGPoint(x: 79, y: 36))
        dragon.addLine(to: CGPoint(x: 74, y: 43))
        dragon.addLine(to: CGPoint(x: 82, y: 47))
        dragon.addLine(to: CGPoint(x: 76, y: 51))
        dragon.addQuadCurve(to: CGPoint(x: 68, y: 74), control: CGPoint(x: 79, y: 63))
        dragon.closeSubpath()
        stamp(dragon, color: accent)
        line([(53, 43), (58, 44), (63, 40)], width: 2.6)
        ellipse(x: 39, y: 47, width: 2.7, height: 2.7, color: ink)
        line([(44, 52), (50, 51)], width: 1.8)

        line([(22, 52), (28, 47)], width: 4.5)
        line([(40, 47), (46, 51)], width: 4.5)
        line([(27, 73), (24, 78)], width: 2.5)
        line([(40, 73), (43, 78)], width: 2.5)
        let face = Path(ellipseIn: CGRect(x: 21, y: 50, width: 26, height: 26))
        stamp(face, color: paper)
        line([(34, 55), (34, 63), (39, 66)], width: 2.4)
    }

    // 酒櫃裡浮現的王冠面具。左右酒瓶以單色剪影陪襯。
    private func eveningCabinet() {
        stamp(polygon([(20, 30), (50, 19), (80, 30), (80, 74), (20, 74)]), color: paper)
        line([(24, 31), (50, 23), (76, 31)], width: 1.7)
        line([(21, 68), (79, 68)], width: 3)
        for x: CGFloat in [24, 69] {
            let bottle = polygon([(x, 64), (x, 53), (x + 2, 50), (x + 2, 43),
                                  (x + 6, 43), (x + 6, 50), (x + 8, 53), (x + 8, 64)])
            context.fill(bottle, with: .color(ink))
        }
        stamp(polygon([(35, 48), (50, 42), (65, 48), (62, 61), (50, 72), (38, 61)]), color: ink)
        stamp(polygon([(33, 33), (43, 39), (50, 29), (57, 39), (67, 33),
                       (63, 46), (37, 46)]), color: accent)
        line([(40, 51), (46, 54)], width: 3, color: paper)
        line([(54, 54), (60, 51)], width: 3, color: paper)
        line([(47, 62), (50, 60), (53, 62)], width: 1.8, color: paper)
    }

    private func polygon(_ points: [(CGFloat, CGFloat)], closed: Bool = true) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.0, y: first.1))
        for (x, y) in points.dropFirst() {
            path.addLine(to: CGPoint(x: x, y: y))
        }
        if closed { path.closeSubpath() }
        return path
    }

    private func stamp(_ path: Path, color: Color, width: CGFloat = 2.5) {
        context.fill(path, with: .color(color))
        context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: width, lineJoin: .round))
    }

    private func line(_ points: [(CGFloat, CGFloat)], width: CGFloat, color: Color? = nil) {
        context.stroke(polygon(points, closed: false), with: .color(color ?? ink),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func ellipse(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: Color) {
        let shape = Path(ellipseIn: CGRect(x: x, y: y, width: width, height: height))
        context.fill(shape, with: .color(color))
    }
}
