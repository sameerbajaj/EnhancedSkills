import SwiftUI

struct ImprovementPreviewSheet: View {
    let plan: SkillImprovementPlan
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Improvement Preview")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DS.Color.text)
                    Text(plan.skill.folderName)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                Spacer()
                Button { state.cancelImprovements() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(DS.Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(DS.Spacing.lg)

            Divider()

            // File changes
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    ForEach(plan.fileChanges) { change in
                        FileDiffView(
                            change: change,
                            originalContent: plan.originalContents[change.relativePath]
                        )
                    }
                }
                .padding(DS.Spacing.lg)
            }

            Divider()

            // Footer
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.textTertiary)
                Text("A backup will be created before applying changes.")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Color.textTertiary)

                Spacer()

                Button("Cancel") {
                    state.cancelImprovements()
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Color.textSecondary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)

                Button {
                    Task { await state.applyImprovements() }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        if state.improvementState == .applying {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                        }
                        Text(state.improvementState == .applying ? "Applying…" : "Apply Changes")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
                .disabled(state.improvementState == .applying)
            }
            .padding(DS.Spacing.lg)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(DS.Color.surface)
    }
}

// MARK: - File Diff View

struct FileDiffView: View {
    let change: SkillFileChange
    let originalContent: String?

    private var diffLines: [DiffLine] {
        if change.isNew || originalContent == nil {
            return change.content.components(separatedBy: "\n").map {
                DiffLine(type: .added, text: $0)
            }
        }
        return computeDiff(
            old: originalContent!.components(separatedBy: "\n"),
            new: change.content.components(separatedBy: "\n")
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: change.isNew ? "doc.badge.plus" : "doc.text")
                    .font(.system(size: 12))
                    .foregroundStyle(change.isNew ? DS.Color.synced : DS.Color.accent)
                Text(change.relativePath)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DS.Color.text)
                if change.isNew {
                    Text("NEW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DS.Color.synced)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(DS.Color.syncedBg)
                        .clipShape(Capsule())
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(diffLines.enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 0) {
                            Text(line.prefix)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(line.prefixColor)
                                .frame(width: 14, alignment: .center)

                            Text(line.text)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(line.textColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 1)
                        .background(line.bgColor)
                    }
                }
            }
            .background(DS.Color.canvas)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Color.borderLight, lineWidth: 1))
        }
    }
}

// MARK: - Diff Computation

enum DiffLineType {
    case unchanged
    case added
    case removed
}

struct DiffLine {
    let type: DiffLineType
    let text: String

    var prefix: String {
        switch type {
        case .unchanged: return " "
        case .added: return "+"
        case .removed: return "-"
        }
    }

    var prefixColor: Color {
        switch type {
        case .unchanged: return DS.Color.textTertiary
        case .added: return DS.Color.synced
        case .removed: return DS.Color.invalid
        }
    }

    var textColor: Color {
        switch type {
        case .unchanged: return DS.Color.textSecondary
        case .added: return DS.Color.synced
        case .removed: return DS.Color.invalid
        }
    }

    var bgColor: Color {
        switch type {
        case .unchanged: return .clear
        case .added: return DS.Color.synced.opacity(0.08)
        case .removed: return DS.Color.invalid.opacity(0.08)
        }
    }
}

/// Simple line-by-line diff using CollectionDifference.
func computeDiff(old: [String], new: [String]) -> [DiffLine] {
    let diff = new.difference(from: old)
    var result: [DiffLine] = []

    // Build a set of removed and inserted indices
    var removedIndices: [(offset: Int, element: String)] = []
    var insertedIndices: [(offset: Int, element: String)] = []

    for change in diff {
        switch change {
        case .remove(let offset, let element, _):
            removedIndices.append((offset, element))
        case .insert(let offset, let element, _):
            insertedIndices.append((offset, element))
        }
    }

    let removedSet = Set(removedIndices.map(\.offset))

    // Walk through old lines, emitting removed and unchanged
    var insertIdx = 0
    for (oldIdx, line) in old.enumerated() {
        // Emit any inserts that go before this position
        while insertIdx < insertedIndices.count {
            let ins = insertedIndices[insertIdx]
            // Apply inserts for positions at or before current output position
            if ins.offset <= result.count {
                result.append(DiffLine(type: .added, text: ins.element))
                insertIdx += 1
            } else {
                break
            }
        }

        if removedSet.contains(oldIdx) {
            result.append(DiffLine(type: .removed, text: line))
        } else {
            result.append(DiffLine(type: .unchanged, text: line))
        }
    }

    // Emit remaining inserts
    while insertIdx < insertedIndices.count {
        result.append(DiffLine(type: .added, text: insertedIndices[insertIdx].element))
        insertIdx += 1
    }

    return result
}
