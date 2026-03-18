# EnhancedSkills v1 Implementation Plan

## Summary
Build a macOS SwiftUI app that discovers, compares, and manually syncs skills between Codex and Claude with a premium, screenshot-worthy interface.

V1 scope:
- Detect local provider roots automatically
- Parse and list skills from Codex and Claude
- Show merged inventory with clear sync status
- Let the user copy a skill from one provider to the other with preview and overwrite confirmation
- Ship a strong editorial-light desktop UI designed for shareable screenshots

Out of scope for v1:
- Auto-sync/background watchers
- Skill optimization or revamp workflows
- Semantic conversion between provider formats
- Gemini implementation
- Cloud sync, history, rollback, or version diffing

## Product Decisions
### Providers
- Codex root: `~/.codex/skills`
- Claude root: `~/.claude/skills`
- Future providers must fit a common adapter model, but only Codex and Claude are implemented in v1.

### Skill identity
- Primary cross-provider identity is the skill folder name, normalized as a slug.
- Parsed frontmatter `name` is display-only metadata and must not be the primary key.
- A skill can exist in:
  - both providers
  - Codex only
  - Claude only
  - invalid/unparseable state

### Sync behavior
- Sync is manual and explicit.
- Supported actions:
  - `Copy to Claude`
  - `Copy to Codex`
  - `Reveal in Finder`
  - `Refresh`
- Transfer copies the full directory recursively.
- Existing destination directories are not overwritten silently.
- If destination exists, show replace confirmation before proceeding.

### Visual direction
- Editorial light aesthetic.
- Warm off-white canvas, dark text, restrained but sharp accent, premium spacing, oversized headings.
- Avoid generic utility-app styling; the app should look designed for screenshots.

## Technical Approach
### Stack
- Native macOS app using SwiftUI.
- App entry remains SwiftUI-first with a single-window desktop experience.
- Use modern observation/state patterns supported by the current Xcode template baseline.

### High-level architecture
- `App`: app entry and top-level scene wiring.
- `AppState` or equivalent: owns refresh cycle, provider state, merged inventory, selection, filters, errors, and transfer sheet state.
- `SkillProvider` protocol: provider-specific discovery and transfer implementation.
- `CodexProvider` and `ClaudeProvider`: concrete adapters.
- `SkillRecord`: normalized merged model for UI.
- `SkillTransferPlan`: preflight preview model for confirmation UI.
- `SkillParser`: parses `SKILL.md` and extracts frontmatter plus lightweight inferred metadata.

### Suggested file layout
- `EnhancedSkills/EnhancedSkillsApp.swift`
- `EnhancedSkills/ContentView.swift`
- `EnhancedSkills/App/`
- `EnhancedSkills/Models/`
- `EnhancedSkills/Providers/`
- `EnhancedSkills/Services/`
- `EnhancedSkills/Views/`
- `EnhancedSkills/DesignSystem/`

Exact filenames may vary, but responsibilities should stay separated by app state, provider logic, parsing, and presentation.

## Data Model
### Provider enum
- Cases:
  - `codex`
  - `claude`
- Properties:
  - display name
  - badge color/style token
  - default root path

### Raw discovered skill
- Fields:
  - `provider`
  - `folderName`
  - `rootPath`
  - `skillPath`
  - `skillMarkdownPath`
  - `parsedName`
  - `parsedDescription`
  - `isSystem`
  - `hasScripts`
  - `hasReferences`
  - `lastModified`
  - `parseStatus`

### Merged `SkillRecord`
- Fields:
  - `id` = normalized folder slug
  - `displayName`
  - `description`
  - `slug`
  - `codexSkill: DiscoveredSkill?`
  - `claudeSkill: DiscoveredSkill?`
  - `status`
  - `preferredPreviewSource`
  - `tags`
  - `lastModified`

### Skill status enum
- `synced`
- `codexOnly`
- `claudeOnly`
- `conflict`
- `invalid`

`conflict` is reserved for future content mismatch logic but can be omitted from v1 UI if no content diffing is implemented. If omitted, keep the enum internal or leave a placeholder for future expansion.

### Transfer preview model
- Fields:
  - source provider
  - destination provider
  - source path
  - destination path
  - source file count
  - destination exists
  - willReplace
  - warnings

## Provider Rules
### Codex provider
- Root path: `~/.codex/skills`
- Enumerate immediate child directories only.
- Treat directories beginning with `.` as hidden/system candidates.
- Mark `.system` or descendants within it as system skills.
- A valid skill is a directory containing `SKILL.md`.
- Preserve nested content such as `scripts/`, `references/`, and assets during transfer.

### Claude provider
- Root path: `~/.claude/skills`
- Enumerate immediate child directories only.
- A valid skill is a directory containing `SKILL.md`.
- If the root does not exist, treat Claude as available but empty and allow creation of the root during the first transfer.
- Claude folders should be copied in the same shape as source skill folders unless future conversion rules are introduced.

### Common provider behavior
- Discovery must never mutate the filesystem.
- Transfer may create:
  - provider root if missing
  - destination skill folder if missing
- Hidden files should be copied unless explicitly excluded for safety.
- Initial exclusion rule:
  - skip macOS `.DS_Store`

## Parsing Rules
### `SKILL.md`
- If YAML frontmatter exists, extract at minimum:
  - `name`
  - `description`
- If frontmatter is missing:
  - derive display name from folder name
  - description may be nil
- If frontmatter is malformed:
  - mark parse status as malformed
  - still include the skill in the inventory
- Preview excerpt should come from the first meaningful body content after frontmatter.

