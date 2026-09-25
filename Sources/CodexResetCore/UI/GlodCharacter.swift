#if canImport(SwiftUI) && os(iOS)
import SwiftUI

// Glóð is drawn from shapes, not images, so the app and the widget share one
// character and every part of it can animate. Coordinates are a 100×100 grid.

/// One frame of Glóð's body language.
public struct GlodPose: Equatable {
    /// Vertical offset on the 100-point grid. Negative moves up.
    public var lift: Double
    /// 1 is rest. Above 1 stretches up, below 1 squashes.
    public var stretch: Double
    /// Lean of the flame tip, -1...1.
    public var sway: Double
    /// Pupil direction, -1...1.
    public var look: Double
    public var blink: Bool
    /// Just tapped: happy eyes and hearts, whatever the mood.
    public var poked: Bool

    public init(lift: Double = 0, stretch: Double = 1, sway: Double = 0, look: Double = 0, blink: Bool = false, poked: Bool = false) {
        self.lift = lift
        self.stretch = stretch
        self.sway = sway
        self.look = look
        self.blink = blink
        self.poked = poked
    }

    public static let rest = GlodPose()
    public static let poke = GlodPose(lift: -14, stretch: 1.12, sway: 0.4, poked: true)

    /// Poses the widget steps through, one per timeline entry.
    /// WidgetKit animates the change between neighbouring entries.
    public static let widgetCycle: [GlodPose] = [
        GlodPose(),
        GlodPose(lift: -4, stretch: 1.05, sway: 0.5, look: -1),
        GlodPose(sway: -0.3, blink: true),
        GlodPose(lift: -2, stretch: 0.96, sway: -0.6, look: 1),
        GlodPose(lift: -6, stretch: 1.08, sway: 0.2),
        GlodPose(stretch: 0.94, sway: -0.2, look: 0.5),
    ]

    public static func widgetFrame(_ index: Int) -> GlodPose {
        widgetCycle[((index % widgetCycle.count) + widgetCycle.count) % widgetCycle.count]
    }

    /// Continuous idle motion for the app, driven by a TimelineView.
    public static func live(at time: TimeInterval, mood: GlodMood) -> GlodPose {
        let calm = mood == .sleepy ? 0.45 : 1.0
        let bob = sin(time * 2.2 * calm)
        let blinkPhase = time.truncatingRemainder(dividingBy: mood == .sleepy ? 2.6 : 3.8)
        return GlodPose(
            lift: -3 * calm * (bob + 1) / 2 - (mood == .celebrating ? 4 * abs(sin(time * 4)) : 0),
            stretch: 1 + 0.035 * calm * bob,
            sway: 0.55 * sin(time * 3.1) + 0.2 * sin(time * 7.3),
            look: mood == .sleepy ? 0 : sin(time * 0.7),
            blink: blinkPhase < 0.14
        )
    }
}

public enum GlodPalette {
    public static let ink = Color(glodHex: 0x3A1F2E)
    public static let berry = Color(glodHex: 0xC2415A)
    public static let blush = Color(glodHex: 0xFF7A8A)
    public static let coin = Color(glodHex: 0xF5C542)
    public static let coinEdge = Color(glodHex: 0xC9921B)
    public static let coinLight = Color(glodHex: 0xFFF4B8)

    public static func flameOuter(_ mood: GlodMood) -> Color {
        mood == .sleepy ? Color(glodHex: 0xFF9F7A) : Color(glodHex: 0xFF8A3D)
    }

    public static func flameInner(_ mood: GlodMood) -> Color {
        mood == .sleepy ? Color(glodHex: 0xFFD3A8) : Color(glodHex: 0xFFE28A)
    }

    /// Three stops, light to deep, for the widget ground and the app hero.
    public static func ground(_ mood: GlodMood) -> [Color] {
        switch mood {
        case .sleepy:
            return [Color(glodHex: 0x8E8CC9), Color(glodHex: 0x5C5A9C), Color(glodHex: 0x34335F)]
        case .rich:
            return [Color(glodHex: 0x9FE3C6), Color(glodHex: 0x3FAE9A), Color(glodHex: 0x1F6E6F)]
        case .celebrating:
            return [Color(glodHex: 0xFFC48F), Color(glodHex: 0xF07A5A), Color(glodHex: 0xB9446A)]
        case .content, .waiting:
            return [Color(glodHex: 0xFFB487), Color(glodHex: 0xE8745A), Color(glodHex: 0xA8456A)]
        }
    }
}

/// Mood-coloured ground with a soft light in the top corner.
public struct GlodBackground: View {
    public var mood: GlodMood

    public init(mood: GlodMood) {
        self.mood = mood
    }

