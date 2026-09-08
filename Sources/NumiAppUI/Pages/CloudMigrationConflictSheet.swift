import SwiftUI
import NumiCore

public struct CloudMigrationConflictSheet: View {
    public let assessment: CloudMigrationAssessment
    public let onSelect: (CloudMigrationConflictStrategy) -> Void

    public init(assessment: CloudMigrationAssessment, onSelect: @escaping (CloudMigrationConflictStrategy) -> Void) {
        self.assessment = assessment
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s4) {
            Text(NumiLocalized.string("sync.migration.conflict.title"))
                .font(NumiFont.title)
            Text(NumiLocalized.string(messageKey))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            Text(NumiLocalized.string("sync.migration.local.summary", assessment.localTransactionCount, assessment.localAccountCount, assessment.localInstallmentPlanCount))
                .font(NumiFont.footnote)
                .foregroundStyle(NumiColor.textSecondary)
            Text(NumiLocalized.string("sync.migration.cloud.summary", assessment.cloudTransactionCount, assessment.cloudAccountCount, assessment.cloudInstallmentPlanCount))
                .font(NumiFont.footnote)
                .foregroundStyle(NumiColor.textSecondary)
            if assessment.resolution != .keepICloud {
                choice("sync.migration.prefer.local", .preferLocal)
            }
            if assessment.resolution != .importLocal {
                choice("sync.migration.prefer.cloud", .preferICloud)
            }
            Button(NumiLocalized.string("sync.migration.cancel")) { onSelect(.cancel) }
                .font(NumiFont.bodyStrong)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(NumiColor.textSecondary)
        }
        .padding(NumiSpacing.s5)
        .accessibilityIdentifier("sheet.cloudMigrationConflict")
    }

    private func choice(_ key: String, _ strategy: CloudMigrationConflictStrategy) -> some View {
        Button { onSelect(strategy) } label: {
            Text(NumiLocalized.string(key))
                .font(NumiFont.bodyStrong)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(NumiColor.accentPrimary)
    }

    private var messageKey: String {
        switch assessment.resolution {
        case .importLocal:
            "sync.migration.empty.cloud.message"
        case .keepICloud:
            "sync.migration.empty.local.message"
        case .requiresDecision:
            "sync.migration.conflict.message"
        }
    }
}
