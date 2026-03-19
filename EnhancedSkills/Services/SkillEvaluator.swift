import Foundation

// MARK: - Errors

enum EvaluationError: LocalizedError {
    case cliNotFound(String)
    case executionFailed(exitCode: Int32, stderr: String)
    case invalidJSON(String)
    case timeout
    case noContent
    case missingAPIKey
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .cliNotFound(let name):
            return "\(name) not found. Make sure it is installed and in your PATH."
        case .executionFailed(let code, let stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? "CLI exited with code \(code)."
                : "CLI exited with code \(code): \(detail.prefix(200))"
        case .invalidJSON(let preview):
            return "Could not parse AI response as JSON. Preview: \(preview.prefix(200))"
        case .timeout:
            return "Evaluation timed out after 90 seconds."
        case .noContent:
            return "SKILL.md is empty or could not be read."
        case .missingAPIKey:
            return "API key is not set. Add it in Settings → AI."
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

// MARK: - SkillEvaluator

enum SkillEvaluator {

    // MARK: Best Practices System Prompt

    private static let systemPrompt = """
    You are an expert skill quality evaluator for AI coding assistants. Analyze the provided SKILL.md content and return a structured JSON evaluation.

    ## Structure Rules
    - Skill folder should use kebab-case (lowercase letters and hyphens only, no spaces/underscores/capitals)
    - SKILL.md must be exactly that name (case-sensitive)
    - YAML frontmatter must have --- delimiters at top and bottom
    - Optional directories that improve quality: scripts/ (executable code), references/ (documentation), assets/ (templates/fonts/icons)

    ## Name Field Rules
    - Must be kebab-case only: lowercase letters and hyphens
    - No spaces, underscores, or capital letters
    - Should match the skill folder name
    - Cannot start with "claude" or "anthropic" (reserved prefixes)

    ## Description Field Rules (CRITICAL - this is how the AI decides when to load the skill)
    - MUST include WHAT the skill does AND WHEN to use it (trigger phrases users would say)
    - Under 1024 characters
    - No XML angle brackets (< or >)
    - Include specific trigger phrases users would actually type
    - Good example: "Analyzes Figma design files and generates developer handoff documentation. Use when user uploads .fig files, asks for 'design specs', 'component documentation', or 'design-to-code handoff'."
    - Bad examples: "Helps with projects." (too vague), "Creates sophisticated multi-page documentation systems." (no trigger phrases), "Implements the Project entity model." (too technical, no user triggers)

    ## Content Quality Rules
    - Include a "Gotchas" or "Common Issues" section capturing failure points the AI should avoid
    - Use progressive disclosure: keep SKILL.md focused on core instructions, move detailed docs to references/ with explicit links
    - Avoid railroading: give the AI enough info but allow flexibility to adapt to the situation
    - Instructions should be specific and actionable, not vague ("Run `python scripts/validate.py --input {filename}`" not "Validate the data")
    - Include error handling guidance for common failure cases
    - Reference any bundled scripts or reference files explicitly so the AI knows they exist
    - Keep SKILL.md under 5,000 words (very long files degrade performance)
    - No XML angle brackets anywhere (security restriction - frontmatter appears in system prompt)

    ## Skill Categories
    Classify into exactly one of:
    1. Library & API Reference - explains how to correctly use a library, CLI, or SDK
    2. Product Verification - tests or verifies that code is working (often uses playwright, tmux, etc.)
    3. Data Fetching & Analysis - connects to data and monitoring stacks
    4. Business Process & Team Automation - automates repetitive team workflows
    5. Code Scaffolding & Templates - generates framework boilerplate for a specific codebase
    6. Code Quality & Review - enforces code quality and review standards
    7. CI/CD & Deployment - helps fetch, push, and deploy code
    8. Runbooks - takes a symptom, investigates via multi-tool workflow, produces a report
    9. Infrastructure Operations - routine maintenance and operational procedures

    ## Output Format
    Return ONLY valid JSON with this exact structure (no markdown, no explanation, just JSON):
    {
      "overallScore": <integer 1-10>,
      "category": "<one of the 9 category names above>",
      "structureScore": <integer 1-10>,
      "descriptionScore": <integer 1-10>,
      "contentQualityScore": <integer 1-10>,
      "issues": [
        {
          "field": "<name|description|body|structure>",
          "severity": "<error|warning|suggestion>",
          "message": "<specific, actionable improvement message>"
        }
      ],
      "suggestions": ["<suggestion 1>", "<suggestion 2>"],
      "improvedDescription": "<rewritten description if current one scores below 7, otherwise null>",
      "summary": "<1-2 sentence overall assessment>"
    }

    Score guide: 9-10 = excellent, 7-8 = good, 5-6 = needs improvement, 3-4 = poor, 1-2 = failing.
    """

    // MARK: - Shell Environment

    private static var cachedShellEnv: [String: String]?

    private static func shellEnvironment() -> [String: String] {
        if let cached = cachedShellEnv { return cached }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-ilc", "env"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        var env: [String: String] = ProcessInfo.processInfo.environment
        for line in output.components(separatedBy: "\n") {
            if let eqIdx = line.firstIndex(of: "=") {
                let key = String(line[line.startIndex..<eqIdx])
                let val = String(line[line.index(after: eqIdx)...])
                env[key] = val
            }
        }
        cachedShellEnv = env
        return env
    }

    // MARK: - CLI Path Discovery

    private static var cachedPaths: [AIBackend: String] = [:]

    static func cliPath(for backend: AIBackend) -> String? {
        guard backend.isCLI else { return nil }
        if let cached = cachedPaths[backend] { return cached }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates: [String]
        switch backend {
        case .claudeCLI:
            candidates = [
                "\(home)/.local/bin/claude",
                "/usr/local/bin/claude",
                "/opt/homebrew/bin/claude",
                "/usr/bin/claude"
            ]
        case .codexCLI:
            candidates = [
                "/opt/homebrew/bin/codex",
                "/usr/local/bin/codex",
                "\(home)/.local/bin/codex"
            ]
        case .googleCLI:
            candidates = [
                "\(home)/.local/bin/gemini",
                "/opt/homebrew/bin/gemini",
                "/usr/local/bin/gemini",
                "/usr/bin/gemini"
            ]
        case .anthropicAPI, .openAIAPI, .googleAPI:
            return nil
        }

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                cachedPaths[backend] = path
                return path
            }
        }

        if let found = runWhich(backend.executableName) {
            cachedPaths[backend] = found
            return found
        }

        return nil
    }

