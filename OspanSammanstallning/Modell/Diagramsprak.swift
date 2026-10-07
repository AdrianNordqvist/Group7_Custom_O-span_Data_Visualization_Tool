import Foundation

/// Språket för texterna i själva diagrammet. Appen i övrigt är på svenska.
nonisolated enum Diagramsprak: String, CaseIterable, Identifiable, Sendable {
    case svenska = "Svenska"
    case engelska = "English"

    var id: String { rawValue }
    private var en: Bool { self == .engelska }

    /// Styr decimaltecken och tusentalsavgränsare i diagrammet.
    var locale: Locale { Locale(identifier: en ? "en_GB" : "sv_SE") }

    // MARK: - Mått

    func namn(_ m: Diagrammatt) -> String {
        guard en else { return m.namn }
        switch m {
        case .ospan(let ospan):
            switch ospan {
            case .ospanAbsolut: return "O-Span absolute score"
            case .ospanPartial: return "O-Span partial score"
            case .partialProcent: return "Letters correct"
            case .matteProcent: return "Math accuracy"
            case .matteRTMedel: return "Mean math RT"
            case .matteRTMedian: return "Median math RT"
            case .tidsgrans: return "Math time limit"
            case .vidTidsgrans: return "Sets at the time limit"
            case .bokstavRTMedel: return "Mean letter-recall time"
            case .bokstavRTMedian: return "Median letter-recall time"
            case .bokstavRTTotal: return "Total letter-recall time"
            }
        case .sas:
            return "SAS-SV score"
        case .enkat(let v):
            switch v.nyckel {
            case "skarmtid_timmar": return "Screen time"
            case "tankte_pa_mobilen": return "Thought about phone during test"
            case "utvilad": return "Rested before test"
            case "stressad": return "Stressed before test"
            default: return v.namn
            }
        }
    }

    func enhet(_ m: Diagrammatt) -> String {
        guard en else { return m.enhet }
        switch m.enhet {
        case "poäng": return "points"
        case "st": return "count"
        case "timmar per dag": return "hours per day"
        case "skattning": return "rating"
        case "värde": return "value"
        default: return m.enhet
        }
    }

    func namn(_ m: Setmatt) -> String {
        guard en else { return m.rawValue }
        return m == .procent ? "Letters correct" : "Letter-recall time"
    }

    func anmarkning(_ m: Diagrammatt) -> String? {
        guard let svensk = m.anmarkning else { return nil }
        return en ? "Answers are ranges and are counted as the midpoint: 4–5 hours = 4.5 and more than 6 hours = 6.5." : svensk
    }

    // MARK: - Grupper

    /// Gruppnamnet som det ska stå i diagrammet. Nyckeln är alltid det svenska namnet.
    func grupp(_ nyckel: String) -> String {
        guard en else { return nyckel }
        let oversattning = [
            "Med mobil": "Phone present", "Utan mobil": "Phone absent", "Okänt": "Unknown", "Test": "Test",
            "Kvinna": "Woman", "Man": "Man", "Annat": "Other",
            "Under gränsvärdet": "Below cutoff", "Över gränsvärdet": "Above cutoff", "Gränszon": "Borderline",
            "Alla": "All",
        ]
        return oversattning[nyckel] ?? nyckel
    }

    func gruppering(_ g: Gruppering) -> String {
        guard en else { return g.iTitel }
        switch g {
        case .villkor: return "condition"
        case .kon: return "gender"
        case .sasNiva: return "SAS level"
        case .ingen: return ""
        }
    }

    // MARK: - Enkätfrågor

    /// På engelska får SAS-SV-påståendena korta beskrivande etiketter (inte skalans exakta ordalydelse).
    private static let sasKort = [
        "Miss planned work", "Hard to concentrate on class or work", "Pain in wrists or neck",
        "Could not stand being without it", "Impatient when not holding it", "On my mind when not in use",
        "Would never give it up", "Constantly check social media", "Use it longer than intended",
        "Others say I use it too much",
    ]

    func fraga(_ text: String, plats: Int, antal: Int) -> String {
        guard en else { return text }
        if text.hasPrefix("Fråga ") { return "Question \(plats + 1)" }
        // Bara när enkäten är hela SAS-SV och frågan bär sitt nummer, annars vet vi inte vilken fråga det är.
        if antal == Self.sasKort.count, text.hasPrefix("\(plats + 1). ") {
            return "\(plats + 1). \(Self.sasKort[plats])"
        }
        return text
    }

    // MARK: - Fasta texter

    var median: String { en ? "Mdn" : "Md" }
    var figur: String { en ? "Figure" : "Figur" }
    var setlangd: (namn: String, enhet: String) {
        en ? ("Set size", "number of letters") : ("Setlängd", "antal bokstäver")
    }
    var medelsvar: (namn: String, enhet: String) {
        en ? ("Mean response", "1 = strongly disagree, 6 = strongly agree") : ("Medelsvar", "1 = stämmer inte alls, 6 = stämmer helt")
    }

    func felstapel(_ f: Felstapel) -> String {
        guard en else { return f.iText }
        switch f {
        case .sd: return "± 1 standard deviation"
        case .se: return "± 1 standard error"
        case .ki95: return "the 95% confidence interval"
        case .ingen: return ""
        }
    }

    func tal(_ v: Double, decimaler: Int, tecken: Bool = false) -> String {
        v.formatted(.number.precision(.fractionLength(decimaler)).sign(strategy: tecken ? .always() : .automatic).locale(locale))
    }
}
