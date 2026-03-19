import AppKit
import SwiftUI

struct SkillDetailView: View {
    @Bindable var state: AppState

    var body: some View {
        if let record = state.selectedRecord {
            DetailContent(record: record, state: state)
        } else {
            VStack {
                Image(systemName: "arrow.left")
                    .font(.system(size: 28, weight: .thin))
                    .foregroundStyle(DS.Color.textTertiary)
                Text("Select a skill")
                    .font(.system(size: 15))
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.Color.canvas)
        }
    }
}

struct DetailContent: View {
    let record: SkillRecord
    @Bindable var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {

                // Header
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack {
                        StatusPill(status: record.status)
                        Spacer()
                        if let skill = record.preferredPreviewSource {
                            Button {
                                state.revealInFinder(skill)
                            } label: {
                                Label("Reveal", systemImage: "folder")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DS.Color.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(record.displayName)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(DS.Color.text)

                    if let desc = record.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 14))
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Provider badges with folder reveal icons
                    HStack(spacing: DS.Spacing.md) {
                        ForEach(Provider.allCases) { provider in
                            if let skill = record.skills[provider] {
                                HStack(spacing: DS.Spacing.xs) {
                                    ProviderBadge(provider: provider)
                                    Button { state.revealInFinder(skill) } label: {
                                        Image(systemName: "folder")
                                            .font(.system(size: 11))
                                            .foregroundStyle(DS.Color.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Keep in Sync toggle
                    if record.skills.count >= 2 || record.syncEnabled {
                        Toggle("Keep in Sync", isOn: Binding(
                            get: { record.syncEnabled },
                            set: { _ in state.toggleSyncPreference(for: record) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }

                Divider()

                // Metadata chips
                let source = record.preferredPreviewSource
                if source?.hasScripts == true || source?.hasReferences == true || source?.isSystem == true || source?.parseStatus != .ok {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("METADATA")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.Color.textTertiary)
                        HStack(spacing: DS.Spacing.sm) {
                            if source?.isSystem == true {
                                MetaChip(label: "System", icon: "gear")
                            }
                            if source?.hasScripts == true {
                                MetaChip(label: "Scripts", icon: "terminal")
                            }
                            if source?.hasReferences == true {
                                MetaChip(label: "References", icon: "link")
                            }
                            if let ps = source?.parseStatus, ps != .ok {
                                MetaChip(label: ps.rawValue.capitalized, icon: "exclamationmark.triangle", color: DS.Color.invalid)
                            }
                        }
                    }
                    Divider()
                }

                // Guidelines
                GuidelinesSection(record: record, state: state)

                Divider()

                // AI Evaluation
                AIEvaluationSection(record: record, state: state)

                Divider()

                // Paths with folder reveal buttons
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("LOCATIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DS.Color.textTertiary)

                    ForEach(Provider.allCases) { provider in
                        if let skill = record.skills[provider] {
                            HStack {
                                PathLine(provider: provider, path: skill.skillPath.path)
                                Spacer()
                                Button { state.revealInFinder(skill) } label: {
                                    Image(systemName: "folder")
                                        .font(.system(size: 12))
                                        .foregroundStyle(DS.Color.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Preview
                if let excerpt = record.preferredPreviewSource?.previewExcerpt {
                    Divider()
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("PREVIEW")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.Color.textTertiary)
                        Text(excerpt)
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(DS.Spacing.lg)
                            .background(DS.Color.canvas)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.borderLight, lineWidth: 1))
                    }
                }

                Divider()

                // Transfer actions
                SyncActionsSection(record: record, state: state)
            }
            .padding(DS.Spacing.xxl)
        }
        .background(DS.Color.canvas)
        .frame(minWidth: 280)
        .onChange(of: record.id) { _, _ in
            state.resetEvaluationState()
        }
        .sheet(isPresented: $state.showTransferSheet) {
            if let plan = state.transferPlan {
                TransferConfirmationSheet(plan: plan, state: state)
            }
        }
    }
}

struct SyncActionsSection: View {
    let record: SkillRecord
    @Bindable var state: AppState

    private var missingProviders: [Provider] {
        state.settings.configuredProviders.filter { record.skills[$0] == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("SYNC ACTIONS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DS.Color.textTertiary)

            // Drift detected — needs sync
            if record.status == .needsSync {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(DS.Color.needsSync)
                        Text("Content has drifted across providers.")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    Button {
                        Task { await state.syncNow(record: record) }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14))
                            Text("Sync Now")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(DS.Color.needsSync)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Color.needsSyncBg)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.needsSync.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.isSyncing)
                }
                .padding(DS.Spacing.lg)
                .background(DS.Color.needsSyncBg)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }
            // All synced
            else if record.status == .synced && record.skills.count >= 2 {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Color.synced)
                    Text("Skill is synced across all providers.")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .padding(DS.Spacing.lg)
                .background(DS.Color.syncedBg)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }

            // Copy to missing providers (always shown if applicable)
            if !missingProviders.isEmpty {
                ForEach(missingProviders) { dest in
                    TransferButton(
                        label: "Copy to \(dest.displayName)",
                        icon: "arrow.right.circle.fill",
                        provider: dest
                    ) {
                        state.startTransfer(to: dest)
                    }
                }
            }

            if let err = state.syncError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.invalid)
                    .padding(DS.Spacing.md)
                    .background(DS.Color.invalidBg)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }

            if let err = state.transferError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.invalid)
                    .padding(DS.Spacing.md)
                    .background(DS.Color.invalidBg)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
    }
}

struct MetaChip: View {
    let label: String
    let icon: String
    var color: Color = DS.Color.textSecondary

    var body: some View {
        Label(label, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Color.borderLight)
            .clipShape(Capsule())
    }
}

struct PathLine: View {
    let provider: Provider
    let path: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ProviderBadge(provider: provider)
            Text(path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DS.Color.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

struct GuidelinesSection: View {
    let record: SkillRecord
    @Bindable var state: AppState

    private var reports: [(Provider, ValidationReport, DiscoveredSkill)] {
        var result: [(Provider, ValidationReport, DiscoveredSkill)] = []
        for provider in Provider.allCases {
            if let skill = record.skills[provider], let r = skill.validationReport {
                result.append((provider, r, skill))
            }
        }
        return result
    }

    var body: some View {
        if !reports.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("GUIDELINES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Color.textTertiary)

                ForEach(reports, id: \.0) { provider, report, skill in
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            ProviderBadge(provider: provider)
                            if let specURL = provider.spec.specURL {
                                Button {
                                    NSWorkspace.shared.open(specURL)
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 12))
                                        .foregroundStyle(DS.Color.accent)
                                }
                                .buttonStyle(.plain)
                                .help("View \(provider.displayName) skill specification")
                            }
                            Spacer()
                            if report.autoFixableCount > 0 {
                                Button {
                                    Task { await state.fixAllViolations(for: skill) }
                                } label: {
                                    Label("Fix All (\(report.autoFixableCount))", systemImage: "wrench.fill")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(DS.Color.synced)
                                .disabled(state.isFixing)
                            }
                        }

                        ForEach(report.violations) { violation in
                            let justFixed = state.recentlyFixedRuleIDs.contains(violation.rule.id)
                            GuidelineRow(
                                title: violation.rule.title,
                                severity: violation.rule.severity,
                                fixHint: violation.fixHint,
                                passed: false,
                                isAutoFixable: violation.isAutoFixable,
                                isJustFixed: justFixed,
                                onFix: violation.isAutoFixable ? {
                                    Task { await state.fixViolation(violation.rule.id, skill: skill) }
                                } : nil
                            )
                        }

                        ForEach(report.passedRules) { rule in
                            GuidelineRow(
                                title: rule.title,
                                severity: rule.severity,
                                fixHint: nil,
                                passed: true
                            )
                        }
                    }
                }

                if let err = state.fixError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Color.invalid)
                        .padding(DS.Spacing.md)
                        .background(DS.Color.invalidBg)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
            }
        }
    }
}

