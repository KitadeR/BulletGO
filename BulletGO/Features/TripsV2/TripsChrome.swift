import SwiftUI

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
    var subtitle: String?
    var locale: Locale
    var onEditSubtitle: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: TripsV2Formatting.dayHeading(date, locale: locale))
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.primaryText)
            Button(action: onEditSubtitle) {
                if let subtitle, !subtitle.isEmpty {
                    Text(verbatim: subtitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Add subtitle")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignTokens.Color.secondaryText.opacity(0.7))
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                subtitle == nil
                    ? AccessibilityID.tripsDaySubtitleAdd(date)
                    : AccessibilityID.tripsDaySubtitle(date)
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TripsV2Style.screenPadding)
        .accessibilityElement(children: .contain)
    }
}

struct TripsDaySubtitleEditor: View {
    var date: LocalDate
    var initialText: String
    var locale: Locale
    var onSave: (String?) -> Void
    var onCancel: () -> Void

    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Subtitle", text: $text)
                    .accessibilityIdentifier(AccessibilityID.tripsDaySubtitleField)
            }
            .navigationTitle(Text(verbatim: TripsV2Formatting.dayHeading(date, locale: locale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                    }
                    .accessibilityIdentifier(AccessibilityID.tripsDaySubtitleSave)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Remove subtitle", role: .destructive) {
                        onSave(nil)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .accessibilityIdentifier(AccessibilityID.tripsDaySubtitleClear)
                }
            }
        }
        .onAppear { text = initialText }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier(AccessibilityID.tripsDaySubtitleSheet)
    }
}
