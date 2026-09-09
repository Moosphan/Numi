import SwiftUI
import NumiCore

public struct CSVImportReviewSheet: View {
    @ObservedObject private var themeController = NumiThemeController.shared
    private let document: CSVImportDocument
    private let context: CSVImportContext
    private let onImport: ([NumiCore.Transaction]) -> Void
    private let templateStore: CSVImportMappingTemplateStore

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var membership = MembershipController.shared
    @State private var mapping: CSVImportMapping
    @State private var templates: [CSVImportMappingTemplate]
    @State private var templateName = ""
    @State private var showsTemplateNameEditor = false
    @State private var membershipPaywallContext: MembershipPaywallContext?

    public init(
        document: CSVImportDocument,
        ledger: Ledger,
        snapshot: BookkeepingSnapshot,
        templateStore: CSVImportMappingTemplateStore = .shared,
        onImport: @escaping ([NumiCore.Transaction]) -> Void
    ) {
        self.document = document
        context = CSVImportContext(
            ledger: ledger,
            categories: snapshot.categories,
            accounts: snapshot.accounts
        )
        self.onImport = onImport
        self.templateStore = templateStore
        _mapping = State(initialValue: CSVImportMapping(headers: document.headers))
        _templates = State(initialValue: templateStore.templates)
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
        .alert(NumiLocalized.string("io.import.csv.template.save.title"), isPresented: $showsTemplateNameEditor) {
            TextField("io.import.csv.template.save.placeholder", text: $templateName)
            Button(NumiLocalized.string("common.cancel"), role: .cancel) {}
            Button(NumiLocalized.string("io.import.csv.template.save")) {
                saveTemplate()
            }
            .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .task { await membership.start() }
        .membershipPaywall(context: $membershipPaywallContext)
    }

    private var preview: CSVImportResult {
        NumiCSVImporter.preview(document: document, mapping: mapping, context: context)
    }

    private var mappingSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            HStack {
                Text(NumiLocalized.string("io.import.csv.mapping"))
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textSecondary)
                Spacer()
                mappingTemplateMenu
            }

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

    @ViewBuilder
    private var mappingTemplateMenu: some View {
        Menu {
            if !templates.isEmpty {
                Menu(NumiLocalized.string("io.import.csv.template.load")) {
                    ForEach(templates) { template in
                        Button(template.name) {
                            mapping = template.mapping.applying(to: document.headers)
                        }
                    }
                }
                Divider()
            }
            Button(NumiLocalized.string("io.import.csv.template.save")) {
                startSavingTemplate()
            }
            if !templates.isEmpty {
                Menu(NumiLocalized.string("io.import.csv.template.delete")) {
                    ForEach(templates) { template in
                        Button(template.name, role: .destructive) {
                            deleteTemplate(template)
                        }
                    }
                }
            }
        } label: {
            Label(NumiLocalized.string("io.import.csv.template.label"), systemImage: "bookmark")
                .font(NumiFont.footnote)
                .foregroundStyle(NumiColor.accentDeep)
        }
        .accessibilityIdentifier("menu.csvImportMappingTemplate")
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Text(NumiLocalized.string("io.import.csv.valid.count", preview.transactions.count))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            if preview.containsForeignCurrency(comparedTo: context.ledger.currencyCode) {
                HStack(alignment: .top, spacing: NumiSpacing.s3) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(NumiColor.expenseText)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(NumiLocalized.string("io.import.csv.currency.warning.title"))
                            .font(NumiFont.bodyStrong)
                            .foregroundStyle(NumiColor.textPrimary)
                        Text(NumiLocalized.string("io.import.csv.currency.warning.message"))
                            .font(NumiFont.footnote)
                            .foregroundStyle(NumiColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(NumiSpacing.s3)
                .background(NumiColor.expenseBackground, in: RoundedRectangle(cornerRadius: NumiRadius.lg))
                .accessibilityIdentifier("io.import.csv.currency.warning")
            }

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
                        Text("#\(error.lineNumber) · \(localizedMessage(for: error))")
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

    private func startSavingTemplate() {
        switch membership.decision(for: .openAdvancedImportExport) {
        case .granted:
            templateName = ""
            showsTemplateNameEditor = true
        case .blocked(let context):
            membershipPaywallContext = context
        }
    }

    private func saveTemplate() {
        let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        templateStore.save(CSVImportMappingTemplate(name: name, mapping: mapping))
        templates = templateStore.templates
    }

    private func deleteTemplate(_ template: CSVImportMappingTemplate) {
        templateStore.delete(id: template.id)
        templates = templateStore.templates
    }

    private func localizedMessage(for error: CSVImportError) -> String {
        switch error.code {
        case .accountCurrencyMismatch:
            NumiLocalized.string("io.import.csv.error.account.currency.mismatch")
        case .convertedAmountCurrencyMismatch:
            NumiLocalized.string("io.import.csv.error.converted.amount.currency.mismatch")
        case nil:
            error.message
        }
    }
}