struct GuidelineRow: View {
    let title: String
    let severity: GuidelineSeverity
    let fixHint: String?
    let passed: Bool
    var isAutoFixable: Bool = false
    var isJustFixed: Bool = false
    var onFix: (() -> Void)?

    /// Non-fixable suggestions are purely informational — no icon needed.
    private var showIcon: Bool {
        if passed || isJustFixed { return true }
        if severity == .suggestion && !isAutoFixable { return false }
        return true
    }

    private var iconName: String {
        if isJustFixed { return "checkmark.circle.fill" }
        return passed ? "checkmark.circle.fill" : severity.iconName
    }

    private var iconColor: Color {
        if isJustFixed { return DS.Color.synced }
        if passed { return DS.Color.synced }
        switch severity {
        case .error: return DS.Color.invalid
        case .warning: return DS.Color.warning
        case .suggestion: return DS.Color.suggestion
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: DS.Spacing.sm) {
                if showIcon {
                    Image(systemName: iconName)
                        .font(.system(size: 12))
                        .foregroundStyle(iconColor)
                        .contentTransition(.symbolEffect(.replace))
                }
                Text(isJustFixed ? "\(title) — Fixed" : title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isJustFixed ? DS.Color.synced : DS.Color.text)
                Spacer()
                if !passed && !isJustFixed && isAutoFixable, let onFix {
                    Button(action: onFix) {
                        Label("Fix", systemImage: "wrench")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.Color.synced)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isJustFixed)
            if let hint = fixHint, !passed && !isJustFixed {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Color.textSecondary)
                    .padding(.leading, DS.Spacing.xl)
            }
        }
    }
}

