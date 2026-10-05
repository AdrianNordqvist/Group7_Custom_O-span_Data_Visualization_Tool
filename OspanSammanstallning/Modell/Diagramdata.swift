import Foundation

nonisolated enum Diagramtyp: String, CaseIterable, Identifiable, Sendable {
    case gruppmedel = "Medelvärde per grupp"
    case lada = "Lådagram per grupp"
    case perDeltagare = "Stapel per deltagare"
    case samband = "Samband mellan två mått"
    case setlangd = "Resultat per setlängd"
    case sasFragor = "SAS-SV per fråga"

    var id: String { rawValue }
    /// En enda stapel eller låda säger ingenting, så de här typerna kräver en gruppering.
    var tillaterOgrupperat: Bool { self != .gruppmedel && self != .lada }
}

nonisolated enum Gruppering: String, CaseIterable, Identifiable, Sendable {
    case villkor = "Villkor"
    case kon = "Kön"
    case sasNiva = "SAS-nivå"
    case ingen = "Ingen gruppering"

    var id: String { rawValue }
    var kraverEnkat: Bool { self == .kon || self == .sasNiva }

    /// Fast ordning. Gruppens plats avgör färgen, så samma grupp får samma färg i alla diagram.
    var ordning: [String] {
        switch self {
        case .villkor: Villkor.allCases.map(\.rawValue)
        case .kon: [Kon.kvinna, .man, .annat].map(\.rawValue)
        case .sasNiva: [SASNiva.under, .over, .granszon].map(\.namn)
        case .ingen: ["Alla"]
        }
    }

    var iTitel: String {
        switch self {
        case .villkor: "villkor"
        case .kon: "kön"
        case .sasNiva: "SAS-nivå"
        case .ingen: ""
        }
    }
}

nonisolated enum Felstapel: String, CaseIterable, Identifiable, Sendable {
    case sd = "± 1 standardavvikelse"
    case se = "± 1 medelfel (SE)"
    case ki95 = "95 % konfidensintervall"
    case ingen = "Inga"

    var id: String { rawValue }

    func varde(_ v: [Double]) -> Double? {
        switch self {
        case .sd: Statistik.sd(v)
        case .se: Statistik.medelfel(v)
        case .ki95: Statistik.konfidens95(v)
        case .ingen: nil
        }
    }

    var iText: String {
        switch self {
        case .sd: "± 1 standardavvikelse"
        case .se: "± 1 medelfel"
        case .ki95: "95 % konfidensintervall"
        case .ingen: ""
        }
    }
}

nonisolated enum Setmatt: String, CaseIterable, Identifiable, Sendable {
    case procent = "Andel rätt bokstäver"
    case tid = "Tid för att ange bokstäverna"

    var id: String { rawValue }
    var enhet: String { self == .procent ? "%" : "ms" }
}

nonisolated enum Diagramstorlek: String, CaseIterable, Identifiable, Sendable {
    case liten = "Liten (480 × 340)"
    case mellan = "Mellan (640 × 420)"
    case stor = "Stor (800 × 520)"
    case bred = "Bred (900 × 420)"

    var id: String { rawValue }

    var bredd: CGFloat {
        switch self {
        case .liten: 480
        case .mellan: 640
        case .stor: 800
        case .bred: 900
        }
    }

    var hojd: CGFloat {
        switch self {
        case .liten: 340
        case .mellan, .bred: 420
        case .stor: 520
        }
    }
}

/// Ett mått per deltagare som kan ritas: OSPAN-måtten, SAS-SV-poängen och enkätens övriga sifferfrågor.
nonisolated enum Diagrammatt: Hashable, Identifiable, Sendable {
    case ospan(Matt)
    case sas
    case enkat(EnkatVariabel)

    static func alla(_ variabler: [EnkatVariabel]) -> [Diagrammatt] {
        Matt.allCases.map(Diagrammatt.ospan) + [.sas] + variabler.map(Diagrammatt.enkat)
    }

    var kraverEnkat: Bool {
        if case .ospan = self { false } else { true }
    }

    var id: String {
        switch self {
        case .ospan(let m): m.rawValue
        case .sas: "sas"
        case .enkat(let v): "enkat-\(v.index)"
        }
    }

    var namn: String {
        switch self {
        case .ospan(let m): m.namn
        case .sas: "SAS-SV-poäng"
        case .enkat(let v): v.namn
        }
    }

    var enhet: String {
        switch self {
        case .ospan(let m): m.enhet
        case .sas: "poäng"
        case .enkat(let v): v.enhet
        }
    }

    var decimaler: Int {
        switch self {
        case .ospan(let m): m.decimaler
        case .sas: 1
        case .enkat(let v): v.decimaler
        }
    }

    /// Något läsaren behöver veta om hur måttet är räknat.
    var anmarkning: String? {
        if case .enkat(let v) = self { v.anmarkning } else { nil }
    }

    /// Måttets naturliga skala, när det har en.
    var skala: ClosedRange<Double>? {
        switch self {
        case .ospan(.ospanAbsolut), .ospan(.ospanPartial): 0...50
        case .ospan(.partialProcent), .ospan(.matteProcent): 0...100
        case .ospan(.vidTidsgrans): 0...10
        case .sas: 0...60
        default: nil
        }
    }

    @MainActor
    func varde(_ d: Deltagare, _ enkat: EnkatSvar?) -> Double? {
        switch self {
        case .ospan(let m): m.varde(d.sammanfattning)
        case .sas: enkat?.resultat?.poang
        case .enkat(let v): enkat?.varde(v)
        }
    }
}

