import SwiftUI

/// Fliken för enkäten om mobilanvändning, poängsatt och tolkad enligt SAS-SV.
struct EnkatFlik: View {
    let data: Sammanstallning
    let valjFiler: () -> Void

    var body: some View {
        if data.enkatsvar.isEmpty {
            ContentUnavailableView {
                Label("Ingen enkät inläst", systemImage: "list.bullet.clipboard")
            } description: {
                Text("Dra in svarsfilen från Google Formulär (.csv). Svaren poängsätts enligt SAS-SV (1–6 per fråga) och kopplas till OSPAN-omgången som sparades närmast i tid.")
            } actions: {
                Button("Välj enkätfil …", action: valjFiler)
            }
        } else {
            let kopplingar = data.kopplingar
            VSplitView {
                EnkatTabell(data: data, kopplingar: kopplingar)
                    .frame(minHeight: 180)
                ScrollView {
                    SASTolkningVy(data: data, kopplingar: kopplingar)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 160, idealHeight: 420)
            }
        }
    }
}

// MARK: - Tabell

struct EnkatRad: Identifiable {
    let svar: EnkatSvar
    let deltagare: Deltagare?

    var id: EnkatSvar.ID { svar.id }
    var tidSortering: Date { svar.tidSortering }
    var kod: String { deltagare?.kod ?? "~" }
    var villkor: Villkor { deltagare?.villkor ?? .okant }
    var ospan: Int { deltagare?.sammanfattning.ospanAbsolut ?? -1 }
    var svarText: String { svar.svar.map { $0.map(String.init) ?? "?" }.joined(separator: "  ") }
    var summa: Int { svar.resultat?.summa ?? -1 }
    var poang: Double { svar.resultat?.poang ?? -1 }
    var nivaSortering: Int { svar.niva?.rawValue ?? -1 }
    var kon: String { svar.kon?.rawValue ?? "–" }

    /// Värdet på en övrig enkätfråga; saknade svar sorteras sist.
    subscript(extra variabel: EnkatVariabel) -> Double { svar.varde(variabel) ?? .infinity }
}

private struct EnkatTabell: View {
    let data: Sammanstallning
    let kopplingar: [EnkatSvar.ID: Deltagare]
    @State private var sortering = [KeyPathComparator(\EnkatRad.tidSortering)]

    var body: some View {
        let rader = data.enkatsvar.map { EnkatRad(svar: $0, deltagare: kopplingar[$0.id]) }.sorted(using: sortering)
        let n = data.enkatFragor.count
        Table(rader, sortOrder: $sortering) {
          Group {
            TableColumn("Tid", value: \EnkatRad.tidSortering) { (r: EnkatRad) in
                Text(r.svar.tidText).monospacedDigit()
            }
            .width(min: 120, ideal: 135)
            TableColumn("OSPAN-omgång", value: \EnkatRad.kod) { (r: EnkatRad) in
                KopplingCell(svar: r.svar, deltagare: data.deltagare, kopplad: r.deltagare)
            }
            .width(min: 180, ideal: 260)
            TableColumn("Villkor", value: \EnkatRad.villkor) { (r: EnkatRad) in
                Text(r.deltagare?.villkor.rawValue ?? "–")
            }
            .width(min: 70, ideal: 80)
            TableColumn("Kön", value: \EnkatRad.kon)
                .width(50)
            TableColumn("OSPAN", value: \EnkatRad.ospan) { (r: EnkatRad) in
                Siffra(r.deltagare.map { "\($0.sammanfattning.ospanAbsolut)" } ?? "–")
            }
            .width(50)
          }
          Group {
            TableColumn("Svar F1–F\(n)", value: \EnkatRad.svarText) { (r: EnkatRad) in
                Text(r.svarText)
                    .monospaced()
                    .help(zip(data.enkatFragor, r.svar.svar)
                        .map { "\($0): \($1.map(String.init) ?? "saknas")" }
                        .joined(separator: "\n"))
            }
            .width(min: 110, ideal: 130)
            TableColumn("Summa (\(n)–\(6 * n))", value: \EnkatRad.summa) { (r: EnkatRad) in
                Siffra(r.svar.resultat.map { "\($0.summa)" } ?? "–")
            }
            .width(80)
            TableColumn("SAS 10–60", value: \EnkatRad.poang) { (r: EnkatRad) in
                Siffra(r.svar.resultat.map { $0.poang.formatted(.number.precision(.fractionLength(1))) } ?? "–")
            }
            .width(70)
            TableColumn("Tolkning", value: \EnkatRad.nivaSortering) { (r: EnkatRad) in
                if let niva = r.svar.niva {
                    NivaEtikett(niva: niva)
                }
            }
            .width(min: 120, ideal: 140)
            TableColumnForEach(data.enkatVariabler) { variabel in
                TableColumn(variabel.namn, value: \EnkatRad[extra: variabel]) { (r: EnkatRad) in
                    Siffra(r.svar.varde(variabel).map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "–")
                        .help(variabel.fraga)
                }
                .width(min: 60, ideal: 90)
            }
          }
        }
    }
}

