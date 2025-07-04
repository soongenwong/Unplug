import SwiftUI

// MARK: - API Key Loading Helper (from previous iteration)
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

// MARK: - UnplugView (Modified with Streak)

struct UnplugView: View {
    @State private var isLoading: Bool = false
    @State private var aiResponse: String = ""
    @State private var showResponse: Bool = false
    @State private var errorMessage: String?

    // MARK: - Streak Properties using @AppStorage
    // @AppStorage automatically reads from/writes to UserDefaults
    @AppStorage("currentStreak") private var currentStreak: Int = 0
    // We store Date as Data because AppStorage doesn't directly support Date.
    // We'll encode/decode it manually.
    @AppStorage("lastUnplugDateData") private var lastUnplugDateData: Data?

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
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack {
                    Spacer()

                    Text("Unplug")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.bottom, 10)

                    Text("Feeling an urge to game? Tap the button for an immediate break.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 30) // Adjusted padding

                    // MARK: - Streak Display
                    HStack {
                        Image(systemName: "flame.fill") // Fire emoji for streak
                            .font(.title2)
                            .foregroundColor(.orange)
                        Text("Streak: \(currentStreak) days / 90 days")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                    .padding(.bottom, 30)

                    NavigationLink(destination: HobbiesView()) {
                        Label("Explore Hobbies", systemImage: "sparkles.magnifyingglass")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.vertical, 15)
                            .padding(.horizontal, 30)
                            .background(LinearGradient(colors: [Color.purple.opacity(0.85), Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(25)
                            .shadow(color: .purple.opacity(0.25), radius: 10, x: 0, y: 5)
                    }
                    .padding(.bottom, 16)

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
    }

    // MARK: - Groq API Call Logic (Modified to call updateStreak)

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
                errorMessage = "API Key not found or empty. Please check secrets.plist."
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
        let userPrompt = "I feel a strong urge to start gaming. Give me a concise, compelling reason not to, or a single 5-minute, non-digital activity I can do right now to break the impulse. Start directly with the reason or activity."

        let groqRequest = GroqChatRequest(
            model: "llama3-8b-8192",
            messages: [
                GroqMessage(role: "system", content: "You are a helpful assistant for breaking digital habits. Your responses are direct and actionable."),
                GroqMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.7,
            max_tokens: 150, // Slightly reduced for conciseness
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
                    // IMPORTANT: Update the streak only after a successful response
                    self.updateStreak()
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

    // MARK: - Streak Logic

    private func updateStreak() {
        let calendar = Calendar.current
        // Get today's date at the start of the day (no time component)
        let today = calendar.startOfDay(for: Date())

        var lastUnplugDate: Date? = nil
        // Attempt to decode the last stored date
        if let data = lastUnplugDateData {
            lastUnplugDate = try? JSONDecoder().decode(Date.self, from: data)
        }

        if let lastDate = lastUnplugDate {
            // Get the last recorded date at the start of its day
            let lastDay = calendar.startOfDay(for: lastDate)

            if lastDay == today {
                // User already unplugged today. Streak doesn't change.
                print("Already unplugged today. Streak: \(currentStreak)")
                return
            }

            // Check if today is exactly one day after the last unplugged day
            // This is how you continue a streak
            if let yesterday = calendar.date(byAdding: .day, value: 1, to: lastDay),
               yesterday == today {
                // Streak continues!
                currentStreak += 1
                print("Streak continued! New streak: \(currentStreak)")
            } else {
                // Streak broken (missed a day or more), reset to 1
                currentStreak = 1
                print("Streak broken. New streak: \(currentStreak)")
            }
        } else {
            // This is the very first time the user is unplugging. Start streak at 1.
            currentStreak = 1
            print("First unplug. Streak: \(currentStreak)")
        }

        // Save today's date as the last unplug date for the next check
        lastUnplugDateData = try? JSONEncoder().encode(today)
    }
}

// MARK: - Preview Provider (for Xcode Canvas)
struct UnplugView_Previews: PreviewProvider {
    static var previews: some View {
        UnplugView()
    }
}
