import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Fliken där man väljer diagram, ser det i exportstorlek och sparar det som bild.
struct DiagramFlik: View {
    let data: Sammanstallning
    @State private var val = Diagraminstallning()
    /// De egna gruppfärgerna sparas mellan körningar (JSON: gruppnamn → RGB-hex).
    @AppStorage("diagramfarger") private var sparadeFarger = Data()

    private var harEnkat: Bool { !data.enkatsvar.isEmpty }

    private var farger: [String: UInt32] {
        (try? JSONDecoder().decode([String: UInt32].self, from: sparadeFarger)) ?? [:]
    }

    /// Valen med det som inte går att rita just nu utbytt mot något som går.
    private var gallande: Diagraminstallning {
        var v = val
        if v.typ == .sasFragor && !harEnkat { v.typ = .gruppmedel }
        if (v.gruppering.kraverEnkat && !harEnkat) || (v.gruppering == .ingen && !v.typ.tillaterOgrupperat) {
            v.gruppering = .villkor
        }
        // Ett enkätmått som inte längre finns (enkäten borttagen eller utbytt) byts mot ett O-Span-mått.
        let valbara = Diagrammatt.alla(data.enkatVariabler).filter { !$0.kraverEnkat || harEnkat }
        if !valbara.contains(v.matt) { v.matt = .ospan(.ospanPartial) }
        if !valbara.contains(v.xMatt) { v.xMatt = harEnkat ? .sas : .ospan(.matteProcent) }
        v.farger = farger
        return v
    }

    var body: some View {
        if data.medraknade.isEmpty {
            ContentUnavailableView {
                Label("Inget att rita ännu", systemImage: "chart.bar")
            } description: {
                Text("Läs in O-Span-filer och kryssa i minst en deltagare som ska räknas med.")
            }
        } else {
            let v = gallande
            let underlag = Diagramunderlag(data: data, gruppering: v.gruppering)
            HStack(spacing: 0) {
                installningar(v, underlag)
                    .frame(width: 320)
                Divider()
                forhandsvisning(v, underlag)
            }
        }
    }

    // MARK: - Inställningar

