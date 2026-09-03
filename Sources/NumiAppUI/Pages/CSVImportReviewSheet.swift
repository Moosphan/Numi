import SwiftUI
import NumiCore

public struct CSVImportReviewSheet: View {
    private let document: CSVImportDocument
    private let context: CSVImportContext
    private let onImport: ([NumiCore.Transaction]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mapping: CSVImportMapping

    public init(
        document: CSVImportDocument,
        snapshot: BookkeepingSnapshot,
        onImport: @escaping ([NumiCore.Transaction]) -> Void
    ) {
        self.document = document
        context = CSVImportContext(
            ledger: snapshot.ledgers[0],
            categories: snapshot.categories,
            accounts: snapshot.accounts
        )
        self.onImport = onImport
        _mapping = State(initialValue: CSVImportMapping(headers: document.headers))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                    mappingSection
                    previewSection
                    errorsSection
                }
                .padding(NumiSpacing.s5)
                .padding(.bottom, NumiSpacing.s5)
            }
            .accessibilityIdentifier("scroll.csvImportReview")
            .background(NumiColor.surfacePage)
            .navigationTitle(NumiLocalized.string("io.import.csv"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NumiLocalized.string("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NumiLocalized.string("io.import.csv.confirm")) {
                        onImport(preview.transactions)
                        dismiss()
                    }
                    .disabled(preview.transactions.isEmpty)
                    .accessibilityIdentifier("io.import.csv.confirm")
                }
            }
        }
    }

    private var preview: CSVImportResult {
        NumiCSVImporter.preview(document: document, mapping: mapping, context: context)
    }

    private var mappingSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text(NumiLocalized.string("io.import.csv.mapping"))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            VStack(spacing: 0) {
                ForEach(document.headers, id: \.self) { header in
                    Picker(header, selection: mappingBinding(for: header)) {
                        ForEach(CSVImportField.allCases) { field in
                            Text(NumiLocalized.string("io.import.csv.field.\(field.rawValue)"))
                                .tag(field)
                        }
                    }
                    .padding(.horizontal, NumiSpacing.s4)
                    .padding(.vertical, NumiSpacing.s2)

                    if header != document.headers.last {
                        Divider().padding(.leading, NumiSpacing.s4)
                    }
                }
            }
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text(NumiLocalized.string("io.import.csv.valid.count", preview.transactions.count))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            VStack(spacing: 0) {
                ForEach(Array(preview.transactions.prefix(20).enumerated()), id: \.element.id) { index, transaction in
                    HStack(spacing: NumiSpacing.s3) {
                        Text("\(index + 1)")
                            .font(NumiFont.footnote)
                            .foregroundStyle(NumiColor.textTertiary)
                            .frame(width: 20, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(transaction.note.isEmpty ? "—" : transaction.note)
                                .font(NumiFont.body)
                                .foregroundStyle(NumiColor.textPrimary)
                                .lineLimit(1)
                            Text(transaction.occurredAt.formatted(date: .abbreviated, time: .omitted))
                                .font(NumiFont.footnote)
                                .foregroundStyle(NumiColor.textTertiary)
                        }
                        Spacer()
                        Text(transaction.amount.formatted())
                            .font(NumiFont.body)
                            .foregroundStyle(NumiColor.textPrimary)
                    }
                    .padding(.horizontal, NumiSpacing.s4)
                    .padding(.vertical, NumiSpacing.s3)

                    if index < min(preview.transactions.count, 20) - 1 {
                        Divider().padding(.leading, NumiSpacing.s4)
                    }
                }
            }
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        }
    }

    @ViewBuilder
    private var errorsSection: some View {
        if !preview.errors.isEmpty {
            VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                Text(NumiLocalized.string("io.import.csv.errors"))
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textSecondary)

                VStack(alignment: .leading, spacing: NumiSpacing.s2) {
                    ForEach(Array(preview.errors.enumerated()), id: \.offset) { _, error in
                        Text("#\(error.lineNumber) · \(error.message)")
                            .font(NumiFont.footnote)
                            .foregroundStyle(NumiColor.negativeText)
                    }
                }
                .padding(NumiSpacing.s4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NumiColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
            }
        }
    }

    private func mappingBinding(for header: String) -> Binding<CSVImportField> {
        Binding(
            get: { mapping.field(for: header) },
            set: { mapping.assign($0, to: header) }
        )
    }
}
