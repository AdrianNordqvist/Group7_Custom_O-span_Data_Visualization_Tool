import Foundation
import Observation

/// En inläst datafil = en testomgång.
@Observable
final class Deltagare: Identifiable {
    let id = UUID()
    let fil: URL
    let rader: [OspanRad]
    let olasbaraRader: Int
    let datum: Date?
    let sammanfattning: Sammanfattning

    /// P01, P02 … i tidsordning; sätts av `Sammanstallning`.
    var kod = ""
    var namn: String
    var villkor: Villkor
    var medraknas: Bool
    /// Andra inlästa filer med exakt samma data.
    var dubblettAv: [String] = []

    init(fil: URL, rader: [OspanRad], olasbaraRader: Int, info: FilnamnTolkare.Info) {
        self.fil = fil
        self.rader = rader
        self.olasbaraRader = olasbaraRader
        self.datum = info.datum
        self.sammanfattning = Sammanfattning(rader: rader)
        self.namn = info.namn
        self.villkor = info.villkor
        // Testkörningar och ofullständiga omgångar räknas inte med från början.
        self.medraknas = info.villkor != .test && sammanfattning.antalSet == Sammanfattning.forvantadeSet
    }

    var filnamn: String { fil.lastPathComponent }
    var datumSortering: Date { datum ?? .distantFuture }
    var medraknasSortering: Int { medraknas ? 0 : 1 }

    /// "P05 · Utan mobil · 28 sep. 14:21" – används i enkätens kopplingsmeny.
    var etikett: String {
        var delar = [kod]
        if !namn.isEmpty { delar.append(namn) }
        delar.append(villkor.rawValue)
        if let datum { delar.append(datum.formatted(.dateTime.day().month().hour().minute())) }
        return delar.joined(separator: " · ")
    }
    /// Filer med anmärkningar hamnar först vid stigande sortering.
    var varningSortering: String { varningar.first.map { "0 " + $0 } ?? "1" }

    var varningar: [String] {
        var v: [String] = []
        if !dubblettAv.isEmpty {
            v.append("Samma data som " + dubblettAv.joined(separator: ", "))
        }
        if sammanfattning.antalSet != Sammanfattning.forvantadeSet {
            v.append("\(sammanfattning.antalSet) av \(Sammanfattning.forvantadeSet) set")
        }
        if villkor == .okant {
            v.append("Villkoret syns inte i filnamnet")
        }
        if sammanfattning.matteProcent < 85 {
            v.append("Matte under 85 % rätt")
        }
        if olasbaraRader > 0 {
            v.append("\(olasbaraRader) rader gick inte att läsa")
        }
        return v
    }
}
