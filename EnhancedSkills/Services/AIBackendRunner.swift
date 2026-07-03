import Foundation

// MARK: - AIBackendRunner
// Shared AI backend infrastructure extracted from SkillEvaluator.
// Provides a single entry point for sending prompts to any configured backend.

enum AIBackendRunner {

    // MARK: - Shell Environment

    private static var cachedShellEnv: [String: String]?

    static func shellEnvironment() -> [String: String] {
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
                "\(home)/.local/bin/agy",
                "/opt/homebrew/bin/agy",
                "/usr/local/bin/agy",
                "/usr/bin/agy",
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

    // MARK: - JSON Extraction

    static func extractJSONObject(from text: String) -> String? {
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

    // MARK: - Main Entry Point

    /// Sends a system+user prompt to the specified backend and returns the raw text response.
    static func run(systemPrompt: String, userPrompt: String, backend: AIBackend, apiKey: String) async throws -> String {
        switch backend {
        case .claudeCLI:
            guard let path = cliPath(for: backend) else {
                throw EvaluationError.cliNotFound(backend.displayName)
            }
            return try await runClaudeCLI(cliPath: path, systemPrompt: systemPrompt, userPrompt: userPrompt)
        case .codexCLI:
            guard let path = cliPath(for: backend) else {
                throw EvaluationError.cliNotFound(backend.displayName)
            }
            let fullPrompt = systemPrompt + "\n\n---\n\n" + userPrompt
            return try await runProcess(executablePath: path, arguments: ["exec", "--skip-git-repo-check", fullPrompt])
        case .googleCLI:
            guard let path = cliPath(for: backend) else {
                throw EvaluationError.cliNotFound(backend.displayName)
            }
            let fullPrompt = systemPrompt + "\n\n---\n\n" + userPrompt
            return try await runProcess(executablePath: path, arguments: [fullPrompt])
        case .anthropicAPI:
            return try await callAnthropicAPI(systemPrompt: systemPrompt, userPrompt: userPrompt, apiKey: apiKey)
        case .openAIAPI:
            return try await callOpenAIAPI(systemPrompt: systemPrompt, userPrompt: userPrompt, apiKey: apiKey)
        case .googleAPI:
            return try await callGoogleAPI(systemPrompt: systemPrompt, userPrompt: userPrompt, apiKey: apiKey)
        }
    }

    // MARK: - Claude CLI

    private struct ClaudeJSONEnvelope: Decodable {
        let result: String?
        let isError: Bool?
        enum CodingKeys: String, CodingKey {
            case result
            case isError = "is_error"
        }
    }

    private static func runClaudeCLI(cliPath: String, systemPrompt: String, userPrompt: String) async throws -> String {
        let output = try await runProcess(
            executablePath: cliPath,
            arguments: [
                "-p",
                "--output-format", "json",
                "--system-prompt", systemPrompt,
                userPrompt
            ]
        )

        if let envelopeData = output.data(using: .utf8),
           let envelope = try? JSONDecoder().decode(ClaudeJSONEnvelope.self, from: envelopeData),
           let resultText = envelope.result {
            return resultText
        }

        return output
    }

    // MARK: - Anthropic API

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

    struct AnthropicAPIResponse: Decodable {
        struct ContentBlock: Decodable {
            let text: String?
        }
        struct APIErrorBody: Decodable {
            let message: String
        }
        let content: [ContentBlock]?
        let error: APIErrorBody?
    }

    private static func callAnthropicAPI(systemPrompt: String, userPrompt: String, apiKey: String, maxTokens: Int = 4096) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw EvaluationError.missingAPIKey }

        let body = AnthropicAPIRequest(
            model: "claude-sonnet-4-20250514",
            max_tokens: maxTokens,
            system: systemPrompt,
            messages: [AnthropicAPIMessage(role: "user", content: userPrompt)]
        )

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 120

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

        return text
    }

    // MARK: - OpenAI API

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

    private static func callOpenAIAPI(systemPrompt: String, userPrompt: String, apiKey: String, maxTokens: Int = 4096) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw EvaluationError.missingAPIKey }

        let body = OpenAIChatRequest(
            model: "gpt-4o",
            messages: [
                OpenAIChatMessage(role: "system", content: systemPrompt),
                OpenAIChatMessage(role: "user", content: userPrompt)
            ],
            max_tokens: maxTokens
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 120

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

        return text
    }

    // MARK: - Google AI API

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

    private static func callGoogleAPI(systemPrompt: String, userPrompt: String, apiKey: String) async throws -> String {
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
        request.timeoutInterval = 120

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

        return text
    }

    // MARK: - Process Runner

    static func runProcess(executablePath: String, arguments: [String]) async throws -> String {
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
            DispatchQueue.global().asyncAfter(deadline: .now() + 120, execute: timeoutWork)

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
