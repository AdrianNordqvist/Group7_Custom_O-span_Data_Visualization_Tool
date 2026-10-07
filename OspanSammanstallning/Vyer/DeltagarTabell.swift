import AppKit
import SwiftUI

/// En rad per inläst fil. Namn, villkor och "Med" går att ändra direkt i tabellen.
struct DeltagarTabell: View {
    let data: Sammanstallning
    @Binding var markerade: Set<Deltagare.ID>
    @State private var sortering = [KeyPathComparator(\Deltagare.villkor), KeyPathComparator(\Deltagare.datumSortering)]

    var body: some View {
        Table(data.deltagare.sorted(using: sortering), selection: $markerade, sortOrder: $sortering) {
            Group {
                TableColumn("Med", value: \Deltagare.medraknasSortering) { (d: Deltagare) in MedraknasCell(deltagare: d) }
                    .width(34)
                TableColumn("Kod", value: \Deltagare.kod)
                    .width(40)
                TableColumn("Namn", value: \Deltagare.namn) { (d: Deltagare) in NamnCell(deltagare: d) }
                    .width(min: 70, ideal: 90)
                TableColumn("Villkor", value: \Deltagare.villkor) { (d: Deltagare) in VillkorCell(deltagare: d) }
                    .width(min: 100, ideal: 110)
                TableColumn("Datum", value: \Deltagare.datumSortering) { (d: Deltagare) in
                    Text(d.datum?.formatted(date: .numeric, time: .shortened) ?? "–")
                        .foregroundStyle(.secondary)
                }
                .width(min: 90, ideal: 120)
            }
            Group {
                TableColumn("O-Span", value: \Deltagare.sammanfattning.ospanAbsolut) { (d: Deltagare) in
                    Siffra("\(d.sammanfattning.ospanAbsolut)")
                }
                .width(50)
                TableColumn("Partial", value: \Deltagare.sammanfattning.partial) { (d: Deltagare) in
                    Siffra("\(d.sammanfattning.partial)/\(d.sammanfattning.maxBokstaver)")
                }
                .width(56)
                TableColumn("Matte %", value: \Deltagare.sammanfattning.matteProcent) { (d: Deltagare) in
                    Siffra(d.sammanfattning.matteProcent.formatted(.number.precision(.fractionLength(0))))
                        .foregroundStyle(d.sammanfattning.matteProcent < 85 ? .orange : .primary)
                }
                .width(56)
                TableColumn("Matte-RT", value: \Deltagare.sammanfattning.matteRTMedel) { (d: Deltagare) in
                    Siffra(ms(d.sammanfattning.matteRTMedel))
                }
                .width(70)
                TableColumn("Tidsgräns", value: \Deltagare.sammanfattning.tidsgrans) { (d: Deltagare) in
                    Siffra(ms(Double(d.sammanfattning.tidsgrans)))
                }
                .width(70)
            }
            Group {
                TableColumn("Vid gräns", value: \Deltagare.sammanfattning.antalVidTidsgrans) { (d: Deltagare) in
                    Siffra("\(d.sammanfattning.antalVidTidsgrans)")
                }
                .width(56)
                TableColumn("Bokstav-RT", value: \Deltagare.sammanfattning.bokstavRTMedel) { (d: Deltagare) in
                    Siffra(ms(d.sammanfattning.bokstavRTMedel))
                }
                .width(74)
                TableColumn("Anmärkning", value: \Deltagare.varningSortering) { (d: Deltagare) in VarningCell(deltagare: d) }
                    .width(min: 120, ideal: 260)
                TableColumn("Fil", value: \Deltagare.filnamn) { (d: Deltagare) in
                    Text(d.filnamn).foregroundStyle(.secondary).help(d.fil.path)
                }
                .width(min: 120, ideal: 260)
            }
        }
        .contextMenu(forSelectionType: Deltagare.ID.self) { ids in
            if !ids.isEmpty {
                Button("Räkna med") { data.satt(medraknas: true, for: ids) }
                Button("Räkna inte med") { data.satt(medraknas: false, for: ids) }
                Menu("Sätt villkor") {
                    ForEach(Villkor.allCases) { v in
                        Button(v.rawValue) { data.satt(villkor: v, for: ids) }
                    }
                }
                Divider()
                Button("Visa i Finder") {
                    let filer = data.deltagare.filter { ids.contains($0.id) }.map(\.fil)
                    NSWorkspace.shared.activateFileViewerSelecting(filer)
                }
                Button("Ta bort från listan", role: .destructive) { data.taBort(ids) }
            }
        }
        .onDeleteCommand { data.taBort(markerade) }
    }

    private func ms(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0))) + " ms"
    }
}

struct Siffra: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct MedraknasCell: View {
    @Bindable var deltagare: Deltagare

    var body: some View {
        Toggle("Räkna med", isOn: $deltagare.medraknas)
            .labelsHidden()
            .help("Räknas med i jämförelsen och exporten")
    }
}

private struct NamnCell: View {
    @Bindable var deltagare: Deltagare

    var body: some View {
        TextField("Namn", text: $deltagare.namn)
            .textFieldStyle(.plain)
    }
}

private struct VillkorCell: View {
    @Bindable var deltagare: Deltagare

    var body: some View {
        Picker("Villkor", selection: $deltagare.villkor) {
            ForEach(Villkor.allCases) { v in
                Text(v.rawValue).tag(v)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
    }
}

private struct VarningCell: View {
    let deltagare: Deltagare

    var body: some View {
        let varningar = deltagare.varningar
        if let forsta = varningar.first {
            HStack(spacing: 4) {
                Image(systemName: deltagare.dubblettAv.isEmpty ? "exclamationmark.circle" : "doc.on.doc.fill")
                    .foregroundStyle(deltagare.dubblettAv.isEmpty ? .orange : .red)
                Text(varningar.count > 1 ? "\(forsta) (+\(varningar.count - 1))" : forsta)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .help(varningar.joined(separator: "\n"))
        }
    }
}
