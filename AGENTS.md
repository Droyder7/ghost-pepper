# Ghost Pepper Agent Instructions

Guidance for AI agents working on the Ghost Pepper codebase, specifically the cleanup model implementation and LLM-based text correction.

## Project Overview
Ghost Pepper is a macOS transcription and text cleanup tool. It uses local LLMs (Qwen 3.5 variants) to refine raw transcriptions with OCR context and deterministic rules.

## Core Cleanup Architecture
The cleanup system is split into three layers:
- [CleanupModelProbe](CleanupModelProbe/main.swift): CLI harness for testing the cleanup pipeline.
- [CleanupModelProbeSupport](CleanupModelProbeSupport/Cleanup/): Core cleanup logic (prompt building, model management, deterministic rules).
- [GhostPepper/Cleanup](GhostPepper/Cleanup/): App integration layer (shared files with `CleanupModelProbeSupport`).

### Key Components
- [TextCleanupManager](CleanupModelProbeSupport/Cleanup/TextCleanupManager.swift): Manages model lifecycle and selection (`0.8B`, `2B`, `4B` Qwen variants).
- [CleanupPromptBuilder](CleanupModelProbeSupport/Cleanup/CleanupPromptBuilder.swift): Dynamically assembles the LLM prompt with OCR context (`<WINDOW-OCR-CONTENT>`) and deterministic corrections.
- [DeterministicCorrectionEngine](CleanupModelProbeSupport/Cleanup/DeterministicCorrectionEngine.swift): Regex-based phrase protection and replacement applied *before* the LLM.
- [TextCleaner](CleanupModelProbeSupport/Cleanup/TextCleaner.swift): Contains the [default system prompt](CleanupModelProbeSupport/Cleanup/TextCleaner.swift#L77-L140) (10 rules) and output sanitization (`<think>` tag removal).

## Development Workflow

### Build & Test Commands
Run these from the workspace root:

```bash
# Test cleanup pipeline via CLI probe
./scripts/cleanup-model-probe.sh --model fast --input "Is this running?" --thinking none

# Run interactive probe with thinking suppressed
./scripts/cleanup-model-probe.sh --model fast --thinking suppressed

# Run all tests
xcodebuild -scheme GhostPepperTests test

# Build the CLI probe directly
xcodebuild -project GhostPepper.xcodeproj -scheme CleanupModelProbe build
```

### Conventions & Pitfalls
- **Phrase Protection:** [DeterministicCorrectionEngine](CleanupModelProbeSupport/Cleanup/DeterministicCorrectionEngine.swift) uses Unicode word-boundary regex (`(?<![\\p{L}\\p{N}])`) to prevent partial word mangling.
- **Deterministic Priority:** Corrections are applied *before* the LLM. Aggressive rules in [CorrectionStore](CleanupModelProbeSupport/Cleanup/CorrectionStore.swift) can override LLM context.
- **OCR Constraints:** [CleanupPromptBuilder](CleanupModelProbeSupport/Cleanup/CleanupPromptBuilder.swift) limits OCR context to 4000 characters. OCR is for disambiguation, not rewriting.
- **Output Sanitization:** Always use [TextCleaner.sanitizeCleanupOutput](CleanupModelProbeSupport/Cleanup/TextCleaner.swift#L31) to strip model `<think>` blocks.

## Documentation Links
- [Cleanup Probe Guide](docs/development.md): Detailed CLI usage and examples.
- [Models & Performance](README.md#cleanup-models): Model sizes, speeds, and dependencies.
- [Cleanup Tests](GhostPepperTests/CleanupBackendTests.swift): Exemplars of expected cleanup behavior.
