import Foundation
import Observation

/// SAS-SV – Smartphone Addiction Scale, Short Version (Kwon m.fl., 2013; formulering enligt
/// Olson m.fl., 2020, healthyscreens.com/sas-sv.pdf): 10 påståenden à 1–6 poäng, summa 10–60.
nonisolated enum SAS {
    static let antalFragor = 10
    static let gransMan = 31.0
    static let gransKvinna = 33.0

    /// Svarsalternativen 1–6. Google Formulär kan ge svenska eller engelska etiketter.
    static let alternativ: [(poang: Int, svenska: String, engelska: String)] = [
        (1, "Stämmer inte alls", "Strongly disagree"),
        (2, "Stämmer inte", "Disagree"),
        (3, "Stämmer knappast", "Weakly disagree"),
        (4, "Stämmer delvis", "Weakly agree"),
        (5, "Stämmer", "Agree"),
        (6, "Stämmer helt", "Strongly agree"),
    ]

    static func poang(_ text: String) -> Int? {
        if let siffra = Int(normalisera(text)), (1...6).contains(siffra) { return siffra }
        return etikettPoang(text)
    }

    /// Bara textsvaren ("Stämmer delvis"), inte siffror – skiljer SAS-frågorna från andra 1–7-skalor i enkäten.
    static func etikettPoang(_ text: String) -> Int? {
        let t = normalisera(text)
        return alternativ.first { normalisera($0.svenska) == t || normalisera($0.engelska) == t }?.poang
    }

    private static func normalisera(_ s: String) -> String {
        s.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

nonisolated enum Kon: String, Sendable {
    case man = "Man"
    case kvinna = "Kvinna"
    case annat = "Annat"

    init?(_ text: String) {
        switch text.lowercased().trimmingCharacters(in: .whitespaces) {
        case "": return nil
        case "man", "male": self = .man
        case "kvinna", "woman", "female": self = .kvinna
        default: self = .annat
        }
    }
}

/// En övrig sifferfråga i enkäten (skärmtid, utvilad, stress …) som kan jämföras med OSPAN.
nonisolated struct EnkatVariabel: Hashable, Identifiable, Sendable {
    let index: Int
    /// Frågan som den står i enkäten.
    let fraga: String
    /// Kort namn för tabeller och diagram.
    let namn: String
    let enhet: String
    /// Kolumnnamn i CSV-exporten.
    let nyckel: String
    let anmarkning: String?

    var id: Int { index }
    var decimaler: Int { 1 }

    init(index: Int, rubrik: String, harIntervall: Bool) {
        self.index = index
        fraga = rubrik
        let r = rubrik.lowercased()
        if r.contains("timmar") || r.contains("hours") {
            (namn, enhet, nyckel) = ("Skärmtid", "timmar per dag", "skarmtid_timmar")
        } else if r.contains("utvil") {
            (namn, enhet, nyckel) = ("Utvilad före testet", "skattning", "utvilad")
        } else if r.contains("stress") {
            (namn, enhet, nyckel) = ("Stressad före testet", "skattning", "stressad")
        } else if r.contains("tänkte") {
            (namn, enhet, nyckel) = ("Tänkte på mobilen under testet", "skattning", "tankte_pa_mobilen")
        } else {
            (namn, enhet, nyckel) = (rubrik.isEmpty ? "Extra \(index + 1)" : String(rubrik.prefix(40)), "värde", "extra_\(index + 1)")
        }
        anmarkning = harIntervall
            ? "Svaren är intervall och räknas som intervallets mitt: 4–5 timmar = 4,5 och mer än 6 timmar = 6,5."
            : nil
    }
}

/// Gör enkätsvar till tal: "3", "4–5 timmar" (→ 4,5), "Mer än 6 timmar" (→ 6,5).
nonisolated enum Enkattal {
    static func tolka(_ text: String) -> Double? {
        let t = text.lowercased().trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        if let v = Double(t.replacingOccurrences(of: ",", with: ".")) { return v.isFinite ? v : nil }
        let siffra = #"(\d+(?:[.,]\d+)?)"#
        let enhet = #"[\p{L}\s/.]*$"#
        if let m = tal(i: t, "^\(siffra)\\s*[–—-]\\s*\(siffra)\\s*\(enhet)"), m.count == 2 { return (m[0] + m[1]) / 2 }
        if let m = tal(i: t, "^(?:mer än|more than|över|over|>)\\s*\(siffra)\\s*\(enhet)"), m.count == 1 { return m[0] + 0.5 }
        if let m = tal(i: t, "^(?:mindre än|less than|under|<)\\s*\(siffra)\\s*\(enhet)"), m.count == 1 { return max(0, m[0] - 0.5) }
        return nil
    }

    static func arIntervall(_ text: String) -> Bool {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) == nil && tolka(text) != nil
    }

    /// Talen i mönstrets grupper, eller nil om texten inte passar.
    private static func tal(i text: String, _ monster: String) -> [Double]? {
        guard let regex = try? NSRegularExpression(pattern: monster),
              let traff = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<traff.numberOfRanges).compactMap { i in
            Range(traff.range(at: i), in: text).flatMap { Double(text[$0].replacingOccurrences(of: ",", with: ".")) }
        }
    }
}

