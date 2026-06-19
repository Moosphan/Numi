import SwiftUI
import NumiCore

public struct CategoryManagementView: View {
    @State private var selectedKind: CategoryKind = .expense
    @State private var localCategories: [NumiCore.Category]

    private let categories: [NumiCore.Category]
    private let onVisibilityChange: (NumiCore.Category, Bool) -> Void

    public init(
        categories: [NumiCore.Category],
        onVisibilityChange: @escaping (NumiCore.Category, Bool) -> Void
    ) {
        self.categories = categories
        self._localCategories = State(initialValue: categories)
        self.onVisibilityChange = onVisibilityChange
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                Picker("分类类型", selection: $selectedKind) {
                    Text("支出").tag(CategoryKind.expense)
                    Text("收入").tag(CategoryKind.income)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("picker.categoryKind")

                VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                    Text(selectedKind == .expense ? "支出分类" : "收入分类")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(NumiColor.textSecondary)

                    VStack(spacing: 0) {
                        ForEach(visibleRows) { category in
                            categoryRow(category)
                            if category.id != visibleRows.last?.id {
                                Divider().padding(.leading, 36 + NumiSpacing.s3)
                            }
                        }
                    }
                    .background(NumiColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(NumiColor.separator, lineWidth: 1)
                    }

                    Text("关闭后，该分类不会出现在新增和编辑账单的分类网格中，历史账单仍会保留原分类。")
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)
                        .padding(.horizontal, NumiSpacing.s1)
                }
            }
            .padding(.horizontal, NumiSpacing.s5)
            .padding(.top, NumiSpacing.s4)
            .padding(.bottom, 120)
        }
        .background(NumiColor.surfacePage)
        .navigationTitle("分类管理")
        .modifier(LargeTitleNavigationChrome())
        .tint(NumiColor.accentDeep)
        .onChange(of: categories) { _, newValue in
            localCategories = newValue
        }
    }

    private var visibleRows: [NumiCore.Category] {
        localCategories
            .filter { $0.kind == selectedKind }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    lhs.name < rhs.name
                } else {
                    lhs.sortOrder < rhs.sortOrder
                }
            }
    }

    private func categoryRow(_ category: NumiCore.Category) -> some View {
        Button {
            let nextHidden = !isCategoryHidden(category.id)
            setCategoryHidden(category, isHidden: nextHidden)
            onVisibilityChange(category, nextHidden)
        } label: {
            HStack(spacing: NumiSpacing.s3) {
                Image(systemName: category.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(NumiColor.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(NumiColor.surfaceCardSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(NumiColor.textPrimary)
                    Text(isCategoryHidden(category.id) ? "已隐藏" : "记账页显示")
                        .font(NumiFont.footnote)
                        .foregroundStyle(NumiColor.textTertiary)
                }

                Spacer()

                Toggle(
                    "显示分类",
                    isOn: Binding(
                        get: { !isCategoryHidden(category.id) },
                        set: { isVisible in
                            setCategoryHidden(category, isHidden: !isVisible)
                            onVisibilityChange(category, !isVisible)
                        }
                    )
                )
                .labelsHidden()
                .allowsHitTesting(false)
            }
            .padding(.horizontal, NumiSpacing.s4)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NumiColor.surfaceCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tint(NumiColor.accentPrimary)
        .accessibilityIdentifier("toggle.category.\(category.name)")
    }

    private func isCategoryHidden(_ categoryID: UUID) -> Bool {
        localCategories.first { $0.id == categoryID }?.isHidden ?? true
    }

    private func setCategoryHidden(_ category: NumiCore.Category, isHidden: Bool) {
        guard let index = localCategories.firstIndex(where: { $0.id == category.id }) else {
            return
        }
        localCategories[index].isHidden = isHidden
    }
}

#Preview {
    NavigationStack {
        CategoryManagementView(
            categories: NumiPreviewData.store().categories,
            onVisibilityChange: { _, _ in }
        )
    }
}
