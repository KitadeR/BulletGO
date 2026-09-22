import SwiftUI
import UIKit

enum GuidedAddPalette {
    static var canvas: Color { DesignTokens.Color.canvas }
    static var card: Color { DesignTokens.Color.elevated }
    static var mutedFill: Color { DesignTokens.Color.grouped }
    static var inputStroke: Color { DesignTokens.Color.inputStroke }
    static var primaryText: Color { DesignTokens.Color.primaryText }
    static var secondaryText: Color { DesignTokens.Color.secondaryText }
    static var ctaFill: Color { DesignTokens.Color.ctaFill }
    static var ctaText: Color { DesignTokens.Color.ctaText }
    static var ctaDisabledFill: Color { DesignTokens.Color.ctaDisabledFill }
    static var ctaDisabledText: Color { DesignTokens.Color.ctaDisabledText }
}

enum GuidedAddMotion {
    static let card = Animation.spring(duration: 0.44, bounce: 0.06)

    static func card(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: DesignTokens.Motion.quick) : card
    }

    static var step: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
}

enum GuidedAddFactAccessory {
    case check
    case chevron
    case none
}

enum GuidedAddMetrics {
    static let horizontal: CGFloat = 20
    static let cardRadius: CGFloat = 18
    static let inputRadius: CGFloat = 12
    static let howRadius: CGFloat = 14
    static let ctaRadius: CGFloat = 22
    static let chipRadius: CGFloat = 21
    static let dateCell: CGFloat = 36
    static let inputHeight: CGFloat = 52
    static let ctaHeight: CGFloat = 44
    static let howHeight: CGFloat = 74
    static let compactEmpty: CGFloat = 78
    static let compactSelected: CGFloat = 82
    static let summaryHeight: CGFloat = 70
    static let reviewHeight: CGFloat = 62
    static let clockHeight: CGFloat = 150
    static let transportIcon = CGSize(width: 44, height: 36)
}

enum GuidedAddCopy {
    static func dateText(_ date: Date) -> String {
        formatter("M月d日").string(from: date)
    }

    static func monthText(_ date: Date) -> String {
        formatter("yyyy年M月").string(from: date)
    }

    static func clockText(_ date: Date) -> String {
        formatter("HH:mm").string(from: date)
    }

    static func weekdaySymbols() -> [String] {
        ["日", "月", "火", "水", "木", "金", "土"]
    }

    static func placeSubtitle(address: String?, category: String?) -> String {
        PlaceDisplayFormatting.guidedAddSubtitle(address: address, category: category)
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = tokyoCalendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TripCalendar.timeZone
        formatter.dateFormat = format
        return formatter
    }

    static var tokyoCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TripCalendar.timeZone
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.firstWeekday = 1
        return calendar
    }
}