nonisolated enum SASNiva: Int, CaseIterable, Comparable, Sendable {
    case under, granszon, over

    /// Gränsvärdet beror på kön (31 för män, 33 för kvinnor). Utan känt kön blir 31–32 en egen zon.
    init(poang: Double, kon: Kon?) {
        switch kon {
        case .man: self = poang >= SAS.gransMan ? .over : .under
        case .kvinna: self = poang >= SAS.gransKvinna ? .over : .under
        default: self = poang >= SAS.gransKvinna ? .over : poang >= SAS.gransMan ? .granszon : .under
        }
    }

    var namn: String {
        switch self {
        case .under: "Under gränsvärdet"
        case .granszon: "Gränszon"
        case .over: "Över gränsvärdet"
        }
    }

    var forklaring: String {
        switch self {
        case .under: "Under gränsvärdet (31 för män, 33 för kvinnor) – ingen förhöjd risk enligt SAS-SV"
        case .granszon: "31–32 utan angivet kön – över gränsen för män (31) men under gränsen för kvinnor (33)"
        case .over: "På eller över gränsvärdet (31 för män, 33 för kvinnor) – risk för problematisk mobilanvändning"
        }
    }

    static func < (a: SASNiva, b: SASNiva) -> Bool { a.rawValue < b.rawValue }
}

nonisolated struct SASResultat: Sendable {
    let besvarade: Int
    let summa: Int

    init?(svar: [Int?]) {
        let besvarat = svar.compactMap { $0 }
        guard !besvarat.isEmpty else { return nil }
        besvarade = besvarat.count
        summa = besvarat.reduce(0, +)
    }

    var medel: Double { Double(summa) / Double(besvarade) }
    /// Poäng på SAS-SV:s skala 10–60 (medel × 10). Samma som summan när alla tio frågor finns med.
    var poang: Double { Double(summa * SAS.antalFragor) / Double(besvarade) }
}

/// Ett svar i enkäten (en rad i Google Formulärs svarsfil).
@Observable
final class EnkatSvar: Identifiable {
    nonisolated enum Koppling: Hashable, Sendable {
        case automatisk
        case ingen
        case deltagare(UUID)
    }

    let id = UUID()
    let tid: Date?
    let tidText: String
    /// Poäng 1–6 per fråga; nil om svaret saknas eller inte gick att tolka.
    let svar: [Int?]
    let kon: Kon?
    /// Övriga sifferfrågor, i samma ordning som `Sammanstallning.enkatVariabler`.
    let extra: [Double?]
    /// Övriga celler på raden, t.ex. en kolumn där OSPAN-filens namn står.
    let ovrigt: [String]
    let resultat: SASResultat?
    var koppling: Koppling = .automatisk

    init(tid: Date?, tidText: String, svar: [Int?], kon: Kon?, extra: [Double?], ovrigt: [String]) {
        self.tid = tid
        self.tidText = tidText
        self.svar = svar
        self.kon = kon
        self.extra = extra
        self.ovrigt = ovrigt
        self.resultat = SASResultat(svar: svar)
    }

    func varde(_ variabel: EnkatVariabel) -> Double? {
        variabel.index < extra.count ? extra[variabel.index] : nil
    }

    var niva: SASNiva? { resultat.map { SASNiva(poang: $0.poang, kon: kon) } }

    var tidSortering: Date { tid ?? .distantFuture }
    var saknadeSvar: Int { svar.filter { $0 == nil }.count }
}

