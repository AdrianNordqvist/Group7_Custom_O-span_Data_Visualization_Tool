import Foundation
import Observation

/// Alla inlästa filer plus logiken för import, dubbletter, gruppering och enkätkoppling.
@Observable
final class Sammanstallning {
    struct ImportResultat {
        var ospan = 0
        var enkatsvar = 0
    }

    private(set) var deltagare: [Deltagare] = []
    private(set) var enkatsvar: [EnkatSvar] = []
    private(set) var enkatFragor: [String] = []
    /// Övriga sifferfrågor i enkäten: skärmtid, utvilad, stress …
    private(set) var enkatVariabler: [EnkatVariabel] = []
    var meddelande: String?

    private static let filandelser: Set<String> = ["csv", "txt"]
    /// Enkäten fylls i direkt efter testet: från 2 min före till 10 min efter att OSPAN-filen sparades.
    private static let kopplingsfonster: ClosedRange<TimeInterval> = -120...600

    var medraknade: [Deltagare] {
        deltagare.filter(\.medraknas)
            .sorted { ($0.villkor, $0.datumSortering, $0.filnamn) < ($1.villkor, $1.datumSortering, $1.filnamn) }
    }

    var grupper: [Grupp] {
        Villkor.allCases.compactMap { v in
            let s = deltagare.filter { $0.medraknas && $0.villkor == v }.map(\.sammanfattning)
            return s.isEmpty ? nil : Grupp(villkor: v, sammanfattningar: s)
        }
    }

    /// Enkätsvar → deltagare. Manuella val gäller först; övriga svar kopplas till den
    /// medräknade OSPAN-omgång som ligger närmast i tid (inom `kopplingsfonster`).
    var kopplingar: [EnkatSvar.ID: Deltagare] {
        var resultat: [EnkatSvar.ID: Deltagare] = [:]
        var upptagna = Set<Deltagare.ID>()
        for s in enkatsvar {
            if case .deltagare(let id) = s.koppling, let d = deltagare.first(where: { $0.id == id }) {
                resultat[s.id] = d
                upptagna.insert(id)
            }
        }

        // Enkäten kan själv peka ut filen, t.ex. en kolumn med OSPAN-filens namn.
        for s in enkatsvar where s.koppling == .automatisk {
            if let d = deltagare(utpekadAv: s), !upptagna.contains(d.id) {
                resultat[s.id] = d
                upptagna.insert(d.id)
            }
        }

        var par: [(avstand: TimeInterval, svar: EnkatSvar, deltagare: Deltagare)] = []
        for s in enkatsvar where s.koppling == .automatisk && resultat[s.id] == nil {
            guard let tid = s.tid else { continue }
            for d in deltagare where d.medraknas && !upptagna.contains(d.id) {
                guard let datum = d.datum else { continue }
                let skillnad = tid.timeIntervalSince(datum)
                if Self.kopplingsfonster.contains(skillnad) { par.append((abs(skillnad), s, d)) }
            }
        }
        for p in par.sorted(by: { $0.avstand < $1.avstand })
        where resultat[p.svar.id] == nil && !upptagna.contains(p.deltagare.id) {
            resultat[p.svar.id] = p.deltagare
            upptagna.insert(p.deltagare.id)
        }
        return resultat
    }

    /// Letar efter ett filnamn bland svarets övriga celler ("M ospan_data_2026-09-30_10-50-21 M").
    private func deltagare(utpekadAv s: EnkatSvar) -> Deltagare? {
        for cell in s.ovrigt {
            var text = cell.lowercased().trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("m ") || text.hasPrefix("u ") { text.removeFirst(2) }
            guard text.count >= 10 else { continue }
            let traffar = deltagare.filter {
                ($0.filnamn as NSString).deletingPathExtension.lowercased().contains(text)
            }
            if let d = traffar.first(where: \.medraknas) ?? traffar.first { return d }
        }
        return nil
    }

    /// Deltagare → enkätsvar (för exporten).
    var enkatPerDeltagare: [Deltagare.ID: EnkatSvar] {
        var resultat: [Deltagare.ID: EnkatSvar] = [:]
        let k = kopplingar
        for s in enkatsvar {
            if let d = k[s.id], resultat[d.id] == nil { resultat[d.id] = s }
        }
        return resultat
    }

    // MARK: - Import

