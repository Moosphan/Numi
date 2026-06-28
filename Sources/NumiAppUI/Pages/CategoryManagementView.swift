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
                Picker("category.type", selection: $selectedKind) {
                    Text("record.expense")
                        .tag(CategoryKind.expense)
                        .accessibilityIdentifier("categoryKind.expense")
                    Text("record.income")
                        .tag(CategoryKind.income)
                        .accessibilityIdentifier("categoryKind.income")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("picker.categoryKind")

                VStack(alignment: .leading, spacing: NumiSpacing.s3) {
                    Text(selectedKind == .expense ? NumiLocalized.string( "category.expense") : NumiLocalized.string( "category.income"))
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

                    Text(NumiLocalized.string( "category.hide.desc"))
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
        .navigationTitle("category.title")
        .modifier(LargeTitleNavigationChrome())
        .tint(NumiColor.accentDeep)
        .toolbar {
            ToolbarItem(placement: .trailingBar) {
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
            .sortedForLocalizedDisplay()
    }

    private func categoryRow(_ category: NumiCore.Category) -> some View {
        HStack(spacing: NumiSpacing.s3) {
            CategoryIconView(category: category, size: 48)
                .foregroundStyle(NumiColor.textPrimary)
                .background(NumiColor.surfaceCardSubtle)
                .clipShape(RoundedRectangle(cornerRadius: NumiRadius.lg, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(category.localizedDisplayName)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(NumiColor.textPrimary)
                Text(isCategoryHidden(category.id) ? NumiLocalized.string( "category.hidden") : NumiLocalized.string( "category.show.in.record"))
                    .font(NumiFont.footnote)
                    .foregroundStyle(NumiColor.textTertiary)
            }

            Spacer()

            Toggle(
                NumiLocalized.string( "category.show"),
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
                Label(isCategoryHidden(category.id) ? NumiLocalized.string( "category.show") : NumiLocalized.string( "category.hide"),
                      systemImage: isCategoryHidden(category.id) ? "eye" : "eye.slash")
            }

            if onCategoryDelete != nil {
                Button(role: .destructive) {
                    onCategoryDelete?(category)
                } label: {
                    Label("common.delete", systemImage: "trash")
                }
            }
        }
        .accessibilityIdentifier("toggle.category.\(category.id.uuidString)")
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
    @State private var selectedCategory = Self.allCategoryKey

    private static let allCategoryKey = "__all__"
    private static let fallbackCategoryKey = "__other__"

    /// 英文分类 key → 本地化显示名
    private var categoryDisplayName: [String: String] {
        [
            Self.allCategoryKey: NumiLocalized.string( "icon.category.all"),
            "food-drink": NumiLocalized.string( "icon.category.food-drink"),
            "animals": NumiLocalized.string( "icon.category.animals"),
            "vehicles-transport": NumiLocalized.string( "icon.category.vehicles-transport"),
            "entertainment-leisure": NumiLocalized.string( "icon.category.entertainment-leisure"),
            "everyday-life": NumiLocalized.string( "icon.category.everyday-life"),
            "fashion-style": NumiLocalized.string( "icon.category.fashion-style"),
            "health-wellness": NumiLocalized.string( "icon.category.health-wellness"),
            "technology-media": NumiLocalized.string( "icon.category.technology-media"),
            "sports": NumiLocalized.string( "icon.category.sports"),
            "hobbies": NumiLocalized.string( "icon.category.hobbies"),
            "nature-outdoors": NumiLocalized.string( "icon.category.nature-outdoors"),
            "places-structures": NumiLocalized.string( "icon.category.places-structures"),
            "professions": NumiLocalized.string( "icon.category.professions"),
            "work-industry": NumiLocalized.string( "icon.category.work-industry"),
            "space-science": NumiLocalized.string( "icon.category.space-science"),
            "fantasy-imagination": NumiLocalized.string( "icon.category.fantasy-imagination"),
            "countries": NumiLocalized.string( "icon.category.countries"),
            "flags": NumiLocalized.string( "icon.category.flags"),
            "interface-symbols": NumiLocalized.string( "icon.category.interface-symbols"),
            "historical-figures": NumiLocalized.string( "icon.category.historical-figures"),
            "history-culture": NumiLocalized.string( "icon.category.history-culture"),
            "events": NumiLocalized.string( "icon.category.events"),
            Self.fallbackCategoryKey: NumiLocalized.string( "other.fallback")
        ]
    }

    private static let iconCategories: [String: [String]] = {
        var mapping: [String: [String]] = [Self.allCategoryKey: []]

        // SPM .copy() 将文件直接放到 bundle 根目录
        if let url = Bundle.module.url(forResource: "manifest", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] {
            for (category, icons) in json {
                mapping[category] = icons.sorted()
                mapping[Self.allCategoryKey, default: []].append(contentsOf: icons)
            }
        }

        // 补充未在 manifest 中的图标
        if let iconsURL = Bundle.module.url(forResource: "Icons", withExtension: nil),
           let files = try? FileManager.default.contentsOfDirectory(atPath: iconsURL.path) {
            let allInManifest = Set(mapping[Self.allCategoryKey] ?? [])
            for file in files where file.hasSuffix(".png") {
                let slug = String(file.dropLast(4))
                if !allInManifest.contains(slug) {
                    mapping[Self.fallbackCategoryKey, default: []].append(slug)
                    mapping[Self.allCategoryKey, default: []].append(slug)
                }
            }
        }

        mapping[Self.allCategoryKey] = (mapping[Self.allCategoryKey] ?? []).sorted()
        mapping[Self.fallbackCategoryKey] = (mapping[Self.fallbackCategoryKey] ?? []).sorted()
        return mapping
    }()

    private var categoryNames: [String] {
        Self.iconCategories.keys.sorted { a, b in
            if a == Self.allCategoryKey { return true }
            if b == Self.allCategoryKey { return false }
            if a == Self.fallbackCategoryKey { return false }
            if b == Self.fallbackCategoryKey { return true }
            let left = displayName(for: a)
            let right = displayName(for: b)
            let comparison = left.compare(
                right,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                range: nil,
                locale: NumiLocalized.currentLocale
            )
            if comparison != .orderedSame {
                return comparison == .orderedAscending
            }
            return a < b
        }
    }

    private func displayName(for key: String) -> String {
        categoryDisplayName[key] ?? key
    }

    private var filteredIcons: [String] {
        Self.iconCategories[selectedCategory] ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NumiSpacing.s5) {
                // 分类名称
                VStack(alignment: .leading, spacing: NumiSpacing.s2) {
                    Text("category.name.label")
                        .font(NumiFont.bodySmall)
                        .foregroundStyle(NumiColor.textSecondary)

                    VStack(spacing: 0) {
                        HStack(spacing: NumiSpacing.s3) {
                            Text("category.name.label")
                                .font(NumiFont.body)
                                .foregroundStyle(NumiColor.textPrimary)
                            Spacer()
                            TextField("category.name.placeholder", text: $name)
                                .font(NumiFont.body)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
#if os(iOS)
                                .textInputAutocapitalization(.never)
#endif
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
                    Text("category.select.icon")
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
        .navigationTitle("category.add")
        .modifier(LargeTitleNavigationChrome())
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel") { onDismiss() }
                    .foregroundStyle(NumiColor.toolbarIcon)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("common.add") { onCreate(name, selectedIcon) }
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
