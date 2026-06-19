import SwiftUI
import NumiCore

public enum HomePeriod: String, CaseIterable, Identifiable {
    case week = "周"
    case month = "月"
    case quarter = "季度"
    case year = "年"

    public var id: String { rawValue }
}

public struct TransactionHomeRow: Identifiable {
    public let transaction: NumiCore.Transaction
    public let categoryName: String
    public let iconName: String
    public let subtitle: String?

    public var id: UUID { transaction.id }

    public init(
        transaction: NumiCore.Transaction,
        categoryName: String,
        iconName: String,
        subtitle: String?
    ) {
        self.transaction = transaction
        self.categoryName = categoryName
        self.iconName = iconName
        self.subtitle = subtitle
    }
}

public struct TransactionHomeSection: Identifiable {
    public let id: String
    public let title: String
    public let rows: [TransactionHomeRow]

    public init(id: String, title: String, rows: [TransactionHomeRow]) {
        self.id = id
        self.title = title
        self.rows = rows
    }
}

public struct TransactionsHomeView: View {
    private let summary: TransactionSummary
    private let periodTitle: String
    private let selectedPeriod: HomePeriod
    private let isNextPeriodEnabled: Bool
    private let sections: [TransactionHomeSection]
    private let onPreviousPeriod: () -> Void
    private let onNextPeriod: () -> Void
    private let onSelectPeriod: (HomePeriod) -> Void
    private let onSelect: (NumiCore.Transaction) -> Void
    private let onPrimaryAction: () -> Void
    private let onDelete: (NumiCore.Transaction) -> Void
    private let onUndoDelete: () -> Void
    private let onSearch: () -> Void
    private let onEdit: (NumiCore.Transaction) -> Void
    private let onShare: (NumiCore.Transaction) -> Void
    @State private var pendingDelete: NumiCore.Transaction?
    @State private var showsUndo = false
    @State private var showsPeriodPicker = false