struct GuidedAddChrome<Content: View>: View {
    var title: LocalizedStringResource
    var subtitle: String? = nil
    var isFirst: Bool
    var showsCTA: Bool
    var ctaTitle: LocalizedStringResource
    var ctaEnabled: Bool
    var ctaBusy: Bool
    var ctaID: String
    var onCancel: () -> Void
    var onBack: () -> Void
    var onCTA: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(GuidedAddPalette.canvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsCTA {
                PrimaryCTA(
                    title: ctaTitle,
                    isEnabled: ctaEnabled,
                    isBusy: ctaBusy,
                    accessibilityID: ctaID,
                    action: onCTA
                )
                .padding(.horizontal, GuidedAddMetrics.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(GuidedAddPalette.canvas)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(GuidedAddMotion.card(reduceMotion), value: showsCTA)
        .animation(GuidedAddMotion.card(reduceMotion), value: String(localized: title))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isFirst {
                Button("キャンセル", action: onCancel)
                    .font(DesignTokens.Typography.callout)
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                    .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
                    .accessibilityIdentifier(AccessibilityID.guidedAddCancel)
            } else {
                Button(action: onBack) {
                    Text("‹")
                        .font(.system(size: 27, weight: .regular))
                        .foregroundStyle(GuidedAddPalette.primaryText)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier(AccessibilityID.guidedAddBack)
            }
            Text(title)
                .font(isFirst ? DesignTokens.Typography.title : Font.title.weight(.semibold))
                .foregroundStyle(GuidedAddPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            if let subtitle, !subtitle.isEmpty {
                Text(verbatim: subtitle)
                    .font(DesignTokens.Typography.callout)
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, GuidedAddMetrics.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

struct GuidedAddCTA: View {
    var title: LocalizedStringResource
    var isEnabled: Bool
    var isBusy: Bool
    var accessibilityID: String
    var action: () -> Void

    var body: some View {
        PrimaryCTA(
            title: title,
            isEnabled: isEnabled,
            isBusy: isBusy,
            accessibilityID: accessibilityID,
            action: action
        )
    }
}

struct GuidedAddCard<Content: View>: View {
    var radius: CGFloat = GuidedAddMetrics.cardRadius
    var fill: Color = GuidedAddPalette.card
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct GuidedAddInnerSearchField: View {
    var title: LocalizedStringKey
    @Binding var text: String
    var accessibilityID: String
    var focused: FocusState<Bool>.Binding
    var onSubmit: () -> Void

    var body: some View {
        TextField(title, text: $text)
            .textInputAutocapitalization(.words)
            .submitLabel(.search)
            .font(DesignTokens.Typography.headline)
            .foregroundStyle(GuidedAddPalette.primaryText)
            .padding(.horizontal, 14)
            .frame(height: GuidedAddMetrics.inputHeight)
            .background(
                GuidedAddPalette.canvas,
                in: RoundedRectangle(cornerRadius: GuidedAddMetrics.inputRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: GuidedAddMetrics.inputRadius, style: .continuous)
                    .stroke(GuidedAddPalette.inputStroke, lineWidth: 1)
            }
            .focused(focused)
            .accessibilityLabel(Text(title))
            .accessibilityHint("Search places")
            .accessibilityIdentifier(accessibilityID)
            .onSubmit(onSubmit)
    }
}

struct GuidedAddCheck: View {
    var body: some View {
        Text("✓")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(GuidedAddPalette.primaryText)
            .accessibilityHidden(true)
    }
}

struct GuidedAddRouteArrow: View {
    var body: some View {
        Text("↓")
            .font(.system(size: 24))
            .foregroundStyle(GuidedAddPalette.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .accessibilityHidden(true)
    }
}

struct GuidedAddReviewRow: View {
    var title: LocalizedStringKey
    var value: String
    var accessibilityID: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(GuidedAddPalette.secondaryText)
                    Text(verbatim: value)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(GuidedAddPalette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("›")
                    .font(.system(size: 22))
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: GuidedAddMetrics.reviewHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(GuidedAddPalette.card, in: RoundedRectangle(cornerRadius: GuidedAddMetrics.cardRadius, style: .continuous))
        .accessibilityIdentifier(accessibilityID)
    }
}

struct GuidedAddSummaryCard: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(GuidedAddPalette.primaryText)
            Text(verbatim: subtitle)
                .font(DesignTokens.Typography.footnote)
                .foregroundStyle(GuidedAddPalette.secondaryText)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: GuidedAddMetrics.summaryHeight, alignment: .leading)
        .background(GuidedAddPalette.card, in: RoundedRectangle(cornerRadius: GuidedAddMetrics.cardRadius, style: .continuous))
    }
}

struct GuidedAddCompactFact: View {
    var title: LocalizedStringKey
    var value: String
    var accessory: GuidedAddFactAccessory = .check
    var accessibilityID: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DesignTokens.Typography.footnote)
                        .foregroundStyle(GuidedAddPalette.secondaryText)
                    Text(verbatim: value)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(GuidedAddPalette.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                accessoryView
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(GuidedAddPalette.card, in: RoundedRectangle(cornerRadius: GuidedAddMetrics.cardRadius, style: .continuous))
        .accessibilityIdentifier(accessibilityID)
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .check:
            GuidedAddCheck()
        case .chevron:
            Text("›")
                .font(.system(size: 22))
                .foregroundStyle(GuidedAddPalette.secondaryText)
                .accessibilityHidden(true)
        case .none:
            EmptyView()
        }
    }
}

struct GuidedAddDateGrid: View {
    var month: Date
    var selected: Date?
    var onSelect: (Date) -> Void
    var onChangeMonth: (Int) -> Void

    private var calendar: Calendar { GuidedAddCopy.tokyoCalendar }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(verbatim: GuidedAddCopy.monthText(month))
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(GuidedAddPalette.primaryText)
                Spacer()
                Button {
                    onChangeMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: DesignTokens.TapTarget.minimum, height: DesignTokens.TapTarget.minimum)
                }
                .accessibilityLabel("Previous month")
                Button {
                    onChangeMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: DesignTokens.TapTarget.minimum, height: DesignTokens.TapTarget.minimum)
                }
                .accessibilityLabel("Next month")
            }
            .foregroundStyle(GuidedAddPalette.primaryText)

            HStack(spacing: 0) {
                ForEach(GuidedAddCopy.weekdaySymbols(), id: \.self) { symbol in
                    Text(verbatim: symbol)
                        .font(DesignTokens.Typography.footnote)
                        .foregroundStyle(GuidedAddPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 18) {
                ForEach(days, id: \.self) { day in
                    dateCell(day)
                }
            }

            if selected == nil {
                Text("日付を選ぶ")
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(GuidedAddPalette.secondaryText)
            }
        }
        .accessibilityIdentifier(AccessibilityID.guidedAddDate)
    }

    private var days: [Date] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        guard
            let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart),
            let range = calendar.range(of: .day, in: .month, for: monthStart)
        else {
            return []
        }
        let total = Int(ceil(Double(leading + range.count) / 7.0) * 7.0)
        return (0..<total).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    @ViewBuilder
    private func dateCell(_ date: Date) -> some View {
        let inMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
        let isSelected = selected.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        Button {
            onSelect(date)
        } label: {
            Text(verbatim: "\(calendar.component(.day, from: date))")
                .font(DesignTokens.Typography.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? GuidedAddPalette.ctaText : GuidedAddPalette.primaryText)
                .frame(width: GuidedAddMetrics.dateCell, height: GuidedAddMetrics.dateCell)
                .background(
                    isSelected ? GuidedAddPalette.ctaFill : GuidedAddPalette.canvas,
                    in: Circle()
                )
                .opacity(inMonth ? 1 : 0.35)
        }
        .disabled(!inMonth)
        .accessibilityLabel(Text(date, format: .dateTime.year().month().day()))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier(dateCellID(date))
    }

