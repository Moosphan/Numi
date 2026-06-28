import SwiftUI
import NumiCore

/// Thiings图标使用示例
struct ThiingsIconUsageExample: View {
    var body: some View {
        NavigationView {
            List {
                // MARK: - 基础使用
                Section(NumiLocalized.string("preview.icon.section.basic")) {
                    HStack {
                        Image("acai-bowl")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)

                        Text(CategoryIcon.acaiBowl.displayName)
                    }

                    HStack {
                        Image("cash")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)

                        Text(CategoryIcon.cash.displayName)
                    }
                }

                // MARK: - 带样式
                Section(NumiLocalized.string("preview.icon.section.styled")) {
                    HStack {
                        Image("airplane")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )

                        VStack(alignment: .leading) {
                            Text(CategoryIcon.airplane.displayName)
                                .font(.headline)
                            Text(CategoryIcon.airplane.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // MARK: - 图标网格
                Section(NumiLocalized.string("preview.icon.section.grid")) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(CategoryIcon.expenseIcons.prefix(8), id: \.self) { icon in
                            VStack {
                                Image(icon.iconName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                Text(icon.displayName)
                                    .font(.caption2)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // MARK: - 使用CategoryIcon枚举
                Section(NumiLocalized.string("preview.icon.section.enum")) {
                    ForEach(CategoryIcon.allCases.prefix(6), id: \.self) { icon in
                        HStack(spacing: 12) {
                            Image(icon.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                                .background(
                                    Circle()
                                        .fill(icon.category == .expense ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(icon.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text(icon.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(NumiLocalized.string(icon.category == .expense ? "preview.icon.badge.expense" : "preview.icon.badge.income"))
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(icon.category == .expense ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                                .foregroundColor(icon.category == .expense ? .red : .green)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .navigationTitle("preview.icon.example.title")
        }
    }
}

// MARK: - 图标选择器视图

/// 图标选择器
struct IconPickerView: View {
    @Binding var selectedIcon: CategoryIcon
    let category: CategoryIcon.IconCategory

    var body: some View {
        NavigationView {
            List {
                ForEach(iconsForCategory, id: \.self) { icon in
                    Button(action: {
                        selectedIcon = icon
                    }) {
                        HStack(spacing: 12) {
                            Image(icon.iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(icon.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text(icon.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if selectedIcon == icon {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle(
                NumiLocalized.string(
                    "preview.icon.select.category",
                    NumiLocalized.string(category == .expense ? "category.expense" : "category.income")
                )
            )
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private var iconsForCategory: [CategoryIcon] {
        switch category {
        case .expense:
            return CategoryIcon.expenseIcons
        case .income:
            return CategoryIcon.incomeIcons
        }
    }
}

// MARK: - 图标详情视图

/// 图标详情
struct IconDetailView: View {
    let icon: CategoryIcon

    var body: some View {
        VStack(spacing: 24) {
            // 大图标
            Image(icon.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

            // 信息
            VStack(spacing: 12) {
                Text(icon.displayName)
                    .font(.title)
                    .fontWeight(.bold)

                Text(icon.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text(NumiLocalized.string("preview.icon.fileName", icon.iconName))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 分类标签
            HStack {
                Label(
                    NumiLocalized.string(icon.category == .expense ? "category.expense" : "category.income"),
                    systemImage: icon.category == .expense ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
                )
                .foregroundColor(icon.category == .expense ? .red : .green)
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(icon.category == .expense ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
            .clipShape(Capsule())

            // 代码示例
            VStack(alignment: .leading, spacing: 8) {
                Text(NumiLocalized.string("preview.icon.codeExample"))
                    .font(.headline)

                Text("Image(\"\(icon.iconName)\")")
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .navigationTitle(icon.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - 预览

#Preview("使用示例") {
    ThiingsIconUsageExample()
}

#Preview("图标选择器") {
    IconPickerView(selectedIcon: .constant(.acaiBowl), category: .expense)
}

#Preview("图标详情") {
    IconDetailView(icon: .acaiBowl)
}
