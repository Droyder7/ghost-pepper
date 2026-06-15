import Foundation
import FoundationModels

@available(macOS 26.0, *)
final class AppleFoundationCleanupBackend: CleanupBackend {
    private let model: SystemLanguageModel
    
    init(permissive: Bool = false) {
        self.model = SystemLanguageModel(
            guardrails: permissive ? .permissiveContentTransformations : .default
        )
    }
    
    func clean(text: String, prompt: String, modelKind: LocalCleanupModelKind?) async throws -> String {
        guard let isAvailable = try? await model.isAvailable, isAvailable else {
            throw CleanupBackendError.unavailable
        }
        
        // 1. Build Transcript with Instructions (System Prompt)
        let systemSegment = Transcript.TextSegment(content: prompt)
        let instructions = Transcript.Instructions(segments: [.text(systemSegment)])
        
        // 2. Build User Prompt
        let userSegment = Transcript.TextSegment(content: text)
        let userPrompt = Transcript.Prompt(segments: [.text(userSegment)])
        
        // 3. Create Session with Instructions and Prompt
        let transcript = Transcript(entries: [.instructions(instructions), .prompt(userPrompt)])
        let session = LanguageModelSession(model: model, transcript: transcript)
        
        do {
            var fullResponse = ""
            // AFM uses async sequence for streaming responses
            for try await piece in session.generateResponse() {
                fullResponse += piece.text
            }
            
            let trimmed = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw CleanupBackendError.unusableOutput(rawOutput: fullResponse)
            }
            
            return trimmed
        } catch {
            // Map AFM specific errors to CleanupBackendError if needed, 
            // or just let them propagate if they aren't part of the protocol yet.
            // For now, treat unknown errors as unavailable to trigger fallback.
            throw CleanupBackendError.unavailable
        }
    }
}
