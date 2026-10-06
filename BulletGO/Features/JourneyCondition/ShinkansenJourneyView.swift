import SwiftUI

struct ShinkansenJourneyView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let tripID: TripID
    let legID: LegID
    @State private var expanded: ShinkansenJourneyPresentation.Focus?
    @State private var isSaving = false
    @State private var saveFailed = false
    @State private var editsDate = false
    @State private var selectedDate = Date()

    private var trip: Trip? {
        guard session.trip?.id == tripID else { return nil }
        return session.trip
    }

    private var leg: Leg? { trip?.legs.first { $0.id == legID } }

    var body: some View {
        Group {
            if let trip, let leg {
                let state = ShinkansenJourneyPresentation.make(trip: trip, leg: leg, pack: session.pack)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("新幹線の移動")
                            .font(.largeTitle.bold())
                        Text(verbatim: state.route)
                            .font(.title2.weight(.semibold))
                        if let date = state.date {
                            Text(verbatim: date).foregroundStyle(GuidedAddPalette.secondaryText)
                        }
                        Text("必要なことを、確認できた順に整理します。")
                            .font(.subheadline)
                            .foregroundStyle(GuidedAddPalette.secondaryText)
                            .padding(.bottom, 8)
                        movementCard(state)
                        card(number: "02", title: "必要な条件", subtitle: conditionSummary(state), open: isOpen(.conditions, state)) {
                            conditionContent(state)
                        } onTap: { toggle(.conditions) }
                        card(number: "03", title: "予約・きっぷ", subtitle: reservationSummary(state), open: isOpen(.reservation, state)) {
                            reservationContent(state)
                        } onTap: { toggle(.reservation) }
                        card(number: "04", title: "乗車準備", subtitle: boardingSummary(state), open: isOpen(.boarding, state)) {
                            boardingContent(state)
                        } onTap: { toggle(.boarding) }
                        card(number: "05", title: "乗車当日", subtitle: "乗車前に確認", open: isOpen(.travelDay, state)) {
                            dayContent(state)
                        } onTap: { toggle(.travelDay) }
                        if saveFailed {
                            Text("保存できませんでした。もう一度お試しください。")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, GuidedAddMetrics.horizontal)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                .animation(GuidedAddMotion.card(reduceMotion), value: expanded)
                .animation(GuidedAddMotion.card(reduceMotion), value: state.focus)
            } else {
                ContentUnavailableView("移動が見つかりません", systemImage: "tram")
            }
        }
        .background(GuidedAddPalette.canvas)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityID.legDetail)
        .onAppear {
            if let date = leg?.scheduledAt.value?.date?.date(in: TripCalendar.timeZone) {
                selectedDate = date
            }
        }
    }

    private func isOpen(_ section: ShinkansenJourneyPresentation.Focus, _ state: ShinkansenJourneyPresentation) -> Bool {
        (expanded ?? state.focus) == section
    }

    private func toggle(_ section: ShinkansenJourneyPresentation.Focus) {
        expanded = expanded == section ? nil : section
    }

    private func movementCard(_ state: ShinkansenJourneyPresentation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("01  移動内容").font(.caption.weight(.semibold)).foregroundStyle(GuidedAddPalette.secondaryText)
            Text(verbatim: state.route).font(.headline)
            if let date = state.date { Text(verbatim: date).font(.subheadline) }
            Button("乗車日を設定・変更") { editsDate.toggle() }
                .font(.subheadline.weight(.semibold))
            if editsDate {
                DatePicker("乗車日", selection: $selectedDate, displayedComponents: .date)
                primary("日付を保存") { Task { await saveDate() } }
            }
            Text("移動内容を変更した場合、予約内容の再確認が必要です。")
                .font(.footnote).foregroundStyle(GuidedAddPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(GuidedAddPalette.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func card<Content: View>(
        number: String,
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource,
        open: Bool,
        @ViewBuilder content: () -> Content,
        onTap: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 12) {
                    Text(verbatim: number).font(.caption.weight(.semibold))
                        .foregroundStyle(GuidedAddPalette.secondaryText)
                        .frame(width: 25, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.headline).foregroundStyle(GuidedAddPalette.primaryText)
                        Text(subtitle).font(.subheadline).foregroundStyle(GuidedAddPalette.secondaryText)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: open ? "minus" : "plus")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(GuidedAddPalette.primaryText)
                }
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(subtitle))
            .accessibilityAddTraits(open ? .isSelected : [])
            if open {
                Rectangle().fill(GuidedAddPalette.inputStroke).frame(height: 1).padding(.vertical, 16)
                content()
            }
        }
        .padding(20)
        .background(GuidedAddPalette.card, in: RoundedRectangle(cornerRadius: 18))
    }

    private func conditionSummary(_ state: ShinkansenJourneyPresentation) -> LocalizedStringResource {
        if state.booking == nil { return "予約状況を確認" }
        if state.booking == .booked { return "予約済みと申告" }
        switch state.baggage {
        case .none: return "大きな荷物なしと申告"
        case .withinLimit: return "荷物サイズを確認済み"
        case .oversizedSeat: return "特大荷物用座席を確認"
        case .notAllowed: return "持ち込めるサイズを超過"
        default: return "荷物条件を確認"
        }
    }

    @ViewBuilder private func conditionContent(_ state: ShinkansenJourneyPresentation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if state.booking == nil {
                Text("この移動は、もう予約しましたか？").font(.title3.weight(.semibold))
                choice("まだ予約していない") { Task { await mutate([.setReservationStatus(legID, .notBooked, .confirmed)]) } }
                choice("予約済み。内容を記録する") { router.push(.bookingRecord(tripID, legID)) }
                choice("まだわからない") { Task { await mutate([.setReservationStatus(legID, nil, .skipped)]) } }
                if leg?.reservation.status.status == .skipped {
                    Text("保留中です。予約状況が分かったらここで更新してください。")
                        .font(.footnote).foregroundStyle(GuidedAddPalette.secondaryText)
                }
            } else if state.booking == .notBooked {
                switch state.baggage {
                case .unanswered, .deferred:
                    Text("大きな荷物を持って行きますか？").font(.title3.weight(.semibold))
                    choice("ない") { Task { await mutate([.setBaggagePresence(legID, .no, .confirmed)]) } }
                    choice("ある。サイズを確認する") {
                        Task {
                            let bagID = leg?.bagIDs.first ?? BagID()
                            if await mutate([.setBaggagePresence(legID, .yes, .confirmed), .addBag(legID, bagID)]) {
                                router.push(.legBaggageCheck(tripID, legID))
                            }
                        }
                    }
                    choice("まだわからない") { Task { await mutate([.setBaggagePresence(legID, nil, .skipped)]) } }
                case .needsMeasurement:
                    Text("荷物の縦・横・高さを測ると、必要な座席条件が分かります。")
                    primary("荷物を測る") { router.push(.legBaggageCheck(tripID, legID)) }
                case .oversizedSeat:
                    Text("3辺の合計が160 cmを超え250 cm以内です。特大荷物スペースつき座席など、対応する座席の予約が必要です。")
                    Link("JRの特大荷物案内", destination: URL(string: "https://railway.jr-central.co.jp/oversized-baggage/")!)
                case .notAllowed:
                    Text("3辺の合計が250 cmを超えています。この荷物は持ち込めません。荷物の方法を変更してから予約してください。")
                case .none, .withinLimit:
                    Text("荷物条件を確認しました。")
                }
                choice("荷物の回答を変更") { Task { await mutate([.setBaggagePresence(legID, nil, .skipped)]) } }
            } else {
                switch state.baggage {
                case .unanswered, .deferred:
                    Text("予約済みでも、荷物条件を確認してください。大きな荷物はありますか？")
                    choice("ない") { Task { await mutate([.setBaggagePresence(legID, .no, .confirmed)]) } }
                    choice("ある。サイズを確認する") {
                        Task {
                            let bagID = leg?.bagIDs.first ?? BagID()
                            if await mutate([.setBaggagePresence(legID, .yes, .confirmed), .addBag(legID, bagID)]) {
                                router.push(.legBaggageCheck(tripID, legID))
                            }
                        }
                    }
                    choice("まだわからない") { Task { await mutate([.setBaggagePresence(legID, nil, .skipped)]) } }
                case .needsMeasurement, .notAllowed:
                    if state.baggage == .notAllowed {
                        Text("荷物は持込サイズを超えています。方法を変更してください。")
                    } else {
                        Text("荷物の3辺を測って条件を確認してください。")
                    }
                    primary("荷物を測る") { router.push(.legBaggageCheck(tripID, legID)) }
                case .oversizedSeat:
                    Text("特大荷物用座席が予約内容に含まれるか確認してください。")
                case .none, .withinLimit:
                    Text("荷物条件を確認しました。")
                }
                choice("荷物の回答を変更") { Task { await mutate([.setBaggagePresence(legID, nil, .skipped)]) } }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reservationSummary(_ state: ShinkansenJourneyPresentation) -> LocalizedStringResource {
        if state.booking == .booked { return state.hasRecordedDetails ? "予約内容を記録済み" : "予約内容を記録" }
        if state.booking == .notBooked { return "予約方法を選ぶ" }
        return "予約状況を確認後に案内"
    }

    @ViewBuilder private func reservationContent(_ state: ShinkansenJourneyPresentation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if state.booking == .notBooked {
                if state.baggage == .notAllowed || state.baggage == .needsMeasurement || state.baggage == .deferred || state.baggage == .unanswered {
                    Text("先に荷物条件を確認してください。")
                } else {
                    Text("予約と決済は外部サービスで行います。方法を選んで手順を確認できます。")
                    primary("予約方法を見る") { router.push(.bookingMethods(tripID, legID)) }
                }
            } else if state.booking == .booked {
                Text("列車・号車・座席・確認番号を、分かる範囲で記録できます。")
                primary("予約内容を記録・変更") { router.push(.bookingRecord(tripID, legID)) }
            } else {
                Text("予約状況が分かると、この移動に合う案内を表示します。")
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func boardingSummary(_ state: ShinkansenJourneyPresentation) -> LocalizedStringResource {
        if state.booking != .booked { return "予約後に乗車方法を確認" }
        if state.boarding == nil { return "乗車方法を確認" }
        switch state.boarding {
        case .designatedIC: return "指定済みICと申告"
        case .qrTicket: return "QRと申告"
        case .paperTicket: return "紙のきっぷと申告"
        case nil: return "乗車方法を確認"
        }
    }

    @ViewBuilder private func boardingContent(_ state: ShinkansenJourneyPresentation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if state.booking != .booked {
                Text("予約後に、予約画面に表示された乗車方法を確認します。")
            } else {
                Text("予約画面には、改札で使うものとして何が表示されていますか？")
                choice("QRコード") { Task { await mutate([.setStatedBoarding(legID, .qrTicket)]) } }
                choice("指定済みICカード") { Task { await mutate([.setStatedBoarding(legID, .designatedIC)]) } }
                choice("紙のきっぷ") { Task { await mutate([.setStatedBoarding(legID, .paperTicket)]) } }
                choice("まだわからない") { Task { await mutate([.setStatedBoarding(legID, nil)]) } }
                if state.baggage == .oversizedSeat {
                    if state.oversizedSeatReserved == true {
                        Text("特大荷物用座席は申告済み").font(.subheadline)
                    } else {
                        Text("特大荷物用座席が予約内容にあるか確認してください。").font(.subheadline)
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func dayContent(_ state: ShinkansenJourneyPresentation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if state.booking != .booked {
                Text("予約後に、乗車当日の手順を表示します。")
            } else {
                switch state.boarding {
                case .qrTicket:
                    if leg?.reservation.service.value == .smartEX {
                        Text("SmartEXの乗車用QRを印刷するかApple Walletに追加し、対応する改札で使ってください。")
                        Link("SmartEX公式：QRで乗車", destination: URL(string: "https://smart-ex.jp/entraining/qr/")!)
                    } else {
                        Text("予約先の案内でQRの表示・使用方法を確認してください。")
                    }
                case .designatedIC:
                    Text("予約に指定したICカードを持ち、対応する改札でタッチしてください。")
                    if leg?.reservation.service.value == .smartEX {
                        Link("SmartEX公式：ICで乗車", destination: URL(string: "https://smart-ex.jp/entraining/iccard/")!)
                    }
                case .paperTicket:
                    Text("乗車前に予約先が指定する場所できっぷを受け取り、改札で使用してください。")
                    if leg?.reservation.service.value == .smartEX {
                        Link("SmartEX公式：きっぷ受取", destination: URL(string: "https://smart-ex.jp/entraining/ticket/place/")!)
                    }
                case nil:
                    Text("乗車方法は未確認です。予約画面で確認してください。")
                }
                if state.baggage == .oversizedSeat && state.oversizedSeatReserved != true {
                    Text("特大荷物用座席の予約内容も確認してください。")
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func choice(_ title: LocalizedStringResource, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.body.weight(.medium))
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
            }
            .foregroundStyle(GuidedAddPalette.primaryText)
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(GuidedAddPalette.mutedFill, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    private func primary(_ title: LocalizedStringResource, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.body.weight(.semibold))
                .foregroundStyle(GuidedAddPalette.ctaText)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(GuidedAddPalette.ctaFill, in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }

    @discardableResult
    private func mutate(_ mutations: [TripMutation]) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        saveFailed = await session.process(.applyMutations(mutations)) == nil
        return !saveFailed
    }

    private func saveDate() async {
        do {
            let local = try LocalDate(date: selectedDate, timeZone: TripCalendar.timeZone)
            let moment: ScheduledMoment
            if let current = leg?.scheduledAt.value {
                moment = try current.replacingDate(local)
            } else {
                moment = try ScheduledMoment(date: local, timeZoneIdentifier: TripCalendar.timeZoneIdentifier)
            }
            if await mutate([.setLegScheduledAt(legID, moment)]) { editsDate = false }
        } catch {
            saveFailed = true
        }
    }
}
