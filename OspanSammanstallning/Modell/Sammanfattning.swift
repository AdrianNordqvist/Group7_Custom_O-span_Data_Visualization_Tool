import Foundation

nonisolated enum Statistik {
    static func medel(_ v: [Double]) -> Double? {
        v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
    }

    /// Stickprovsstandardavvikelse (n − 1).
    static func sd(_ v: [Double]) -> Double? {
        guard v.count > 1, let m = medel(v) else { return nil }
        return (v.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(v.count - 1)).squareRoot()
    }

    static func median(_ v: [Double]) -> Double? {
        guard !v.isEmpty else { return nil }
        let s = v.sorted()
        let mitt = s.count / 2
        return s.count.isMultiple(of: 2) ? (s[mitt - 1] + s[mitt]) / 2 : s[mitt]
    }

    /// Pearsons korrelation; nil vid färre än tre par eller ingen spridning.
    static func pearson(_ x: [Double], _ y: [Double]) -> Double? {
        guard x.count == y.count, x.count > 2, let mx = medel(x), let my = medel(y) else { return nil }
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for (a, b) in zip(x, y) {
            sxy += (a - mx) * (b - my)
            sxx += (a - mx) * (a - mx)
            syy += (b - my) * (b - my)
        }
        guard sxx > 0, syy > 0 else { return nil }
        return sxy / (sxx * syy).squareRoot()
    }

    /// Kvartil med linjär interpolation – samma som KVARTIL.INKL i Excel och Kalkylark.
    static func kvantil(_ v: [Double], _ p: Double) -> Double? {
        guard !v.isEmpty else { return nil }
        let s = v.sorted()
        let lage = p * Double(s.count - 1)
        let under = Int(lage.rounded(.down))
        let over = min(under + 1, s.count - 1)
        return s[under] + (s[over] - s[under]) * (lage - Double(under))
    }

    /// Minsta kvadrat-linjen y = skärning + lutning · x.
    static func regression(_ x: [Double], _ y: [Double]) -> (lutning: Double, skarning: Double)? {
        guard x.count == y.count, x.count > 1, let mx = medel(x), let my = medel(y) else { return nil }
        let sxx = x.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
        guard sxx > 0 else { return nil }
        let sxy = zip(x, y).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        return (sxy / sxx, my - sxy / sxx * mx)
    }

    /// Medelfel: SD / √n.
    static func medelfel(_ v: [Double]) -> Double? {
        sd(v).map { $0 / Double(v.count).squareRoot() }
    }

    /// Halva bredden på 95 %-konfidensintervallet för medelvärdet (t-fördelning, n − 1 frihetsgrader).
    static func konfidens95(_ v: [Double]) -> Double? {
        let t = [12.706, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365, 2.306, 2.262, 2.228,
                 2.201, 2.179, 2.160, 2.145, 2.131, 2.120, 2.110, 2.101, 2.093, 2.086,
                 2.080, 2.074, 2.069, 2.064, 2.060, 2.056, 2.052, 2.048, 2.045, 2.042]
        guard let se = medelfel(v) else { return nil }
        let fg = v.count - 1
        return se * (fg <= t.count ? t[fg - 1] : fg <= 60 ? 2.0 : 1.96)
    }
}

