import Combine
import SwiftUI

/// The 2D baker avatar, drawn with SwiftUI shapes - a direct port of the React
/// Native AvatarFace exactly like it ports the website's SVG avatar.
struct AssistantAvatar: View {
    let mood: AssistantMood
    var size: CGFloat = 64

    @State private var blinking = false
    @State private var mouthOpen = false

    private let blinkTimer = Timer.publish(every: 3.2, on: .main, in: .common).autoconnect()
    private let mouthTimer = Timer.publish(every: 0.16, on: .main, in: .common).autoconnect()

    private let eyeColor = Color(hex: 0x3B2A22)
    private let mouthColor = Color(hex: 0xA23E4A)
    private let skinColor = Color(hex: 0xF7D5BD)
    private let hairColor = Color(hex: 0x6B4130)

    private var eyeY: CGFloat { mood == .thinking ? 64 : 67 }
    private var pupilY: CGFloat { mood == .thinking ? 62.6 : 65.6 }
    private var browY: CGFloat { mood == .listening ? 58 : 59 }

    var body: some View {
        ZStack {
            backdrop
            HairShape().fill(hairColor)
            face
            HatShape().fill(Color.white)
            HatShape().stroke(Palette.border, lineWidth: 1.5)
            HatBandShape().fill(Color.white)
            HatBandShape().stroke(Palette.primary, lineWidth: 1.5)
            hatButton
            eyes
            brows
            cheeks
            mouth
            thinkingDots
        }
        .frame(width: 120, height: 120)
        .scaleEffect(size / 120)
        .frame(width: size, height: size)
        .onReceive(blinkTimer) { _ in blink() }
        .onReceive(mouthTimer) { _ in
            guard mood == .speaking else { return }
            mouthOpen.toggle()
        }
        .onChange(of: mood) { newValue in
            if newValue != .speaking { mouthOpen = false }
        }
        .accessibilityLabel("Sprinkles, the Crazy Cakes assistant")
    }

    private var backdrop: some View {
        ZStack {
            Circle().fill(Palette.blush)
            Circle().strokeBorder(Palette.primary, lineWidth: 3)
        }
        .frame(width: 114, height: 114)
    }

    private var face: some View {
        Ellipse()
            .fill(skinColor)
            .frame(width: 50, height: 54)
            .position(x: 60, y: 70)
    }

    private var hatButton: some View {
        Circle()
            .fill(Palette.primary)
            .frame(width: 4, height: 4)
            .position(x: 60, y: 48)
    }

    private var eyes: some View {
        ZStack {
            Ellipse()
                .fill(eyeColor)
                .frame(width: 6.6, height: blinking ? 1.2 : 8)
                .position(x: 50, y: eyeY)
            Ellipse()
                .fill(eyeColor)
                .frame(width: 6.6, height: blinking ? 1.2 : 8)
                .position(x: 70, y: eyeY)

            if !blinking {
                Circle()
                    .fill(Color.white)
                    .frame(width: 2.2, height: 2.2)
                    .position(x: 51.2, y: pupilY)
                Circle()
                    .fill(Color.white)
                    .frame(width: 2.2, height: 2.2)
                    .position(x: 71.2, y: pupilY)
            }
        }
    }

