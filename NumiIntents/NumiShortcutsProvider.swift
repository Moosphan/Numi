import AppIntents

struct NumiShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordTransactionIntent(),
            phrases: [
                "intent.phrase.record \(.applicationName) \(\.$text)",
            ],
            shortTitle: "intent.shortTitle",
            systemImageName: "plus.circle.fill"
        )
    }
}
