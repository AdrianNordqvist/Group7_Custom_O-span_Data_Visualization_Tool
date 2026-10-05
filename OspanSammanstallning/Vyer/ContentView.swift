import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var data = Sammanstallning()
    @State private var markerade = Set<Deltagare.ID>()
    @State private var flik = Flik.ospan
    @State private var visarImport = false
    @State private var visarRensa = false
    @State private var malOver = false

    @State private var exportDokument: CSVDokument?
    @State private var exportNamn = ""
    @State private var visarExport = false
    @AppStorage("decimaltecken") private var decimaltecken = Locale.current.decimalSeparator ?? ","

    private enum Flik: Hashable {
        case ospan, enkat, diagram
    }

    private enum Export {
        case perDeltagare, allaRader, grupper, enkat

        var filnamn: String {
            switch self {
            case .perDeltagare: "ospan_sammanstallning"
            case .allaRader: "ospan_alla_rader"
            case .grupper: "ospan_gruppjamforelse"
            case .enkat: "sas_enkat"
            }
        }
    }

    var body: some View {
        Group {
            if data.deltagare.isEmpty && data.enkatsvar.isEmpty {
                tomVy
            } else {
                VStack(spacing: 0) {
                    TabView(selection: $flik) {
                        Tab("OSPAN", systemImage: "brain.head.profile", value: Flik.ospan) {
                            ospanFlik
                        }
                        Tab("Mobilanvändning (SAS-SV)", systemImage: "iphone", value: Flik.enkat) {
                            EnkatFlik(data: data, valjFiler: { visarImport = true })
                        }
                        Tab("Diagram", systemImage: "chart.bar", value: Flik.diagram) {
                            DiagramFlik(data: data)
                        }
                    }
                    statusrad
                }
            }
        }
        .overlay {
            if malOver {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            importera(urls)
            return true
        } isTargeted: { malOver = $0 }
        .toolbar { verktygsfalt }
        .fileImporter(isPresented: $visarImport, allowedContentTypes: [.text, .folder], allowsMultipleSelection: true) { resultat in
            if case .success(let urls) = resultat { importera(urls) }
        }
        .fileExporter(isPresented: $visarExport, document: exportDokument, contentType: .commaSeparatedText, defaultFilename: exportNamn) { resultat in
            switch resultat {
            case .success(let url): data.meddelande = "Sparade \(url.lastPathComponent)"
            case .failure(let fel): data.meddelande = "Kunde inte spara: \(fel.localizedDescription)"
            }
        }
        .confirmationDialog("Töm listan?", isPresented: $visarRensa) {
            Button("Töm listan", role: .destructive) {
                markerade.removeAll()
                data.rensa()
            }
        } message: {
            Text("Filerna på disken påverkas inte, men ändrade namn, villkor och kopplingar försvinner.")
        }
    }

    private func importera(_ urls: [URL]) {
        let resultat = data.importera(urls)
        // Bara en enkät inläst → visa enkätfliken direkt.
        if resultat.ospan == 0 && resultat.enkatsvar > 0 { flik = .enkat }
    }

    // MARK: - Delar

    private var tomVy: some View {
        ContentUnavailableView {
            Label("Släpp OSPAN-filer här", systemImage: "tray.and.arrow.down")
        } description: {
            Text("Dra in .csv- eller .txt-filer från OSPAN-testet och enkätsvaren från Google Formulär – eller en hel mapp. Villkoret (med/utan mobil) läses av från filnamnet och kan ändras i tabellen efteråt.")
        } actions: {
            Button("Välj filer eller mapp …") { visarImport = true }
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var ospanFlik: some View {
        if data.deltagare.isEmpty {
            ContentUnavailableView {
                Label("Inga OSPAN-filer inlästa", systemImage: "brain.head.profile")
            } description: {
                Text("Dra in .csv- eller .txt-filer från OSPAN-testet.")
            } actions: {
                Button("Välj filer eller mapp …") { visarImport = true }
            }
        } else {
            VSplitView {
                DeltagarTabell(data: data, markerade: $markerade)
                    .frame(minHeight: 200)
                GruppJamforelseVy(grupper: data.grupper)
                    .frame(minHeight: 150, idealHeight: 330)
            }
        }
    }

    private var statusrad: some View {
        let medraknade = data.deltagare.filter(\.medraknas)
        let dubbletter = data.deltagare.filter { !$0.dubblettAv.isEmpty }.count
        let ejKopplade = data.enkatsvar.count - data.kopplingar.count
        return HStack(spacing: 16) {
            Text("\(data.deltagare.count) filer · \(medraknade.count) räknas med")
            ForEach(data.grupper) { g in
                Text("\(g.villkor.rawValue): \(g.n)")
                    .foregroundStyle(.secondary)
            }
            if !data.enkatsvar.isEmpty {
                Text("\(data.enkatsvar.count) enkätsvar")
                if ejKopplade > 0 {
                    Label("\(ejKopplade) ej kopplade", systemImage: "questionmark.circle.fill")
                        .foregroundStyle(.orange)
                }
            }
            if dubbletter > 0 {
                Label("\(dubbletter) filer har identisk data", systemImage: "doc.on.doc.fill")
                    .foregroundStyle(.red)
            }
            Spacer()
            if let meddelande = data.meddelande {
                Text(meddelande)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var verktygsfalt: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                visarImport = true
            } label: {
                Label("Lägg till filer", systemImage: "plus")
            }
            .help("Lägg till OSPAN-filer, enkätsvar eller en mapp")

            Button {
                visarRensa = true
            } label: {
                Label("Töm listan", systemImage: "trash")
            }
            .disabled(data.deltagare.isEmpty && data.enkatsvar.isEmpty)
            .help("Töm listan")

            Menu {
                Button("Sammanställning per deltagare …") { exportera(.perDeltagare) }
                    .disabled(data.medraknade.isEmpty)
                Button("Alla rader under varandra (långt format) …") { exportera(.allaRader) }
                    .disabled(data.medraknade.isEmpty)
                Button("Gruppjämförelse med mobil / utan mobil …") { exportera(.grupper) }
                    .disabled(data.medraknade.isEmpty)
                Button("Enkät med SAS-SV-poäng …") { exportera(.enkat) }
                    .disabled(data.enkatsvar.isEmpty)
                Divider()
                Picker("Decimaltecken", selection: $decimaltecken) {
                    Text("Decimalkomma (svensk Excel/Numbers)").tag(",")
                    Text("Decimalpunkt").tag(".")
                }
                .pickerStyle(.inline)
            } label: {
                Label("Exportera CSV", systemImage: "square.and.arrow.up")
            } primaryAction: {
                exportera(flik == .enkat && !data.enkatsvar.isEmpty ? .enkat : .perDeltagare)
            }
            .disabled(data.medraknade.isEmpty && data.enkatsvar.isEmpty)
            .help("Exportera till CSV. Sammanställningen per deltagare får med SAS-poängen när enkäten är inläst.")
        }
    }

    // MARK: - Export

    private func exportera(_ typ: Export) {
        let format = CSVFormat(decimaltecken: decimaltecken)
        let text = switch typ {
        case .perDeltagare:
            CSVExport.perDeltagare(data.medraknade, sas: data.enkatPerDeltagare, sasFragor: data.enkatFragor.count,
                                   variabler: data.enkatVariabler, format: format)
        case .allaRader: CSVExport.allaRader(data.medraknade, format: format)
        case .grupper: CSVExport.gruppjamforelse(data.grupper, format: format)
        case .enkat:
            CSVExport.enkat(data.enkatsvar, fragor: data.enkatFragor, variabler: data.enkatVariabler,
                            kopplingar: data.kopplingar, format: format)
        }
        exportDokument = CSVDokument(text: text)
        exportNamn = "\(typ.filnamn)_\(Date().formatted(.iso8601.year().month().day()))"
        visarExport = true
    }
}

#Preview {
    ContentView()
        .frame(width: 1100, height: 700)
}
