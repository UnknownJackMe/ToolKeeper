import Foundation

enum AnthropicAPIError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, message: String)
    case noContent
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .httpError(let code, let msg):
            return "HTTP 错误 (\(code)): \(msg)"
        case .noContent:
            return "API 返回为空"
        case .decodingError(let msg):
            return "解析错误: \(msg)"
        }
    }
}

struct AnthropicAPIClient {
    let baseURL: String
    let apiKey: String
    let model: String
    let useFullURL: Bool

    init(baseURL: String, apiKey: String, model: String, useFullURL: Bool = false) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.useFullURL = useFullURL
    }

    func send(prompt: String, maxTokens: Int = 4096) async throws -> String {
        let urlString: String
        if useFullURL {
            urlString = baseURL.trimmingCharacters(in: .whitespaces)
        } else {
            urlString = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                + "/v1/messages"
        }

        guard let url = URL(string: urlString) else {
            throw AnthropicAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicAPIError.httpError(statusCode: 0, message: "非 HTTP 响应")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "无详情"
            throw AnthropicAPIError.httpError(
                statusCode: httpResponse.statusCode,
                message: "请求 URL: \(urlString)\n\(String(errorBody.prefix(500)))"
            )
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AnthropicAPIError.decodingError("无法从响应中提取 text")
        }

        return text
    }

    func sendStructured(prompt: String, maxTokens: Int = 8192) async throws -> String {
        let wrappedPrompt = prompt
            + "\n\n重要：请只返回 JSON，不要包含任何其他文字、解释或 markdown 代码块标记。"

        return try await send(prompt: wrappedPrompt, maxTokens: maxTokens)
    }
}
