import SwiftUI

struct UnplugView: View {
    @State private var isLoading: Bool = false // Controls loading spinner
    @State private var aiResponse: String = "" // Stores the AI's generated text
    @State private var showResponse: Bool = false // Controls visibility of the response area

    var body: some View {
        ZStack {
            // Background Color (optional, but gives a calm feel)
            Color.white.ignoresSafeArea()

            VStack {
                Spacer() // Pushes content towards the center/top

                // MARK: - Title and Description
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
                    triggerAIResponse()
                } label: {
                    Text("I have an urge!")
                        .font(.largeTitle) // Make the text in the button very prominent
                        .fontWeight(.heavy)
                        .foregroundColor(.white)
                        .padding(.vertical, 40) // Make the button taller
                        .padding(.horizontal, 30) // Make the button wider
                        .background(
                            LinearGradient(
                                colors: [Color.red.opacity(0.8), Color.red], // A nice gradient for the SOS feel
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(35) // Rounded corners
                        .shadow(color: .red.opacity(0.4), radius: 15, x: 0, y: 10) // Subtle shadow
                }
                .disabled(isLoading) // Disable button while AI is "thinking"
                .scaleEffect(isLoading ? 0.95 : 1.0) // Small animation when disabled
                .animation(.spring(), value: isLoading) // Smooth animation

                Spacer() // Pushes content towards the center/bottom

                // MARK: - AI Response Area
                if isLoading {
                    ProgressView("Thinking...")
                        .font(.title2)
                        .padding()
                        .transition(.opacity) // Smooth fade in
                } else if showResponse {
                    ScrollView { // Use a ScrollView in case the response is long
                        Text(aiResponse)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.blue.opacity(0.1)) // A subtle background for the advice
                            .cornerRadius(20)
                            .padding(.horizontal)
                            .minimumScaleFactor(0.8) // Allow text to shrink if very long
                    }
                    .frame(maxHeight: 250) // Limit the height of the scrollable area
                    .transition(.opacity) // Smooth fade in
                }

                Spacer() // Pushes content further up if no response, or just provides space
            }
        }
    }

    // MARK: - AI Simulation Logic
    func triggerAIResponse() {
        isLoading = true
        showResponse = false // Hide previous response
        aiResponse = ""     // Clear previous response

        let compellingReasons = [
            "Think about what you truly want to achieve today. Is gaming aligned with that, or is there something more fulfilling waiting for your focus?",
            "You're in control. This urge is just a feeling, and you have the power to let it pass without acting on it. Embrace that power.",
            "Remember that incredible feeling after you accomplish something meaningful? That's what you're choosing over a quick, fleeting distraction.",
            "Consider the long-term benefits of not gaming right now: more energy, clearer mind, progress on your most important goals.",
            "Is this truly how you want to spend the next hour? Or is there a non-digital adventure or a productive task you've been putting off?"
        ]

        let nonDigitalActivities = [
            "**5-Minute Activity:** Stand up and stretch your entire body, reaching for the sky, touching your toes. Focus on your breath.",
            "**5-Minute Activity:** Go to a window. Name 5 things you can see, 4 things you can hear, 3 things you can smell, 2 things you can touch (your clothes, your hair), and 1 thing you can taste (the inside of your mouth).",
            "**5-Minute Activity:** Drink a large glass of water, slowly and mindfully. Notice the sensation.",
            "**5-Minute Activity:** Grab a pen and paper. Write down 3 things you are genuinely grateful for right now.",
            "**5-Minute Activity:** Do 10 push-ups or 20 jumping jacks. Get your heart rate up and feel your body.",
            "**5-Minute Activity:** Tidy up one small area around you – your desk, a table, or a shelf.",
            "**5-Minute Activity:** Pick up a physical book or magazine and read just one page.",
            "**5-Minute Activity:** Close your eyes and simply listen to the sounds around you for 2 minutes. What do you notice?"
        ]

        // Combine and pick randomly
        let allResponses = compellingReasons + nonDigitalActivities
        let selectedResponse = allResponses.randomElement() ?? "Take a deep breath and reassess your next action."

        // Simulate a network delay for the AI response (e.g., 2 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.aiResponse = selectedResponse
            self.isLoading = false
            withAnimation(.easeOut(duration: 0.5)) { // Animate the response appearing
                self.showResponse = true
            }
        }
    }
}

// MARK: - Preview Provider (for Xcode Canvas)
struct UnplugView_Previews: PreviewProvider {
    static var previews: some View {
        UnplugView()
    }
}
