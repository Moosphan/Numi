import SwiftUI

/// 分类图标预览视图
struct CategoryIconPreviewView: View {
    var body: some View {
        NavigationView {
            List {
                Section("支出分类 (\(CategoryIcon.expenseIcons.count)个)") {
                    ForEach(CategoryIcon.expenseIcons, id: \.self) { icon in
                        CategoryIconRow(icon: icon)
                    }
                }

                Section("收入分类 (\(CategoryIcon.incomeIcons.count)个)") {
                    ForEach(CategoryIcon.incomeIcons, id: \.self) { icon in
                        CategoryIconRow(icon: icon)
                    }
                }
            }
            .navigationTitle("Numi 分类图标")
        }
    }
}

/// 单个图标行
struct CategoryIconRow: View {
    let icon: CategoryIcon

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(icon.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(icon.displayName)
                    .font(.headline)

                Text(icon.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 分类标签
            Text(icon.category == .expense ? "支出" : "收入")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(icon.category == .expense ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                .foregroundColor(icon.category == .expense ? .red : .green)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

/// 图标网格视图
struct CategoryIconGridView: View {
    let icons: [CategoryIcon]
    let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(icons, id: \.self) { icon in
                VStack(spacing: 8) {
                    Image(icon.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                    Text(icon.displayName)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
        .padding()
    }
}

/// 图标详情视图
struct CategoryIconDetailView: View {
    let icon: CategoryIcon

    var body: some View {
        VStack(spacing: 20) {
            // 大图标
            Image(icon.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

            // 信息
            VStack(spacing: 8) {
                Text(icon.displayName)
                    .font(.title)
                    .fontWeight(.bold)

                Text(icon.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("文件名: \(icon.iconName).png")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 分类标签
            HStack {
                Label(icon.category == .expense ? "支出分类" : "收入分类",
                      systemImage: icon.category == .expense ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundColor(icon.category == .expense ? .red : .green)
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(icon.category == .expense ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
            .clipShape(Capsule())

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

#Preview("图标列表") {
    CategoryIconPreviewView()
}

#Preview("图标网格") {
    ScrollView {
        CategoryIconGridView(icons: Array(CategoryIcon.expenseIcons.prefix(12)))
    }
}

#Preview("图标详情") {
    CategoryIconDetailView(icon: .acaiBowl)
}
