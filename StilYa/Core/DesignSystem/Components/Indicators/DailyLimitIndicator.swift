//
//  CreditIndicator.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 6.12.2025.
//

import SwiftUI

// MARK: - Background Style

enum CreditCardStyle {
    case linen      // Kumaş dokusu
    case tag        // Kıyafet etiketi
    case magazine   // Dergi kupürü
    case wallet     // Deri cüzdan
    case strip      // Floating strip — kutu yok, inline bilgi
}

struct CreditIndicator: View {
    let credits: Int
    let isPro: Bool
    var maxCredits: Int?
    var weeklyResetDate: Date?
    var proCreditsCycleStart: Date?
    var subscriptionPlan: String?
    var onAddCredits: (() -> Void)?
    var onWatchAd: (() -> Void)?
    var canWatchAd: Bool = false
    var adCooldownText: String? = nil
    var closetAccentColor: Color = Color.proGold
    var style: CreditCardStyle = .wallet

    private let totalHearts = 5

    /// Kalp durumlarini hesapla: .filled, .half, .empty
    private var heartStates: [HeartState] {
        guard credits > 0 else {
            return Array(repeating: .empty, count: totalHearts)
        }

        let max = isPro
            ? CGFloat(maxCredits ?? credits)
            : CGFloat(AppConstants.freeWeeklyCredits)
        let ratio = min(CGFloat(credits) / max, 1.0)
        let filledHearts = ratio * CGFloat(totalHearts)

        var states: [HeartState] = []
        for i in 0..<totalHearts {
            let heartValue = filledHearts - CGFloat(i)
            if heartValue >= 0.75 {
                states.append(.filled)
            } else if heartValue >= 0.25 {
                states.append(.half)
            } else {
                states.append(.empty)
            }
        }
        return states
    }

    /// Haftalik yenilenmeye kalan zaman + haftalik kredi bilgisi
    private var renewalText: String {
        if isPro {
            return proRenewalText
        }

        let weeklyInfo = L10n.creditsWeeklyFree(AppConstants.freeWeeklyCredits)

        guard let resetDate = weeklyResetDate else { return weeklyInfo }

        let nextReset = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: resetDate) ?? resetDate
        let now = Date()

