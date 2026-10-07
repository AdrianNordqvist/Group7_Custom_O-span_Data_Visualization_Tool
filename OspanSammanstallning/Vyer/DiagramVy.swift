import Charts
import SwiftUI

/// Färger och bläck för diagrammen. Alltid ljus yta – bilderna ska in i en rapport.
/// Serieordningen (blå, orange, turkos) är kontrollerad för färgblindhet mot vit yta.
enum Diagramstil {
    static let yta = Color.white
    static let primar = Color(hex: 0x0b0b0b)
    static let sekundar = Color(hex: 0x52514e)
    static let dampad = Color(hex: 0x898781)
    static let rutnat = Color(hex: 0xe1e0d9)
    static let baslinje = Color(hex: 0xc3c2b7)
    static let serier: [UInt32] = [0x2a78d6, 0xeb6834, 0x1baf7a]
    static let stapel: CGFloat = 24

    /// Standardfärgen följer gruppen (dess plats i den fasta ordningen), inte ordningen i just det här diagrammet.
    static func standardfarg(_ grupp: String, i gruppering: Gruppering) -> UInt32 {
        guard let plats = gruppering.ordning.firstIndex(of: grupp), plats < serier.count else { return 0x898781 }
        return serier[plats]
    }

    /// Gruppens färg: den användaren har valt, annars standardfärgen.
    static func farg(_ grupp: String, i gruppering: Gruppering, egna: [String: UInt32] = [:]) -> Color {
        Color(hex: egna[grupp] ?? standardfarg(grupp, i: gruppering))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}

/// Ett färdigt diagram i exportstorlek. Samma vy används för förhandsvisning och export.
struct DiagramVy: View {
    let underlag: Diagramunderlag
    let val: Diagraminstallning

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if val.visaTitel {
                Text(Diagramtext.titel(val))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Diagramstil.primar)
                Text(Diagramtext.forklaring(val, underlag))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Diagramstil.sekundar)
                    .fixedSize(horizontal: false, vertical: true)
            }
            diagram
                .padding(.top, val.visaTitel ? 10 : 0)
        }
        .padding(EdgeInsets(top: 18, leading: 18, bottom: 14, trailing: 24))
        .frame(width: val.storlek.bredd, height: val.storlek.hojd, alignment: .topLeading)
        .background(Diagramstil.yta)
        .environment(\.colorScheme, .light)
        .environment(\.locale, val.sprak.locale)
    }

    @ViewBuilder
    private var diagram: some View {
        switch val.typ {
        case .gruppmedel: gruppmedel
        case .lada: lada
        case .perDeltagare: perDeltagare
        case .samband: samband
        case .setlangd: setlangd
        case .sasFragor: sasFragor
        }
    }

    private func farg(_ grupp: String) -> Color {
        Diagramstil.farg(grupp, i: underlag.gruppering, egna: val.farger)
    }

    /// Formen följer gruppen på samma sätt som färgen, så att diagrammet går att läsa i svartvitt.
    private func symbol(_ grupp: String) -> BasicChartSymbolShape {
        let former: [BasicChartSymbolShape] = [.circle, .square, .triangle]
        guard let plats = underlag.gruppering.ordning.firstIndex(of: grupp), plats < former.count else { return .diamond }
        return former[plats]
    }

    private func tal(_ v: Double, _ decimaler: Int) -> String {
        val.sprak.tal(v, decimaler: decimaler)
    }

    /// Gruppnamnet på diagrammets språk. Färg och form slås fortfarande upp på den svenska nyckeln.
    private func visad(_ grupp: String) -> String {
        val.sprak.grupp(grupp)
    }

    private func axeltitel(_ matt: Diagrammatt) -> some View {
        axeltitel(val.sprak.namn(matt), val.sprak.enhet(matt))
    }

    // MARK: - Medelvärde per grupp

    private var gruppmedel: some View {
        let grupper = underlag.varden(val.matt)
        let hogst = grupper.flatMap(\.tal).max() ?? 1
        return Chart {
            baslinje
            ForEach(grupper) { g in
                if let medel = g.medel {
                    BarMark(x: .value("Grupp", g.grupp), y: .value(val.matt.namn, medel), width: .fixed(Diagramstil.stapel))
                        .foregroundStyle(farg(g.grupp))
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
                    if let fel = val.felstapel.varde(g.tal) {
                        felstapel(grupp: g.grupp, fran: max(0, medel - fel), till: medel + fel)
                    }
                    if val.visaPunkter { punkter(g) }
                    PointMark(x: .value("Grupp", g.grupp), y: .value("Medel", medel))
                        .symbolSize(0)
                        .annotation(position: .trailing, alignment: .center, spacing: 24) {
                            vardeetikett(tal(medel, val.matt.decimaler))
                        }
                }
            }
        }
        .chartXScale(domain: grupper.map(\.grupp), range: .plotDimension(padding: sidmarginal(grupper.count)))
        .yskala(val.matt.skala.map { 0...max($0.upperBound, hogst) }, franNoll: true)
        .chartXAxis { gruppaxel(grupper) }
        .chartYAxis { vardeaxel }
        .chartYAxisLabel(position: .top, alignment: .leading) { axeltitel(val.matt) }
        .chartLegend(.hidden)
    }

    // MARK: - Lådagram

    private var lada: some View {
        let grupper = underlag.varden(val.matt)
        return Chart {
            ForEach(grupper) { g in
                if let lagst = g.tal.min(), let hogst = g.tal.max(), let median = g.median,
                   let q1 = Statistik.kvantil(g.tal, 0.25), let q3 = Statistik.kvantil(g.tal, 0.75) {
                    felstapel(grupp: g.grupp, fran: lagst, till: hogst)
                    BarMark(x: .value("Grupp", g.grupp), yStart: .value("Kvartil 1", q1), yEnd: .value("Kvartil 3", q3),
                            width: .fixed(Diagramstil.stapel))
                        .foregroundStyle(farg(g.grupp))
                        .cornerRadius(2)
                    // Medianen är en glipa i ytans färg, inte en ritad linje.
                    PointMark(x: .value("Grupp", g.grupp), y: .value("Median", median))
                        .symbol { Rectangle().fill(Diagramstil.yta).frame(width: Diagramstil.stapel, height: 2) }
                        .annotation(position: .trailing, alignment: .center, spacing: 12) {
                            vardeetikett("\(val.sprak.median) \(tal(median, val.matt.decimaler))")
                        }
                    if val.visaPunkter { punkter(g) }
                }
            }
        }
        .chartXScale(domain: grupper.map(\.grupp), range: .plotDimension(padding: sidmarginal(grupper.count)))
        .yskala(val.matt.skala, franNoll: false)
        .chartXAxis { gruppaxel(grupper) }
        .chartYAxis { vardeaxel }
        .chartYAxisLabel(position: .top, alignment: .leading) { axeltitel(val.matt) }
        .chartLegend(.hidden)
    }

    // MARK: - Stapel per deltagare

    private var perDeltagare: some View {
        let grupper = underlag.varden(val.matt)
        // Inom varje grupp: högst värde först.
        let staplar = grupper.flatMap { g in
            zip(g.koder, g.tal).sorted { $0.1 > $1.1 }.map { (kod: $0.0, varde: $0.1, grupp: g.grupp) }
        }
        let plats = (val.storlek.bredd - 90) / CGFloat(max(staplar.count, 1))
        return Chart {
            baslinje
            ForEach(staplar, id: \.kod) { s in
                BarMark(x: .value("Deltagare", s.kod), y: .value(val.matt.namn, s.varde),
                        width: .fixed(min(Diagramstil.stapel, plats * 0.62)))
                    .foregroundStyle(by: .value("Grupp", visad(s.grupp)))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
            }
        }
        .chartForegroundStyleScale(domain: grupper.map { visad($0.grupp) }, range: grupper.map { farg($0.grupp) })
        .chartXScale(domain: staplar.map(\.kod))
        .yskala(val.matt.skala, franNoll: true)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel(orientation: staplar.count > 14 ? .verticalReversed : .horizontal)
                    .font(.system(size: 10))
                    .foregroundStyle(Diagramstil.sekundar)
            }
        }
        .chartYAxis { vardeaxel }
        .chartYAxisLabel(position: .top, alignment: .leading) { axeltitel(val.matt) }
        .forklaringsruta(visas: grupper.count > 1)
    }

    // MARK: - Samband

    private var samband: some View {
        let punkter = underlag.rader.compactMap { r -> (id: UUID, grupp: String, x: Double, y: Double)? in
            guard let x = val.xMatt.varde(r.deltagare, r.enkat), let y = val.matt.varde(r.deltagare, r.enkat) else { return nil }
            return (r.id, r.grupp, x, y)
        }
        let x = punkter.map(\.x), y = punkter.map(\.y)
        let grupper = underlag.grupper.filter { g in punkter.contains { $0.grupp == g } }
        return Chart {
            if val.trendlinje, let linje = Statistik.regression(x, y), let x0 = x.min(), let x1 = x.max() {
                ForEach([x0, x1], id: \.self) { xv in
                    LineMark(x: .value(val.xMatt.namn, xv), y: .value(val.matt.namn, linje.skarning + linje.lutning * xv),
                             series: .value("Serie", "Trend"))
                        .foregroundStyle(Diagramstil.dampad)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
            }
            ForEach(punkter, id: \.id) { p in
                // Vit ring under varje punkt så att överlappande punkter går att skilja åt.
                PointMark(x: .value(val.xMatt.namn, p.x), y: .value(val.matt.namn, p.y))
                    .foregroundStyle(Diagramstil.yta)
                    .symbol(by: .value("Grupp", visad(p.grupp)))
                    .symbolSize(150)
                PointMark(x: .value(val.xMatt.namn, p.x), y: .value(val.matt.namn, p.y))
                    .foregroundStyle(by: .value("Grupp", visad(p.grupp)))
                    .symbol(by: .value("Grupp", visad(p.grupp)))
                    .symbolSize(70)
            }
        }
        .chartForegroundStyleScale(domain: grupper.map(visad), range: grupper.map(farg))
        .chartSymbolScale(domain: grupper.map(visad), range: grupper.map(symbol))
        .chartXScale(domain: omrade(x))
        .chartYScale(domain: omrade(y))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Diagramstil.rutnat)
                AxisValueLabel().font(.system(size: 11)).foregroundStyle(Diagramstil.sekundar)
            }
        }
        .chartYAxis { vardeaxel }
        .chartXAxisLabel(position: .bottom, alignment: .center) { axeltitel(val.xMatt) }
        .chartYAxisLabel(position: .top, alignment: .leading) { axeltitel(val.matt) }
        .forklaringsruta(visas: grupper.count > 1)
    }

    // MARK: - Per setlängd

    private var setlangd: some View {
        let langder = Array(Sammanfattning.langder)
        let grupper = underlag.grupper
        // Grupperna skjuts isär lite i sidled så att felstaplarna inte hamnar på varandra.
        let punkter = langder.flatMap { langd in
            underlag.varden(val.setMatt, langd: langd).compactMap { g -> (id: String, grupp: String, x: Double, medel: Double, fel: Double?)? in
                guard let medel = g.medel, let i = grupper.firstIndex(of: g.grupp) else { return nil }
                let x = Double(langd) + (Double(i) - Double(grupper.count - 1) / 2) * 0.09
                return ("\(g.grupp)-\(langd)", g.grupp, x, medel, val.felstapel.varde(g.tal))
            }
        }
        return Chart {
            ForEach(punkter, id: \.id) { p in
                if let fel = p.fel {
                    RuleMark(x: .value("Setlängd", p.x), yStart: .value("Nedre", p.medel - fel), yEnd: .value("Övre", p.medel + fel))
                        .foregroundStyle(by: .value("Grupp", visad(p.grupp)))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
                LineMark(x: .value("Setlängd", p.x), y: .value(val.setMatt.rawValue, p.medel))
                    .foregroundStyle(by: .value("Grupp", visad(p.grupp)))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("Setlängd", p.x), y: .value(val.setMatt.rawValue, p.medel))
                    .foregroundStyle(Diagramstil.yta)
                    .symbol(by: .value("Grupp", visad(p.grupp)))
                    .symbolSize(150)
                PointMark(x: .value("Setlängd", p.x), y: .value(val.setMatt.rawValue, p.medel))
                    .foregroundStyle(by: .value("Grupp", visad(p.grupp)))
                    .symbol(by: .value("Grupp", visad(p.grupp)))
                    .symbolSize(70)
            }
        }
        .chartForegroundStyleScale(domain: grupper.map(visad), range: grupper.map(farg))
        .chartSymbolScale(domain: grupper.map(visad), range: grupper.map(symbol))
        .chartXScale(domain: 2.6...7.4)
        .yskala(val.setMatt == .procent ? 0...100 : nil, franNoll: false)
        .chartXAxis {
            AxisMarks(values: langder.map(Double.init)) { _ in
                AxisValueLabel().font(.system(size: 12)).foregroundStyle(Diagramstil.primar)
            }
        }
        .chartYAxis { vardeaxel }
        .chartXAxisLabel(position: .bottom, alignment: .center) { axeltitel(val.sprak.setlangd.namn, val.sprak.setlangd.enhet) }
        .chartYAxisLabel(position: .top, alignment: .leading) { axeltitel(val.sprak.namn(val.setMatt), val.setMatt.enhet) }
        .forklaringsruta(visas: grupper.count > 1)
    }

    // MARK: - SAS-SV per fråga

    private var sasFragor: some View {
        let grupper = underlag.enkatgrupper
        let staplar = underlag.fragor.indices.flatMap { i in
            underlag.svar(fraga: i).compactMap { g in
                g.medel.map {
                    (id: "\(i)-\(g.grupp)", fraga: val.sprak.fraga(underlag.fragor[i], plats: i, antal: underlag.fragor.count),
                     grupp: g.grupp, medel: $0)
                }
            }
        }
        let band = (val.storlek.hojd - 130) / CGFloat(max(underlag.fragor.count, 1))
        let hojd = min(Diagramstil.stapel, max(4, band * 0.72 / CGFloat(max(grupper.count, 1)) - 2))
        return Chart {
            RuleMark(x: .value("Lägsta svar", 1))
                .foregroundStyle(Diagramstil.baslinje)
                .lineStyle(StrokeStyle(lineWidth: 1))
            ForEach(staplar, id: \.id) { s in
                BarMark(xStart: .value("Lägsta svar", 1), xEnd: .value("Medel", s.medel), y: .value("Fråga", s.fraga),
                        height: .fixed(hojd))
                    .foregroundStyle(by: .value("Grupp", visad(s.grupp)))
                    .position(by: .value("Grupp", visad(s.grupp)), axis: .vertical)
                    .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 4, topTrailingRadius: 4))
                    .annotation(position: .trailing, alignment: .center, spacing: 5) {
                        // Siffra på varje stapel bara när det är en serie – annars blir det plottrigt.
                        if grupper.count == 1 { vardeetikett(tal(s.medel, 1)) }
                    }
            }
        }
        .chartForegroundStyleScale(domain: grupper.map(visad), range: grupper.map(farg))
        .chartXScale(domain: 1...6.4)
        .chartXAxis {
            AxisMarks(values: [1, 2, 3, 4, 5, 6]) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Diagramstil.rutnat)
                AxisValueLabel().font(.system(size: 11)).foregroundStyle(Diagramstil.sekundar)
            }
        }
        .chartYAxis {
            AxisMarks(preset: .extended, position: .leading) { varde in
                AxisValueLabel(centered: true) {
                    if let fraga = varde.as(String.self) {
                        Text(fraga)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Diagramstil.primar)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(width: min(300, val.storlek.bredd * 0.46), alignment: .leading)
                    }
                }
            }
        }
        .chartXAxisLabel(position: .bottom, alignment: .center) {
            axeltitel(val.sprak.medelsvar.namn, val.sprak.medelsvar.enhet)
        }
        .forklaringsruta(visas: grupper.count > 1)
    }

    // MARK: - Gemensamma delar

    @ChartContentBuilder
    private var baslinje: some ChartContent {
        RuleMark(y: .value("Noll", 0))
            .foregroundStyle(Diagramstil.baslinje)
            .lineStyle(StrokeStyle(lineWidth: 1))
    }

    /// Lodrät linje med korta tvärstreck i ändarna (felstapel eller lådagrammets spröt).
    @ChartContentBuilder
    private func felstapel(grupp: String, fran: Double, till: Double) -> some ChartContent {
        RuleMark(x: .value("Grupp", grupp), yStart: .value("Nedre", fran), yEnd: .value("Övre", till))
            .foregroundStyle(Diagramstil.primar)
            .lineStyle(StrokeStyle(lineWidth: 1.5))
        ForEach([fran, till], id: \.self) { y in
            PointMark(x: .value("Grupp", grupp), y: .value("Ände", y))
                .symbol { Rectangle().fill(Diagramstil.primar).frame(width: 10, height: 1.5) }
        }
    }

    /// Enskilda deltagare. Närliggande värden får olika sidoförskjutning så att de inte täcker varandra.
    @ChartContentBuilder
    private func punkter(_ g: Gruppvarden) -> some ChartContent {
        let forskjutning: [CGFloat] = [0, -5, 5, -10, 10]
        ForEach(Array(g.tal.sorted().enumerated()), id: \.offset) { i, v in
            PointMark(x: .value("Grupp", g.grupp), y: .value("Deltagare", v))
                .symbol {
                    Circle()
                        .fill(Diagramstil.primar.opacity(0.8))
                        .frame(width: 7, height: 7)
                        .padding(1.5)
                        .background(Diagramstil.yta, in: Circle())
                }
                .offset(x: forskjutning[i % forskjutning.count])
        }
    }

    private func vardeetikett(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(Diagramstil.primar)
    }

    private func axeltitel(_ namn: String, _ enhet: String) -> some View {
        Text("\(namn) (\(enhet))")
            .font(.system(size: 11))
            .foregroundStyle(Diagramstil.sekundar)
    }

    private func gruppaxel(_ grupper: [Gruppvarden]) -> some AxisContent {
        AxisMarks { varde in
            AxisValueLabel {
                if let namn = varde.as(String.self) {
                    VStack(spacing: 1) {
                        Text(visad(namn))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Diagramstil.primar)
                        Text("n = \(grupper.first { $0.grupp == namn }?.n ?? 0)")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Diagramstil.sekundar)
                    }
                }
            }
        }
    }

    private var vardeaxel: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { _ in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Diagramstil.rutnat)
            AxisValueLabel().font(.system(size: 11)).foregroundStyle(Diagramstil.sekundar)
        }
    }

    /// Få grupper ska stå samlade i mitten i stället för utspridda över hela bredden.
    private func sidmarginal(_ antalGrupper: Int) -> CGFloat {
        max(0, (val.storlek.bredd - 100 - CGFloat(antalGrupper) * 150) / 2)
    }

    /// Lite luft runt punkterna utan att dra in nollan i onödan.
    private func omrade(_ v: [Double]) -> ClosedRange<Double> {
        guard let lagst = v.min(), let hogst = v.max(), lagst < hogst else { return 0...1 }
        let luft = (hogst - lagst) * 0.08
        return (lagst - luft)...(hogst + luft)
    }
}