/// Läser svarsfilen från Google Formulär/Kalkylark: tidsstämpel i första kolumnen,
/// sedan svar. Rubrikraden är valfri – finns den används frågetexterna.
nonisolated enum EnkatTolkare {
    struct Rad {
        var tid: Date
        var tidText: String
        var svar: [Int?]
        var kon: Kon?
        var extra: [Double?]
        var ovrigt: [String]
    }

    struct Resultat {
        var fragor: [String]
        var variabler: [EnkatVariabel]
        var rader: [Rad]
    }

    static func tolka(_ text: String) -> Resultat? {
        let rensad = text.replacingOccurrences(of: "\u{FEFF}", with: "")
        let forsta = rensad.prefix { !$0.isNewline }
        let avgransare: Character = forsta.filter { $0 == ";" }.count > forsta.filter { $0 == "," }.count ? ";" : ","
        let rader = csvRader(rensad, avgransare: avgransare)
            .map { $0.map { $0.trimmingCharacters(in: .whitespaces) } }
            .filter { $0.contains { !$0.isEmpty } }

        let format = datumformat()
        func datum(_ s: String) -> Date? { format.lazy.compactMap { $0.date(from: s) }.first }

        let data = rader.compactMap { rad in rad.first.flatMap(datum).map { (rad, $0) } }
        guard !data.isEmpty else { return nil }
        let rubrik = rader.first.flatMap { rad in rad.first.flatMap(datum) == nil ? rad : nil }

        // SAS-kolumner = kolumner där minst hälften av svaren är ett SAS-alternativ i text.
        // Siffror godtas bara om enkäten saknar textsvar – annars räknas andra 1–7-skalor in.
        let alla = Array(1..<max(data.map(\.0.count).max() ?? 0, 1))
        func varden(_ k: Int) -> [String] {
            data.compactMap { k < $0.0.count ? $0.0[k] : nil }.filter { !$0.isEmpty }
        }
        func flest(_ k: Int, _ test: (String) -> Bool) -> Bool {
            let v = varden(k)
            return !v.isEmpty && v.filter(test).count * 2 >= v.count
        }
        let textkolumner = alla.filter { k in flest(k) { SAS.etikettPoang($0) != nil } }
        let kolumner = textkolumner.count >= 3 ? textkolumner : alla.filter { k in flest(k) { SAS.poang($0) != nil } }
        guard kolumner.count >= 3 else { return nil }

        func rubriktext(_ k: Int) -> String { rubrik.flatMap { k < $0.count ? $0[k] : nil } ?? "" }
        let konKolumn = alla.first { k in
            !kolumner.contains(k) && ["kön", "gender"].contains { rubriktext(k).lowercased().contains($0) }
        }
        // Övriga kolumner där svaren är tal eller intervall blir egna mått; resten sparas som text.
        let kandidater = alla.filter { !kolumner.contains($0) && $0 != konKolumn }
        let talkolumner = kandidater.filter { k in flest(k) { Enkattal.tolka($0) != nil } }
        let ovriga = kandidater.filter { !talkolumner.contains($0) }
        let variabler = talkolumner.enumerated().map { i, k in
            EnkatVariabel(index: i, rubrik: rubriktext(k), harIntervall: varden(k).contains(where: Enkattal.arIntervall))
        }

        let fragor = kolumner.enumerated().map { i, k in
            let text = fragetext(rubriktext(k))
            return text.isEmpty ? "Fråga \(i + 1)" : text
        }
        let svar = data.map { rad, tid in
            func cell(_ k: Int) -> String { k < rad.count ? rad[k] : "" }
            return Rad(tid: tid, tidText: rad[0], svar: kolumner.map { SAS.poang(cell($0)) },
                       kon: konKolumn.flatMap { Kon(cell($0)) },
                       extra: talkolumner.map { Enkattal.tolka(cell($0)) },
                       ovrigt: ovriga.map(cell).filter { !$0.isEmpty })
        }
        return Resultat(fragor: fragor, variabler: variabler, rader: svar)
    }

    /// Google Formulärs rutnätsfrågor heter "Gemensam fråga? [1. Påståendet.]" – behåll påståendet.
    private static func fragetext(_ rubrik: String) -> String {
        guard rubrik.hasSuffix("]"), let start = rubrik.lastIndex(of: "[") else { return rubrik }
        return String(rubrik[rubrik.index(after: start)..<rubrik.index(before: rubrik.endIndex)])
    }

    private static func datumformat() -> [DateFormatter] {
        ["yyyy-MM-dd HH.mm.ss", "yyyy-MM-dd HH:mm:ss", "yyyy/MM/dd HH:mm:ss", "dd/MM/yyyy HH:mm:ss",
         "M/d/yyyy H:mm:ss", "dd.MM.yyyy HH:mm:ss", "yyyy-MM-dd HH.mm", "yyyy-MM-dd HH:mm"].map {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = $0
            return f
        }
    }

    /// CSV med citattecken (frågetexter innehåller ofta kommatecken).
    private static func csvRader(_ text: String, avgransare: Character) -> [[String]] {
        var rader: [[String]] = []
        var rad: [String] = []
        var falt = ""
        var iCitat = false
        var tecken = text.makeIterator()
        var foregaende: Character?

        while let c = foregaende ?? tecken.next() {
            foregaende = nil
            if iCitat {
                if c == "\"" {
                    let nasta = tecken.next()
                    if nasta == "\"" {
                        falt.append("\"")
                    } else {
                        iCitat = false
                        foregaende = nasta
                    }
                } else {
                    falt.append(c)
                }
            } else if c == "\"" {
                iCitat = true
            } else if c == avgransare {
                rad.append(falt)
                falt = ""
            } else if c.isNewline {
                rad.append(falt)
                rader.append(rad)
                rad = []
                falt = ""
            } else {
                falt.append(c)
            }
        }
        if !falt.isEmpty || !rad.isEmpty {
            rad.append(falt)
            rader.append(rad)
        }
        return rader
    }
}
