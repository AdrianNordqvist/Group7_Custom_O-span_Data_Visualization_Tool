import Foundation

/// Semikolonseparerad CSV med UTF-8-BOM, så att svensk Excel/Numbers öppnar den rätt direkt.
nonisolated struct CSVFormat {
    var decimaltecken: String

    func tal(_ v: Double?, _ decimaler: Int) -> String {
        guard let v, v.isFinite else { return "" }
        return String(format: "%.\(decimaler)f", v).replacingOccurrences(of: ".", with: decimaltecken)
    }

    func text(_ s: String) -> String {
        guard s.contains(where: { $0 == ";" || $0 == "\"" || $0.isNewline }) else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    func dokument(_ rader: [[String]]) -> String {
        "\u{FEFF}" + rader.map { $0.joined(separator: ";") }.joined(separator: "\r\n") + "\r\n"
    }
}

enum CSVExport {
    private static let tidsformat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private static func datum(_ d: Date?) -> String { d.map(tidsformat.string(from:)) ?? "" }

    /// En rad per deltagare med poäng och tider – den stora jämförelsefilen.
    /// Med enkätsvar kopplade kommer SAS-SV-kolumnerna med sist.
    static func perDeltagare(_ deltagare: [Deltagare], sas: [Deltagare.ID: EnkatSvar] = [:], sasFragor: Int = 0,
                             variabler: [EnkatVariabel] = [], format f: CSVFormat) -> String {
        let langder = Array(Sammanfattning.langder)
        var rubrik = [
            "deltagare", "namn", "villkor", "datum", "fil",
            "antal_set", "ospan_absolut", "ospan_partial", "max_bokstaver", "partial_procent",
            "matte_ratt", "matte_fel", "matte_procent", "matte_minst_85",
            "tidsgrans_matte_ms", "matteRT_medel_ms", "matteRT_median_ms", "matteRT_sd_ms",
            "matteRT_min_ms", "matteRT_max_ms", "antal_set_vid_tidsgrans",
            "bokstavRT_medel_ms", "bokstavRT_median_ms", "bokstavRT_sd_ms", "bokstavRT_totalt_ms",
        ]
        rubrik += langder.map { "bokstavRT_langd\($0)_ms" }
        rubrik += langder.map { "bokstaver_procent_langd\($0)" }
        rubrik += ["ovning_matteRT_medel_ms", "ovning_bokstavRT_medel_ms"]
        if sasFragor > 0 {
            rubrik += Self.sasRubriker + (1...sasFragor).map { "sas_f\($0)" } + variabler.map(\.nyckel)
        }
        rubrik.append("varningar")

        var rader = [rubrik]
        for d in deltagare {
            let s = d.sammanfattning
            var rad = [
                d.kod, f.text(d.namn), d.villkor.rawValue, datum(d.datum), f.text(d.filnamn),
                String(s.antalSet), String(s.ospanAbsolut), String(s.partial), String(s.maxBokstaver),
                f.tal(s.partialProcent, 1),
                String(s.matteRatt), String(s.matteFel), f.tal(s.matteProcent, 1), s.matteProcent >= 85 ? "ja" : "nej",
                String(s.tidsgrans), f.tal(s.matteRTMedel, 0), f.tal(s.matteRTMedian, 0), f.tal(s.matteRTSD, 0),
                f.tal(s.matteRTMin, 0), f.tal(s.matteRTMax, 0), String(s.antalVidTidsgrans),
                f.tal(s.bokstavRTMedel, 0), f.tal(s.bokstavRTMedian, 0), f.tal(s.bokstavRTSD, 0), String(s.bokstavRTTotal),
            ]
            rad += langder.map { f.tal(s.bokstavRTPerLangd[$0], 0) }
            rad += langder.map { f.tal(s.bokstaverProcentPerLangd[$0], 1) }
            rad += [f.tal(s.ovningMatteRTMedel, 0), f.tal(s.ovningBokstavRTMedel, 0)]
            if sasFragor > 0 {
                rad += sasKolumner(sas[d.id], antalFragor: sasFragor, format: f)
                rad += variabler.map { v in f.tal(sas[d.id]?.varde(v), v.decimaler) }
            }
            rad.append(f.text(d.varningar.joined(separator: " | ")))
            rader.append(rad)
        }
        return f.dokument(rader)
    }

    /// En rad per enkätsvar med SAS-SV-poäng och kopplad OSPAN-omgång.
    static func enkat(_ svar: [EnkatSvar], fragor: [String], variabler: [EnkatVariabel] = [],
                      kopplingar: [EnkatSvar.ID: Deltagare], format f: CSVFormat) -> String {
        // Första kolumnen är inte en tidsstämpel, så filen läses inte in igen som enkät.
        var rader = [["deltagare", "namn", "villkor", "tid"] + sasRubriker
                     + fragor.indices.map { "sas_f\($0 + 1)" } + variabler.map(\.nyckel) + ["ospan_absolut", "ospan_partial"]]
        for s in svar {
            let d = kopplingar[s.id]
            var rad = [d?.kod ?? "", f.text(d?.namn ?? ""), d?.villkor.rawValue ?? "", f.text(s.tidText)]
            rad += sasKolumner(s, antalFragor: fragor.count, format: f)
            rad += variabler.map { v in f.tal(s.varde(v), v.decimaler) }
            rad += [d.map { String($0.sammanfattning.ospanAbsolut) } ?? "", d.map { String($0.sammanfattning.partial) } ?? ""]
            rader.append(rad)
        }
        return f.dokument(rader)
    }

    private static let sasRubriker = ["kon", "sas_besvarade", "sas_summa", "sas_medel_1_6", "sas_poang_10_60", "sas_niva"]

    private static func sasKolumner(_ s: EnkatSvar?, antalFragor: Int, format f: CSVFormat) -> [String] {
        guard let s, let r = s.resultat else { return Array(repeating: "", count: sasRubriker.count + antalFragor) }
        return [s.kon?.rawValue ?? "", String(r.besvarade), String(r.summa), f.tal(r.medel, 2), f.tal(r.poang, 1),
                s.niva?.namn ?? ""]
            + (0..<antalFragor).map { $0 < s.svar.count ? s.svar[$0].map(String.init) ?? "" : "" }
    }

    /// Alla rader från alla filer under varandra (långt format), med deltagare och villkor först.
    static func allaRader(_ deltagare: [Deltagare], format f: CSVFormat) -> String {
        var rader = [["deltagare", "namn", "villkor", "fil", "rad", "set_nr"] + OspanRad.kolumner]
        for d in deltagare {
            var setNr = 0
            for (i, r) in d.rader.enumerated() {
                var set = ""
                if r.arHuvuddata {
                    setNr += 1
                    set = String(setNr)
                }
                rader.append([d.kod, f.text(d.namn), d.villkor.rawValue, f.text(d.filnamn), String(i + 1), set] + r.falt.map(f.text))
            }
        }
        return f.dokument(rader)
    }

    /// Ett mått per rad, villkoren bredvid varandra.
    static func gruppjamforelse(_ grupper: [Grupp], format f: CSVFormat) -> String {
        var rubrik = ["matt", "enhet"]
        for g in grupper {
            rubrik += ["n", "medel", "sd", "median", "min", "max"].map { "\(g.villkor.slug)_\($0)" }
        }
        let med = grupper.first { $0.villkor == .medMobil }
        let utan = grupper.first { $0.villkor == .utanMobil }
        let skillnad = med != nil && utan != nil
        if skillnad { rubrik.append("skillnad_medel_med_minus_utan") }

        var rader = [rubrik]
        for m in Matt.allCases {
            var rad = [m.namn, m.enhet]
            for g in grupper {
                let v = g.varden(m)
                rad += [String(g.n), f.tal(g.medel(m), 2), f.tal(g.sd(m), 2), f.tal(g.median(m), 2),
                        f.tal(v.min(), 2), f.tal(v.max(), 2)]
            }
            if skillnad, let a = med?.medel(m), let b = utan?.medel(m) {
                rad.append(f.tal(a - b, 2))
            }
            rader.append(rad)
        }
        return f.dokument(rader)
    }
}
