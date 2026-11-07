import SwiftUI

/// The single, stateless eye renderer used by the app and every Live Activity presentation.
nonisolated struct EyeView: View {
    var diameter: CGFloat
    /// Normalized -1...1 in each axis; clamped to the unit circle.
    var pupilOffset: CGVector = .zero
    var isClosed: Bool = false
    var isRed: Bool = false
    /// In-app only: the 85%+ "getting tired" look.
    var isTiring: Bool = false

    var body: some View {
        let s = diameter
        let pupilD = s * EyeStyle.pupilRatio
        let offset = clamped(pupilOffset)
        let showsRed = isRed
        let tiring = isTiring && !isRed

        ZStack(alignment: .topLeading) {
            Rectangle().fill(sclera(showsRed, tiring))

            // Pupil + highlight
            Circle()
                .fill(EyeStyle.pupil)
                .frame(width: pupilD, height: pupilD)
                .overlay(alignment: .topLeading) {
                    if s >= EyeStyle.highlightMinDiameter && !isClosed {
                        let h = pupilD * EyeStyle.highlightRatio
                        Circle().fill(.white)
                            .frame(width: h, height: h)
                            .offset(x: pupilD * 0.56, y: pupilD * 0.14)
                    }
                }
                .offset(
                    x: (s - pupilD) / 2 + offset.dx * s * EyeStyle.maxTravel,
                    y: (s - pupilD) / 2 + offset.dy * s * EyeStyle.maxTravel
                )

            // Tired / red upper lid
            let lidH = showsRed ? s * EyeStyle.redLidRatio : tiring ? s * EyeStyle.tiringLidRatio : 0
            if lidH > 0 && !isClosed {
                let lidLine = max(EyeStyle.minRim, s * 0.04)
                LidShape()
                    .fill(showsRed ? EyeStyle.accent : EyeStyle.lidTiring)
                    .frame(width: s, height: lidH)
                LidShape.edge
                    .stroke(showsRed ? EyeStyle.lashRed : EyeStyle.rimTiring, lineWidth: lidLine)
                    .frame(width: s, height: lidH)
            }

            // Rim
            if showsRed || tiring {
                let rim = showsRed
                    ? max(EyeStyle.minRim, s * EyeStyle.redRimRatio)
                    : max(0.75, s * EyeStyle.tiringRimRatio)
                Circle()
                    .strokeBorder(showsRed ? EyeStyle.accent : EyeStyle.rimTiring, lineWidth: rim)
                    .frame(width: s, height: s)
            }

            // Closed: eyelid covers the eye, lash curve on top
            if isClosed {
                Rectangle().fill(showsRed ? EyeStyle.shutRed : EyeStyle.shutWhite)
                LashShape()
                    .stroke(
                        showsRed ? EyeStyle.lashRed : EyeStyle.lashWhite,
                        style: StrokeStyle(
                            lineWidth: max(EyeStyle.lashMinWidth, s * EyeStyle.lashRatio),
                            lineCap: .butt
                        )
                    )
                    .frame(width: s * 0.64, height: s * 0.28)
                    .offset(x: s * 0.18, y: s * 0.3)
            }
        }
        .frame(width: s, height: s, alignment: .topLeading)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private func sclera(_ red: Bool, _ tiring: Bool) -> Color {
        red ? EyeStyle.scleraRed : tiring ? EyeStyle.scleraTiring : EyeStyle.sclera
    }

    private func clamped(_ v: CGVector) -> CGVector {
        let m = (v.dx * v.dx + v.dy * v.dy).squareRoot()
        guard m > 1 else { return v }
        return CGVector(dx: v.dx / m, dy: v.dy / m)
    }
}

/// Flat top, curved bottom edge (matches the design's `0 0 50% 50% / 0 0 40% 40%` lid).
private nonisolated struct LidShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.height * 0.6))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.height * 0.6),
            control: CGPoint(x: rect.midX, y: rect.height * 1.4)
        )
        p.closeSubpath()
        return p
    }

    /// Just the curved bottom edge, for stroking.
    static var edge: some Shape { Edge() }

    private struct Edge: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.maxX, y: rect.height * 0.6))
            p.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.height * 0.6),
                control: CGPoint(x: rect.midX, y: rect.height * 1.4)
            )
            return p
        }
    }
}

/// The closed-eye lash: a downward smile arc.
private nonisolated struct LashShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY * 2 - rect.minY)
        )
        return p
    }
}

#Preview("Eye states × sizes") {
    let states: [(String, Bool, Bool)] = [
        ("Open", false, false), ("Closed", true, false),
        ("Red", false, true), ("Red+closed", true, true)
    ]
    VStack(alignment: .leading, spacing: 16) {
        ForEach(states, id: \.0) { name, closed, red in
            HStack(alignment: .center, spacing: 16) {
                Text(name).font(.caption).foregroundStyle(.white).frame(width: 80, alignment: .leading)
                ForEach([14.0, 24.0, 60.0, 90.0], id: \.self) { d in
                    EyeView(diameter: d, isClosed: closed, isRed: red)
                }
            }
        }
        Text("Pupil positions").font(.caption).foregroundStyle(.white)
        HStack(spacing: 16) {
            ForEach([CGVector.zero, CGVector(dx: -1, dy: 0), CGVector(dx: 1, dy: 0),
                     CGVector(dx: 0, dy: -1), CGVector(dx: 0, dy: 1)], id: \.dx) { v in
                EyeView(diameter: 60, pupilOffset: v)
            }
        }
        HStack(spacing: 16) {
            EyeView(diameter: 60, isTiring: true)
            EyeView(diameter: 60, pupilOffset: CGVector(dx: 0, dy: 1), isRed: true)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
}
