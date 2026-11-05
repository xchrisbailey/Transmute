#if os(iOS)
    import AVFAudio
    import SwiftUI
    import TransmuteCore
    import TransmuteUI
    import WebKit

    struct ExerciseDemoSheet: View {
        let exercise: LoggedExercise
        @State private var demo: SessionDemo
        @State private var player: YouTubeDemoPlayer
        @Environment(\.scenePhase) private var scenePhase
        @Environment(\.dismiss) private var dismiss

        init(workout: Workout, exercise: LoggedExercise, library: ExerciseLibrary) {
            self.exercise = exercise
            let player = YouTubeDemoPlayer()
            _player = State(initialValue: player)
            _demo = State(initialValue: SessionDemo(workout: workout, library: library, player: player))
        }

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let webView = player.webView {
                            PlayerSurface(webView: webView)
                                .id(ObjectIdentifier(webView))
                                .frame(minWidth: 200, maxWidth: .infinity)
                                .frame(height: 270)
                                .accessibilityLabel(Text(DemoCopy.player))
                        }
                        playerControls
                        if let association = demo.association {
                            Text(DemoCopy.equipment).font(.headline)
                            let equipment = association.equipment.sorted(by: { $0.rawValue < $1.rawValue })
                            ForEach(equipment, id: \.self) { equipment in
                                Text(equipment.label)
                            }
                        }
                        Text(DemoCopy.cues).font(.headline).accessibilityAddTraits(.isHeader)
                        ForEach(Array(demo.cues.enumerated()), id: \.offset) { _, cue in
                            Text(verbatim: cue).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text(DemoCopy.disclosure).font(.footnote)
                        Link(destination: URL(string: "https://www.youtube.com/t/terms")!) {
                            Text(DemoCopy.terms)
                        }
                        Link(destination: URL(string: "https://policies.google.com/privacy")!) {
                            Text(DemoCopy.privacy)
                        }
                    }
                    .padding()
                }
                .navigationTitle(Text(verbatim: demo.name))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            demo.dismiss()
                            dismiss()
                        } label: {
                            Text(DemoCopy.close)
                        }
                    }
                }
            }
            .presentationDetents([.large])
            .onAppear {
                if !demo.open(exercise) { dismiss() }
                demo.setSceneActive(scenePhase == .active)
            }
            .onDisappear { demo.dismiss() }
            .onChange(of: scenePhase) { _, phase in demo.setSceneActive(phase == .active) }
            .onReceive(interruptions, perform: interruption)
        }

        private var interruptions: NotificationCenter.Publisher {
            NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
        }

        private func interruption(_ notification: Notification) {
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: raw)
            else { return }
            demo.setInterrupted(type == .began)
        }

        @ViewBuilder private var playerControls: some View {
            switch demo.phase {
            case .loading:
                ProgressView { Text(DemoCopy.loading) }
            case .unavailable:
                Text(DemoCopy.unavailable)
                Button {
                    demo.retry()
                } label: {
                    Text(DemoCopy.retry)
                }
            case .ready, .paused:
                Button {
                    demo.play()
                } label: {
                    Text(DemoCopy.play)
                }
                .disabled(scenePhase != .active || player.webView == nil)
            case .playing:
                EmptyView()
            }
        }
    }

    private struct PlayerSurface: UIViewRepresentable {
        let webView: WKWebView

        func makeUIView(context: Context) -> WKWebView { webView }
        func updateUIView(_ uiView: WKWebView, context: Context) {}
    }
#endif