private struct KopplingCell: View {
    @Bindable var svar: EnkatSvar
    let deltagare: [Deltagare]
    let kopplad: Deltagare?

    var body: some View {
        HStack(spacing: 4) {
            if kopplad == nil {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.orange)
                    .help("Enkäten pekar inte ut någon fil och ingen OSPAN-omgång sparades inom 2 min före till 10 min efter svaret. Välj deltagare i menyn.")
            }
            Picker("OSPAN-omgång", selection: $svar.koppling) {
                Text(autoText).tag(EnkatSvar.Koppling.automatisk)
                Text("Ingen").tag(EnkatSvar.Koppling.ingen)
                Divider()
                ForEach(deltagare) { d in
                    Text(d.etikett).tag(EnkatSvar.Koppling.deltagare(d.id))
                }
            }
            .labelsHidden()
        }
    }

    private var autoText: String {
        guard svar.koppling == .automatisk else { return "Automatiskt (filnamn i enkäten, annars närmast i tid)" }
        return kopplad.map { "Auto: \($0.etikett)" } ?? "Auto: ingen träff – välj"
    }
}

struct NivaEtikett: View {
    let niva: SASNiva

    var body: some View {
        Text(niva.namn)
            .font(.callout)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(farg.opacity(0.18), in: Capsule())
            .foregroundStyle(farg)
            .help(niva.forklaring)
    }

    private var farg: Color {
        switch niva {
        case .under: .green
        case .granszon: .orange
        case .over: .red
        }
    }
}

// MARK: - Tolkning

struct SASTolkningVy: View {
    let data: Sammanstallning
    let kopplingar: [EnkatSvar.ID: Deltagare]

    private struct Grupp: Identifiable {
        let namn: String
        let poang: [Double]
        let ospan: [Double]
        let partial: [Double]
        let nivaer: [SASNiva]
        var id: String { namn }
    }

