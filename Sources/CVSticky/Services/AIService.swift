import Foundation

@MainActor
final class AIService: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var streamedText = ""
    @Published var lastError: String?

    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func generateActions(for content: String) async -> [AIPinAction] {
        let fallback = fallbackActions(content: content)
        guard settings.ai.enabled,
              !settings.ai.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !settings.ai.model.isEmpty else { return fallback }
        isLoading = true
        streamedText = ""
        defer { isLoading = false }
        do {
            let system = "你是 CVSticky 剪贴笺的便签整理助手。返回 JSON 数组，每项必须包含 id、label、prompt、title、content_markdown。生成原文保存、优化表达、任务清单、摘要、结构化和美化排版等方案。不要返回 JSON 以外的解释。"
            let answer = try await streamChat(system: system, user: String(content.prefix(12_000)))
            streamedText = answer
            let parsed = parseActions(answer)
            return parsed.isEmpty ? fallback : parsed
        } catch {
            lastError = error.localizedDescription
            return fallback
        }
    }

    func transform(_ content: String, instruction: String) async -> String {
        guard settings.ai.enabled else { return content }
        isLoading = true
        defer { isLoading = false }
        do {
            return try await chat(
                system: "你是 CVSticky 的 Markdown 便签助手。按要求处理内容，只输出最终 Markdown 正文。",
                user: "处理要求：\(instruction)\n\n剪贴内容：\n\(String(content.prefix(12_000)))"
            )
        } catch {
            lastError = error.localizedDescription
            return content
        }
    }

    func testConnection(configuration: AIConfiguration) async throws -> String {
        let previous = settings.ai
        settings.updateAI(configuration)
        defer { settings.updateAI(previous) }
        return try await chat(system: "只回复 OK", user: "测试连接")
    }

    private func chat(system: String, user: String) async throws -> String {
        let config = settings.ai
        let request = try makeRequest(config: config, system: system, user: user, stream: false)
        let (data, response) = try await URLSession.shared.compatibleData(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AIError.requestFailed(String(data: data, encoding: .utf8) ?? "请求失败")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        guard let content = message?["content"] as? String, !content.isEmpty else {
            throw AIError.emptyResponse
        }
        return content
    }

    private func streamChat(system: String, user: String) async throws -> String {
        let config = settings.ai
        let request = try makeRequest(config: config, system: system, user: user, stream: true)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AIError.requestFailed("AI 流式请求失败")
        }
        var result = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else { continue }
            result += content
            streamedText = result
        }
        guard !result.isEmpty else { throw AIError.emptyResponse }
        return result
    }

    private func makeRequest(
        config: AIConfiguration,
        system: String,
        user: String,
        stream: Bool
    ) throws -> URLRequest {
        guard let url = completionsURL(config.baseURL) else { throw AIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": config.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "temperature": 0.4,
            "stream": stream
        ])
        return request
    }

    private func completionsURL(_ base: String) -> URL? {
        let clean = base.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if clean.hasSuffix("chat/completions") { return URL(string: clean) }
        if clean.hasSuffix("/v1") { return URL(string: clean + "/chat/completions") }
        return URL(string: clean + "/v1/chat/completions")
    }

    private func parseActions(_ raw: String) -> [AIPinAction] {
        var clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
        if let data = clean.data(using: .utf8),
           let actions = try? JSONDecoder().decode([AIPinAction].self, from: data) {
            return actions
        }
        guard let start = clean.firstIndex(of: "["), let end = clean.lastIndex(of: "]") else { return [] }
        let candidate = String(clean[start...end])
        return candidate.data(using: .utf8).flatMap { try? JSONDecoder().decode([AIPinAction].self, from: $0) } ?? []
    }

    private func fallbackActions(content: String) -> [AIPinAction] {
        [
            AIPinAction(id: "save", label: "原文保存", prompt: "保留原始内容", title: String(content.prefix(24)), contentMarkdown: content),
            AIPinAction(id: "improve", label: "优化表达", prompt: "在不改变事实的前提下优化表达", title: "优化表达", contentMarkdown: content),
            AIPinAction(id: "todo", label: "转换清单", prompt: "整理为 Markdown 任务清单", title: "任务清单", contentMarkdown: content),
            AIPinAction(id: "polish", label: "美化排版", prompt: "整理为层级清晰的 Markdown", title: "美化排版", contentMarkdown: content)
        ]
    }
}

enum AIError: LocalizedError {
    case invalidURL
    case requestFailed(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "AI Base URL 不合法"
        case .requestFailed(let message): return message
        case .emptyResponse: return "AI 返回了空内容"
        }
    }
}

private extension URLSession {
    func compatibleData(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            dataTask(with: request) { data, response, error in
                if let error { continuation.resume(throwing: error) }
                else if let data, let response { continuation.resume(returning: (data, response)) }
                else { continuation.resume(throwing: AIError.emptyResponse) }
            }.resume()
        }
    }
}