    private var brows: some View {
        BrowsShape(listening: mood == .listening, browY: browY)
            .stroke(hairColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private var cheeks: some View {
        ZStack {
            Circle()
                .fill(Palette.primary)
                .frame(width: 9, height: 9)
                .position(x: 44, y: 78)
                .opacity(0.35)
            Circle()
                .fill(Palette.primary)
                .frame(width: 9, height: 9)
                .position(x: 76, y: 78)
                .opacity(0.35)
        }
    }

    @ViewBuilder
    private var mouth: some View {
        if mood == .speaking {
            Ellipse()
                .fill(mouthColor)
                .frame(width: 12, height: mouthOpen ? 10 : 3.2)
                .position(x: 60, y: 85)
        } else if mood == .listening {
            Ellipse()
                .fill(mouthColor)
                .frame(width: 7, height: 6)
                .position(x: 60, y: 85)
        } else {
            SmileShape()
                .stroke(mouthColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }

    private var thinkingDots: some View {
        Group {
            if mood == .thinking {
                ZStack {
                    Circle().fill(Palette.primary).frame(width: 6, height: 6).position(x: 88, y: 30)
                    Circle().fill(Palette.primary).frame(width: 7, height: 7).position(x: 97, y: 24)
                    Circle().fill(Palette.primary).frame(width: 8, height: 8).position(x: 107, y: 17)
                }
            }
        }
    }

    private func blink() {
        blinking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            blinking = false
        }
    }
}

// MARK: - Shapes (SVG paths from avatar-face.tsx, in the 120x120 viewBox)

private struct HairShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 30, y: 70))
        path.addCurve(to: CGPoint(x: 60, y: 32), control1: CGPoint(x: 30, y: 46), control2: CGPoint(x: 43, y: 32))
        path.addCurve(to: CGPoint(x: 90, y: 70), control1: CGPoint(x: 77, y: 32), control2: CGPoint(x: 107, y: 46))
        path.addLine(to: CGPoint(x: 90, y: 86))
        path.addCurve(to: CGPoint(x: 81, y: 62), control1: CGPoint(x: 84, y: 82), control2: CGPoint(x: 81, y: 72))
        path.addCurve(to: CGPoint(x: 39, y: 62), control1: CGPoint(x: 70, y: 68), control2: CGPoint(x: 50, y: 69))
        path.addCurve(to: CGPoint(x: 30, y: 86), control1: CGPoint(x: 39, y: 72), control2: CGPoint(x: 36, y: 82))
        path.closeSubpath()
        return path
    }
}

private struct HatShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 37, y: 44))
        path.addCurve(to: CGPoint(x: 33, y: 26), control1: CGPoint(x: 28, y: 43), control2: CGPoint(x: 25, y: 31))
        path.addCurve(to: CGPoint(x: 52, y: 23), control1: CGPoint(x: 36, y: 17), control2: CGPoint(x: 48, y: 16))
        path.addCurve(to: CGPoint(x: 72, y: 23), control1: CGPoint(x: 57, y: 16), control2: CGPoint(x: 68, y: 16))
        path.addCurve(to: CGPoint(x: 87, y: 32), control1: CGPoint(x: 79, y: 19), control2: CGPoint(x: 88, y: 24))
        path.addCurve(to: CGPoint(x: 82, y: 45), control1: CGPoint(x: 94, y: 36), control2: CGPoint(x: 90, y: 46))
        path.addLine(to: CGPoint(x: 82, y: 52))
        path.addLine(to: CGPoint(x: 37, y: 52))
        path.closeSubpath()
        return path
    }
}

private struct HatBandShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: CGRect(x: 36, y: 44, width: 48, height: 8), cornerRadius: 2.5)
    }
}

private struct BrowsShape: Shape {
    let listening: Bool
    let browY: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if listening {
            path.move(to: CGPoint(x: 44, y: 58))
            path.addQuadCurve(to: CGPoint(x: 55, y: 58), control: CGPoint(x: 50, y: 54))
            path.move(to: CGPoint(x: 65, y: 58))
            path.addQuadCurve(to: CGPoint(x: 76, y: 58), control: CGPoint(x: 70, y: 54))
        } else {
            path.move(to: CGPoint(x: 45, y: browY))
            path.addQuadCurve(to: CGPoint(x: 55, y: browY), control: CGPoint(x: 50, y: browY - 3))
            path.move(to: CGPoint(x: 65, y: browY))
            path.addQuadCurve(to: CGPoint(x: 75, y: browY), control: CGPoint(x: 70, y: browY - 3))
        }
        return path
    }
}

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 51, y: 83))
        path.addQuadCurve(to: CGPoint(x: 69, y: 83), control: CGPoint(x: 60, y: 91))
        return path
    }
}