    private func dateCellID(_ date: Date) -> String {
        guard let local = try? LocalDate(date: date, timeZone: TripCalendar.timeZone) else {
            return AccessibilityID.guidedAddDate
        }
        return AccessibilityID.guidedAddDateCell(local)
    }
}

struct GuidedAddClockWheel: View {
    @Binding var hour: Int
    @Binding var minute: Int
    var onInteract: () -> Void

    private let hours = Array(0..<24)
    private let minutes = Array(stride(from: 0, through: 50, by: 10))

    var body: some View {
        ZStack {
            Capsule()
                .fill(GuidedAddPalette.canvas)
                .frame(height: 48)
            HStack(spacing: 0) {
                GuidedAddClockColumn(
                    values: hours,
                    selection: $hour,
                    onInteract: onInteract,
                    incrementID: AccessibilityID.guidedAddClockHourNext
                )
                .accessibilityIdentifier(AccessibilityID.guidedAddClockHour)
                GuidedAddClockColumn(values: minutes, selection: $minute, onInteract: onInteract)
                    .accessibilityIdentifier(AccessibilityID.guidedAddClockMinute)
            }
        }
        .frame(height: GuidedAddMetrics.clockHeight)
        .clipped()
        .accessibilityIdentifier(AccessibilityID.guidedAddClock)
    }
}

