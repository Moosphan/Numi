import SwiftUI
import NumiCore

/// A compact in-app guide for the free Siri and App Shortcuts bookkeeping flow.
public struct SiriShortcutsGuideView: View {
    @ObservedObject private var themeController = NumiThemeController.shared
    private let isAIConfigured: Bool

    public init(isAIConfigured: Bool) {
        self.isAIConfigured = isAIConfigured
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                hero
                setupStatus
                steps
                example
            }
            .padding(NumiSpacing.s5)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("scroll.siriShortcutsGuide")
        .background(NumiColor.surfacePage)
        .navigationTitle(NumiLocalized.string("siri.shortcuts.title"))
        .modifier(LargeTitleNavigationChrome())
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            Image(systemName: "mic.and.signal.meter")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(NumiColor.accentDeep)
                .frame(width: 64, height: 64)
                .background(NumiColor.iconBackground)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))

            Text(NumiLocalized.string("siri.shortcuts.title"))
                .font(NumiFont.title)
                .foregroundStyle(NumiColor.textPrimary)

            Text(NumiLocalized.string("siri.shortcuts.summary"))
                .font(NumiFont.body)
                .foregroundStyle(NumiColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NumiSpacing.s5)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private var setupStatus: some View {
        HStack(spacing: NumiSpacing.s3) {
            Image(systemName: isAIConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isAIConfigured ? NumiColor.positiveText : NumiColor.textTertiary)

            Text(NumiLocalized.string(
                isAIConfigured ? "siri.shortcuts.status.ready" : "siri.shortcuts.status.setup"
            ))
            .font(NumiFont.bodyStrong)
            .foregroundStyle(NumiColor.textPrimary)

            Spacer()
        }
        .padding(NumiSpacing.s4)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s3) {
            guideStep(number: 1, textKey: "siri.shortcuts.step.setup")
            guideStep(number: 2, textKey: "siri.shortcuts.step.open")
            guideStep(number: 3, textKey: "siri.shortcuts.step.record")
        }
    }

    private var example: some View {
        VStack(alignment: .leading, spacing: NumiSpacing.s2) {
            Text(NumiLocalized.string("siri.shortcuts.example.label"))
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textSecondary)

            Text(NumiLocalized.string("siri.shortcuts.example"))
                .font(NumiFont.bodyStrong)
                .foregroundStyle(NumiColor.accentDeep)
                .textSelection(.enabled)
        }
        .padding(NumiSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NumiColor.iconBackground)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
    }

    private func guideStep(number: Int, textKey: String) -> some View {
        HStack(alignment: .top, spacing: NumiSpacing.s3) {
            Text("\(number)")
                .font(NumiFont.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(NumiColor.accentDeep)
                .clipShape(Circle())

            Text(NumiLocalized.string(textKey))
                .font(NumiFont.body)
                .foregroundStyle(NumiColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(NumiSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NumiColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
    }
}