        guard nextReset > now else { return weeklyInfo }

        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: nextReset)
        let days = components.day ?? 0
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0

        if days > 0 {
            return "\(weeklyInfo) · \(L10n.creditsRenewsInDaysHours(days, hours))"
        } else if hours > 0 {
            return "\(weeklyInfo) · \(L10n.creditsRenewsInHours(hours))"
        } else {
            return "\(weeklyInfo) · \(minutes)dk"
        }
    }

    /// Pro kullanici icin yenilenme suresi
    private var proRenewalText: String {
        guard let cycleStart = proCreditsCycleStart, let plan = subscriptionPlan else {
            return L10n.creditsProLabel
        }

        let daysInCycle = plan == "weekly" ? 7 : 30
        guard let nextRenewal = Calendar.current.date(byAdding: .day, value: daysInCycle, to: cycleStart) else {
            return L10n.creditsProLabel
        }

        let now = Date()
        guard nextRenewal > now else {
            return L10n.creditsProLabel
        }

        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: nextRenewal)
        let days = components.day ?? 0
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0

        if days > 0 {
            return "Pro · \(L10n.creditsRenewsInDaysHours(days, hours))"
        } else if hours > 0 {
            return "Pro · \(L10n.creditsRenewsInHours(hours))"
        } else {
            return "Pro · \(minutes)dk"
        }
    }

    var body: some View {
        switch style {
        case .linen:
            linenStyle
        case .tag:
            tagStyle
        case .magazine:
            magazineStyle
        case .wallet:
            walletStyle
        case .strip:
            stripStyle
        }
    }

    // MARK: - Shared Content

    private var creditContent: some View {
        VStack(spacing: 0) {
            // Row 1: Hearts + credit text + button
            HStack(alignment: .center) {
                // Left: Hearts + "5 kredi"
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(0..<totalHearts, id: \.self) { index in
                            heartImage(for: heartStates[index])
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                        }
                    }

                    Text(L10n.creditsCount(credits))
                        .font(STFont.handwritingLarge)
                        .foregroundColor(.textPrimary.opacity(0.85))
                        .rotationEffect(.degrees(-1))
                }

                Spacer()

                // Right: Kredi Ekle button
                Button(action: {
                    onAddCredits?()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(L10n.creditsAdd)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.proGold)
                    )
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(L10n.creditsInvite)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.proGold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        )
                        .offset(x: 4, y: 8)
                }
            }

            // Row 2: Renewal text
            HStack {
                Text(renewalText)
                    .font(STFont.handwriting)
                    .foregroundColor(.textPrimary.opacity(0.55))
                    .rotationEffect(.degrees(0.5))

                Spacer()
            }
        }
    }

    // MARK: - Style 1: Linen (Kumaş Dokusu)

    private var linenStyle: some View {
        creditContent
            .padding(.horizontal, 36)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.94, green: 0.91, blue: 0.87)) // Keten rengi
                    .overlay(
                        // Kumaş dokusu efekti — çapraz çizgiler
                        Canvas { context, size in
                            let spacing: CGFloat = 4
                            // Yatay iplikler
                            for y in stride(from: 0, to: size.height, by: spacing) {
                                var path = Path()
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: size.width, y: y))
                                context.stroke(path, with: .color(.black.opacity(0.03)), lineWidth: 0.5)
                            }
                            // Dikey iplikler
                            for x in stride(from: 0, to: size.width, by: spacing) {
                                var path = Path()
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: size.height))
                                context.stroke(path, with: .color(.black.opacity(0.02)), lineWidth: 0.5)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    )
                    .overlay(
                        // Kenar dikişi
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                Color.textSecondary.opacity(0.15),
                                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                            )
                            .padding(4)
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Style 2: Clothing Tag (Kıyafet Etiketi)

    private var tagStyle: some View {
        VStack(spacing: 0) {
            // Üstte delik + ip
            ZStack {
                // İp
                Circle()
                    .strokeBorder(Color.textSecondary.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 18, height: 18)

                Circle()
                    .fill(Color.bgPrimary)
                    .frame(width: 8, height: 8)
            }
            .offset(y: 8)
            .zIndex(1)

            // Etiket gövdesi
            creditContent
                .padding(.horizontal, 36)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .background(
                    ZStack {
                        // Ana etiket
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.97, green: 0.96, blue: 0.93))

                        // İnce kenar çizgisi
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.textSecondary.opacity(0.12), lineWidth: 1)

                        // Sol kenar — marka çizgisi
                        HStack {
                            Rectangle()
                                .fill(Color.proGold.opacity(0.3))
                                .frame(width: 3)
                            Spacer()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                )
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        }
    }

    // MARK: - Style 3: Magazine Cutout (Dergi Kupürü)

    private var magazineStyle: some View {
        ZStack {
            // Arkadaki "sayfa" — belirgin eğik
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.90, green: 0.87, blue: 0.82))
                .shadow(color: .black.opacity(0.08), radius: 3, x: 1, y: 2)
                .rotationEffect(.degrees(2.5))

            // Üstteki ana kupür
            creditContent
                .padding(.horizontal, 36)
                .padding(.vertical, 20)
                .background(
                    ZStack {
                        MagazineCutoutShape()
                            .fill(Color(red: 0.97, green: 0.95, blue: 0.92))

                        MagazineCutoutShape()
                            .strokeBorder(Color.textSecondary.opacity(0.12), lineWidth: 0.5)
                    }
                )
                .shadow(color: .black.opacity(0.1), radius: 6, x: 2, y: 3)
                .rotationEffect(.degrees(-1))
        }
    }

    // MARK: - Style 4: Wallet (Deri Cüzdan)

    private var walletContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(0..<totalHearts, id: \.self) { index in
                            heartImage(for: heartStates[index])
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                        }
                    }

                    Text(L10n.creditsCount(credits))
                        .font(STFont.handwritingLarge)
                        .foregroundColor(.white.opacity(0.9))
                        .rotationEffect(.degrees(-1))
                }

                Spacer()

                Button(action: {
                    onAddCredits?()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(L10n.creditsAdd)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.30, blue: 0.22))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.92, green: 0.86, blue: 0.78))
                    )
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(L10n.creditsInvite)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(red: 0.42, green: 0.30, blue: 0.22))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.92, green: 0.86, blue: 0.78))
                                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        )
                        .offset(x: 4, y: 8)
                }
            }

            HStack {
                Text(renewalText)
                    .font(STFont.handwriting)
                    .foregroundColor(.white.opacity(0.5))
                    .rotationEffect(.degrees(0.5))

                Spacer()
            }
        }
    }

    private var walletStyle: some View {
        walletContent
            .padding(.horizontal, 36)
            .padding(.vertical, 22)
            .background(
                ZStack {
                    // Deri arka plan
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.42, green: 0.30, blue: 0.22), // Koyu kahve
                                    Color(red: 0.50, green: 0.36, blue: 0.26), // Orta kahve
                                    Color(red: 0.44, green: 0.32, blue: 0.24)  // Koyu kahve
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Deri doku efekti — ince gürültü
                    Canvas { context, size in
                        for _ in 0..<200 {
                            let x = CGFloat.random(in: 0...size.width)
                            let y = CGFloat.random(in: 0...size.height)
                            let rect = CGRect(x: x, y: y, width: 1, height: 1)
                            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(Double.random(in: 0.01...0.04))))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Dikişli kenar
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            Color(red: 0.62, green: 0.48, blue: 0.36).opacity(0.6),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                        )
                        .padding(6)

                    // Üst sol köşede kabartma logo hissi
                    VStack {
                        HStack {
                            Spacer()
                            Text("STILYA")
                                .font(.system(size: 8, weight: .bold, design: .serif))
                                .tracking(3)
                                .foregroundColor(Color(red: 0.55, green: 0.42, blue: 0.32).opacity(0.5))
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            )
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    // MARK: - Style 5: Floating Strip (Paper arka plan, tek kalp)

    private var stripStyle: some View {
        VStack(spacing: 6) {
            ZStack {
                // Paper texture background
                Image("paper")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 120)
                    .opacity(0.6)

                HStack(spacing: 8) {
                    // Tek statik kalp
                    Image("pixel-heart-filled")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 20, height: 20)

                    // Credit count
                    Text("\(credits)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)

                    Text(L10n.homeCredit)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textSecondary)

                    // Watch ad button — next to credit count, distinct style
                    if canWatchAd {
                        Button(action: { onWatchAd?() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 14))
                                Text("+1")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(closetAccentColor)
                            )
                        }
                    } else if !isPro, let cooldown = adCooldownText {
                        // Disabled cooldown state
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text(cooldown)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.textSecondary.opacity(0.12))
                        )
                        .opacity(0.6)
                    }

                    Spacer()

                    // Kredi Ekle button with invite badge
                    Button(action: {
                        onAddCredits?()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                            Text(L10n.creditsAdd)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .fixedSize()
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color.accent)
                        )
                    }


                }
                .padding(.horizontal, 16)
            }
            .frame(height: 64)
            .padding(.vertical, 6)

            // Renewal text
            HStack(spacing: 0) {
                Text(renewalText)
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary.opacity(0.6))

                Spacer()
            }
        }
    }

    // MARK: - Heart Image Helper

    private func heartImage(for state: HeartState) -> Image {
        switch state {
        case .filled:
            return Image("pixel-heart-filled")
        case .half:
            return Image("half-filled-heart")
        case .empty:
            return Image("pixel-heart-empty")
        }
    }
}