struct TransferButton: View {
    let label: String
    let icon: String
    let provider: Provider
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
            }
            .foregroundStyle(provider.badgeColor)
            .padding(DS.Spacing.lg)
            .background(isHovered ? provider.badgeBgColor.opacity(0.8) : provider.badgeBgColor)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(provider.badgeColor.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - AI Evaluation Section

struct AIEvaluationSection: View {
    let record: SkillRecord
    @Bindable var state: AppState

    private var evaluationSkill: DiscoveredSkill? {
        record.preferredPreviewSource
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("AI EVALUATION")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DS.Color.textTertiary)
                Spacer()
                if let skill = evaluationSkill {
                    Button {
                        Task { await state.evaluateSkill(skill) }
                    } label: {
                        Label(
                            state.evaluationState == .evaluating ? "Evaluating…" : "Evaluate with AI",
                            systemImage: "sparkles"
                        )
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Color.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(state.evaluationState == .evaluating)
                }
            }

            switch state.evaluationState {
            case .idle:
                Text("Click \"Evaluate with AI\" to analyze this skill against best practices.")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Color.textTertiary)
            case .evaluating:
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analyzing skill against best practices…")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Color.textSecondary)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Color.canvas)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.borderLight, lineWidth: 1))
            case .completed(let evaluation):
                AIEvaluationResultView(evaluation: evaluation)
            case .failed(let message):
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.invalid)
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Color.invalidBg)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
    }
}

// MARK: - AI Evaluation Result View

struct AIEvaluationResultView: View {
    let evaluation: AIEvaluation

    private var scoreColor: Color {
        evaluation.overallScore >= 7 ? DS.Color.synced :
        evaluation.overallScore >= 4 ? DS.Color.warning :
        DS.Color.invalid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {

            // Score + category row
            HStack(spacing: DS.Spacing.md) {
                // Score circle
                ZStack {
                    Circle()
                        .stroke(DS.Color.borderLight, lineWidth: 3)
                        .frame(width: 48, height: 48)
                    Circle()
                        .trim(from: 0, to: Double(evaluation.overallScore) / 10.0)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                    Text("\(evaluation.overallScore)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(scoreColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(evaluation.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Color.text)
                        .fixedSize(horizontal: false, vertical: true)
                    MetaChip(label: evaluation.category, icon: "sparkles")
                }
            }

            // Sub-scores
            HStack(spacing: DS.Spacing.md) {
                ScoreLabel(label: "Structure", score: evaluation.structureScore)
                ScoreLabel(label: "Description", score: evaluation.descriptionScore)
                ScoreLabel(label: "Content", score: evaluation.contentQualityScore)
            }

            // Issues
            if !evaluation.issues.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ForEach(evaluation.issues) { issue in
                        AIIssueRow(issue: issue)
                    }
                }
            }

            // Suggestions
            if !evaluation.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggestions")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Color.textSecondary)
                    ForEach(evaluation.suggestions, id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: DS.Spacing.xs) {
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textTertiary)
                            Text(suggestion)
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            // Improved description
            if let improved = evaluation.improvedDescription {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack {
                        Text("Suggested Description")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DS.Color.textSecondary)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(improved, forType: .string)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Color.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(improved)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DS.Color.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(DS.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.Color.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).stroke(DS.Color.borderLight, lineWidth: 1))
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Color.borderLight, lineWidth: 1))
    }
}

struct ScoreLabel: View {
    let label: String
    let score: Int

    private var color: Color {
        score >= 7 ? DS.Color.synced :
        score >= 4 ? DS.Color.warning :
        DS.Color.invalid
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(score)/10")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DS.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Color.canvas)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

struct AIIssueRow: View {
    let issue: AIEvaluationIssue

    private var iconName: String {
        switch issue.severity {
        case "error": return "xmark.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        default: return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch issue.severity {
        case "error": return DS.Color.invalid
        case "warning": return DS.Color.warning
        default: return DS.Color.suggestion
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: iconName)
                    .font(.system(size: 11))
                    .foregroundStyle(iconColor)
                Text(issue.field)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Color.textSecondary)
            }
            Text(issue.message)
                .font(.system(size: 11))
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, DS.Spacing.xl)
        }
    }
}
