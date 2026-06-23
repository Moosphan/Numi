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
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("scroll.categoryManagement")
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
    @State private var selectedCategory = "全部"

    /// 英文分类 key → 中文显示名
    private static let categoryDisplayName: [String: String] = [
        "全部": "全部",
        "food-drink": "美食饮品",
        "animals": "动物",
        "vehicles-transport": "交通出行",
        "entertainment-leisure": "娱乐休闲",
        "everyday-life": "日常生活",
        "fashion-style": "时尚穿搭",
        "health-wellness": "健康医疗",
        "technology-media": "科技数码",
        "sports": "运动健身",
        "hobbies": "兴趣爱好",
        "nature-outdoors": "自然户外",
        "places-structures": "建筑地标",
        "professions": "职业",
        "work-industry": "办公文教",
        "space-science": "天文科学",
        "fantasy-imagination": "奇幻想象",
        "countries": "国家地区",
        "flags": "旗帜",
        "interface-symbols": "界面符号",
        "historical-figures": "历史人物",
        "history-culture": "历史文化",
        "events": "活动事件",
        "其他": "其他"
    ]

    private static let iconCategories: [String: [String]] = {
        var mapping: [String: [String]] = ["全部": []]

        // SPM .copy() 将文件直接放到 bundle 根目录
        if let url = Bundle.module.url(forResource: "manifest", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] {
            for (category, icons) in json {
                mapping[category] = icons.sorted()
                mapping["全部", default: []].append(contentsOf: icons)
            }
        }

        // 补充未在 manifest 中的图标
        if let iconsURL = Bundle.module.url(forResource: "Icons", withExtension: nil),
           let files = try? FileManager.default.contentsOfDirectory(atPath: iconsURL.path) {
            let allInManifest = Set(mapping["全部"] ?? [])
            for file in files where file.hasSuffix(".png") {
                let slug = String(file.dropLast(4))
                if !allInManifest.contains(slug) {
                    mapping["其他", default: []].append(slug)
                    mapping["全部", default: []].append(slug)
                }
            }
        }

        mapping["全部"] = (mapping["全部"] ?? []).sorted()
        mapping["其他"] = (mapping["其他"] ?? []).sorted()
        return mapping
    }()

    private var categoryNames: [String] {
        Self.iconCategories.keys.sorted { a, b in
            if a == "全部" { return true }
            if b == "全部" { return false }
            if a == "其他" { return false }
            if b == "其他" { return true }
            return a < b
        }
    }

    private func displayName(for key: String) -> String {
        Self.categoryDisplayName[key] ?? key
    }

    private var filteredIcons: [String] {
        Self.iconCategories[selectedCategory] ?? []
    }

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

                    // 分类 Tab - 大圆角胶囊 segment
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(categoryNames, id: \.self) { cat in
                                let isSelected = selectedCategory == cat
                                Button {
                                    selectedCategory = cat
                                } label: {
                                    Text(displayName(for: cat))
                                        .font(NumiFont.body)
                                        .foregroundStyle(isSelected ? .white : NumiColor.textSecondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Group {
                                                if isSelected {
                                                    Capsule().fill(NumiColor.accentDeep)
                                                }
                                            }
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .background(NumiColor.surfaceCard)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                    }

                    // 图标网格
                    let icons = filteredIcons
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: NumiSpacing.s4) {
                        ForEach(icons, id: \.self) { icon in
                            IconCell(iconName: icon, isSelected: selectedIcon == icon) {
                                selectedIcon = icon
                            }
                        }
                    }
                    .padding(NumiSpacing.s3)
                    .animation(nil, value: selectedCategory)
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

// MARK: - Icon Cell

private struct IconCell: View {
    let iconName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CategoryIconView(iconName: iconName, size: 64)
                .background(isSelected ? NumiColor.iconBackground : NumiColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous)
                            .strokeBorder(NumiColor.accentDeep, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
