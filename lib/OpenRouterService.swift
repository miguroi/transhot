import Foundation
import Security
import AppKit

enum KeychainHelper {
    private static let service = "com.transhot.app"
    private static let apiKeyAccount = "openrouter-api-key"

    static func saveAPIKey(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }
        delete(account: apiKeyAccount)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteAPIKey() {
        delete(account: apiKeyAccount)
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

struct OpenRouterRequest: Codable {
    let model: String
    let messages: [Message]
    let temperature: Double?
    let maxTokens: Int?

    struct Message: Codable {
        let role: String
        let content: [ContentPart]
    }

    struct ContentPart: Codable {
        let type: String
        let text: String?
        let image_url: ImageURL?

        struct ImageURL: Codable {
            let url: String
        }

        init(text: String) {
            self.type = "text"
            self.text = text
            self.image_url = nil
        }

        init(imageData: Data, mimeType: String = "image/png") {
            self.type = "image_url"
            self.text = nil
            let base64 = imageData.base64EncodedString()
            self.image_url = ImageURL(url: "data:\(mimeType);base64,\(base64)")
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encodeIfPresent(text, forKey: .text)
            try container.encodeIfPresent(image_url, forKey: .image_url)
        }

        private enum CodingKeys: String, CodingKey {
            case type, text, image_url
        }
    }
}

struct OpenRouterResponse: Codable {
    let id: String
    let choices: [Choice]?
    let error: ErrorResponse?

    struct Choice: Codable {
        let message: Message

        struct Message: Codable {
            let content: String
        }
    }

    struct ErrorResponse: Codable {
        let message: String
    }
}

actor LLMClient {
    static let shared = LLMClient()

    private let session = URLSession.shared
    private let baseURL = "https://openrouter.ai/api/v1/chat/completions"

    func translate(text: String, to language: SupportedLanguage, apiKey: String, model: String = "openai/gpt-4o") async throws -> String {
        let request = OpenRouterRequest(
            model: model,
            messages: [
                .init(role: "system", content: [
                    .init(text: "You are a professional translator. Translate the given text to the target language. Return ONLY the translation, no explanations, no original text, no extra words.")
                ]),
                .init(role: "user", content: [
                    .init(text: "Translate to \(language.rawValue):\n\n\(text)")
                ])
            ],
            temperature: 0.1,
            maxTokens: 4096
        )

        return try await sendRequest(request: request, apiKey: apiKey)
    }

    func recognizeText(from image: CGImage, apiKey: String, model: String = "openai/gpt-4o") async throws -> String {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let imageData = bitmap.representation(using: .png, properties: [:]) else {
            throw LLMError.invalidImage
        }

        let prompt = """
        Extract all text from this image. \
        Preserve the original layout and formatting as much as possible. \
        Only return the extracted text, nothing else. \
        If there is no text in the image, return an empty string.
        """

        let request = OpenRouterRequest(
            model: model,
            messages: [
                .init(role: "user", content: [.init(text: prompt), .init(imageData: imageData)])
            ],
            temperature: 0.1,
            maxTokens: 4096
        )

        return try await sendRequest(request: request, apiKey: apiKey)
    }

    private func sendRequest(request: OpenRouterRequest, apiKey: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw LLMError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("https://transhot.app", forHTTPHeaderField: "HTTP-Referer")
        urlRequest.setValue("Transhot", forHTTPHeaderField: "X-Title")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 60

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let llmResponse = try? JSONDecoder().decode(OpenRouterResponse.self, from: data),
               let error = llmResponse.error {
                throw LLMError.apiError(error.message)
            }
            throw LLMError.httpError(httpResponse.statusCode)
        }

        let llmResponse = try JSONDecoder().decode(OpenRouterResponse.self, from: data)

        guard let content = llmResponse.choices?.first?.message.content else {
            throw LLMError.noContent
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum LLMError: LocalizedError {
    case invalidURL
    case invalidImage
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case noContent
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .invalidImage: return "Failed to process image"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code): return "HTTP error: \(code)"
        case .apiError(let message): return "API error: \(message)"
        case .noContent: return "No content returned"
        case .noAPIKey: return "No API key configured. Please add your OpenRouter API key in Settings."
        }
    }
}