private extension View {
    /// Fast skala när måttet har en, annars automatisk.
    @ViewBuilder
    func yskala(_ omrade: ClosedRange<Double>?, franNoll: Bool) -> some View {
        if let omrade {
            chartYScale(domain: omrade)
        } else {
            chartYScale(domain: .automatic(includesZero: franNoll))
        }
    }

    /// Förklaringsruta behövs bara när färgen skiljer flera grupper åt.
    @ViewBuilder
    func forklaringsruta(visas: Bool) -> some View {
        if visas {
            chartLegend(position: .top, alignment: .leading, spacing: 10)
        } else {
            chartLegend(.hidden)
        }
    }
}

/// Rubrik, förklaring och figurtext till ett diagram, på diagrammets språk.
enum Diagramtext {
    static func titel(_ val: Diagraminstallning) -> String {
        let egen = val.egenTitel.trimmingCharacters(in: .whitespaces)
        return egen.isEmpty ? automatiskTitel(val) : egen
    }

    static func automatiskTitel(_ val: Diagraminstallning) -> String {
        let sprak = val.sprak
        let en = sprak == .engelska
        let matt = sprak.namn(val.matt)
        switch val.typ {
        case .gruppmedel, .lada:
            return val.gruppering == .ingen ? matt : "\(matt) \(en ? "by" : "per") \(sprak.gruppering(val.gruppering))"
        case .perDeltagare:
            return "\(matt) \(en ? "per participant" : "per deltagare")"
        case .samband:
            return "\(matt) \(en ? "vs." : "mot") \(sprak.namn(val.xMatt))"
        case .setlangd:
            return "\(sprak.namn(val.setMatt)) \(en ? "by set size" : "per setlängd")"
        case .sasFragor:
            return en ? "SAS-SV: mean response per item" : "SAS-SV: medelsvar per fråga"
        }
    }

