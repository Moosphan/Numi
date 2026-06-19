import SwiftUI

public struct NumiDatePickerRow: View {
    private let title: String
    @Binding private var selectedDate: Date
    @State private var isCustomDatePresented = false
    private let accessibilityIdentifier: String
    private let calendar: Calendar

    public init(
        title: String = "日期",
        selectedDate: Binding<Date>,
        accessibilityIdentifier: String,
        calendar: Calendar = .current
    ) {
        self.title = title
        self._selectedDate = selectedDate
        self.accessibilityIdentifier = accessibilityIdentifier
        self.calendar = calendar
    }

    public var body: some View {
        Menu {
            shortcutButton(title: "今天", dayOffset: 0)
            shortcutButton(title: "昨天", dayOffset: -1)
            shortcutButton(title: "前天", dayOffset: -2)
            Button {
                isCustomDatePresented = true
            } label: {
                Label("自定义日期", systemImage: "calendar")
            }
            .accessibilityIdentifier("dateShortcut.自定义日期")
        } label: {
            HStack(spacing: NumiSpacing.s3) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NumiColor.textTertiary)
                    .frame(width: 24)
                Text(title)
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textSecondary)
                Spacer()
                Text(Self.displayText(for: selectedDate, calendar: calendar))
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NumiColor.textTertiary)
            }
            .padding(.horizontal, NumiSpacing.s4)
            .frame(minHeight: 44)
            .background(NumiColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .sheet(isPresented: $isCustomDatePresented) {
            NavigationStack {
                DatePicker("日期", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .padding(NumiSpacing.s5)
                    .navigationTitle("选择日期")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") {
                                isCustomDatePresented = false
                            }
                        }
                    }
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
        }
    }

    public static func displayText(for date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return "今天"
        }
        if calendar.isDateInYesterday(date) {
            return "昨天"
        }
        if let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: Date()),
           calendar.isDate(date, inSameDayAs: dayBeforeYesterday) {
            return "前天"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func shortcutButton(title: String, dayOffset: Int) -> some View {
        Button {
            selectedDate = date(dayOffset: dayOffset)
        } label: {
            Label(title, systemImage: dayOffset == 0 ? "calendar.badge.clock" : "calendar")
        }
        .accessibilityIdentifier("dateShortcut.\(title)")
    }

    private func date(dayOffset: Int) -> Date {
        calendar.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
    }
}
