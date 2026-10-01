import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// A developer screen that streams a small structured result from the model, to check guided
/// generation, streaming and the library tool on a real device (#8). Debug builds only, so its
/// labels aren't localized.
public struct IntelligenceDebugView: View {
    @State private var status: IntelligenceStatus
    @State private var focus = "legs and hips"
    @State private var partial: WarmUpProbe.PartiallyGenerated?
    @State private var result: WarmUpProbe?
    @State private var error: IntelligenceError?
    @State private var task: Task<Void, Never>?
    @State private var elapsed: Duration?
    let library: ExerciseLibrary

    public init(service: any IntelligenceService, library: ExerciseLibrary = .bundled) {
        _status = State(initialValue: IntelligenceStatus(service: service))
        self.library = library
    }

    public var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text(verbatim: "\(status.availability)")
                } label: {
                    Text(verbatim: status.service.providerName)
                }
                IntelligenceNotice(availability: status.availability)
            }
            Section {
                TextField(text: $focus) {
                    Text(verbatim: "Session focus")
                }
                if task == nil {
                    Button {
                        run()
                    } label: {
                        Text(verbatim: "Stream a warm-up")
                    }
                    .disabled(!status.availability.canGenerate)
                } else {
                    Button(role: .cancel) {
                        task?.cancel()
                    } label: {
                        Text(verbatim: "Cancel")
                    }
                }
            }
            if let title = result?.title ?? partial?.title {
                Section {
                    ForEach(Array(moves.enumerated()), id: \.offset) { _, move in
                        LabeledContent {
                            Text(verbatim: move.dose)
                        } label: {
                            Text(verbatim: move.name)
                        }
                    }
                } header: {
                    Text(verbatim: title)
                } footer: {
                    if let elapsed {
                        Text(
                            verbatim:
                                "Done in \(elapsed.formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1))))"
                        )
                    }
                }
            }
            if let error {
                Section {
                    Text(error.message)
                    Text(verbatim: "\(error)")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.brandText(\.subtext))
                }
            }
        }
        .navigationTitle(Text(verbatim: "Apple Intelligence"))
        .task { await status.watch() }
    }

    private var moves: [(name: String, dose: String)] {
        if let result {
            return result.moves.map { (name(for: $0.exerciseID), $0.dose) }
        }
        return (partial?.moves ?? []).map { (name(for: $0.exerciseID), $0.dose ?? "…") }
    }

    private func name(for id: String?) -> String {
        guard let id else { return "…" }
        return library.exercise(id: id)?.name ?? "Unknown id: \(id)"
    }

    private func run() {
        partial = nil
        result = nil
        error = nil
        elapsed = nil
        let request = WarmUpProbe.request(focus: focus, library: library)
        let service = status.service
        task = Task {
            let clock = ContinuousClock()
            let start = clock.now
            do {
                for try await update in service.stream(request, generating: WarmUpProbe.self) {
                    switch update {
                    case .partial(let snapshot): partial = snapshot
                    case .complete(let content): result = content
                    }
                }
                elapsed = clock.now - start
            } catch let failure as IntelligenceError {
                error = failure
            } catch is CancellationError {
            } catch {
                self.error = .failed(detail: "\(error)")
            }
            task = nil
        }
    }
}
