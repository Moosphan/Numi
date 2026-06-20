import AppIntents

struct NumiShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordTransactionIntent(),
            phrases: [
                "用 \(.applicationName) 记一笔 \(\.$text)",
                "\(.applicationName) 记账 \(\.$text)",
                "快速记账 \(\.$text)",
                "糯米记一笔 \(\.$text)",
                "糯米记账 \(\.$text)",
                "糯米 \(\.$text)"
            ],
            shortTitle: "快速记账",
            systemImageName: "plus.circle.fill"
        )
    }
}
