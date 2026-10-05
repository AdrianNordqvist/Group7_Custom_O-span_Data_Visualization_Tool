import SwiftUI

/// Medelvärde (SD) per villkor för deltagarna som räknas med.
struct GruppJamforelseVy: View {
    let grupper: [Grupp]

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            GruppJamforelseInnehall(grupper: grupper)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct GruppJamforelseInnehall: View {
    let grupper: [Grupp]

    private var med: Grupp? { grupper.first { $0.villkor == .medMobil } }
    private var utan: Grupp? { grupper.first { $0.villkor == .utanMobil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Jämförelse mellan villkor")
                    .font(.headline)
                Text("Medelvärde (standardavvikelse) för deltagarna som räknas med. RT = reaktionstid.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if grupper.isEmpty {
                Text("Ingen deltagare räknas med ännu.")
                    .foregroundStyle(.secondary)
            } else {
                tabell
            }
        }
    }

    private var tabell: some View {
        Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 6) {
            GridRow {
                Text("Mått")
                ForEach(grupper) { g in
                    Text("\(g.villkor.rawValue) (n = \(g.n))")
                        .gridColumnAlignment(.trailing)
                }
                if med != nil, utan != nil {
                    Text("Skillnad med − utan")
                        .gridColumnAlignment(.trailing)
                }
            }
            .font(.subheadline.bold())

            Divider()

            ForEach(Matt.allCases) { m in
                GridRow {
                    Text("\(m.namn) (\(m.enhet))")
                    ForEach(grupper) { g in
                        Text(medelOchSD(g, m))
                            .monospacedDigit()
                    }
                    if let med, let utan, let a = med.medel(m), let b = utan.medel(m) {
                        Text(tal(a - b, m, tecken: true))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func medelOchSD(_ g: Grupp, _ m: Matt) -> String {
        guard let medel = g.medel(m) else { return "–" }
        guard let sd = g.sd(m) else { return tal(medel, m) }
        return "\(tal(medel, m)) (\(tal(sd, m)))"
    }

    private func tal(_ v: Double, _ m: Matt, tecken: Bool = false) -> String {
        v.formatted(.number.precision(.fractionLength(m.decimaler)).sign(strategy: tecken ? .always() : .automatic))
    }
}