    /// Tar emot filer och/eller mappar (mappar gås igenom rekursivt efter .csv/.txt).
    /// Varje fil tolkas som OSPAN-data eller som enkätsvar.
    @discardableResult
    func importera(_ urls: [URL]) -> ImportResultat {
        var nya: [Deltagare] = []
        var enkater: [EnkatTolkare.Resultat] = []
        var ejOspan: [String] = []
        var redanInlasta = 0
        var kanda = Set(deltagare.map { $0.fil.standardizedFileURL })

        for url in urls {
            let atkomst = url.startAccessingSecurityScopedResource()
            defer { if atkomst { url.stopAccessingSecurityScopedResource() } }
            for fil in Self.filer(i: url) {
                guard kanda.insert(fil.standardizedFileURL).inserted else {
                    redanInlasta += 1
                    continue
                }
                guard let text = Self.lasText(fil) else {
                    ejOspan.append(fil.lastPathComponent)
                    continue
                }
                if let d = Self.ospan(text, fil: fil) {
                    nya.append(d)
                } else if let e = EnkatTolkare.tolka(text) {
                    enkater.append(e)
                } else {
                    ejOspan.append(fil.lastPathComponent)
                }
            }
        }
        let nyaSvar = laggTill(enkater)

        nya.sort { ($0.datumSortering, $0.filnamn) < ($1.datumSortering, $1.filnamn) }
        for ny in nya {
            // Samma data som en fil som redan räknas med → räknas inte med två gånger.
            if deltagare.contains(where: { $0.medraknas && $0.rader == ny.rader }) {
                ny.medraknas = false
            }
            deltagare.append(ny)
        }
        uppdatera()

        var delar = ["Lade till \(nya.count) OSPAN-\(nya.count == 1 ? "fil" : "filer")"]
        if nyaSvar > 0 { delar.append("\(nyaSvar) enkätsvar") }
        if redanInlasta > 0 { delar.append("\(redanInlasta) fanns redan") }
        if !ejOspan.isEmpty {
            delar.append("hoppade över \(ejOspan.count) andra filer (\(ejOspan.prefix(3).joined(separator: ", "))\(ejOspan.count > 3 ? " …" : ""))")
        }
        meddelande = delar.joined(separator: " · ")
        return ImportResultat(ospan: nya.count, enkatsvar: nyaSvar)
    }

    func taBort(_ ids: Set<Deltagare.ID>) {
        deltagare.removeAll { ids.contains($0.id) }
        uppdatera()
    }

    func rensa() {
        deltagare.removeAll()
        enkatsvar.removeAll()
        enkatFragor.removeAll()
        enkatVariabler.removeAll()
        meddelande = nil
    }

    /// Lägger till enkätsvar. Samma tidsstämpel = samma svar: en fil med fler frågor
    /// ersätter då det som redan är inläst, annars hoppas raden över.
    private func laggTill(_ enkater: [EnkatTolkare.Resultat]) -> Int {
        var antal = 0
        for e in enkater {
            let generiska = { (f: [String]) in f.allSatisfy { $0.hasPrefix("Fråga ") } }
            if e.fragor.count > enkatFragor.count
                || (e.fragor.count == enkatFragor.count && generiska(enkatFragor) && !generiska(e.fragor)) {
                enkatFragor = e.fragor
            }
            if e.variabler.count > enkatVariabler.count { enkatVariabler = e.variabler }
            for r in e.rader {
                let ny = EnkatSvar(tid: r.tid, tidText: r.tidText, svar: r.svar, kon: r.kon, extra: r.extra, ovrigt: r.ovrigt)
                if let i = enkatsvar.firstIndex(where: { $0.tidText == r.tidText }) {
                    let gammal = enkatsvar[i]
                    guard ny.svar.count > gammal.svar.count
                        || (ny.svar.count == gammal.svar.count && ny.extra.count > gammal.extra.count) else { continue }
                    // Samma svar från en fullständigare fil: byt ut, men räkna det inte som nytt.
                    ny.koppling = gammal.koppling
                    enkatsvar[i] = ny
                } else {
                    enkatsvar.append(ny)
                    antal += 1
                }
            }
        }
        enkatsvar.sort { $0.tidSortering < $1.tidSortering }
        return antal
    }

    func satt(villkor: Villkor, for ids: Set<Deltagare.ID>) {
        for d in deltagare where ids.contains(d.id) { d.villkor = villkor }
    }

    func satt(medraknas: Bool, for ids: Set<Deltagare.ID>) {
        for d in deltagare where ids.contains(d.id) { d.medraknas = medraknas }
    }

    /// Koder i tidsordning och dubblettmarkering.
    private func uppdatera() {
        deltagare.sort { ($0.datumSortering, $0.filnamn) < ($1.datumSortering, $1.filnamn) }
        for (i, d) in deltagare.enumerated() {
            d.kod = String(format: "P%02d", i + 1)
        }
        let lika = Dictionary(grouping: deltagare, by: \.rader)
        for d in deltagare {
            d.dubblettAv = (lika[d.rader] ?? []).filter { $0 !== d }.map(\.filnamn)
        }
    }

    // MARK: - Filer

    private static func filer(i url: URL) -> [URL] {
        var arMapp: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &arMapp) else { return [] }
        guard arMapp.boolValue else { return [url] }
        let uppraknare = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants])
        var resultat: [URL] = []
        while let fil = uppraknare?.nextObject() as? URL {
            if filandelser.contains(fil.pathExtension.lowercased()) { resultat.append(fil) }
        }
        return resultat
    }

    private static func ospan(_ text: String, fil: URL) -> Deltagare? {
        let resultat = OspanTolkare.tolka(text)
        guard resultat.rader.contains(where: \.arHuvuddata) else { return nil }
        let info = FilnamnTolkare.tolka(
            filnamn: fil.lastPathComponent,
            mappnamn: fil.deletingLastPathComponent().lastPathComponent)
        return Deltagare(fil: fil, rader: resultat.rader, olasbaraRader: resultat.olasbaraRader, info: info)
    }

    private static func lasText(_ fil: URL) -> String? {
        if let s = try? String(contentsOf: fil, encoding: .utf8) { return s }
        return try? String(contentsOf: fil, encoding: .isoLatin1)
    }
}