    public init(
        summary: TransactionSummary,
        periodTitle: String,
        selectedPeriod: HomePeriod,
        isNextPeriodEnabled: Bool,
        sections: [TransactionHomeSection],
        onPreviousPeriod: @escaping () -> Void = {},
        onNextPeriod: @escaping () -> Void = {},
        onSelectPeriod: @escaping (HomePeriod) -> Void = { _ in },
        onSearch: @escaping () -> Void = {},
        onSelect: @escaping (NumiCore.Transaction) -> Void = { _ in },
        onPrimaryAction: @escaping () -> Void = {},
        onEdit: @escaping (NumiCore.Transaction) -> Void = { _ in },
        onShare: @escaping (NumiCore.Transaction) -> Void = { _ in },
        onDelete: @escaping (NumiCore.Transaction) -> Void = { _ in },
        onUndoDelete: @escaping () -> Void = {}
    ) {
        self.summary = summary
        self.periodTitle = periodTitle
        self.selectedPeriod = selectedPeriod
        self.isNextPeriodEnabled = isNextPeriodEnabled
        self.sections = sections
        self.onPreviousPeriod = onPreviousPeriod
        self.onNextPeriod = onNextPeriod
        self.onSelectPeriod = onSelectPeriod
        self.onSearch = onSearch
        self.onSelect = onSelect
        self.onPrimaryAction = onPrimaryAction
        self.onEdit = onEdit
        self.onShare = onShare
        self.onDelete = onDelete
        self.onUndoDelete = onUndoDelete
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            contentView
                .background(NumiColor.surfacePage)
                .modifier(HomeToolbarChrome(periodToolbarControl: periodToolbarControl, searchToolbarButton: searchToolbarButton))
                .confirmationDialog(
                    "删除这笔记录？",
                    isPresented: deleteConfirmationBinding,
                    titleVisibility: .visible,
                    presenting: pendingDelete
                ) { transaction in
                    Button("删除", role: .destructive) {
                        onDelete(transaction)
                        showsUndo = true
                    }
                    .accessibilityIdentifier("action.confirmDeleteRecord")

                    Button("取消", role: .cancel) {}
                } message: { _ in
                    Text("删除后可立即撤销。")
                }

            if showsUndo {
                undoBar
                    .padding(.horizontal, NumiSpacing.s5)
                    .padding(.bottom, 152)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showsPeriodPicker) {
            homePeriodPickerSheet
                .presentationDetents([.height(320)])
                .presentationCornerRadius(28)
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDelete = nil
                }
            }
        )
    }

    private var periodToolbarControl: some View {
        HStack(spacing: 2) {
            toolbarChevronButton(
                systemImage: "chevron.left",
                identifier: "home.period.previous",
                action: onPreviousPeriod
            )
            Button {
                showsPeriodPicker = true
            } label: {
                HStack(spacing: 2) {
                    Text(periodTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(NumiColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NumiColor.textTertiary)
                        .padding(.horizontal, 2)
                }
                .frame(minWidth: 132)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.period.title")
            .accessibilityLabel(periodTitle)
            toolbarChevronButton(
                systemImage: "chevron.right",
                identifier: "home.period.next",
                isEnabled: isNextPeriodEnabled,
                action: onNextPeriod
            )
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NumiSpacing.s3) {
            NumiSummaryTile(title: "支出", value: summary.expense.formatted(), systemImage: "cart", variant: .expense)
            NumiSummaryTile(title: "收入", value: summary.income.formatted(), systemImage: "creditcard", variant: .income)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if sections.isEmpty {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: NumiSpacing.s5) {
                        summaryGrid
                        homeEmptyState
                            .frame(minHeight: max(proxy.size.height - 220, 360))
                    }
                    .padding(.horizontal, NumiSpacing.s5)
                    .padding(.top, NumiSpacing.s3)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    summaryGrid
                        .padding(.horizontal, NumiSpacing.s5)
                        .padding(.top, NumiSpacing.s3)
                        .padding(.bottom, NumiSpacing.s2)

                    recordsList
                }
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var recordsList: some View {
        ForEach(sections) { section in
            Section {
                VStack(spacing: 0) {
                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                        let isFirst = index == 0
                        let isLast = index == section.rows.count - 1

                        PressableRow(onSelect: { onSelect(row.transaction) }) {
                            NumiRecordRow(
                                transaction: row.transaction,
                                categoryName: row.categoryName,
                                iconName: row.iconName,
                                subtitle: row.subtitle,
                                style: .grouped
                            )
                        }
                        .background(NumiColor.surfaceCard)
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: isFirst ? NumiRadius.xl : 0,
                            bottomLeadingRadius: isLast ? NumiRadius.xl : 0,
                            bottomTrailingRadius: isLast ? NumiRadius.xl : 0,
                            topTrailingRadius: isFirst ? NumiRadius.xl : 0,
                            style: .continuous
                        ))
                        .overlay {
                            UnevenRoundedRectangle(
                                topLeadingRadius: isFirst ? NumiRadius.xl : 0,
                                bottomLeadingRadius: isLast ? NumiRadius.xl : 0,
                                bottomTrailingRadius: isLast ? NumiRadius.xl : 0,
                                topTrailingRadius: isFirst ? NumiRadius.xl : 0,
                                style: .continuous
                            )
                            .strokeBorder(.white.opacity(0.44), lineWidth: 0.9)
                        }
                        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                        .contextMenu {
                            Button {
                                onEdit(row.transaction)
                            } label: {
                                Label("编辑", systemImage: "square.and.pencil")
                            }
                            .accessibilityIdentifier("action.context.editRecord")

                            Button {
                                pendingDelete = row.transaction
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            .accessibilityIdentifier("action.context.deleteRecord")

                            Button {
                                onShare(row.transaction)
                            } label: {
                                Label("分享", systemImage: "square.and.arrow.up")
                            }
                            .accessibilityIdentifier("action.context.shareRecord")
                        }

                        if !isLast {
                            Divider()
                                .padding(.leading, 62)
                        }
                    }
                }
                .padding(.horizontal, NumiSpacing.s5)
                .padding(.bottom, NumiSpacing.s4)
            } header: {
                Text(section.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NumiColor.textSecondary.opacity(section.id == "today" || section.id == "yesterday" ? 1 : 0.92))
                    .textCase(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, NumiSpacing.s5)
                    .padding(.top, NumiSpacing.s4)
                    .padding(.bottom, NumiSpacing.s2)
                    .background(NumiColor.surfacePage)
                    .accessibilityIdentifier("home.sectionDate.\(section.id)")
            }
        }
    }

    private var undoBar: some View {
        HStack(spacing: NumiSpacing.s3) {
            Text("已删除记录")
                .font(NumiFont.bodySmall)
                .foregroundStyle(NumiColor.textPrimary)
            Spacer()
            Button {
                onUndoDelete()
                showsUndo = false
            } label: {
                Text("撤销")
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.accentDeep)
                    .frame(minWidth: 72, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("action.undoDeleteRecord")
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, NumiSpacing.s3)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
    }

    private var searchToolbarButton: some View {
        Button {
            onSearch()
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: NumiChromeMetrics.toolbarSymbolSize, weight: .semibold))
                .foregroundStyle(NumiColor.textSecondary)
                .frame(
                    width: NumiChromeMetrics.toolbarButtonHitSize,
                    height: NumiChromeMetrics.toolbarButtonHitSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("action.openTransactionSearch")
    }

    private var homeEmptyState: some View {
        VStack(spacing: NumiSpacing.s5) {
            Spacer(minLength: 0)
            Image(systemName: "tray.full")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(NumiColor.textTertiary)
            VStack(spacing: NumiSpacing.s2) {
                Text("开始记录你的第一笔账单")
                    .font(NumiFont.bodyStrong)
                    .foregroundStyle(NumiColor.textPrimary)
                    .accessibilityIdentifier("home.empty.title")
                Text("点击右下角记录账单，这里会按日期整理最近的流水。")
                    .font(NumiFont.bodySmall)
                    .foregroundStyle(NumiColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("home.empty.subtitle")
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, NumiSpacing.s6)
        .padding(.vertical, NumiSpacing.s5)
    }

    private func toolbarChevronButton(
        systemImage: String,
        identifier: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: NumiChromeMetrics.toolbarSymbolSize, weight: .semibold))
                .foregroundStyle(NumiColor.textSecondary)
                .frame(
                    width: 30,
                    height: NumiChromeMetrics.toolbarButtonHitSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.32)
        .accessibilityIdentifier(identifier)
    }

    private var homePeriodPickerSheet: some View {
        NumiBottomSheet(
            title: "时间范围",
            accessibilityPrefix: "sheet.homePeriodPicker",
            dismissTitle: "关闭",
            onDismiss: {
                showsPeriodPicker = false
            }
        ) {
            VStack(spacing: NumiSpacing.s2) {
                ForEach(HomePeriod.allCases) { period in
                    Button {
                        onSelectPeriod(period)
                        showsPeriodPicker = false
                    } label: {
                        HStack(spacing: NumiSpacing.s3) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(periodTitle(for: period))
                                    .font(NumiFont.bodyStrong)
                                    .foregroundStyle(NumiColor.textPrimary)
                                Text(periodDescription(for: period))
                                    .font(NumiFont.footnote)
                                    .foregroundStyle(NumiColor.textTertiary)
                            }
                            Spacer()
                            if period == selectedPeriod {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(NumiColor.accentDeep)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                        .padding(.horizontal, NumiSpacing.s4)
                        .background(
                            RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous)
                                .fill(period == selectedPeriod ? NumiColor.surfaceCardSubtle : NumiColor.surfaceCard)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.period.option.\(periodOptionIdentifier(period))")
                }
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.bottom, NumiSpacing.s4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sheet.homePeriodPicker")
        .accessibilityIdentifier("sheet.homePeriodPicker.content")
    }

    private func periodTitle(for period: HomePeriod) -> String {
        switch period {
        case .week:
            return "按周查看"
        case .month:
            return "按月查看"
        case .quarter:
            return "按季度查看"
        case .year:
            return "按年查看"
        }
    }

    private func periodDescription(for period: HomePeriod) -> String {
        switch period {
        case .week:
            return "适合查看近一周的支出与节奏"
        case .month:
            return "适合日常复盘和月度对比"
        case .quarter:
            return "适合阶段性趋势观察"
        case .year:
            return "适合年度汇总和长期变化"
        }
    }

    private func periodOptionIdentifier(_ period: HomePeriod) -> String {
        switch period {
        case .week:
            return "week"
        case .month:
            return "month"
        case .quarter:
            return "quarter"
        case .year:
            return "year"
        }
    }
}

private struct HomeToolbarChrome<Principal: View, Trailing: View>: ViewModifier {
    let periodToolbarControl: Principal
    let searchToolbarButton: Trailing

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    periodToolbarControl
                }
                ToolbarItem(placement: .topBarTrailing) {
                    searchToolbarButton
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        #else
        content
        #endif
    }
}

// MARK: - PressableRow

private struct PressableRow<Content: View>: View {
    let onSelect: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
    }
}