nonisolated struct Diagraminstallning: Equatable, Sendable {
    var typ = Diagramtyp.gruppmedel
    var matt = Diagrammatt.ospan(.ospanPartial)
    var xMatt = Diagrammatt.sas
    var setMatt = Setmatt.procent
    var gruppering = Gruppering.villkor
    var felstapel = Felstapel.sd
    var visaPunkter = true
    var trendlinje = true
    var visaTitel = true
    var egenTitel = ""
    var storlek = Diagramstorlek.mellan
    var sprak = Diagramsprak.svenska
}

/// Värden för en grupp, i samma ordning som deltagarna.
nonisolated struct Gruppvarden: Identifiable, Sendable {
    let grupp: String
    let koder: [String]
    let tal: [Double]

    var id: String { grupp }
    var n: Int { tal.count }
    var medel: Double? { Statistik.medel(tal) }
    var sd: Double? { Statistik.sd(tal) }
    var median: Double? { Statistik.median(tal) }
}

/// De medräknade deltagarna indelade i grupper – det alla diagram ritas från.
struct Diagramunderlag {
    struct Rad: Identifiable {
        let deltagare: Deltagare
        let enkat: EnkatSvar?
        let grupp: String

        var id: Deltagare.ID { deltagare.id }
        var kod: String { deltagare.kod }
    }

    struct Enkatrad {
        let svar: [Int?]
        let grupp: String
    }

    let gruppering: Gruppering
    let rader: [Rad]
    let enkatrader: [Enkatrad]
    let fragor: [String]
    /// Medräknade deltagare som saknar grupp, t.ex. ingen enkät när man grupperar på kön.
    let utanGrupp: Int

    init(data: Sammanstallning, gruppering: Gruppering) {
        self.gruppering = gruppering
        fragor = data.enkatFragor
        let enkater = data.enkatPerDeltagare
        let kopplingar = data.kopplingar
        let medraknade = data.medraknade

        rader = medraknade.compactMap { d in
            let enkat = enkater[d.id]
            return Self.grupp(gruppering, deltagare: d, enkat: enkat).map { Rad(deltagare: d, enkat: enkat, grupp: $0) }
        }
        utanGrupp = medraknade.count - rader.count
        enkatrader = data.enkatsvar.compactMap { s in
            let d = kopplingar[s.id].flatMap { $0.medraknas ? $0 : nil }
            // Villkoret kommer från OSPAN-omgången, så okopplade svar faller bort där.
            if gruppering == .villkor && d == nil { return nil }
            return Self.grupp(gruppering, deltagare: d, enkat: s).map { Enkatrad(svar: s.svar, grupp: $0) }
        }
    }

    private static func grupp(_ gruppering: Gruppering, deltagare: Deltagare?, enkat: EnkatSvar?) -> String? {
        switch gruppering {
        case .ingen: "Alla"
        case .villkor: deltagare?.villkor.rawValue
        case .kon: enkat?.kon?.rawValue
        case .sasNiva: enkat?.niva?.namn
        }
    }

    /// Grupperna som faktiskt förekommer, i fast ordning.
    var grupper: [String] {
        gruppering.ordning.filter { g in rader.contains { $0.grupp == g } }
    }

    var enkatgrupper: [String] {
        gruppering.ordning.filter { g in enkatrader.contains { $0.grupp == g } }
    }

    func varden(_ matt: Diagrammatt) -> [Gruppvarden] {
        grupper.map { g in
            let par = rader.filter { $0.grupp == g }.compactMap { r in
                matt.varde(r.deltagare, r.enkat).map { (r.kod, $0) }
            }
            return Gruppvarden(grupp: g, koder: par.map(\.0), tal: par.map(\.1))
        }
        .filter { $0.n > 0 }
    }

    /// Värden per grupp för en viss setlängd (3–7).
    func varden(_ matt: Setmatt, langd: Int) -> [Gruppvarden] {
        grupper.map { g in
            let par = rader.filter { $0.grupp == g }.compactMap { r -> (String, Double)? in
                let s = r.deltagare.sammanfattning
                let v = matt == .procent ? s.bokstaverProcentPerLangd[langd] : s.bokstavRTPerLangd[langd]
                return v.map { (r.kod, $0) }
            }
            return Gruppvarden(grupp: g, koder: par.map(\.0), tal: par.map(\.1))
        }
        .filter { $0.n > 0 }
    }

    /// Svaren (1–6) på en enkätfråga per grupp.
    func svar(fraga i: Int) -> [Gruppvarden] {
        enkatgrupper.map { g in
            let tal = enkatrader.filter { $0.grupp == g }.compactMap { i < $0.svar.count ? $0.svar[i] : nil }.map(Double.init)
            return Gruppvarden(grupp: g, koder: [], tal: tal)
        }
        .filter { $0.n > 0 }
    }
}