/// Nyckeltal för en deltagare, räknade på huvuddelen (10 set med längd 3–7, två av varje).
nonisolated struct Sammanfattning: Sendable {
    static let forvantadeSet = 10
    static let langder = 3...7

    var antalSet = 0
    /// Absolut O-Span: summan av set där alla bokstäver (och all matte) blev rätt – testets egen "ospan".
    var ospanAbsolut = 0
    /// Partial score: antal bokstäver rätt totalt.
    var partial = 0
    var maxBokstaver = 0
    var partialProcent = 0.0
    var matteRatt = 0
    var matteFel = 0
    var matteProcent = 0.0

    /// Tidsgräns för mattetal (maxMathRT1_ms), räknad från övningen.
    var tidsgrans = 0
    var matteRTMedel = 0.0
    var matteRTMedian = 0.0
    var matteRTSD: Double?
    var matteRTMin = 0.0
    var matteRTMax = 0.0
    /// Antal set där mathRT1 nådde tidsgränsen.
    var antalVidTidsgrans = 0

    var bokstavRTMedel = 0.0
    var bokstavRTMedian = 0.0
    var bokstavRTSD: Double?
    var bokstavRTTotal = 0

    var bokstavRTPerLangd: [Int: Double] = [:]
    var bokstaverProcentPerLangd: [Int: Double] = [:]

    var ovningMatteRTMedel: Double?
    var ovningBokstavRTMedel: Double?

    init(rader: [OspanRad]) {
        let huvud = rader.filter(\.arHuvuddata)
        antalSet = huvud.count
        ospanAbsolut = huvud.last?.ospan ?? 0

        partial = huvud.reduce(0) { $0 + $1.bokstaverRattForsok }
        maxBokstaver = huvud.reduce(0) { $0 + $1.sekvenslangd }
        partialProcent = maxBokstaver > 0 ? Double(partial) / Double(maxBokstaver) * 100 : 0

        matteRatt = huvud.reduce(0) { $0 + $1.matteRattForsok }
        matteFel = huvud.reduce(0) { $0 + $1.matteFelForsok }
        let matteTotalt = matteRatt + matteFel
        matteProcent = matteTotalt > 0 ? Double(matteRatt) / Double(matteTotalt) * 100 : 0

        tidsgrans = huvud.last?.maxMathRT1 ?? 0
        let matteRT = huvud.map { Double($0.mathRT1) }
        matteRTMedel = Statistik.medel(matteRT) ?? 0
        matteRTMedian = Statistik.median(matteRT) ?? 0
        matteRTSD = Statistik.sd(matteRT)
        matteRTMin = matteRT.min() ?? 0
        matteRTMax = matteRT.max() ?? 0
        antalVidTidsgrans = huvud.filter { $0.maxMathRT1 > 0 && $0.mathRT1 >= $0.maxMathRT1 }.count

        let bokstavRT = huvud.map { Double($0.bokstavRT) }
        bokstavRTMedel = Statistik.medel(bokstavRT) ?? 0
        bokstavRTMedian = Statistik.median(bokstavRT) ?? 0
        bokstavRTSD = Statistik.sd(bokstavRT)
        bokstavRTTotal = huvud.reduce(0) { $0 + $1.bokstavRT }

        for langd in Self.langder {
            let set = huvud.filter { $0.sekvenslangd == langd }
            guard !set.isEmpty else { continue }
            bokstavRTPerLangd[langd] = Statistik.medel(set.map { Double($0.bokstavRT) })
            let ratt = set.reduce(0) { $0 + $1.bokstaverRattForsok }
            bokstaverProcentPerLangd[langd] = Double(ratt) / Double(langd * set.count) * 100
        }

        ovningMatteRTMedel = Statistik.medel(rader.filter { $0.blocknamn == "practiseMath" }.map { Double($0.mathRT1) })
        ovningBokstavRTMedel = Statistik.medel(rader.filter { $0.blocknamn == "practiseLetters" }.map { Double($0.bokstavRT) })
    }
}

/// Måtten som jämförs mellan villkoren.
nonisolated enum Matt: String, CaseIterable, Identifiable, Sendable {
    case ospanAbsolut, ospanPartial, partialProcent, matteProcent
    case matteRTMedel, matteRTMedian, tidsgrans, vidTidsgrans
    case bokstavRTMedel, bokstavRTMedian, bokstavRTTotal

    var id: String { rawValue }

    var namn: String {
        switch self {
        case .ospanAbsolut: "O-Span absolut"
        case .ospanPartial: "O-Span partial"
        case .partialProcent: "Bokstäver rätt"
        case .matteProcent: "Matte rätt"
        case .matteRTMedel: "Matte-RT medel"
        case .matteRTMedian: "Matte-RT median"
        case .tidsgrans: "Tidsgräns matte"
        case .vidTidsgrans: "Set vid tidsgränsen"
        case .bokstavRTMedel: "Bokstav-RT medel"
        case .bokstavRTMedian: "Bokstav-RT median"
        case .bokstavRTTotal: "Bokstav-RT totalt"
        }
    }

    var enhet: String {
        switch self {
        case .ospanAbsolut, .ospanPartial: "poäng"
        case .partialProcent, .matteProcent: "%"
        case .vidTidsgrans: "st"
        default: "ms"
        }
    }

    var decimaler: Int {
        switch self {
        case .matteRTMedel, .matteRTMedian, .tidsgrans, .bokstavRTMedel, .bokstavRTMedian, .bokstavRTTotal: 0
        default: 1
        }
    }

    func varde(_ s: Sammanfattning) -> Double {
        switch self {
        case .ospanAbsolut: Double(s.ospanAbsolut)
        case .ospanPartial: Double(s.partial)
        case .partialProcent: s.partialProcent
        case .matteProcent: s.matteProcent
        case .matteRTMedel: s.matteRTMedel
        case .matteRTMedian: s.matteRTMedian
        case .tidsgrans: Double(s.tidsgrans)
        case .vidTidsgrans: Double(s.antalVidTidsgrans)
        case .bokstavRTMedel: s.bokstavRTMedel
        case .bokstavRTMedian: s.bokstavRTMedian
        case .bokstavRTTotal: Double(s.bokstavRTTotal)
        }
    }
}

/// Alla deltagare som räknas med i ett villkor.
nonisolated struct Grupp: Identifiable, Sendable {
    let villkor: Villkor
    let sammanfattningar: [Sammanfattning]

    var id: Villkor { villkor }
    var n: Int { sammanfattningar.count }

    func varden(_ m: Matt) -> [Double] { sammanfattningar.map(m.varde) }
    func medel(_ m: Matt) -> Double? { Statistik.medel(varden(m)) }
    func sd(_ m: Matt) -> Double? { Statistik.sd(varden(m)) }
    func median(_ m: Matt) -> Double? { Statistik.median(varden(m)) }
}
