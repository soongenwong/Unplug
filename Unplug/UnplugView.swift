import SwiftUI

// MARK: - API Key Loading Helper

// This extension makes it easy to load values from any custom plist file
extension Bundle {
    func loadPlist(named name: String) -> [String: Any]? {
        guard let url = self.url(forResource: name, withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else {
            print("Error: Could not find or load '\(name).plist'")
            return nil
        }
        return dict
    }
}

// MARK: - Groq API Data Structures (Codable)

// Request Body
struct GroqChatRequest: Encodable {
    let model: String
    let messages: [GroqMessage]
    let temperature: Double
    let max_tokens: Int? // Optional, good to limit response length
    let stream: Bool // Usually false for single shot responses
}

struct GroqMessage: Codable { // Codable because it's used in both request and response
    let role: String
    let content: String
}

// Response Body
struct GroqChatResponse: Decodable {
    let choices: [GroqChoice]
}

struct GroqChoice: Decodable {
    let message: GroqMessage
}

// MARK: - UnplugView (Modified)

struct UnplugView: View {
    @State private var isLoading: Bool = false
    @State private var aiResponse: String = ""
    @State private var showResponse: Bool = false
    @State private var errorMessage: String? // To show API errors

    // Store API key after loading it once
    private let groqAPIKey: String?

    // Initialize the View and load the API key
    init() {
        if let secrets = Bundle.main.loadPlist(named: "Secrets") {
            self.groqAPIKey = secrets["GROQ_API_KEY"] as? String
        } else {
            self.groqAPIKey = nil
            print("WARNING: Groq API Key not found in Secrets.plist.")
        }
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack {
                Spacer()

                Text("Unplug")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)

                Text("Feeling an urge to game? Tap the button for an immediate break.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 60)

                // MARK: - The "SOS" Button
                Button {
                    // Use Task {} to call the async function from a synchronous button action
                    Task {
                        await triggerAIResponse()
                    }
                } label: {
                    Text("I have an urge!")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(.white)
                        .padding(.vertical, 40)
                        .padding(.horizontal, 30)
                        .background(
                            LinearGradient(
                                colors: [Color.red.opacity(0.8), Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(35)
                        .shadow(color: .red.opacity(0.4), radius: 15, x: 0, y: 10)
                }
                .disabled(isLoading)
                .scaleEffect(isLoading ? 0.95 : 1.0)
                .animation(.spring(), value: isLoading)

                Spacer()

                // MARK: - AI Response Area
                if isLoading {
                    ProgressView("Thinking...")
                        .font(.title2)
                        .padding()
                        .transition(.opacity)
                } else if showResponse {
                    ScrollView {
                        Text(aiResponse)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(20)
                            .padding(.horizontal)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxHeight: 250)
                    .transition(.opacity)
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

                Spacer()
            }
        }
    }

    // MARK: - Groq API Call Logic

    func triggerAIResponse() async {
        // Ensure UI updates are on the main actor
        await MainActor.run {
            isLoading = true
            showResponse = false
            aiResponse = ""
            errorMessage = nil
        }

        guard let apiKey = groqAPIKey, !apiKey.isEmpty else {
            await MainActor.run {
                errorMessage = "API Key not found or empty. Please check Secrets.plist."
                isLoading = false
            }
            return
        }

        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            await MainActor.run {
                errorMessage = "Invalid API URL."
                isLoading = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // The prompt for the AI
        let userPrompt = "I feel a strong urge to start gaming. Give me a compelling reason not to, or a 5-minute, non-digital activity I can do right now to break the impulse. Be concise and actionable."

        let groqRequest = GroqChatRequest(
            model: "llama3-8b-8192", // You can try "llama2-70b-8192" or other models
            messages: [
                GroqMessage(role: "system", content: "You are a helpful assistant for breaking digital habits."),
                GroqMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.7,
            max_tokens: 200, // Limit response length
            stream: false
        )

        do {
            request.httpBody = try JSONEncoder().encode(groqRequest)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                print("HTTP Error: Status \(status), Body: \(responseBody)")
                await MainActor.run {
                    errorMessage = "API request failed with status \(status). Response: \(responseBody.prefix(100))."
                    isLoading = false
                }
                return
            }

            let groqResponse = try JSONDecoder().decode(GroqChatResponse.self, from: data)

            if let firstChoice = groqResponse.choices.first {
                await MainActor.run {
                    self.aiResponse = firstChoice.message.content
                    self.showResponse = true
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "No response content from AI."
                }
            }

        } catch {
            print("API Error: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to get AI response: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }
}

// MARK: - Preview Provider (for Xcode Canvas)
struct UnplugView_Previews: PreviewProvider {
    static var previews: some View {
        UnplugView()
    }
}
