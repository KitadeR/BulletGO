import SwiftUI

struct TripsV2Header: View {
    var destinations: String
    var datesText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: destinations)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let datesText {
                Text(verbatim: datesText)
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.Color.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TripsV2Style.screenPadding)
        .accessibilityElement(children: .combine)
    }
}

struct TripsDateStrip: View {
    var options: [TripsDayOption]
    var selectedDate: LocalDate?
    var locale: Locale
    var onSelect: (LocalDate) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: TripsV2Style.dateChipSpacing) {
                    ForEach(options) { option in
                        Button {
                            onSelect(option.date)
                        } label: {
                            chip(option)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: TripsV2Formatting.dayHeading(option.date, locale: locale)))
                        .accessibilityAddTraits(selectedDate == option.date ? .isSelected : [])
                        .accessibilityIdentifier(AccessibilityID.tripsDateOption(option.date))
                        .id(ItineraryDayComposer.selectorAnchor(for: option.date))
                    }
                }
                .padding(.horizontal, TripsV2Style.screenPadding)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier(AccessibilityID.tripsDateSelector)
            .onChange(of: selectedDate) { _, date in
                guard let date else { return }
                proxy.scrollTo(ItineraryDayComposer.selectorAnchor(for: date), anchor: .center)
            }
        }
    }

    private func chip(_ option: TripsDayOption) -> some View {
        let selected = selectedDate == option.date
        return VStack(spacing: 2) {
            Text(verbatim: "\(option.date.day)")
                .font(.system(size: 16, weight: selected ? .semibold : .regular))
            Text(verbatim: TripsV2Formatting.weekday(option.date, locale: locale))
                .font(.system(size: 11))
                .foregroundStyle(DesignTokens.Color.secondaryText)
        }
        .foregroundStyle(selected ? TripsV2Style.accent : DesignTokens.Color.primaryText)
        .frame(width: TripsV2Style.dateChipSize.width, height: TripsV2Style.dateChipSize.height)
        .background(
            selected ? TripsV2Style.selectedFill : Color.clear,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(TripsV2Style.selectedStroke, lineWidth: 1)
            }
        }
        .opacity(option.hasItems || selected ? 1 : 0.55)
    }
}

struct TripsDaySectionHeader: View {
    var date: LocalDate
    var place: String?
    var locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: TripsV2Formatting.dayHeading(date, locale: locale))
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.primaryText)
            if let place, !place.isEmpty {
                Text(verbatim: place)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignTokens.Color.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TripsV2Style.screenPadding)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.tripsDaySection(date))
    }
}