    /// Hela figurtexten: "Figur X. Rubrik. Förklaring."
    static func figurtext(_ val: Diagraminstallning, _ underlag: Diagramunderlag) -> String {
        "\(val.sprak.figur) X. \(automatiskTitel(val)). \(forklaring(val, underlag))"
    }

    /// Vad märkena betyder – står under rubriken och i den föreslagna figurtexten.
    static func forklaring(_ val: Diagraminstallning, _ underlag: Diagramunderlag) -> String {
        let sprak = val.sprak
        let en = sprak == .engelska
        var delar: [String] = []
        switch val.typ {
        case .gruppmedel:
            delar.append(en ? "Bars show the mean" : "Staplarna visar medelvärdet")
            if val.felstapel != .ingen {
                delar.append("\(en ? "error bars" : "felstaplarna") \(sprak.felstapel(val.felstapel))")
            }
            if val.visaPunkter { delar.append(en ? "dots individual participants" : "punkterna enskilda deltagare") }
        case .lada:
            delar.append(en
                ? "The box spans the first to the third quartile, the gap is the median and the whiskers reach the lowest and highest value"
                : "Lådan går från första till tredje kvartilen, glipan är medianen och spröten går till lägsta och högsta värdet")
            if val.visaPunkter { delar.append(en ? "dots are individual participants" : "punkterna är enskilda deltagare") }
        case .perDeltagare:
            delar.append(en
                ? "One bar per participant, sorted by value within each group"
                : "En stapel per deltagare, sorterade efter värde inom varje grupp")
        case .samband:
            let par = underlag.rader.compactMap { r -> (Double, Double)? in
                guard let x = val.xMatt.varde(r.deltagare, r.enkat), let y = val.matt.varde(r.deltagare, r.enkat) else { return nil }
                return (x, y)
            }
            delar.append("\(en ? "One dot per participant" : "En punkt per deltagare") (n = \(par.count))")
            if let r = Statistik.pearson(par.map(\.0), par.map(\.1)) {
                delar.append("\(en ? "Pearson's" : "Pearsons") r = \(sprak.tal(r, decimaler: 2, tecken: true))")
            }
            if val.trendlinje {
                delar.append(en ? "the line is the best-fitting straight line" : "linjen är den räta linje som passar punkterna bäst")
            }
        case .setlangd:
            delar.append(en ? "Mean per set size" : "Medelvärde per setlängd")
            if val.felstapel != .ingen {
                delar.append("\(en ? "error bars show" : "felstaplarna visar") \(sprak.felstapel(val.felstapel))")
            }
        case .sasFragor:
            delar.append("\(en ? "Mean response per statement" : "Medelsvar per påstående") (n = \(underlag.enkatrader.count))")
        }
        var text = delar.joined(separator: ", ") + "."
        let anvanda = val.typ == .samband ? [val.matt, val.xMatt] : val.typ == .setlangd || val.typ == .sasFragor ? [] : [val.matt]
        if let anmarkning = anvanda.compactMap(sprak.anmarkning).first {
            text += " " + anmarkning
        }
        return text
    }
}
