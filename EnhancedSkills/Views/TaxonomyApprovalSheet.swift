import SwiftUI

struct TaxonomyApprovalSheet: View {
    let proposed: [ProposedCategory]
    let onApprove: ([SkillCategory]) -> Void
    let onCancel: () -> Void

    @State private var selections: [String: Bool] = [:]
    @State private var names: [String: String] = [:]
    @State private var shortLabels: [String: String] = [:]

    init(proposed: [ProposedCategory], onApprove: @escaping ([SkillCategory]) -> Void, onCancel: @escaping () -> Void) {
        self.proposed = proposed
        self.onApprove = onApprove
        self.onCancel = onCancel
        
        var initialSelections: [String: Bool] = [:]
        var initialNames: [String: String] = [:]
        var initialShortLabels: [String: String] = [:]
        for cat in proposed {
            initialSelections[cat.name] = true
            initialNames[cat.name] = cat.name
            initialShortLabels[cat.name] = cat.shortLabel
        }
        _selections = State(initialValue: initialSelections)
        _names = State(initialValue: initialNames)
        _shortLabels = State(initialValue: initialShortLabels)
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
                Text("Toggle categories on/off or edit their names and short labels.")
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

                        TextField("Name", text: Binding(
                            get: { names[cat.name] ?? cat.name },
                            set: { names[cat.name] = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Color.text)

                        TextField("Label", text: Binding(
                            get: { shortLabels[cat.name] ?? cat.shortLabel },
                            set: { shortLabels[cat.name] = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Color.textSecondary)
                        .frame(maxWidth: 100)

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
                    let approved: [SkillCategory] = proposed.compactMap { cat in
                        guard selections[cat.name] == true else { return nil }
                        let finalName = names[cat.name]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? cat.name
                        guard !finalName.isEmpty else { return nil }
                        let finalLabel = shortLabels[cat.name]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let label = finalLabel.isEmpty ? nil : finalLabel
                        return SkillCategory(name: finalName, shortLabel: label)
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
        .frame(width: 540, height: 460)
    }
}
