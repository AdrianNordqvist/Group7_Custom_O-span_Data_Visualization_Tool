import Foundation

/// En rad i OSPAN-testets utdata: ett set i huvuddelen eller en övningsomgång.
/// Kolumnerna är samma som testet sparar (KOLUMNER i OspanTestV1KPGrupp7_spara.html).
nonisolated struct OspanRad: Hashable, Sendable {
    static let kolumner = [
        "block", "blocknamn", "ospan", "bokstaverRattHittills", "matteRattHittills",
        "mathRT1_ms", "bokstavRT_ms", "maxMathRT1_ms", "matteRattProcent", "sekvenslangd",
        "matteRattForsok", "matteFelForsok", "bokstaverRattForsok",
    ]

    var block: Int
    var blocknamn: String
    var ospan: Int
    var bokstaverRattHittills: Int
    var matteRattHittills: Int
    var mathRT1: Int
    var bokstavRT: Int
    var maxMathRT1: Int
    var matteRattProcent: Int
    var sekvenslangd: Int
    var matteRattForsok: Int
    var matteFelForsok: Int
    var bokstaverRattForsok: Int

    /// Huvuddelen ("maindata") – övningsblocken räknas inte in i poängen.
    var arHuvuddata: Bool { blocknamn.caseInsensitiveCompare("maindata") == .orderedSame }

    /// Värdena i samma ordning som `kolumner`.
    var falt: [String] {
        [String(block), blocknamn, String(ospan), String(bokstaverRattHittills), String(matteRattHittills),
         String(mathRT1), String(bokstavRT), String(maxMathRT1), String(matteRattProcent), String(sekvenslangd),
         String(matteRattForsok), String(matteFelForsok), String(bokstaverRattForsok)]
    }

    /// Tolkar 13 fält; nil om raden inte är data (rubrikrad, tom mallrad o.s.v.).
    init?(falt: [String]) {
        guard falt.count >= 13, !falt[1].isEmpty else { return nil }
        var n: [Int] = []
        for (i, f) in falt.prefix(13).enumerated() where i != 1 {
            guard let v = Self.heltal(f) else { return nil }
            n.append(v)
        }
        block = n[0]; blocknamn = falt[1]
        ospan = n[1]; bokstaverRattHittills = n[2]; matteRattHittills = n[3]
        mathRT1 = n[4]; bokstavRT = n[5]; maxMathRT1 = n[6]; matteRattProcent = n[7]
        sekvenslangd = n[8]; matteRattForsok = n[9]; matteFelForsok = n[10]; bokstaverRattForsok = n[11]
    }

    private static func heltal(_ s: String) -> Int? {
        if let i = Int(s) { return i }
        // Tål decimaltal om filen har passerat Excel/Numbers.
        guard let d = Double(s.replacingOccurrences(of: ",", with: ".")), d.isFinite else { return nil }
        return Int(d.rounded())
    }
}

/// Läser både testets .csv (semikolon, med rubrik) och PsyToolkits .txt (mellanslag, utan rubrik).
nonisolated enum OspanTolkare {
    struct Resultat {
        var rader: [OspanRad]
        var olasbaraRader: Int
    }

    static func tolka(_ text: String) -> Resultat {
        var rader: [OspanRad] = []
        var olasbara = 0
        for rad in text.replacingOccurrences(of: "\u{FEFF}", with: "").components(separatedBy: .newlines) {
            let trimmad = rad.trimmingCharacters(in: .whitespaces)
            guard !trimmad.isEmpty else { continue }
            let falt = delaUpp(trimmad)
            if let r = OspanRad(falt: falt) {
                rader.append(r)
            } else if falt.first?.caseInsensitiveCompare("block") != .orderedSame {
                olasbara += 1
            }
        }
        return Resultat(rader: rader, olasbaraRader: olasbara)
    }

    private static let skrap = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\""))

    private static func delaUpp(_ rad: String) -> [String] {
        for avgransare in [";", "\t", ","] where rad.contains(avgransare) {
            return rad.components(separatedBy: avgransare).map { $0.trimmingCharacters(in: skrap) }
        }
        return rad.split(separator: " ").map(String.init)
    }
}
