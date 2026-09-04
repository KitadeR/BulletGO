import SwiftUI

struct BaggageMeasurementDiagram: View {
    var body: some View {
        Canvas { context, size in
            let bodyRect = CGRect(
                x: size.width * 0.22,
                y: size.height * 0.22,
                width: size.width * 0.52,
                height: size.height * 0.48
            )
            context.fill(
                Path(roundedRect: bodyRect, cornerRadius: 10),
                with: .color(DesignTokens.Color.tint.opacity(0.18))
            )
            context.stroke(
                Path(roundedRect: bodyRect, cornerRadius: 10),
                with: .color(DesignTokens.Color.tint),
                lineWidth: 3
            )

            let handle = Path(roundedRect: CGRect(
                x: size.width * 0.38,
                y: size.height * 0.08,
                width: size.width * 0.20,
                height: size.height * 0.12
            ), cornerRadius: 8)
            context.stroke(handle, with: .color(DesignTokens.Color.tint), lineWidth: 3)

            for offset in [0.28, 0.62] as [CGFloat] {
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: size.width * offset,
                        y: size.height * 0.70,
                        width: size.width * 0.10,
                        height: size.height * 0.12
                    )),
                    with: .color(DesignTokens.Color.tint.opacity(0.7))
                )
            }

            var heightLine = Path()
            heightLine.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.08))
            heightLine.addLine(to: CGPoint(x: size.width * 0.12, y: size.height * 0.82))
            context.stroke(heightLine, with: .color(DesignTokens.Color.primaryText.opacity(0.55)), lineWidth: 2)

            var lengthLine = Path()
            lengthLine.move(to: CGPoint(x: size.width * 0.22, y: size.height * 0.90))
            lengthLine.addLine(to: CGPoint(x: size.width * 0.74, y: size.height * 0.90))
            context.stroke(lengthLine, with: .color(DesignTokens.Color.primaryText.opacity(0.55)), lineWidth: 2)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .background(
            DesignTokens.Color.grouped,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
        )
        .accessibilityHidden(true)
    }
}
