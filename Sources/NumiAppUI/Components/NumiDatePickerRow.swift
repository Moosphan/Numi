import SwiftUI
import NumiCore

public struct NumiDatePickerRow: View {
    private let title: String?
    @Binding private var selectedDate: Date
    @State private var isCustomDatePresented = false
    private let accessibilityIdentifier: String
    private let calendar: Calendar

    public init(
        title: String? = nil,
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
            shortcutButton(
                accessibilityKey: "today",
                title: NumiLocalized.string("date.today"),
                dayOffset: 0
            )
            shortcutButton(
                accessibilityKey: "yesterday",
                title: NumiLocalized.string("date.yesterday"),
                dayOffset: -1
            )
            shortcutButton(
                accessibilityKey: "dayBeforeYesterday",
                title: NumiLocalized.string("date.dayBeforeYesterday"),
                dayOffset: -2
            )
            Button {
                isCustomDatePresented = true
            } label: {
                Label("addRecordFlow.datePicker.title", systemImage: "calendar")
            }
            .accessibilityIdentifier("dateShortcut.custom")
        } label: {
            HStack(spacing: NumiSpacing.s3) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NumiColor.textTertiary)
                    .frame(width: 24)
                Text(title ?? NumiLocalized.string("record.date"))
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
                DatePicker("record.date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .padding(NumiSpacing.s5)
                    .navigationTitle("addRecordFlow.datePicker.title")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("common.done") {
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
        displayText(for: date, calendar: calendar, includesTime: true)
    }

    public static func displayText(
        for date: Date,
        calendar: Calendar = .current,
        includesTime: Bool
    ) -> String {
        if calendar.isDateInToday(date) {
            return NumiLocalized.string("date.today")
        }
        if calendar.isDateInYesterday(date) {
            return NumiLocalized.string("date.yesterday")
        }
        if let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: Date()),
           calendar.isDate(date, inSameDayAs: dayBeforeYesterday) {
            return NumiLocalized.string("date.dayBeforeYesterday")
        }

        let formatter = DateFormatter()
        formatter.locale = NumiLocalized.currentLocale
        formatter.setLocalizedDateFormatFromTemplate(includesTime ? "MMMdjm" : "MMMd")
        return formatter.string(from: date)
    }

    private func shortcutButton(accessibilityKey: String, title: String, dayOffset: Int) -> some View {
        Button {
            selectedDate = date(dayOffset: dayOffset)
        } label: {
            Label(title, systemImage: dayOffset == 0 ? "calendar.badge.clock" : "calendar")
        }
        .accessibilityIdentifier("dateShortcut.\(accessibilityKey)")
    }

    private func date(dayOffset: Int) -> Date {
        calendar.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
    }
}
