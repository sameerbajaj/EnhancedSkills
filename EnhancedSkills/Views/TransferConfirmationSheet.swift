import SwiftUI

struct TransferConfirmationSheet: View {
    let plan: SkillTransferPlan
    @Bindable var state: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            // Header
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Confirm Transfer")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(DS.Color.text)
                Text("Review the details before copying this skill.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            // Details
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                DetailRow(label: "From", value: plan.sourceProvider.displayName)
                DetailRow(label: "To", value: plan.destinationProvider.displayName)
                DetailRow(label: "Source", value: plan.sourcePath.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                DetailRow(label: "Destination", value: plan.destinationPath.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                DetailRow(label: "Files", value: "\(plan.sourceFileCount) item\(plan.sourceFileCount == 1 ? "" : "s")")
            }
            .padding(DS.Spacing.lg)
            .background(DS.Color.canvas)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.borderLight, lineWidth: 1))

            // Warning
            if plan.willReplace {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DS.Color.codexOnly)
                    Text("This will replace the existing skill at the destination.")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Color.codexOnly)
                }
                .padding(DS.Spacing.lg)
                .background(DS.Color.codexOnlyBg)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }

            if let err = state.transferError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.invalid)
            }

            // Actions
            HStack {
                Button("Cancel") {
                    state.showTransferSheet = false
                    state.transferPlan = nil
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DS.Color.textSecondary)
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.md)
                .background(DS.Color.borderLight)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

                Spacer()

                Button {
                    Task { await state.confirmTransfer() }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        if state.isTransferring {
                            ProgressView().controlSize(.small)
                        }
                        Text(state.isTransferring ? "Copying…" : plan.willReplace ? "Replace & Copy" : "Copy")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.md)
                    .background(plan.willReplace ? DS.Color.codexOnly : DS.Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
                .disabled(state.isTransferring)
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 480)
        .background(DS.Color.surface)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.Color.textTertiary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: label == "Source" || label == "Destination" ? .monospaced : .default))
                .foregroundStyle(DS.Color.text)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }
}