private struct GuidedAddClockColumn: View {
    var values: [Int]
    @Binding var selection: Int
    var onInteract: () -> Void
    var incrementID: String? = nil

    @State private var dragOffset: CGFloat = 0
    @State private var gestureStartIndex: Int?

    private let rowHeight: CGFloat = 50

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Text(label(value(at: -1)))
                    .font(.system(size: 19))
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: rowHeight)
                    .accessibilityLabel("Previous value")
                    .accessibilityAddTraits(.isButton)
                    .onTapGesture { move(-1) }
                Text(label(selection))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(GuidedAddPalette.primaryText)
                    .frame(maxWidth: .infinity, minHeight: 48)
                Text(label(value(at: 1)))
                    .font(.system(size: 19))
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: rowHeight)
                    .accessibilityLabel("Next value")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier(incrementID ?? "guided-add-clock-next")
                    .onTapGesture { move(1) }
            }
            .offset(y: dragOffset)
            GuidedAddClockPanCatcher(
                onChanged: handlePan(translation:),
                onEnded: endPan(translation:),
                onTap: handleTap(point:size:)
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: GuidedAddMetrics.clockHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityValue(Text(verbatim: label(selection)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: move(1)
            case .decrement: move(-1)
            default: break
            }
        }
    }

    private var index: Int {
        values.firstIndex(of: selection) ?? 0
    }

    private func value(at delta: Int) -> Int {
        values[(index + delta + values.count) % values.count]
    }

    private func label(_ value: Int) -> String {
        String(format: "%02d", value)
    }

    private func move(_ delta: Int) {
        let nextIndex = (index + delta + values.count) % values.count
        selection = values[nextIndex]
        onInteract()
    }

    private func handlePan(translation: CGFloat) {
        if gestureStartIndex == nil {
            gestureStartIndex = index
        }
        let steps = Int((-translation / rowHeight).rounded())
        let start = gestureStartIndex ?? index
        let nextIndex = (start + steps + values.count * 8) % values.count
        dragOffset = translation + CGFloat(steps) * rowHeight
        if values[nextIndex] != selection {
            selection = values[nextIndex]
            onInteract()
        }
    }

    private func endPan(translation: CGFloat) {
        handlePan(translation: translation)
        gestureStartIndex = nil
        withAnimation(.easeOut(duration: 0.18)) {
            dragOffset = 0
        }
    }

    private func handleTap(point: CGPoint, size: CGSize) {
        if point.y < size.height / 3 {
            move(-1)
        } else if point.y > size.height * 2 / 3 {
            move(1)
        }
    }
}

private struct GuidedAddClockPanCatcher: UIViewRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat) -> Void
    var onTap: (CGPoint, CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded, onTap: onTap)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.cancelsTouchesInView = true
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        context.coordinator.host = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.onTap = onTap
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat) -> Void
        var onTap: (CGPoint, CGSize) -> Void
        weak var host: UIView?

        init(onChanged: @escaping (CGFloat) -> Void, onEnded: @escaping (CGFloat) -> Void, onTap: @escaping (CGPoint, CGSize) -> Void) {
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onTap = onTap
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view).y
            switch recognizer.state {
            case .changed:
                onChanged(translation)
            case .ended, .cancelled, .failed:
                onEnded(translation)
            default:
                break
            }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let host else { return }
            onTap(recognizer.location(in: host), host.bounds.size)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            false
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer.view is UIScrollView
        }
    }
}

struct GuidedAddTimeChip: View {
    var title: LocalizedStringResource
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .stroke(GuidedAddPalette.primaryText, lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                    .overlay {
                        if isSelected {
                            Circle()
                                .fill(GuidedAddPalette.primaryText)
                                .frame(width: 6, height: 6)
                        }
                    }
            Text(title)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(GuidedAddPalette.primaryText)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(
                GuidedAddPalette.canvas,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