    private var antalFragor: Int { data.enkatFragor.count }
    private var allaResultat: [SASResultat] { data.enkatsvar.compactMap(\.resultat) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            omSkalan
            sektion("Alla svar") { allaSvar }
            sektion("Per villkor") { perVillkor }
            sektion("Samband med OSPAN") { samband }
            sektion("Per fråga") { perFraga }
            if !data.enkatVariabler.isEmpty {
                sektion("Övriga enkätfrågor") { ovrigaFragor }
            }
        }
    }

    private func sektion(_ titel: String, @ViewBuilder innehall: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titel).font(.headline)
            innehall()
        }
    }

    // MARK: Om skalan

    private var omSkalan: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Så tolkas SAS-SV")
                .font(.headline)
            Text("Smartphone Addiction Scale – Short Version (Kwon m.fl., 2013). Varje påstående ger 1–6 poäng och summan av de tio påståendena blir 10–60. Från 31 poäng för män och 33 för kvinnor tolkas resultatet som risk för problematisk mobilanvändning.")
                .fixedSize(horizontal: false, vertical: true)
            Text(SAS.alternativ.map { "\($0.poang) = \($0.svenska)" }.joined(separator: "   "))
                .font(.caption)
                .foregroundStyle(.secondary)
            if antalFragor != SAS.antalFragor {
                Label("Er enkät har \(antalFragor) frågor, inte \(SAS.antalFragor). Poängen räknas därför om till SAS-skalan som medelvärde × 10. Det är en uppskattning – gränsvärdena är framtagna för alla tio frågorna.", systemImage: "info.circle")
                    .fixedSize(horizontal: false, vertical: true)
            }
            Label(data.enkatsvar.contains { $0.kon != nil }
                  ? "Gränsvärdet väljs efter kön: 31 för män, 33 för kvinnor. Svar utan angivet kön visas som gränszon vid 31–32 poäng."
                  : "Enkäten frågar inte om kön, så 31–32 poäng visas som gränszon: över gränsen för män men under gränsen för kvinnor.",
                  systemImage: "info.circle")
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 760, alignment: .leading)
    }

    // MARK: Alla svar

    private var allaSvar: some View {
        let poang = allaResultat.map(\.poang)
        return VStack(alignment: .leading, spacing: 8) {
            Text("n = \(poang.count) · medel \(tal(Statistik.medel(poang))) (SD \(tal(Statistik.sd(poang)))) · median \(tal(Statistik.median(poang))) · spann \(tal(poang.min()))–\(tal(poang.max())) på skalan 10–60")
                .monospacedDigit()
            HStack(spacing: 14) {
                ForEach(SASNiva.allCases, id: \.self) { niva in
                    HStack(spacing: 6) {
                        NivaEtikett(niva: niva)
                        Text("\(data.enkatsvar.filter { $0.niva == niva }.count) st")
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: Per villkor

    private var grupper: [Grupp] {
        var efterVillkor: [Villkor: [(poang: Double, niva: SASNiva, deltagare: Deltagare)]] = [:]
        var ejKopplade: [(poang: Double, niva: SASNiva)] = []
        for s in data.enkatsvar {
            guard let r = s.resultat, let niva = s.niva else { continue }
            if let d = kopplingar[s.id], d.medraknas {
                efterVillkor[d.villkor, default: []].append((r.poang, niva, d))
            } else {
                ejKopplade.append((r.poang, niva))
            }
        }
        var resultat = Villkor.allCases.compactMap { v -> Grupp? in
            guard let par = efterVillkor[v] else { return nil }
            return Grupp(namn: v.rawValue, poang: par.map(\.poang),
                         ospan: par.map { Double($0.deltagare.sammanfattning.ospanAbsolut) },
                         partial: par.map { Double($0.deltagare.sammanfattning.partial) },
                         nivaer: par.map(\.niva))
        }
        if !ejKopplade.isEmpty {
            resultat.append(Grupp(namn: "Ej kopplade", poang: ejKopplade.map(\.poang), ospan: [], partial: [],
                                  nivaer: ejKopplade.map(\.niva)))
        }
        return resultat
    }

    private var perVillkor: some View {
        let g = grupper
        let med = g.first { $0.namn == Villkor.medMobil.rawValue }
        let utan = g.first { $0.namn == Villkor.utanMobil.rawValue }
        return VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                GridRow {
                    Text("Grupp")
                    Text("n").gridColumnAlignment(.trailing)
                    Text("SAS medel (SD)").gridColumnAlignment(.trailing)
                    Text("Median").gridColumnAlignment(.trailing)
                    ForEach(SASNiva.allCases, id: \.self) { niva in
                        Text(niva.namn).gridColumnAlignment(.trailing)
                    }
                }
                .font(.subheadline.bold())
                Divider()
                ForEach(g) { grupp in
                    GridRow {
                        Text(grupp.namn)
                        Text("\(grupp.poang.count)")
                        Text("\(tal(Statistik.medel(grupp.poang))) (\(tal(Statistik.sd(grupp.poang))))")
                        Text(tal(Statistik.median(grupp.poang)))
                        ForEach(SASNiva.allCases, id: \.self) { niva in
                            Text("\(grupp.nivaer.filter { $0 == niva }.count)")
                        }
                    }
                    .monospacedDigit()
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            if let med, let utan, let a = Statistik.medel(med.poang), let b = Statistik.medel(utan.poang) {
                Text("Skillnad med − utan mobil: \(tal(a - b, tecken: true)) poäng. Ligger grupperna nära varandra har de liknande mobilvanor, och en skillnad i OSPAN beror då troligen inte på det.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 760, alignment: .leading)
            }
        }
    }

    // MARK: Samband

    private var samband: some View {
        let kopplade = grupper.filter { !$0.ospan.isEmpty }
        let alla = Grupp(namn: "Alla kopplade", poang: kopplade.flatMap(\.poang), ospan: kopplade.flatMap(\.ospan),
                         partial: kopplade.flatMap(\.partial), nivaer: [])
        return VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                GridRow {
                    Text("Grupp")
                    Text("n").gridColumnAlignment(.trailing)
                    Text("r med OSPAN absolut").gridColumnAlignment(.trailing)
                    Text("r med OSPAN partial").gridColumnAlignment(.trailing)
                }
                .font(.subheadline.bold())
                Divider()
                ForEach([alla] + kopplade) { grupp in
                    GridRow {
                        Text(grupp.namn)
                        Text("\(grupp.poang.count)")
                        Text(r(Statistik.pearson(grupp.poang, grupp.ospan)))
                        Text(r(Statistik.pearson(grupp.poang, grupp.partial)))
                    }
                    .monospacedDigit()
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            Text("Pearsons r mellan SAS-poäng och OSPAN. Nära 0 = inget samband; negativt r = högre SAS-poäng går ihop med lägre arbetsminnespoäng. Tumregel: |r| ≈ 0,1 svagt, 0,3 måttligt, 0,5 starkt. Med så här få deltagare per grupp är r mycket osäkert.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 760, alignment: .leading)
        }
    }

    // MARK: Per fråga

    private var perFraga: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                GridRow {
                    Text("Fråga")
                    Text("n").gridColumnAlignment(.trailing)
                    Text("Medel (SD)").gridColumnAlignment(.trailing)
                    Text("Andel som instämmer (4–6)").gridColumnAlignment(.trailing)
                }
                .font(.subheadline.bold())
                Divider()
                ForEach(Array(data.enkatFragor.enumerated()), id: \.offset) { i, fraga in
                    let varden = data.enkatsvar.compactMap { i < $0.svar.count ? $0.svar[i] : nil }.map(Double.init)
                    GridRow {
                        Text(fraga)
                            .lineLimit(2)
                            .frame(maxWidth: 420, alignment: .leading)
                        Text("\(varden.count)")
                        Text("\(tal(Statistik.medel(varden))) (\(tal(Statistik.sd(varden))))")
                        Text(varden.isEmpty ? "–" : "\(Int((Double(varden.filter { $0 >= 4 }.count) / Double(varden.count) * 100).rounded())) %")
                    }
                    .monospacedDigit()
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            if data.enkatFragor.allSatisfy({ $0.hasPrefix("Fråga ") }) {
                Text("Filen saknar rubrikrad, så frågetexterna syns inte. Ladda ner svaren från Google Kalkylark med första raden kvar, så visas frågorna här.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 760, alignment: .leading)
            }
        }
    }

    // MARK: Övriga frågor

    /// Skärmtid, utvilad, stress …: nivå per villkor och samband med OSPAN och SAS.
    private var ovrigaFragor: some View {
        let kopplade = data.enkatsvar.compactMap { s in kopplingar[s.id].flatMap { $0.medraknas ? (s, $0) : nil } }
        func medel(_ v: EnkatVariabel, _ villkor: Villkor) -> String {
            let varden = kopplade.filter { $0.1.villkor == villkor }.compactMap { $0.0.varde(v) }
            return varden.isEmpty ? "–" : "\(tal(Statistik.medel(varden))) (n = \(varden.count))"
        }
        func samband(_ v: EnkatVariabel, _ annat: (EnkatSvar, Deltagare) -> Double?) -> String {
            let par = kopplade.compactMap { s, d in s.varde(v).flatMap { x in annat(s, d).map { (x, $0) } } }
            return r(Statistik.pearson(par.map(\.0), par.map(\.1)))
        }
        return VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                GridRow {
                    Text("Fråga")
                    Text("n").gridColumnAlignment(.trailing)
                    Text("Medel (SD)").gridColumnAlignment(.trailing)
                    Text("Spann").gridColumnAlignment(.trailing)
                    Text("Med mobil").gridColumnAlignment(.trailing)
                    Text("Utan mobil").gridColumnAlignment(.trailing)
                    Text("r med OSPAN partial").gridColumnAlignment(.trailing)
                    Text("r med SAS").gridColumnAlignment(.trailing)
                }
                .font(.subheadline.bold())
                Divider()
                ForEach(data.enkatVariabler) { v in
                    let alla = data.enkatsvar.compactMap { $0.varde(v) }
                    GridRow {
                        Text("\(v.namn) (\(v.enhet))")
                            .help(v.fraga)
                        Text("\(alla.count)")
                        Text("\(tal(Statistik.medel(alla))) (\(tal(Statistik.sd(alla))))")
                        Text("\(tal(alla.min()))–\(tal(alla.max()))")
                        Text(medel(v, .medMobil))
                        Text(medel(v, .utanMobil))
                        Text(samband(v) { _, d in Double(d.sammanfattning.partial) })
                        Text(samband(v) { s, _ in s.resultat?.poang })
                    }
                    .monospacedDigit()
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            ForEach(data.enkatVariabler.compactMap(\.anmarkning).prefix(1), id: \.self) { anmarkning in
                Text(anmarkning)
                    .foregroundStyle(.secondary)
            }
            Text("Hela frågan visas när du håller pekaren över namnet. Sambanden räknas på de svar som är kopplade till en medräknad OSPAN-omgång.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 760, alignment: .leading)
        }
    }

    // MARK: Format

    private func tal(_ v: Double?, tecken: Bool = false) -> String {
        guard let v else { return "–" }
        return v.formatted(.number.precision(.fractionLength(1)).sign(strategy: tecken ? .always() : .automatic))
    }

    private func r(_ v: Double?) -> String {
        v.map { $0.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always())) } ?? "–"
    }
}
