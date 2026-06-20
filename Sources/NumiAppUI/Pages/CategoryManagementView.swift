import SwiftUI
import NumiCore

public struct CategoryManagementView: View {
    @State private var selectedKind: CategoryKind = .expense
    @State private var localCategories: [NumiCore.Category]
    @State private var showAddSheet = false

    private let categories: [NumiCore.Category]
    private let onVisibilityChange: (NumiCore.Category, Bool) -> Void
    private let onCategoryCreate: ((CategoryKind, String, String) -> Void)?
    private let onCategoryDelete: ((NumiCore.Category) -> Void)?

    public init(
        categories: [NumiCore.Category],
        onVisibilityChange: @escaping (NumiCore.Category, Bool) -> Void,
        onCategoryCreate: ((CategoryKind, String, String) -> Void)? = nil,
        onCategoryDelete: ((NumiCore.Category) -> Void)? = nil
    ) {
        self.categories = categories
        self._localCategories = State(initialValue: categories)
        self.onVisibilityChange = onVisibilityChange
        self.onCategoryCreate = onCategoryCreate
        self.onCategoryDelete = onCategoryDelete
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
                                Divider().padding(.leading, 48 + NumiSpacing.s3)
                            }
                        }
                    }
                    .background(NumiColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NumiColor.accentDeep)
                }
                .accessibilityIdentifier("button.addCategory")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                AddCategorySheet(
                    kind: selectedKind,
                    onDismiss: { showAddSheet = false },
                    onCreate: { name, icon in
                        onCategoryCreate?(selectedKind, name, icon)
                        showAddSheet = false
                    }
                )
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
        }
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
        HStack(spacing: NumiSpacing.s3) {
            CategoryIconView(category: category, size: 48)
                .foregroundStyle(NumiColor.textPrimary)
                .background(NumiColor.surfaceCardSubtle)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))

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
            .tint(NumiColor.accentPrimary)
        }
        .padding(.horizontal, NumiSpacing.s4)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NumiColor.surfaceCard)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                let nextHidden = !isCategoryHidden(category.id)
                setCategoryHidden(category, isHidden: nextHidden)
                onVisibilityChange(category, nextHidden)
            } label: {
                Label(isCategoryHidden(category.id) ? "显示" : "隐藏",
                      systemImage: isCategoryHidden(category.id) ? "eye" : "eye.slash")
            }

            if onCategoryDelete != nil {
                Button(role: .destructive) {
                    onCategoryDelete?(category)
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
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

// MARK: - Add Category Sheet

private struct AddCategorySheet: View {
    let kind: CategoryKind
    let onDismiss: () -> Void
    let onCreate: (String, String) -> Void

    @State private var name = ""
    @State private var selectedIcon = "money"

    private let allIcons: [String] = [
        "ab-bench", "acai-bowl", "accountant", "airplane", "apartment-building",
        "armchair", "articulated-bus", "atm-cash-machine", "award-ceremony", "baby",
        "bag-of-groceries", "barber", "bingo-ball", "black-car", "book", "briefcase",
        "button-down-shirt", "calligraphy-practice-book", "cash", "cash-register", "cat",
        "cell-phone-cleaning-kit", "charity-ball", "checkbook", "cinema-clapperboard",
        "coin-jar", "coin-purse", "coins", "computer-technician", "desk",
        "desktop-computer", "digital-alarm-clock", "digital-billboard", "digital-certificate",
        "farmhouse", "flea-market", "game-controller", "gift-box", "golden-heart",
        "health-insurance-card", "insurance", "lipstick", "medicine-capsule", "money",
        "stock-trading-candlestick", "trophy", "unboxing-gift"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                // 分类名称
                VStack(alignment: .leading, spacing: NumiSpacing.s2) {
                    Text("分类名称")
                        .font(NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.textSecondary)

                    VStack(spacing: 0) {
                        HStack(spacing: NumiSpacing.s3) {
                            Text("名称")
                                .font(NumiFont.body)
                                .foregroundStyle(NumiColor.textPrimary)
                            Spacer()
                            TextField("例如：餐饮、交通", text: $name)
                                .font(NumiFont.body)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(.horizontal, NumiSpacing.s4)
                        .frame(minHeight: 48)
                    }
                    .background(NumiColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                }

                // 图标选择
                VStack(alignment: .leading, spacing: NumiSpacing.s2) {
                    Text("选择图标")
                        .font(NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.textSecondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: NumiSpacing.s3) {
                        ForEach(allIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                CategoryIconView(iconName: icon, size: 44)
                                    .background(selectedIcon == icon ? NumiColor.accentPrimary.opacity(0.15) : NumiColor.surfaceCard)
                                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous))
                                    .overlay {
                                        if selectedIcon == icon {
                                            RoundedRectangle(cornerRadius: NumiRadius.md, style: .continuous)
                                                .strokeBorder(NumiColor.accentDeep, lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(NumiSpacing.s3)
                    .background(NumiColor.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: NumiRadius.xl, style: .continuous))
                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                }
            }
            .padding(.horizontal, NumiSpacing.s5)
            .padding(.top, NumiSpacing.s4)
            .padding(.bottom, 120)
        }
        .background(NumiColor.surfacePage)
        .navigationTitle("添加分类")
        .modifier(LargeTitleNavigationChrome())
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { onDismiss() }
                    .foregroundStyle(NumiColor.toolbarIcon)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("添加") { onCreate(name, selectedIcon) }
                    .disabled(name.isEmpty)
                    .foregroundStyle(name.isEmpty ? NumiColor.textTertiary : NumiColor.accentDeep)
            }
        }
    }
}