### Inferred metadata
- `hasScripts` if `scripts/` exists
- `hasReferences` if `references/` exists
- `lastModified` from directory or `SKILL.md` modification date
- `isSystem` based on provider-specific rules, not frontmatter

## App Behavior
### Launch
- On app launch:
  - resolve both provider roots
  - scan providers
  - parse discovered skills
  - merge into unified inventory
  - select the first useful item if any exist
- Do not block the UI behind a heavy loading screen; show a designed loading state if scanning is in progress.

### Refresh
- Manual refresh rescans both providers and rebuilds merged state.
- Preserve current filter and selected skill when still valid after refresh.

### Filtering and search
- Filters:
  - `All`
  - `Needs Sync`
  - `Codex Only`
  - `Claude Only`
  - `System`
- Search should match:
  - folder slug
  - display name
  - description

### Selection
- Selecting a skill updates the right detail pane.
- Detail pane should show:
  - title
  - provider presence badges
  - status
  - description
  - filesystem paths
  - metadata chips for scripts/references/system
  - `SKILL.md` preview excerpt
  - transfer CTA

### Transfer flow
1. User selects a skill.
2. User clicks `Copy to Claude` or `Copy to Codex`.
3. App builds `SkillTransferPlan`.
4. App presents confirmation sheet with:
   - source path
   - destination path
   - file count
   - overwrite warning if applicable
5. User confirms.
6. App performs recursive copy.
7. App refreshes provider inventory.
8. App shows success or structured error.

### Error handling
- Discovery errors should not crash the app.
- Provider-level errors should surface as inline banners or a lightweight alert.
- Transfer errors should surface with:
  - source provider
  - destination provider
  - path involved
  - human-readable message

## UX Specification
### Main layout
- Three-column desktop composition:
  - Left rail:
    - app title
    - provider summary cards
    - filter controls
    - refresh action
  - Center:
    - hero summary
    - search
    - skills gallery/list
  - Right detail pane:
    - selected skill metadata
    - markdown excerpt
    - sync actions

### Visual details
- Large editorial header with counts like:
  - total skills
  - synced
  - needs sync
- Use generous spacing and large card surfaces.
- Skill cards should show:
  - display name
  - short description
  - provider badges
  - status pill
  - modified timestamp or metadata chips
- Prefer one memorable accent color and warm neutral surfaces over multicolor clutter.
- Use subtle motion:
  - initial staggered card reveal
  - hover elevation
  - animated badge/status updates

### Empty and missing states
- If both roots are empty or missing:
  - show a polished empty state with detected paths
  - explain what qualifies as a skill
- If one provider is missing:
  - still show the other provider’s inventory
  - present the missing provider as connectable/empty, not broken

## Filesystem Operations
### Path resolution
- Expand `~` using the current user home directory.
- Do not hardcode absolute home paths.

### Recursive copy
- Use `FileManager`-backed recursive copy.
- Copy directories as directories, not as flat file lists.
- Preserve nested structure.
- If destination exists and replace is confirmed:
  - remove destination skill directory first
  - then perform fresh copy
- Never delete anything outside the destination skill directory.

### Finder reveal
- Reveal the selected provider skill path in Finder.

## Testing Plan
### Unit tests
- Discovery:
  - Codex root with valid skills
  - Codex root with `.system` skill folders
  - Claude root missing
  - Claude root present but empty
- Parsing:
  - valid frontmatter
  - no frontmatter
  - malformed frontmatter
  - empty `SKILL.md`
- Merging:
  - same slug in both providers
  - Codex only
  - Claude only
  - duplicate display names with different slugs
- Transfer planning:
  - destination missing
  - destination exists
  - nested files counted correctly
- Transfer execution:
  - destination root created when absent
  - skill copied recursively
  - overwrite replaces destination only after confirmation

### UI tests
- App launches and renders the main structure
- Search filters visible cards
- Filter chips change inventory
- Selecting a skill updates the detail pane
- Transfer confirmation sheet appears for an eligible action

### Manual acceptance criteria
- App auto-detects `~/.codex/skills` and `~/.claude/skills`
- App lists skills cleanly from existing local folders
- Statuses correctly distinguish synced vs one-sided skills
- Copying a skill from Codex to Claude creates a valid folder under `~/.claude/skills`
- Refresh reflects new state immediately
- Screenshots at standard desktop width look intentionally designed, not template-like

## Implementation Order
1. Replace starter app shell with a three-column SwiftUI layout and placeholder data.
2. Add design tokens and reusable UI primitives so the final UI stays cohesive.
3. Implement path resolution and provider protocols.
4. Implement Codex discovery and parsing.
5. Implement Claude discovery and parsing.
6. Implement merge logic and inventory filtering/search.
7. Bind real data into the main UI.
8. Implement transfer preview and recursive copy actions.
9. Add Finder reveal and refresh handling.
10. Add unit tests for parsing, discovery, merge, and transfer.
11. Add UI smoke tests for launch, selection, and transfer prompt.
12. Polish motion, empty states, and screenshot quality.

## Assumptions
- Claude skills should live in `~/.claude/skills`.
- Codex and Claude can both consume the same folder-based skill structure for v1.
- Full directory copy is sufficient; no provider-specific transformation is needed.
- Folder slug is the correct matching key across providers.
- Security-scoped bookmarks are only needed if sandbox/file access restrictions appear during implementation.

## Handoff Notes
- Do not simplify the UI into a default sidebar/list/detail template without visual polish.
- Keep provider logic isolated behind adapters so Gemini can be added later without rewriting the merged inventory.
- Avoid building “skill revamp” into the first pass; keep v1 focused on inventory and sync quality.
- If implementation time is tight, cut animation before cutting transfer preview and overwrite safety.