    public var body: some View {
        let stops = GlodPalette.ground(mood)
        RadialGradient(
            colors: stops,
            center: UnitPoint(x: 0.22, y: 0.18),
            startRadius: 0,
            endRadius: 320
        )
    }
}

public struct GlodCharacter: View {
    public var mood: GlodMood
    public var pose: GlodPose

    public init(mood: GlodMood, pose: GlodPose = .rest) {
        self.mood = mood
        self.pose = pose
    }

    private var happyEyes: Bool { mood == .celebrating || pose.poked }

    public var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let line = max(1.5, side * 0.03)
            ZStack {
                ZStack {
                    GlodFlameShape(inset: false, sway: pose.sway)
                        .fill(GlodPalette.flameOuter(mood))
                    GlodFlameShape(inset: true, sway: pose.sway)
                        .fill(GlodPalette.flameInner(mood))
                    cheeks
                    eyes(line: line)
                    mouth(line: line)
                }
                .scaleEffect(x: 1 / pose.stretch.squareRoot(), y: pose.stretch, anchor: .bottom)
                .offset(y: pose.lift / 100 * side)

                extras(side: side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var cheeks: some View {
        if mood != .sleepy {
            GlodUnitShape { path, unit in
                path.addEllipse(in: unit.rect(28, 57, 10, 6))
                path.addEllipse(in: unit.rect(62, 57, 10, 6))
            }
            .fill(GlodPalette.blush.opacity(0.55))
        }
    }

    @ViewBuilder
    private func eyes(line: CGFloat) -> some View {
        if happyEyes {
            GlodUnitShape { path, unit in
                for x in [36.0, 54.0] {
                    path.move(to: unit.point(x, 53))
                    path.addQuadCurve(to: unit.point(x + 10, 53), control: unit.point(x + 5, 45))
                }
            }
            .stroke(GlodPalette.ink, style: StrokeStyle(lineWidth: line, lineCap: .round))
        } else if mood == .sleepy || pose.blink {
            GlodUnitShape { path, unit in
                for x in [36.0, 54.0] {
                    path.move(to: unit.point(x, 53))
                    path.addLine(to: unit.point(x + 10, 53))
                }
            }
            .stroke(GlodPalette.ink, style: StrokeStyle(lineWidth: line, lineCap: .round))
        } else {
            let shift = pose.look * 2
            ZStack {
                GlodUnitShape { path, unit in
                    path.addEllipse(in: unit.rect(37 + shift, 48, 8, 8))
                    path.addEllipse(in: unit.rect(55 + shift, 48, 8, 8))
                }
                .fill(GlodPalette.ink)
                GlodUnitShape { path, unit in
                    path.addEllipse(in: unit.rect(40.5 + shift, 49, 2.6, 2.6))
                    path.addEllipse(in: unit.rect(58.5 + shift, 49, 2.6, 2.6))
                }
                .fill(Color.white)
            }
        }
    }

    @ViewBuilder
    private func mouth(line: CGFloat) -> some View {
        switch mood {
        case .sleepy where !pose.poked:
            GlodUnitShape { path, unit in
                path.addEllipse(in: unit.rect(46, 62, 8, 6))
            }
            .fill(GlodPalette.ink)
        case .celebrating, .rich, .sleepy:
            Self.openSmile
                .fill(GlodPalette.berry)
                .overlay(Self.openSmile.stroke(GlodPalette.ink, style: StrokeStyle(lineWidth: line, lineJoin: .round)))
        case .content, .waiting:
            GlodUnitShape { path, unit in
                path.move(to: unit.point(43, 62))
                path.addQuadCurve(to: unit.point(57, 62), control: unit.point(50, 69))
            }
            .stroke(GlodPalette.ink, style: StrokeStyle(lineWidth: line, lineCap: .round))
        }
    }

    private static let openSmile = GlodUnitShape { path, unit in
        path.move(to: unit.point(42, 62))
        path.addQuadCurve(to: unit.point(58, 62), control: unit.point(50, 74))
        path.closeSubpath()
    }

    @ViewBuilder
    private func extras(side: CGFloat) -> some View {
        if pose.poked {
            ZStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: side * 0.14))
                    .position(x: side * 0.16, y: side * 0.2)
                Image(systemName: "heart.fill")
                    .font(.system(size: side * 0.1))
                    .position(x: side * 0.86, y: side * 0.14)
            }
            .foregroundStyle(GlodPalette.blush)
        } else {
            switch mood {
            case .celebrating:
                GlodUnitShape { path, unit in
                    path.addSparkle(center: unit.point(14, 22), radius: unit.length(8))
                    path.addSparkle(center: unit.point(86, 14), radius: unit.length(6))
                    path.addSparkle(center: unit.point(90, 46), radius: unit.length(4))
                }
                .fill(Color.white)
            case .sleepy:
                ZStack {
                    Text("z")
                        .font(.system(size: side * 0.16, weight: .bold, design: .rounded))
                        .position(x: side * 0.78, y: side * 0.24)
                    Text("z")
                        .font(.system(size: side * 0.11, weight: .bold, design: .rounded))
                        .position(x: side * 0.88, y: side * 0.1)
                }
                .foregroundStyle(Color.white.opacity(0.9))
            case .rich:
                GlodCoin(label: "+1")
                    .frame(width: side * 0.22, height: side * 0.22)
                    .position(x: side * 0.82, y: side * 0.74)
            case .content, .waiting:
                EmptyView()
            }
        }
    }
}