    private static func runWhich(_ name: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return output?.isEmpty == false ? output : nil
    }

    // MARK: - Main Entry Point

    static func evaluate(skill: DiscoveredSkill, backend: AIBackend, apiKey: String = "") async throws -> AIEvaluation {
        let content: String
        do {
            content = try String(contentsOf: skill.skillMarkdownPath, encoding: .utf8)
        } catch {
            throw EvaluationError.noContent
        }

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EvaluationError.noContent
        }

        let truncated = content.count > 35_000 ? String(content.prefix(35_000)) + "\n\n[...truncated]" : content

        let providerContext = skill.provider.spec.promptContext
        let fullSystemPrompt = systemPrompt + "\n\n" + providerContext

        let userPrompt = """
        Evaluate this skill (provider: \(skill.provider.displayName), folder: \(skill.folderName)):

        \(truncated)
        """

        switch backend {
        case .claudeCLI:
            guard let cliPath = cliPath(for: backend) else {
                throw EvaluationError.cliNotFound(backend.displayName)
            }
            return try await runClaudeCLI(cliPath: cliPath, systemPrompt: fullSystemPrompt, userPrompt: userPrompt)
        case .codexCLI:
            guard let cliPath = cliPath(for: backend) else {
                throw EvaluationError.cliNotFound(backend.displayName)
            }
            return try await runCodexCLI(cliPath: cliPath, systemPrompt: fullSystemPrompt, userPrompt: userPrompt)
        case .googleCLI:
            guard let cliPath = cliPath(for: backend) else {
                throw EvaluationError.cliNotFound(backend.displayName)
            }
            return try await runGeminiCLI(cliPath: cliPath, systemPrompt: fullSystemPrompt, userPrompt: userPrompt)
        case .anthropicAPI:
            return try await evaluateWithAnthropicAPI(systemPrompt: fullSystemPrompt, userPrompt: userPrompt, apiKey: apiKey)
        case .openAIAPI:
            return try await evaluateWithOpenAI(systemPrompt: fullSystemPrompt, userPrompt: userPrompt, apiKey: apiKey)
        case .googleAPI:
            return try await evaluateWithGoogle(systemPrompt: fullSystemPrompt, userPrompt: userPrompt, apiKey: apiKey)
        }
    }

    // MARK: - Claude CLI Execution

    private struct ClaudeJSONEnvelope: Decodable {
        let result: String?
        let isError: Bool?
        enum CodingKeys: String, CodingKey {
            case result
            case isError = "is_error"
        }
    }

    private static func runClaudeCLI(cliPath: String, systemPrompt: String, userPrompt: String) async throws -> AIEvaluation {
        let output = try await runProcess(
            executablePath: cliPath,
            arguments: [
                "-p",
                "--output-format", "json",
                "--system-prompt", systemPrompt,
                userPrompt
            ]
        )

        let decoder = JSONDecoder()
        if let envelopeData = output.data(using: .utf8),
           let envelope = try? decoder.decode(ClaudeJSONEnvelope.self, from: envelopeData),
           let resultText = envelope.result {
            return try extractEvaluation(from: resultText)
        }

        return try extractEvaluation(from: output)
    }

    // MARK: - Codex CLI Execution

    private static func runCodexCLI(cliPath: String, systemPrompt: String, userPrompt: String) async throws -> AIEvaluation {
        let fullPrompt = systemPrompt + "\n\n---\n\n" + userPrompt
        let output = try await runProcess(
            executablePath: cliPath,
            arguments: ["exec", "--skip-git-repo-check", fullPrompt]
        )
        return try extractEvaluation(from: output)
    }

    // MARK: - Gemini CLI Execution

    private static func runGeminiCLI(cliPath: String, systemPrompt: String, userPrompt: String) async throws -> AIEvaluation {
        let fullPrompt = systemPrompt + "\n\n---\n\n" + userPrompt
        let output = try await runProcess(
            executablePath: cliPath,
            arguments: [fullPrompt]
        )
        return try extractEvaluation(from: output)
    }

    // MARK: - JSON Extraction

    private static func extractEvaluation(from text: String) throws -> AIEvaluation {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = trimmed.data(using: .utf8),
           let evaluation = try? JSONDecoder().decode(AIEvaluation.self, from: data) {
            return evaluation
        }

        if let jsonString = extractJSONObject(from: trimmed),
           let data = jsonString.data(using: .utf8),
           let evaluation = try? JSONDecoder().decode(AIEvaluation.self, from: data) {
            return evaluation
        }

        throw EvaluationError.invalidJSON(String(trimmed.prefix(300)))
    }

    private static func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var end: String.Index?
        var inString = false
        var escaped = false

        for index in text[start...].indices {
            let char = text[index]
            if escaped { escaped = false; continue }
            if char == "\\" && inString { escaped = true; continue }
            if char == "\"" { inString.toggle(); continue }
            if !inString {
                if char == "{" { depth += 1 }
                else if char == "}" {
                    depth -= 1
                    if depth == 0 { end = index; break }
                }
            }
        }

        guard let endIndex = end else { return nil }
        return String(text[start...endIndex])
    }

    // MARK: - Anthropic API Evaluation

    private struct AnthropicAPIMessage: Encodable {
        let role: String
        let content: String
    }

    private struct AnthropicAPIRequest: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [AnthropicAPIMessage]
    }

    private struct AnthropicAPIResponse: Decodable {
        struct ContentBlock: Decodable {
            let text: String?
        }
        struct APIErrorBody: Decodable {
            let message: String
        }
        let content: [ContentBlock]?
        let error: APIErrorBody?
    }

    private static func evaluateWithAnthropicAPI(systemPrompt: String, userPrompt: String, apiKey: String) async throws -> AIEvaluation {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw EvaluationError.missingAPIKey }

        let body = AnthropicAPIRequest(
            model: "claude-sonnet-4-20250514",
            max_tokens: 4096,
            system: systemPrompt,
            messages: [AnthropicAPIMessage(role: "user", content: userPrompt)]
        )

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let apiResp = try? JSONDecoder().decode(AnthropicAPIResponse.self, from: data),
               let errorMsg = apiResp.error?.message {
                throw EvaluationError.apiError(errorMsg)
            }
            throw EvaluationError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let apiResponse = try JSONDecoder().decode(AnthropicAPIResponse.self, from: data)
        guard let text = apiResponse.content?.first?.text else {
            throw EvaluationError.noContent
        }

        return try extractEvaluation(from: text)
    }

    // MARK: - OpenAI API Evaluation

    private struct OpenAIChatMessage: Encodable {
        let role: String
        let content: String
    }

    private struct OpenAIChatRequest: Encodable {
        let model: String
        let messages: [OpenAIChatMessage]
        let max_tokens: Int
    }

    private struct OpenAIChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message
        }
        struct APIError: Decodable {
            let message: String
        }
        let choices: [Choice]?
        let error: APIError?
    }

    private static func evaluateWithOpenAI(systemPrompt: String, userPrompt: String, apiKey: String) async throws -> AIEvaluation {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw EvaluationError.missingAPIKey }

        let body = OpenAIChatRequest(
            model: "gpt-4o",
            messages: [
                OpenAIChatMessage(role: "system", content: systemPrompt),
                OpenAIChatMessage(role: "user", content: userPrompt)
            ],
            max_tokens: 4096
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let apiResp = try? JSONDecoder().decode(OpenAIChatResponse.self, from: data),
               let errorMsg = apiResp.error?.message {
                throw EvaluationError.apiError(errorMsg)
            }
            throw EvaluationError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let apiResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let text = apiResponse.choices?.first?.message.content else {
            throw EvaluationError.noContent
        }

        return try extractEvaluation(from: text)
    }

    // MARK: - Google AI API Evaluation

    private struct GoogleContent: Encodable {
        struct Part: Encodable {
            let text: String
        }
        let role: String?
        let parts: [Part]
    }

    private struct GoogleGenerateRequest: Encodable {
        let system_instruction: GoogleContent?
        let contents: [GoogleContent]
    }

    private struct GoogleGenerateResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String?
                }
                let parts: [Part]?
            }
            let content: Content?
        }
        struct APIError: Decodable {
            let message: String
        }
        let candidates: [Candidate]?
        let error: APIError?
    }

    private static func evaluateWithGoogle(systemPrompt: String, userPrompt: String, apiKey: String) async throws -> AIEvaluation {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw EvaluationError.missingAPIKey }

        let body = GoogleGenerateRequest(
            system_instruction: GoogleContent(role: nil, parts: [.init(text: systemPrompt)]),
            contents: [GoogleContent(role: "user", parts: [.init(text: userPrompt)])]
        )

        var urlComponents = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent")!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: key)]

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let apiResp = try? JSONDecoder().decode(GoogleGenerateResponse.self, from: data),
               let errorMsg = apiResp.error?.message {
                throw EvaluationError.apiError(errorMsg)
            }
            throw EvaluationError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let apiResponse = try JSONDecoder().decode(GoogleGenerateResponse.self, from: data)
        guard let text = apiResponse.candidates?.first?.content?.parts?.first?.text else {
            throw EvaluationError.noContent
        }

        return try extractEvaluation(from: text)
    }

    // MARK: - Test Backend

    static func testBackend(_ backend: AIBackend, apiKey: String?) async -> Result<String, Error> {
        switch backend {
        case .claudeCLI, .codexCLI, .googleCLI:
            guard let path = cliPath(for: backend) else {
                return .failure(EvaluationError.cliNotFound(backend.displayName))
            }
            do {
                let output: String
                switch backend {
                case .claudeCLI:
                    output = try await runProcess(executablePath: path, arguments: ["-p", "Say hello in one word."])
                case .codexCLI:
                    output = try await runProcess(executablePath: path, arguments: ["exec", "--skip-git-repo-check", "Say hello in one word."])
                case .googleCLI:
                    output = try await runProcess(executablePath: path, arguments: ["Say hello in one word."])
                default:
                    output = ""
                }
                return .success("Connection successful")
            } catch {
                return .failure(error)
            }

        case .anthropicAPI:
            let key = (apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                return .failure(EvaluationError.missingAPIKey)
            }
            do {
                let body = AnthropicAPIRequest(
                    model: "claude-sonnet-4-20250514",
                    max_tokens: 32,
                    system: "You are a helpful assistant.",
                    messages: [AnthropicAPIMessage(role: "user", content: "Say hello in one word.")]
                )
                var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
                request.httpMethod = "POST"
                request.setValue(key, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                request.setValue("application/json", forHTTPHeaderField: "content-type")
                request.httpBody = try JSONEncoder().encode(body)
                request.timeoutInterval = 30

                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    if let apiResp = try? JSONDecoder().decode(AnthropicAPIResponse.self, from: data),
                       let errorMsg = apiResp.error?.message {
                        return .failure(EvaluationError.apiError(errorMsg))
                    }
                    return .failure(EvaluationError.apiError("HTTP \(httpResponse.statusCode)"))
                }
                return .success("Connection successful")
            } catch {
                return .failure(error)
            }

        case .openAIAPI:
            let key = (apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                return .failure(EvaluationError.missingAPIKey)
            }
            do {
                let body = OpenAIChatRequest(
                    model: "gpt-4o",
                    messages: [
                        OpenAIChatMessage(role: "system", content: "You are a helpful assistant."),
                        OpenAIChatMessage(role: "user", content: "Say hello in one word.")
                    ],
                    max_tokens: 32
                )
                var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
                request.httpMethod = "POST"
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "content-type")
                request.httpBody = try JSONEncoder().encode(body)
                request.timeoutInterval = 30

                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    if let apiResp = try? JSONDecoder().decode(OpenAIChatResponse.self, from: data),
                       let errorMsg = apiResp.error?.message {
                        return .failure(EvaluationError.apiError(errorMsg))
                    }
                    return .failure(EvaluationError.apiError("HTTP \(httpResponse.statusCode)"))
                }
                return .success("Connection successful")
            } catch {
                return .failure(error)
            }

        case .googleAPI:
            let key = (apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                return .failure(EvaluationError.missingAPIKey)
            }
            do {
                let body = GoogleGenerateRequest(
                    system_instruction: nil,
                    contents: [GoogleContent(role: "user", parts: [.init(text: "Say hello in one word.")])]
                )
                var urlComponents = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent")!
                urlComponents.queryItems = [URLQueryItem(name: "key", value: key)]

                var request = URLRequest(url: urlComponents.url!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "content-type")
                request.httpBody = try JSONEncoder().encode(body)
                request.timeoutInterval = 30

                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    if let apiResp = try? JSONDecoder().decode(GoogleGenerateResponse.self, from: data),
                       let errorMsg = apiResp.error?.message {
                        return .failure(EvaluationError.apiError(errorMsg))
                    }
                    return .failure(EvaluationError.apiError("HTTP \(httpResponse.statusCode)"))
                }
                return .success("Connection successful")
            } catch {
                return .failure(error)
            }
        }
    }

    // MARK: - Process Runner

    private static func runProcess(executablePath: String, arguments: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            let lock = NSLock()
            var didFinish = false

            func finish(_ result: Result<String, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !didFinish else { return }
                didFinish = true
                continuation.resume(with: result)
            }

            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.environment = shellEnvironment()
            process.standardOutput = stdout
            process.standardError = stderr

            let timeoutWork = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                    finish(.failure(EvaluationError.timeout))
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 90, execute: timeoutWork)

            process.terminationHandler = { proc in
                timeoutWork.cancel()
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                let outStr = String(data: outData, encoding: .utf8) ?? ""

                if proc.terminationStatus == 0 {
                    finish(.success(outStr))
                } else {
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    finish(.failure(EvaluationError.executionFailed(
                        exitCode: proc.terminationStatus,
                        stderr: errStr
                    )))
                }
            }

            do {
                try process.run()
            } catch {
                timeoutWork.cancel()
                finish(.failure(error))
            }
        }
    }
}