    private func installningar(_ v: Diagraminstallning, _ underlag: Diagramunderlag) -> some View {
        Form {
            Section("Diagram") {
                Picker("Typ", selection: $val.typ) {
                    ForEach(Diagramtyp.allCases.filter { $0 != .sasFragor || harEnkat }) { typ in
                        Text(typ.rawValue).tag(typ)
                    }
                }
                switch v.typ {
                case .gruppmedel, .lada, .perDeltagare:
                    mattval("Mått", $val.matt)
                case .samband:
                    mattval("Y-axel", $val.matt)
                    mattval("X-axel", $val.xMatt)
                case .setlangd:
                    Picker("Mått", selection: $val.setMatt) {
                        ForEach(Setmatt.allCases) { Text($0.rawValue).tag($0) }
                    }
                case .sasFragor:
                    EmptyView()
                }
                Picker("Gruppera efter", selection: $val.gruppering) {
                    ForEach(Gruppering.allCases.filter { g in
                        (!g.kraverEnkat || harEnkat) && (g != .ingen || v.typ.tillaterOgrupperat)
                    }) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
            }

            Section("Utseende") {
                if v.typ == .gruppmedel || v.typ == .setlangd {
                    Picker("Felstaplar", selection: $val.felstapel) {
                        ForEach(Felstapel.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                if v.typ == .gruppmedel || v.typ == .lada {
                    Toggle("Visa enskilda deltagare", isOn: $val.visaPunkter)
                }
                if v.typ == .samband {
                    Toggle("Trendlinje", isOn: $val.trendlinje)
                }
                Toggle("Rubrik och förklaring i bilden", isOn: $val.visaTitel)
                if v.visaTitel {
                    TextField("Rubrik", text: $val.egenTitel, prompt: Text(Diagramtext.automatiskTitel(v)))
                }
                Picker("Storlek", selection: $val.storlek) {
                    ForEach(Diagramstorlek.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Språk i diagrammet", selection: $val.sprak) {
                    ForEach(Diagramsprak.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Färger") {
                ForEach(v.typ == .sasFragor ? underlag.enkatgrupper : underlag.grupper, id: \.self) { grupp in
                    ColorPicker(grupp, selection: fargval(grupp, v.gruppering), supportsOpacity: false)
                }
                Button("Återställ standardfärgerna") { sparadeFarger = Data() }
                    .disabled(farger.isEmpty)
                Text("Färgen följer gruppen i alla diagram och sparas till nästa gång. Standardfärgerna går att skilja åt även vid färgblindhet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Exportera") {
                Button("Spara som PNG …") { spara(.png, v, underlag) }
                Button("Spara som PDF …") { spara(.pdf, v, underlag) }
                Button("Kopiera bilden") { kopiera(v, underlag) }
                Text("PNG passar Google Dokument och Word. PDF är skalbar och blir skarpast i tryck.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// Kopplar Apples färgväljare till gruppens färg. Färgen lagras som sRGB utan genomskinlighet.
    private func fargval(_ grupp: String, _ gruppering: Gruppering) -> Binding<Color> {
        Binding(
            get: { Diagramstil.farg(grupp, i: gruppering, egna: farger) },
            set: { ny in
                guard let srgb = NSColor(ny).usingColorSpace(.sRGB) else { return }
                func kanal(_ v: CGFloat) -> UInt32 { UInt32((min(max(v, 0), 1) * 255).rounded()) }
                var alla = farger
                alla[grupp] = kanal(srgb.redComponent) << 16 | kanal(srgb.greenComponent) << 8 | kanal(srgb.blueComponent)
                sparadeFarger = (try? JSONEncoder().encode(alla)) ?? Data()
            }
        )
    }

    private func mattval(_ rubrik: String, _ val: Binding<Diagrammatt>) -> some View {
        Picker(rubrik, selection: val) {
            ForEach(Diagrammatt.alla(data.enkatVariabler).filter { !$0.kraverEnkat || harEnkat }) { m in
                Text(m.namn).tag(m)
            }
        }
    }

    // MARK: - Förhandsvisning

    private func forhandsvisning(_ v: Diagraminstallning, _ underlag: Diagramunderlag) -> some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 16) {
                DiagramVy(underlag: underlag, val: v)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)

                if underlag.utanGrupp > 0 && v.typ != .sasFragor {
                    Label("\(underlag.utanGrupp) medräknade deltagare saknar \(v.gruppering.iTitel) (inget enkätsvar) och visas inte.",
                          systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Förslag till figurtext")
                        .font(.headline)
                    Text(Diagramtext.figurtext(v, underlag))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Vardetabell(underlag: underlag, val: v)
            }
            .frame(width: max(v.storlek.bredd, 560), alignment: .leading)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    // MARK: - Export

    private func exportvy(_ v: Diagraminstallning, _ underlag: Diagramunderlag) -> ImageRenderer<DiagramVy> {
        ImageRenderer(content: DiagramVy(underlag: underlag, val: v))
    }

    private func png(_ v: Diagraminstallning, _ underlag: Diagramunderlag) -> Data? {
        let rendering = exportvy(v, underlag)
        rendering.scale = 3
        guard let bild = rendering.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: bild).representation(using: .png, properties: [:])
    }

    private func pdf(_ v: Diagraminstallning, _ underlag: Diagramunderlag) -> Data? {
        let data = NSMutableData()
        exportvy(v, underlag).render { storlek, rita in
            var ruta = CGRect(origin: .zero, size: storlek)
            guard let mottagare = CGDataConsumer(data: data as CFMutableData),
                  let sida = CGContext(consumer: mottagare, mediaBox: &ruta, nil) else { return }
            sida.beginPDFPage(nil)
            rita(sida)
            sida.endPDFPage()
            sida.closePDF()
        }
        return data.length > 0 ? data as Data : nil
    }

    private func spara(_ typ: UTType, _ v: Diagraminstallning, _ underlag: Diagramunderlag) {
        guard let innehall = typ == .pdf ? pdf(v, underlag) : png(v, underlag) else {
            data.meddelande = "Kunde inte rita diagrammet"
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [typ]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = filnamn(v)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try innehall.write(to: url)
            data.meddelande = "Sparade \(url.lastPathComponent)"
        } catch {
            data.meddelande = "Kunde inte spara: \(error.localizedDescription)"
        }
    }

    private func kopiera(_ v: Diagraminstallning, _ underlag: Diagramunderlag) {
        guard let innehall = png(v, underlag), let bild = NSImage(data: innehall) else { return }
        // Peka ut storleken i punkter så att bilden inte klistras in tre gånger för stor.
        bild.size = NSSize(width: v.storlek.bredd, height: v.storlek.hojd)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([bild])
        data.meddelande = "Diagrammet kopierat"
    }

    private func filnamn(_ v: Diagraminstallning) -> String {
        let namn = Diagramtext.titel(v).lowercased()
            .replacingOccurrences(of: "å", with: "a").replacingOccurrences(of: "ä", with: "a").replacingOccurrences(of: "ö", with: "o")
        return "figur_" + namn.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: "_")
    }
}

/// Siffrorna bakom diagrammet, så att inget värde bara finns som en färgad form.
private struct Vardetabell: View {
    let underlag: Diagramunderlag
    let val: Diagraminstallning

    private var rubriker: [String] {
        switch val.typ {
        case .gruppmedel, .lada, .perDeltagare: ["Grupp", "n", "Medel", "SD", "Median", "Min", "Max"]
        case .samband: ["Grupp", "n", "Pearsons r"]
        case .setlangd: ["Grupp"] + Sammanfattning.langder.map { "\($0) bokstäver" }
        case .sasFragor: ["Fråga"] + underlag.enkatgrupper
        }
    }

    private var rader: [[String]] {
        switch val.typ {
        case .gruppmedel, .lada, .perDeltagare:
            let d = val.matt.decimaler
            return underlag.varden(val.matt).map { g in
                [g.grupp, "\(g.n)", tal(g.medel, d), tal(g.sd, d), tal(g.median, d), tal(g.tal.min(), d), tal(g.tal.max(), d)]
            }
        case .samband:
            let par = underlag.rader.compactMap { r -> (String, Double, Double)? in
                guard let x = val.xMatt.varde(r.deltagare, r.enkat), let y = val.matt.varde(r.deltagare, r.enkat) else { return nil }
                return (r.grupp, x, y)
            }
            func rad(_ namn: String, _ p: [(String, Double, Double)]) -> [String] {
                [namn, "\(p.count)", Statistik.pearson(p.map(\.1), p.map(\.2)).map {
                    $0.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always()))
                } ?? "–"]
            }
            let perGrupp = underlag.grupper.map { g in rad(g, par.filter { $0.0 == g }) }
            return underlag.grupper.count > 1 ? [rad("Alla", par)] + perGrupp : perGrupp
        case .setlangd:
            return underlag.grupper.map { g in
                [g] + Sammanfattning.langder.map { langd in
                    tal(underlag.varden(val.setMatt, langd: langd).first { $0.grupp == g }?.medel, val.setMatt == .procent ? 1 : 0)
                }
            }
        case .sasFragor:
            return underlag.fragor.indices.map { i in
                let svar = underlag.svar(fraga: i)
                return [underlag.fragor[i]] + underlag.enkatgrupper.map { g in tal(svar.first { $0.grupp == g }?.medel, 2) }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Värden i diagrammet")
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 5) {
                GridRow {
                    ForEach(Array(rubriker.enumerated()), id: \.offset) { i, rubrik in
                        Text(rubrik)
                            .gridColumnAlignment(i == 0 ? .leading : .trailing)
                    }
                }
                .font(.subheadline.bold())
                Divider()
                ForEach(Array(rader.enumerated()), id: \.offset) { _, rad in
                    GridRow {
                        ForEach(Array(rad.enumerated()), id: \.offset) { i, cell in
                            Text(cell)
                                .lineLimit(1)
                                .frame(maxWidth: i == 0 ? 320 : nil, alignment: .leading)
                        }
                    }
                    .monospacedDigit()
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .textSelection(.enabled)
        }
    }

    private func tal(_ v: Double?, _ decimaler: Int) -> String {
        v.map { $0.formatted(.number.precision(.fractionLength(decimaler))) } ?? "–"
    }
}
