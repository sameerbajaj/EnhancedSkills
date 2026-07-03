import SwiftUI

struct TaxonomyApprovalSheet: View {
    let proposed: [ProposedCategory]
    let onApprove: ([String]) -> Void
    let onCancel: () -> Void

    @State private var selections: [String: Bool] = [:]
    @State private var names: [String: String] = [:]

    init(proposed: [ProposedCategory], onApprove: @escaping ([String]) -> Void, onCancel: @escaping () -> Void) {
        self.proposed = proposed
        self.onApprove = onApprove
        self.onCancel = onCancel
        
        var initialSelections: [String: Bool] = [:]
        var initialNames: [String: String] = [:]
        for cat in proposed {
            initialSelections[cat.name] = true
            initialNames[cat.name] = cat.name
        }
        _selections = State(initialValue: initialSelections)
        _names = State(initialValue: initialNames)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Approve Proposed Categories")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DS.Color.text)
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)

            Divider()

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("AI analyzed your skills and suggests these categories:")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Color.textSecondary)
                Text("Toggle categories on/off or click their names to rename them.")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)

            List {
                ForEach(proposed) { cat in
                    HStack(spacing: DS.Spacing.md) {
                        Toggle("", isOn: Binding(
                            get: { selections[cat.name] ?? false },
                            set: { selections[cat.name] = $0 }
                        ))
                        .labelsHidden()

                        TextField("", text: Binding(
                            get: { names[cat.name] ?? cat.name },
                            set: { names[cat.name] = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Color.text)

                        Spacer()

                        Text("\(cat.count) skills")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.textTertiary)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, 2)
                            .background(DS.Color.borderLight)
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                
                Button("Approve & Classify") {
                    let approved = proposed.compactMap { cat -> String? in
                        guard selections[cat.name] == true else { return nil }
                        let finalName = names[cat.name]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? cat.name
                        return finalName.isEmpty ? nil : finalName
                    }
                    onApprove(approved)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.accent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.lg)
            .background(DS.Color.surface)
        }
        .frame(width: 480, height: 420)
    }
}
