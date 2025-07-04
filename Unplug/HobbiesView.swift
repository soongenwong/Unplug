import SwiftUI

struct HobbiesView: View {
    @State private var gamingLikes: String = ""
    @State private var hobbySuggestions: [String] = []
    @State private var isHobbiesLoading: Bool = false
    @State private var hobbyErrorMessage: String?

    private let groqAPIKey: String? // Store API key after loading it once

    // Initialize the View and load the API key (same as UnplugView)
    init() {
        if let secrets = Bundle.main.loadPlist(named: "Secrets") {
            self.groqAPIKey = secrets["GROQ_API_KEY"] as? String
        } else {
            self.groqAPIKey = nil
            print("WARNING: Groq API Key not found in Secrets.plist.")
        }
    }

    var body: some View {
        NavigationView { // Use NavigationView for a title bar
            VStack(spacing: 20) {
                Text("Find New Hobbies")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                    .padding(.bottom, 10)

                Text("What do you like about games?")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // MARK: - Text Input for Interests
                TextEditor(text: $gamingLikes)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .autocorrectionDisabled(true) // Gaming terms might be non-standard
                    .textInputAutocapitalization(.never) // Don't capitalize first letter unnecessarily
                    .scrollContentBackground(.hidden) // Makes the background visible
                    .overlay(alignment: .topLeading) {
                        if gamingLikes.isEmpty {
                            Text("e.g., strategy, competition, story, puzzles, crafting, teamwork...")
                                .foregroundColor(Color.gray.opacity(0.6))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                    }


                // MARK: - Generate Suggestions Button
                Button {
                    Task {
                        await triggerHobbySuggestions()
                    }
                } label: {
                    Text("Suggest Hobbies")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.vertical, 15)
                        .padding(.horizontal, 30)
                        .background(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.8), Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .disabled(isHobbiesLoading)
                .scaleEffect(isHobbiesLoading ? 0.95 : 1.0)
                .animation(.spring(), value: isHobbiesLoading)

                // MARK: - AI Response Area
                if isHobbiesLoading {
                    ProgressView("Generating ideas...")
                        .font(.title2)
                        .padding()
                        .transition(.opacity)
                } else if let error = hobbyErrorMessage {
                    Text("Error: \(error)")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                } else if !hobbySuggestions.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your New Quests:")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.bottom, 5)

                            ForEach(hobbySuggestions, id: \.self) { suggestion in
                                HStack(alignment: .top) {
                                    Image(systemName: "star.fill") // A little icon for each suggestion
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                        .offset(y: 3) // Align with text
                                    Text(suggestion)
                                        .font(.body)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal)
                    }
                    .transition(.opacity)
                    .frame(maxHeight: 300) // Limit height for scrolling
                }

                Spacer()
            }
            .padding(.top) // Add some padding from the top edge
            // .navigationTitle("New Hobbies") // If you want a navigation bar title
            // .navigationBarHidden(true) // If you want to hide the navigation bar completely
        }
    }

    // MARK: - Groq API Call Logic for Hobbies

    func triggerHobbySuggestions() async {
        await MainActor.run {
            isHobbiesLoading = true
            hobbySuggestions = []
            hobbyErrorMessage = nil
        }

        guard let apiKey = groqAPIKey, !apiKey.isEmpty else {
            await MainActor.run {
                hobbyErrorMessage = "API Key not found or empty. Please check secrets.plist."
                isHobbiesLoading = false
            }
            return
        }

        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else {
            await MainActor.run {
                hobbyErrorMessage = "Invalid API URL."
                isHobbiesLoading = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // The specific prompt for hobby suggestions
        let userLikesInput = gamingLikes.isEmpty ? "general interests like learning, being productive, or being creative" : gamingLikes
        let systemPrompt = "You are a creative and helpful assistant specialized in suggesting real-life hobbies and activities. Provide concise, actionable suggestions. Format your response as a numbered list."
        let userPrompt = "I need to replace my gaming habit. The things I like about games are \(userLikesInput). Suggest three real-life hobbies or 'quests' I could start. Each suggestion should be brief and actionable."

        let groqRequest = GroqChatRequest(
            model: "llama3-8b-8192", // Or "llama2-70b-8192" or "gemma-7b-it"
            messages: [
                GroqMessage(role: "system", content: systemPrompt),
                GroqMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.8, // Slightly higher temperature for more creative suggestions
            max_tokens: 300,  // Enough tokens for three good suggestions
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
                    hobbyErrorMessage = "API request failed with status \(status). Response: \(responseBody.prefix(100))."
                    isHobbiesLoading = false
                }
                return
            }

            let groqResponse = try JSONDecoder().decode(GroqChatResponse.self, from: data)

            if let firstChoice = groqResponse.choices.first {
                let rawResponse = firstChoice.message.content
                // Parse the response into individual hobby suggestions
                // Assuming Groq returns a numbered list (1., 2., 3.) or lines of text
                let suggestions = rawResponse
                    .split(whereSeparator: \.isNewline) // Split by newlines
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } // Trim whitespace
                    .filter { !$0.isEmpty } // Remove empty lines
                    .map { line in // Remove leading numbers/dashes if present
                        let trimmedLine = line.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                                              .replacingOccurrences(of: #"^-+\s*"#, with: "", options: .regularExpression)
                        return trimmedLine
                    }

                await MainActor.run {
                    self.hobbySuggestions = suggestions
                }
            } else {
                await MainActor.run {
                    self.hobbyErrorMessage = "No response content from AI."
                }
            }

        } catch {
            print("API Error: \(error.localizedDescription)")
            await MainActor.run {
                self.hobbyErrorMessage = "Failed to get AI response: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            isHobbiesLoading = false
        }
    }
}

// MARK: - Preview Provider (for Xcode Canvas)
struct HobbiesView_Previews: PreviewProvider {
    static var previews: some View {
        HobbiesView()
    }
}