/// A gold coin. Used for Glóð's banked credits.
public struct GlodCoin: View {
    public var label: String?

    public init(label: String? = nil) {
        self.label = label
    }

    public var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [GlodPalette.coinLight, GlodPalette.coin, GlodPalette.coinEdge],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: side * 0.6
                    ))
                Circle()
                    .strokeBorder(GlodPalette.coinEdge.opacity(0.8), lineWidth: max(1, side * 0.08))
                if let label {
                    Text(label)
                        .font(.system(size: side * 0.42, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(glodHex: 0x8A5A00))
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct GlodFlameShape: Shape {
    var inset: Bool
    var sway: Double

    var animatableData: Double {
        get { sway }
        set { sway = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let unit = GlodUnit(rect: rect)
        let lean = sway * 8
        var path = Path()
        if inset {
            path.move(to: unit.point(50 + lean * 0.6, 24))
            path.addCurve(to: unit.point(72, 62), control1: unit.point(56 + lean * 0.4, 36), control2: unit.point(72, 44))
            path.addCurve(to: unit.point(50, 86), control1: unit.point(72, 76), control2: unit.point(62, 86))
            path.addCurve(to: unit.point(28, 62), control1: unit.point(38, 86), control2: unit.point(28, 76))
            path.addCurve(to: unit.point(40, 38), control1: unit.point(28, 50), control2: unit.point(36, 44))
            path.addCurve(to: unit.point(50 + lean * 0.6, 24), control1: unit.point(44, 44), control2: unit.point(48, 44))
        } else {
            path.move(to: unit.point(50 + lean, 6))
            path.addCurve(to: unit.point(80, 60), control1: unit.point(58 + lean * 0.6, 24), control2: unit.point(80, 34))
            path.addCurve(to: unit.point(50, 92), control1: unit.point(80, 80), control2: unit.point(66, 92))
            path.addCurve(to: unit.point(20, 60), control1: unit.point(34, 92), control2: unit.point(20, 80))
            path.addCurve(to: unit.point(34 + lean * 0.4, 26), control1: unit.point(20, 44), control2: unit.point(30, 36))
            path.addCurve(to: unit.point(44, 38), control1: unit.point(38, 34), control2: unit.point(42, 38))
            path.addCurve(to: unit.point(50 + lean, 6), control1: unit.point(44, 26), control2: unit.point(46, 16))
        }
        path.closeSubpath()
        return path
    }
}

struct GlodUnitShape: Shape {
    var draw: @Sendable (inout Path, GlodUnit) -> Void

    func path(in rect: CGRect) -> Path {
        var path = Path()
        draw(&path, GlodUnit(rect: rect))
        return path
    }
}

struct GlodUnit {
    var rect: CGRect

    func point(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: rect.minX + x / 100 * rect.width, y: rect.minY + y / 100 * rect.height)
    }

    func length(_ value: Double) -> CGFloat {
        value / 100 * min(rect.width, rect.height)
    }

    func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> CGRect {
        CGRect(origin: point(x, y), size: CGSize(width: width / 100 * rect.width, height: height / 100 * rect.height))
    }
}

private extension Path {
    mutating func addSparkle(center: CGPoint, radius: CGFloat) {
        let waist = radius * 0.3
        move(to: CGPoint(x: center.x, y: center.y - radius))
        addLine(to: CGPoint(x: center.x + waist, y: center.y - waist))
        addLine(to: CGPoint(x: center.x + radius, y: center.y))
        addLine(to: CGPoint(x: center.x + waist, y: center.y + waist))
        addLine(to: CGPoint(x: center.x, y: center.y + radius))
        addLine(to: CGPoint(x: center.x - waist, y: center.y + waist))
        addLine(to: CGPoint(x: center.x - radius, y: center.y))
        addLine(to: CGPoint(x: center.x - waist, y: center.y - waist))
        closeSubpath()
    }
}

extension Color {
    init(glodHex hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
#endif
