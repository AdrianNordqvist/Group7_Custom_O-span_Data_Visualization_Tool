import Foundation

/// Experimentvillkor. Ordningen här styr sorteringen i tabell och export.
nonisolated enum Villkor: String, CaseIterable, Identifiable, Comparable, Sendable {
    case medMobil = "Med mobil"
    case utanMobil = "Utan mobil"
    case okant = "Okänt"
    case test = "Test"

    var id: String { rawValue }

    /// Namn utan mellanslag/åäö för kolumnrubriker i CSV.
    var slug: String {
        switch self {
        case .medMobil: "med_mobil"
        case .utanMobil: "utan_mobil"
        case .okant: "okant"
        case .test: "test"
        }
    }

    private var ordning: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (a: Villkor, b: Villkor) -> Bool { a.ordning < b.ordning }
}

/// Plockar ut villkor, namn och tidpunkt ur filnamn som
/// "ospan_data_2026-09-30_12-33-55 M Erik.csv", "ospan_data_Annamedmobil2026-09-28_16-13-23.csv"
/// och "Files.data.2026-09-28--13-19 M.txt".
nonisolated enum FilnamnTolkare {
    struct Info {
        var villkor: Villkor
        var namn: String
        var datum: Date?
    }

    static func tolka(filnamn: String, mappnamn: String? = nil) -> Info {
        let bas = (filnamn as NSString).deletingPathExtension
        let villkor = villkorITexten(bas) ?? mappnamn.flatMap(villkorITexten) ?? .okant
        return Info(villkor: villkor, namn: namn(bas), datum: datum(bas))
    }

    /// Ord av enbart bokstäver: "…_12-33-55 M Erik" → ["ospan", "data", "m", "erik"].
    private static func ord(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
    }

    private static func villkorITexten(_ text: String) -> Villkor? {
        let ordlista = ord(text)
        if ordlista.contains("test") { return .test }
        let ihopskrivet = ordlista.joined()
        if ihopskrivet.contains("utanmobil") { return .utanMobil }
        if ihopskrivet.contains("medmobil") { return .medMobil }
        // Ensamma bokstäver U/M efter tidsstämpeln.
        if ordlista.contains("u") || ordlista.contains("utan") { return .utanMobil }
        if ordlista.contains("m") || ordlista.contains("med") { return .medMobil }
        return nil
    }

    private static let stoppord: Set<String> = [
        "ospan", "data", "files", "file", "kopia", "copy", "csv", "txt", "obs",
        "test", "med", "utan", "mobil",
    ]

    private static func namn(_ bas: String) -> String {
        ord(bas)
            .map { $0.replacingOccurrences(of: "utanmobil", with: "").replacingOccurrences(of: "medmobil", with: "") }
            .filter { $0.count > 1 && !stoppord.contains($0) }
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// "2026-09-30_12-33-55" eller "2026-09-28--13-19".
    private static func datum(_ bas: String) -> Date? {
        let monster = #"(\d{4})-(\d{2})-(\d{2})[_ -]+(\d{2})-(\d{2})(?:-(\d{2}))?"#
        guard let regex = try? NSRegularExpression(pattern: monster),
              let traff = regex.firstMatch(in: bas, range: NSRange(bas.startIndex..., in: bas))
        else { return nil }
        func del(_ i: Int) -> Int? {
            Range(traff.range(at: i), in: bas).flatMap { Int(bas[$0]) }
        }
        var k = DateComponents()
        k.year = del(1); k.month = del(2); k.day = del(3)
        k.hour = del(4); k.minute = del(5); k.second = del(6) ?? 0
        return Calendar.current.date(from: k)
    }
}
