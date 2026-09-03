import SwiftUI

struct JourneyArtwork: View {
    var kind: JourneyVisualKind
    var isCompact: Bool = false

    var body: some View {
        Canvas { context, size in
            drawSky(context: &context, size: size)
            switch kind {
            case .shinkansen:
                drawFuji(context: &context, size: size)
                drawShinkansen(context: &context, size: size)
            case .airplane:
                drawHills(context: &context, size: size)
                drawPlane(context: &context, size: size)
            case .localTrain:
                drawHills(context: &context, size: size)
                drawLocalTrain(context: &context, size: size)
            case .cityStay:
                drawCity(context: &context, size: size)
            case .generic:
                drawHills(context: &context, size: size)
                drawPath(context: &context, size: size)
            }
        }
        .accessibilityHidden(true)
        .frame(minHeight: isCompact ? 88 : 168)
    }

    private func drawSky(context: inout GraphicsContext, size: CGSize) {
        let sky = Gradient(colors: [DesignTokens.Color.heroSkyTop, DesignTokens.Color.heroSkyBottom])
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(sky, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
        )
    }

    private func drawFuji(context: inout GraphicsContext, size: CGSize) {
        var mountain = Path()
        mountain.move(to: CGPoint(x: size.width * 0.18, y: size.height * 0.78))
        mountain.addLine(to: CGPoint(x: size.width * 0.48, y: size.height * 0.22))
        mountain.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.78))
        context.fill(mountain, with: .color(Color.white.opacity(0.55)))
        var snow = Path()
        snow.move(to: CGPoint(x: size.width * 0.40, y: size.height * 0.36))
        snow.addLine(to: CGPoint(x: size.width * 0.48, y: size.height * 0.22))
        snow.addLine(to: CGPoint(x: size.width * 0.56, y: size.height * 0.36))
        context.fill(snow, with: .color(.white.opacity(0.92)))
    }

    private func drawHills(context: inout GraphicsContext, size: CGSize) {
        var hill = Path()
        hill.move(to: CGPoint(x: 0, y: size.height * 0.72))
        hill.addQuadCurve(
            to: CGPoint(x: size.width, y: size.height * 0.68),
            control: CGPoint(x: size.width * 0.45, y: size.height * 0.52)
        )
        hill.addLine(to: CGPoint(x: size.width, y: size.height))
        hill.addLine(to: CGPoint(x: 0, y: size.height))
        context.fill(hill, with: .color(DesignTokens.Color.tint.opacity(0.18)))
    }

    private func drawShinkansen(context: inout GraphicsContext, size: CGSize) {
        let y = size.height * 0.70
        var rail = Path()
        rail.move(to: CGPoint(x: 0, y: y + 18))
        rail.addLine(to: CGPoint(x: size.width, y: y + 18))
        context.stroke(rail, with: .color(.primary.opacity(0.18)), lineWidth: 3)

        let body = RoundedRectangle(cornerRadius: 18, style: .continuous)
            .path(in: CGRect(x: size.width * 0.16, y: y - 18, width: size.width * 0.62, height: 36))
        context.fill(body, with: .color(.white.opacity(0.92)))
        context.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.70, y: y - 14, width: 34, height: 28)),
            with: .color(.white.opacity(0.92))
        )
        context.fill(
            Path(CGRect(x: size.width * 0.22, y: y - 6, width: size.width * 0.42, height: 8)),
            with: .color(DesignTokens.Color.tint)
        )
    }

    private func drawLocalTrain(context: inout GraphicsContext, size: CGSize) {
        let y = size.height * 0.68
        let body = RoundedRectangle(cornerRadius: 10, style: .continuous)
            .path(in: CGRect(x: size.width * 0.18, y: y - 16, width: size.width * 0.58, height: 32))
        context.fill(body, with: .color(.white.opacity(0.9)))
        for index in 0..<3 {
            let x = size.width * 0.24 + CGFloat(index) * size.width * 0.14
            context.fill(
                Path(roundedRect: CGRect(x: x, y: y - 8, width: 22, height: 12), cornerRadius: 3),
                with: .color(DesignTokens.Color.heroSkyTop.opacity(0.8))
            )
        }
    }

    private func drawPlane(context: inout GraphicsContext, size: CGSize) {
        var plane = Path()
        plane.move(to: CGPoint(x: size.width * 0.20, y: size.height * 0.48))
        plane.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.38))
        plane.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.44))
        plane.addLine(to: CGPoint(x: size.width * 0.28, y: size.height * 0.58))
        context.fill(plane, with: .color(.white.opacity(0.9)))
    }

    private func drawCity(context: inout GraphicsContext, size: CGSize) {
        let bases: [(CGFloat, CGFloat, CGFloat)] = [
            (0.12, 0.42, 0.18),
            (0.32, 0.28, 0.16),
            (0.50, 0.36, 0.20),
            (0.72, 0.48, 0.14),
        ]
        for (x, top, width) in bases {
            context.fill(
                Path(roundedRect: CGRect(
                    x: size.width * x,
                    y: size.height * top,
                    width: size.width * width,
                    height: size.height * (0.92 - top)
                ), cornerRadius: 6),
                with: .color(.white.opacity(0.78))
            )
        }
    }

    private func drawPath(context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.82))
        path.addQuadCurve(
            to: CGPoint(x: size.width * 0.88, y: size.height * 0.74),
            control: CGPoint(x: size.width * 0.48, y: size.height * 0.58)
        )
        context.stroke(path, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
    }
}

struct JourneyHero: View {
    var title: String
    var subtitle: String?
    var kind: JourneyVisualKind

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            JourneyArtwork(kind: kind)
            LinearGradient(
                colors: [.clear, DesignTokens.Color.canvas.opacity(0.92)],
                startPoint: .center,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(verbatim: title)
                    .font(DesignTokens.Typography.display)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.hero, style: .continuous))
    }
}
