import SwiftUI

struct TripsFloatingAdd: View {
    var selectedDate: LocalDate?
    var locale: Locale
    var onSelect: (TripsFloatingAddAction) -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let menu = Menu {
            Section {
                TripsAddKindMenuItems(onSelect: onSelect, includeAccessibilityIDs: true)
            } header: {
                menuHeader
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 58, height: 58)
                .contentShape(Circle())
        }
        .menuIndicator(.hidden)
        .menuOrder(.fixed)

        if #available(iOS 26, *), GlassChrome.allowsGlass(
            reduceTransparency: reduceTransparency,
            increaseContrast: contrast == .increased
        ) {
            menu
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel(Text("Add to trip"))
                .accessibilityIdentifier(AccessibilityID.tripsV2FloatingAdd)
        } else {
            menu
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel(Text("Add to trip"))
                .accessibilityIdentifier(AccessibilityID.tripsV2FloatingAdd)
        }
    }

    private var menuHeader: Text {
        if let selectedDate {
            Text("Add to day \(TripsFloatingAddComposer.dayLabel(date: selectedDate, locale: locale))")
        } else {
            Text("Add to trip")
        }
    }
}

struct TripsAddKindMenuItems: View {
    var onSelect: (TripsFloatingAddAction) -> Void
    var includeAccessibilityIDs: Bool = false

    var body: some View {
        item(
            title: "Place or activity",
            systemImage: "mappin",
            action: .activity,
            accessibilityID: AccessibilityID.tripsV2AddActivity
        )
        item(
            title: "Travel",
            systemImage: "arrow.right",
            action: .leg,
            accessibilityID: AccessibilityID.tripsV2AddLeg
        )
        item(
            title: "Stay",
            systemImage: "bed.double",
            action: .stay,
            accessibilityID: AccessibilityID.tripsV2AddStay
        )
    }

    @ViewBuilder
    private func item(
        title: LocalizedStringKey,
        systemImage: String,
        action: TripsFloatingAddAction,
        accessibilityID: String
    ) -> some View {
        if includeAccessibilityIDs {
            Button(title, systemImage: systemImage) {
                onSelect(action)
            }
            .accessibilityIdentifier(accessibilityID)
        } else {
            Button(title, systemImage: systemImage) {
                onSelect(action)
            }
        }
    }
}
