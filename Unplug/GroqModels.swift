// Shared Groq API Data Structures for use in multiple views
import Foundation

struct GroqChatRequest: Encodable {
    let model: String
    let messages: [GroqMessage]
    let temperature: Double
    let max_tokens: Int?
    let stream: Bool
}

struct GroqMessage: Codable {
    let role: String
    let content: String
}

struct GroqChatResponse: Decodable {
    let choices: [GroqChoice]
}

struct GroqChoice: Decodable {
    let message: GroqMessage
}