// MARK: - Heart State

private enum HeartState {
    case filled
    case half
    case empty
}

// MARK: - Magazine Cutout Shape (düzensiz kesilmiş kenarlar)

private struct MagazineCutoutShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()

        // Üst kenar — makas ile kesilmiş gibi düzensiz
        path.move(to: CGPoint(x: r.minX + 4, y: r.minY + 3))
        path.addLine(to: CGPoint(x: r.maxX * 0.2, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX * 0.35, y: r.minY + 4))
        path.addLine(to: CGPoint(x: r.maxX * 0.55, y: r.minY + 1))
        path.addLine(to: CGPoint(x: r.maxX * 0.75, y: r.minY + 5))
        path.addLine(to: CGPoint(x: r.maxX - 3, y: r.minY + 1))

        // Sağ kenar
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY * 0.25))
        path.addLine(to: CGPoint(x: r.maxX - 3, y: r.maxY * 0.5))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY * 0.75))
        path.addLine(to: CGPoint(x: r.maxX - 2, y: r.maxY - 3))

        // Alt kenar
        path.addLine(to: CGPoint(x: r.maxX * 0.8, y: r.maxY))
        path.addLine(to: CGPoint(x: r.maxX * 0.6, y: r.maxY - 4))
        path.addLine(to: CGPoint(x: r.maxX * 0.4, y: r.maxY - 1))
        path.addLine(to: CGPoint(x: r.maxX * 0.2, y: r.maxY - 3))
        path.addLine(to: CGPoint(x: r.minX + 2, y: r.maxY))

        // Sol kenar
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY * 0.7))
        path.addLine(to: CGPoint(x: r.minX + 3, y: r.maxY * 0.45))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY * 0.2))

        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> MagazineCutoutShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

// MARK: - Previews

#Preview("1 — Linen") {
    VStack(spacing: 24) {
        CreditIndicator(credits: 5, isPro: false, weeklyResetDate: Date(), style: .linen)
        CreditIndicator(credits: 2, isPro: false, weeklyResetDate: Date(), style: .linen)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 40)
    .background(Color.bgPrimary)
}

#Preview("2 — Tag (Etiket)") {
    VStack(spacing: 24) {
        CreditIndicator(credits: 5, isPro: false, weeklyResetDate: Date(), style: .tag)
        CreditIndicator(credits: 2, isPro: false, weeklyResetDate: Date(), style: .tag)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 40)
    .background(Color.bgPrimary)
}

#Preview("3 — Magazine (Dergi)") {
    VStack(spacing: 24) {
        CreditIndicator(credits: 5, isPro: false, weeklyResetDate: Date(), style: .magazine)
        CreditIndicator(credits: 2, isPro: false, weeklyResetDate: Date(), style: .magazine)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 40)
    .background(Color.bgPrimary)
}

#Preview("4 — Wallet") {
    VStack(spacing: 24) {
        CreditIndicator(credits: 5, isPro: false, weeklyResetDate: Date(), style: .wallet)
        CreditIndicator(credits: 2, isPro: false, weeklyResetDate: Date(), style: .wallet)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 40)
    .background(Color.bgPrimary)
}

#Preview("5 — Strip (Floating)") {
    VStack(spacing: 24) {
        CreditIndicator(credits: 5, isPro: false, weeklyResetDate: Date(), style: .strip)
        CreditIndicator(credits: 2, isPro: false, weeklyResetDate: Date(), style: .strip)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 40)
    .background(Color.bgPrimary)
}
